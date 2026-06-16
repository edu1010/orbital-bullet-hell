class_name DragonBoss
extends Node3D

# Score-triggered boss: every active enemy in the level is recruited into formation
# and flies into a serpentine line that recalls a Chinese dragon. A dedicated head
# leads the body and opens its jaws to fire a tracking laser. The dragon is beaten
# only by destroying the three exposed glowing red weak points (head / mid / tail),
# each with a lot of health; a boss health bar tracks the total. Killed body enemies
# are replaced (the boss keeps the body topped up) so the dragon stays whole.

@export var body_size := 60
@export var slot_spacing := 4
@export var head_speed := 10.0
@export var attack_head_speed := 3.5
@export var dragon_altitude := 9.0
@export var follow_bias := 0.16
# How fast the beam can rotate while firing. Kept below the player's running
# angular speed so a moving player can outrun the beam, while a still one gets hit.
# While firing, the beam aims at a point on the ground that chases the player's
# current ground position with a lag. Lower = more delay, so a moving player can
# stay ahead of the sweeping beam. Used as a lerp rate (per second).
@export var laser_follow_speed := 1.8
@export var weak_point_hp := 55
@export var weak_point_radius := 2.0
@export var float_out := 1.6
@export var laser_hit_radius := 1.8
@export var laser_range := 120.0
# The beam chips health instead of being an instant kill; apply_damage then grants
# invulnerability frames so standing in it drains you over time rather than at once.
@export var laser_damage := 2.0
# Seconds for the lethal beam to grow from the mouth out to the ground/wall, so the
# player sees it coming and can step out of the path.
@export var beam_extend_time := 0.55
@export var attack_interval_min := 10.0
@export var attack_interval_max := 20.0
@export var attack_windup := 0.9
@export var attack_fire_min := 2.0
@export var attack_fire_max := 4.0
@export var defeat_score_bonus := 25000
# Travelling ring "waves" along the beam, mirroring the player's extra shot.
@export var ripple_interval := 0.07
@export var ripple_spacing := 5.0
@export var ripple_scroll_speed := 26.0
@export var ripple_visible_range := 52.0

var manager: GameManager
var player: PlayerController
var active := false
var built := false

var sphere_center := Vector3.ZERO
var sphere_radius := 38.0
var inner_radius := 29.0
var head_position := Vector3.ZERO
var head_dir := Vector3.FORWARD
var trail: Array[Vector3] = []
var trail_capacity := 1
var slots: Array = []

var head_node: Node3D
var jaw_upper: Node3D
var jaw_lower: Node3D
var mouth_open := 0.0
var weak_points: Array = []

var laser_mesh: MeshInstance3D
var laser_material: StandardMaterial3D
var attack_timer := 0.0
var attack_phase := "idle"
var attack_time_left := 0.0
var aim_dir := Vector3.FORWARD
var topup_timer := 0.0
var ripple_timer := 0.0
var ripple_scroll := 0.0
var beam_progress := 0.0
var laser_target := Vector3.ZERO


func configure(_manager: GameManager, _player: PlayerController) -> void:
	manager = _manager
	player = _player
	visible = false
	set_process(true)


func is_active() -> bool:
	return active


func health_fraction() -> float:
	if weak_points.is_empty():
		return 0.0
	var current := 0
	var maximum := 0
	for weak_point in weak_points:
		current += maxi(0, int(weak_point["hp"]))
		maximum += weak_point_hp
	return float(current) / float(maxi(1, maximum))


func start() -> void:
	if not player:
		return
	sphere_center = player.sphere_center
	sphere_radius = player.sphere_radius
	inner_radius = max(6.0, sphere_radius - dragon_altitude)
	if not built:
		_build_visuals()
	var away: Vector3 = sphere_center - player.global_position
	if away.length_squared() <= 0.01:
		away = Vector3.FORWARD
	head_position = sphere_center + away.normalized() * inner_radius
	var radial: Vector3 = (head_position - sphere_center).normalized()
	head_dir = radial.cross(Vector3.UP)
	if head_dir.length_squared() <= 0.01:
		head_dir = radial.cross(Vector3.RIGHT)
	head_dir = head_dir.normalized()
	trail_capacity = (body_size + 2) * slot_spacing
	trail.clear()
	for i in range(trail_capacity):
		trail.append(head_position)
	for slot in slots:
		slot["enemy"] = null
	for weak_point in weak_points:
		weak_point["hp"] = weak_point_hp
		weak_point["alive"] = true
		_apply_weak_point_color(weak_point, true)
	mouth_open = 0.0
	attack_phase = "idle"
	attack_timer = randf_range(attack_interval_min * 0.5, attack_interval_max * 0.5)
	topup_timer = 0.0
	ripple_timer = 0.0
	ripple_scroll = 0.0
	beam_progress = 0.0
	laser_target = head_position
	aim_dir = head_dir
	laser_mesh.visible = false
	active = true
	visible = true
	_topup_slots()
	# Absorb any leftover enemies so the whole level is now the dragon.
	for enemy in manager.active_enemies:
		if enemy.active and not enemy.formation_active:
			manager.spawn_burst(enemy.global_position, Color(1.0, 0.6, 0.2), enemy.body_radius * 1.4, 0.18)
			enemy.deactivate()
	if manager and manager.ui:
		manager.ui.boss_alert("boss_incoming")
		manager.spawn_burst(head_position, Color(1.0, 0.5, 0.15), 8.0, 0.7)


func stop() -> void:
	active = false
	visible = false
	if laser_mesh:
		laser_mesh.visible = false
	_release_all_enemies()


func _release_all_enemies() -> void:
	for slot in slots:
		var enemy: EnemyBase = slot["enemy"]
		if enemy and is_instance_valid(enemy) and enemy.active:
			enemy.exit_formation()
		slot["enemy"] = null


func _process(delta: float) -> void:
	if not active or not manager or not manager.is_playing():
		return
	_move_head(delta)
	trail.push_front(head_position)
	while trail.size() > trail_capacity:
		trail.pop_back()
	topup_timer -= delta
	if topup_timer <= 0.0:
		_topup_slots()
		topup_timer = 0.4
	_update_formation()
	_update_head()
	_update_weak_points(delta)
	_update_attack(delta)


func _move_head(delta: float) -> void:
	var radial: Vector3 = (head_position - sphere_center).normalized()
	var speed: float = attack_head_speed if attack_phase == "fire" else head_speed
	var to_player: Vector3 = player.global_position - head_position
	var to_player_tangent: Vector3 = to_player - radial * to_player.dot(radial)
	var desired: Vector3 = head_dir
	if to_player_tangent.length() > 0.05:
		desired = (head_dir * (1.0 - follow_bias) + to_player_tangent.normalized() * follow_bias).normalized()
	head_dir = head_dir.slerp(desired, clamp(1.4 * delta, 0.0, 1.0))
	head_dir = (head_dir - radial * head_dir.dot(radial)).normalized()
	head_position += head_dir * speed * delta
	head_position = sphere_center + (head_position - sphere_center).normalized() * inner_radius


func _trail_point(sample_index: int) -> Vector3:
	var clamped: int = clampi(sample_index, 0, trail.size() - 1)
	var point: Vector3 = trail[clamped]
	return sphere_center + (point - sphere_center).normalized() * inner_radius


func _topup_slots() -> void:
	# Free slots whose enemy died or left formation, then refill from the live swarm,
	# spawning replacements when the swarm runs short so the body stays full.
	for slot in slots:
		var enemy: EnemyBase = slot["enemy"]
		if enemy == null or not is_instance_valid(enemy) or not enemy.active or not enemy.formation_active:
			slot["enemy"] = null
	var recruits: Array = []
	for enemy in manager.active_enemies:
		if enemy.active and not enemy.formation_active:
			recruits.append(enemy)
	var recruit_index := 0
	for slot in slots:
		if slot["enemy"] != null:
			continue
		var target: Vector3 = _trail_point(slot["sample_index"])
		var picked: EnemyBase = null
		while recruit_index < recruits.size():
			var candidate: EnemyBase = recruits[recruit_index]
			recruit_index += 1
			if candidate.active and not candidate.formation_active:
				picked = candidate
				break
		if picked == null:
			picked = manager.spawn_enemy("swarmer", target)
		if picked:
			picked.enter_formation()
			picked.set_formation_target(target)
			slot["enemy"] = picked


func _update_formation() -> void:
	for slot in slots:
		var enemy: EnemyBase = slot["enemy"]
		if enemy and is_instance_valid(enemy) and enemy.active and enemy.formation_active:
			enemy.set_formation_target(_trail_point(slot["sample_index"]))
		else:
			slot["enemy"] = null


func _update_head() -> void:
	if not head_node:
		return
	head_node.global_position = head_position
	var facing: Vector3 = aim_dir if attack_phase != "idle" else head_dir
	var look_target: Vector3 = head_position + facing
	if look_target.distance_squared_to(head_position) > 0.001:
		# Aiming at the player points roughly outward (along the radial), which would
		# make a radial "up" colinear with the look direction and break look_at; project
		# the radial onto the plane perpendicular to facing to keep a stable up vector.
		var up_hint: Vector3 = (head_position - sphere_center).normalized()
		up_hint = up_hint - facing * up_hint.dot(facing)
		if up_hint.length_squared() <= 0.001:
			up_hint = facing.cross(Vector3.RIGHT)
			if up_hint.length_squared() <= 0.001:
				up_hint = facing.cross(Vector3.UP)
		head_node.look_at(look_target, up_hint.normalized())
	if jaw_lower:
		jaw_lower.rotation.x = mouth_open * 0.6
	if jaw_upper:
		jaw_upper.rotation.x = -mouth_open * 0.35


func _update_weak_points(delta: float) -> void:
	for weak_point in weak_points:
		var root: Node3D = weak_point["root"]
		if weak_point["kind"] == "head" and head_node:
			# A crown gem above the brow, so the opening jaws stay visible below it.
			root.global_position = head_node.to_global(Vector3(0.0, 2.5, -0.3))
		else:
			var anchor_position: Vector3 = _weak_point_anchor(weak_point)
			var radial: Vector3 = (anchor_position - sphere_center).normalized()
			root.global_position = anchor_position + radial * float_out
		var ring_root: Node3D = weak_point["ring_root"]
		if ring_root:
			ring_root.rotation.y += delta * 2.4
			ring_root.rotation.z += delta * 1.3
		if weak_point["alive"]:
			weak_point["pulse"] = float(weak_point["pulse"]) + delta
			var pulse: float = 1.0 + sin(float(weak_point["pulse"]) * 5.0) * 0.12
			weak_point["mesh"].scale = Vector3.ONE * pulse


func _weak_point_anchor(weak_point: Dictionary) -> Vector3:
	match weak_point["kind"]:
		"head":
			return head_position
		"mid":
			return _trail_point(int(body_size / 2.0) * slot_spacing)
		_:
			return _trail_point(body_size * slot_spacing)


func _update_attack(delta: float) -> void:
	match attack_phase:
		"idle":
			mouth_open = lerp(mouth_open, 0.0, clamp(6.0 * delta, 0.0, 1.0))
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_phase = "windup"
				attack_time_left = attack_windup
				# During wind-up the aim snaps to the player's ground spot to telegraph it.
				laser_target = _player_ground_point()
				aim_dir = _aim_to(laser_target)
				laser_material.albedo_color = Color(1.0, 0.5, 0.2, 0.5)
				laser_material.emission = Color(1.0, 0.4, 0.15)
				laser_mesh.visible = true
		"windup":
			mouth_open = lerp(mouth_open, 1.0, clamp(5.0 * delta, 0.0, 1.0))
			attack_time_left -= delta
			laser_target = _player_ground_point()
			aim_dir = _aim_to(laser_target)
			# Thin aiming line all the way to the ground so the target path is telegraphed.
			_update_laser_visual(0.16, _beam_length_to_wall())
			if attack_time_left <= 0.0:
				attack_phase = "fire"
				attack_time_left = randf_range(attack_fire_min, attack_fire_max)
				beam_progress = 0.0
				# Lock the strike onto the ground where the player stands right now; the
				# fire phase then drags this point after the player with a lag.
				laser_target = _player_ground_point()
				laser_material.albedo_color = Color(1.0, 0.12, 0.08, 0.95)
				laser_material.emission = Color(1.0, 0.18, 0.12)
				if manager:
					manager.spawn_burst(head_position, Color(1.0, 0.25, 0.12), 3.0, 0.3)
		"fire":
			mouth_open = 1.0
			attack_time_left -= delta
			# Chase the player's current ground spot, but only a fraction per frame, so
			# the impact point (and the head following it) trails behind the player.
			var follow: float = clamp(laser_follow_speed * delta, 0.0, 1.0)
			laser_target = laser_target.lerp(_player_ground_point(), follow)
			laser_target = sphere_center + (laser_target - sphere_center).normalized() * sphere_radius
			aim_dir = _aim_to(laser_target)
			# The lethal beam grows from the mouth out to the ground over beam_extend_time,
			# and only the part that has been reached can hurt the player.
			beam_progress = min(1.0, beam_progress + delta / max(0.01, beam_extend_time))
			var current_length: float = _beam_length_to_wall() * beam_progress
			_update_laser_visual(0.7, current_length)
			_emit_laser_ripples(delta, current_length)
			_apply_laser_damage(current_length)
			if attack_time_left <= 0.0:
				attack_phase = "idle"
				attack_timer = randf_range(attack_interval_min, attack_interval_max)
				laser_mesh.visible = false


func _player_ground_point() -> Vector3:
	# The spot on the arena floor (sphere wall) directly under the player, which is
	# what the beam scorches.
	var radial: Vector3 = player.global_position - sphere_center
	if radial.length_squared() <= 0.001:
		return player.global_position
	return sphere_center + radial.normalized() * sphere_radius


func _aim_to(target: Vector3) -> Vector3:
	var to_target: Vector3 = target - _mouth_origin()
	if to_target.length_squared() <= 0.001:
		return aim_dir
	return to_target.normalized()


func _mouth_origin() -> Vector3:
	# Anchor to the gap between the jaws (front of the snout, slightly low) so the
	# beam visibly leaves the open mouth rather than the centre of the skull.
	if head_node:
		return head_node.to_global(Vector3(0.0, -0.25, -2.7))
	var facing: Vector3 = aim_dir if attack_phase != "idle" else head_dir
	return head_position + facing * 2.0


func _update_laser_visual(width: float, length: float) -> void:
	var beam_length: float = max(0.01, length)
	var origin: Vector3 = _mouth_origin()
	var y_axis: Vector3 = aim_dir
	var x_axis: Vector3 = y_axis.cross(Vector3.UP)
	if x_axis.length_squared() <= 0.001:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	# Scale the local axes directly (cylinder height runs along local Y = aim_dir).
	# Basis(...).scaled() premultiplies, scaling in WORLD axes, which shears a beam
	# aimed off the vertical into a streak along world up; bake the scale into the columns.
	var beam_basis := Basis(x_axis * width, y_axis * beam_length, z_axis * width)
	laser_mesh.global_transform = Transform3D(beam_basis, origin + aim_dir * beam_length * 0.5)


func _beam_length_to_wall() -> float:
	# Distance from the mouth along the aim direction to where the beam exits the
	# spherical arena (the ground the player stands on), capped at laser_range.
	var origin: Vector3 = _mouth_origin()
	var oc: Vector3 = origin - sphere_center
	var b: float = 2.0 * oc.dot(aim_dir)
	var c: float = oc.dot(oc) - sphere_radius * sphere_radius
	var disc: float = b * b - 4.0 * c
	if disc <= 0.0:
		return laser_range
	var t: float = (-b + sqrt(disc)) * 0.5
	if t <= 0.0:
		return laser_range
	return min(laser_range, t)


func _emit_laser_ripples(delta: float, max_distance: float) -> void:
	# Pulse small expanding rings down the beam, scrolling outward so they read as
	# waves travelling from the mouth toward the player (like the player's extra shot).
	if not manager:
		return
	ripple_scroll = fmod(ripple_scroll + delta * ripple_scroll_speed, ripple_spacing)
	ripple_timer -= delta
	if ripple_timer > 0.0:
		return
	ripple_timer = ripple_interval
	var origin: Vector3 = _mouth_origin()
	var visible_range: float = min(min(laser_range, ripple_visible_range), max_distance)
	if visible_range <= 1.0:
		return
	var ripple_color := Color(1.0, 0.4, 0.16, 0.9)
	var dist: float = ripple_scroll + 1.0
	while dist <= visible_range:
		var t: float = dist / visible_range
		var ring_position: Vector3 = origin + aim_dir * dist
		var ring_end_radius: float = lerp(0.45, 1.5, t)
		manager.spawn_laser_ring(ring_position, aim_dir, 0.12, ring_end_radius, ripple_color, lerp(0.16, 0.3, t))
		dist += ripple_spacing


func _apply_laser_damage(max_distance: float) -> void:
	if not player or player.is_dead():
		return
	var origin: Vector3 = _mouth_origin()
	var to_player: Vector3 = player.global_position - origin
	var along: float = to_player.dot(aim_dir)
	# Only the stretch the beam has already extended over can hurt you, so the growing
	# tip has to actually reach the player before it deals damage.
	if along < 0.0 or along > max_distance:
		return
	var closest: Vector3 = origin + aim_dir * along
	if player.global_position.distance_to(closest) <= laser_hit_radius + 0.6:
		player.apply_damage(laser_damage, origin)


func try_hit(hit_position: Vector3, radius: float) -> bool:
	if not active:
		return false
	for weak_point in weak_points:
		if not weak_point["alive"]:
			continue
		var root: Node3D = weak_point["root"]
		if root.global_position.distance_to(hit_position) <= weak_point_radius + radius:
			_damage_weak_point(weak_point, 1)
			return true
	return false


func try_beam_hit(origin: Vector3, direction: Vector3, radius: float, beam_range: float) -> void:
	if not active:
		return
	for weak_point in weak_points:
		if not weak_point["alive"]:
			continue
		var root: Node3D = weak_point["root"]
		var to_point: Vector3 = root.global_position - origin
		var along: float = to_point.dot(direction)
		if along < -1.0 or along > beam_range:
			continue
		var closest: Vector3 = origin + direction * along
		if root.global_position.distance_to(closest) <= weak_point_radius + radius:
			_damage_weak_point(weak_point, 4)


func _damage_weak_point(weak_point: Dictionary, amount: int) -> void:
	weak_point["hp"] = int(weak_point["hp"]) - amount
	var root: Node3D = weak_point["root"]
	if manager:
		manager.spawn_burst(root.global_position, Color(1.0, 0.25, 0.15), weak_point_radius * 1.2, 0.16)
	if int(weak_point["hp"]) <= 0:
		weak_point["alive"] = false
		weak_point["mesh"].scale = Vector3.ONE
		_apply_weak_point_color(weak_point, false)
		if manager:
			manager.spawn_burst(root.global_position, Color(1.0, 0.85, 0.4), weak_point_radius * 2.6, 0.55)
		_check_defeat()


func _check_defeat() -> void:
	for weak_point in weak_points:
		if weak_point["alive"]:
			return
	_defeat()


func _defeat() -> void:
	active = false
	visible = false
	laser_mesh.visible = false
	_release_all_enemies()
	if manager:
		manager.add_boss_reward(defeat_score_bonus)
		manager.spawn_burst(head_position, Color(1.0, 0.8, 0.3), 14.0, 0.9)
		if manager.ui:
			manager.ui.boss_alert("boss_defeated")


# --- Visual construction ---------------------------------------------------

func _build_visuals() -> void:
	built = true

	var gold: StandardMaterial3D = _make_material(Color(0.85, 0.62, 0.18), Color(0.5, 0.32, 0.06), 0.6)
	var red: StandardMaterial3D = _make_material(Color(0.7, 0.14, 0.12), Color(0.45, 0.06, 0.05), 0.6)
	var mane: StandardMaterial3D = _make_material(Color(0.95, 0.85, 0.3), Color(0.8, 0.6, 0.15), 1.3)
	var teeth: StandardMaterial3D = _make_material(Color(0.95, 0.95, 0.88), Color(0.6, 0.6, 0.55), 0.5)

	head_node = Node3D.new()
	add_child(head_node)
	jaw_upper = Node3D.new()
	head_node.add_child(jaw_upper)
	jaw_lower = Node3D.new()
	jaw_lower.position = Vector3(0.0, -0.1, 1.0)
	head_node.add_child(jaw_lower)

	# Upper skull (faces -Z), horns, mane and eyes.
	_add_mesh(jaw_upper, _box_mesh(Vector3(2.4, 1.7, 2.6)), gold, Vector3(0.0, 0.4, -0.6))
	_add_mesh(jaw_upper, _box_mesh(Vector3(1.9, 0.7, 1.6)), red, Vector3(0.0, 0.2, -2.0))
	for side in [-1.0, 1.0]:
		_add_mesh(jaw_upper, _cone_mesh(0.4, 2.0, 4), mane, Vector3(side * 0.9, 1.5, 0.4), Vector3(-22.0, 0.0, side * 12.0))
		_add_mesh(jaw_upper, _sphere_mesh(0.35), _make_material(Color(1.0, 0.9, 0.2), Color(1.0, 0.85, 0.1), 2.6), Vector3(side * 0.85, 0.6, -1.4))
		_add_mesh(jaw_upper, _cone_mesh(0.16, 0.5, 4), teeth, Vector3(side * 0.6, -0.45, -1.7), Vector3(180.0, 0.0, 0.0))
	# Lower jaw, hinged at the back so it swings open.
	_add_mesh(jaw_lower, _box_mesh(Vector3(2.0, 0.6, 2.4)), gold, Vector3(0.0, -0.3, -1.2))
	for side in [-1.0, 1.0]:
		_add_mesh(jaw_lower, _cone_mesh(0.15, 0.45, 4), teeth, Vector3(side * 0.6, 0.05, -1.9))

	_build_slots()
	_build_weak_points()
	_build_laser()


func _build_slots() -> void:
	slots.clear()
	for i in range(body_size):
		slots.append({"sample_index": (i + 1) * slot_spacing, "enemy": null})


func _build_weak_points() -> void:
	weak_points.clear()
	_make_weak_point("head")
	_make_weak_point("mid")
	_make_weak_point("tail")


func _make_weak_point(kind: String) -> void:
	var root := Node3D.new()
	add_child(root)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _sphere_mesh(weak_point_radius)
	var material := _make_weak_point_material()
	mesh.material_override = material
	root.add_child(mesh)
	var ring_root := Node3D.new()
	root.add_child(ring_root)
	var ring_material := _make_ring_material()
	_add_ring(ring_root, weak_point_radius * 1.7, weak_point_radius * 0.12, ring_material, Vector3.ZERO)
	_add_ring(ring_root, weak_point_radius * 2.1, weak_point_radius * 0.09, ring_material, Vector3(PI * 0.5, 0.0, 0.0))
	_add_ring(ring_root, weak_point_radius * 1.45, weak_point_radius * 0.08, ring_material, Vector3(0.0, PI * 0.5, PI * 0.25))
	weak_points.append({
		"kind": kind,
		"root": root,
		"mesh": mesh,
		"material": material,
		"ring_root": ring_root,
		"ring_material": ring_material,
		"hp": weak_point_hp,
		"alive": true,
		"pulse": randf_range(0.0, TAU),
	})


func _apply_weak_point_color(weak_point: Dictionary, alive: bool) -> void:
	var material: StandardMaterial3D = weak_point["material"]
	var ring_material: StandardMaterial3D = weak_point["ring_material"]
	if alive:
		material.albedo_color = Color(1.0, 0.12, 0.12)
		material.emission = Color(1.0, 0.2, 0.12)
		material.emission_energy_multiplier = 3.4
		ring_material.albedo_color = Color(1.0, 0.5, 0.3, 0.85)
		ring_material.emission = Color(1.0, 0.4, 0.2)
		ring_material.emission_energy_multiplier = 3.2
	else:
		material.albedo_color = Color(0.2, 0.21, 0.24)
		material.emission = Color(0.05, 0.05, 0.06)
		material.emission_energy_multiplier = 0.4
		ring_material.albedo_color = Color(0.25, 0.26, 0.3, 0.4)
		ring_material.emission = Color(0.05, 0.05, 0.06)
		ring_material.emission_energy_multiplier = 0.3


func _build_laser() -> void:
	laser_material = StandardMaterial3D.new()
	laser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	laser_material.albedo_color = Color(1.0, 0.12, 0.08, 0.9)
	laser_material.emission_enabled = true
	laser_material.emission = Color(1.0, 0.18, 0.12)
	laser_material.emission_energy_multiplier = 3.0
	laser_material.no_depth_test = true
	laser_material.render_priority = 4
	laser_mesh = MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 1.0
	beam.bottom_radius = 1.0
	beam.height = 1.0
	beam.radial_segments = 8
	laser_mesh.mesh = beam
	laser_mesh.material_override = laser_material
	laser_mesh.visible = false
	add_child(laser_mesh)


func _make_weak_point_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = 3
	material.emission_enabled = true
	material.albedo_color = Color(1.0, 0.12, 0.12)
	material.emission = Color(1.0, 0.2, 0.12)
	material.emission_energy_multiplier = 3.4
	return material


func _make_ring_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 3
	material.albedo_color = Color(1.0, 0.5, 0.3, 0.85)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.4, 0.2)
	material.emission_energy_multiplier = 3.2
	return material


func _add_ring(parent: Node3D, radius: float, half_width: float, material: Material, local_rotation: Vector3) -> void:
	var mesh := ImmediateMesh.new()
	var segments := 56
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var inner: float = radius - half_width
		var outer: float = radius + half_width
		var inner0 := Vector3(cos(a0) * inner, sin(a0) * inner, 0.0)
		var outer0 := Vector3(cos(a0) * outer, sin(a0) * outer, 0.0)
		var inner1 := Vector3(cos(a1) * inner, sin(a1) * inner, 0.0)
		var outer1 := Vector3(cos(a1) * outer, sin(a1) * outer, 0.0)
		mesh.surface_add_vertex(inner0)
		mesh.surface_add_vertex(outer0)
		mesh.surface_add_vertex(outer1)
		mesh.surface_add_vertex(inner0)
		mesh.surface_add_vertex(outer1)
		mesh.surface_add_vertex(inner1)
	mesh.surface_end()
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = material
	ring.rotation = local_rotation
	parent.add_child(ring)


func _make_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.6
	material.metallic = 0.35
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, local_position: Vector3, local_rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = local_position
	part.rotation_degrees = local_rotation_degrees
	parent.add_child(part)


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _cone_mesh(radius: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return mesh

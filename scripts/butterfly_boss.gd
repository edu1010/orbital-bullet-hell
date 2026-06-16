class_name ButterflyBoss
extends Node3D

# Third boss: the swarm gathers at the centre and forms a butterfly that faces the
# player. Four glowing red weak points sit on the wings (two per side). The wings
# beat quickly, and on every beat the butterfly releases damaging ring waves that
# sweep outward in several directions (like the heal waves, but they hurt you). The
# fast beat means a steady stream of waves, so the player has to fire fast and burst
# the four weak points down before being worn out.

@export var wing_span := 13.0
@export var wing_height := 9.0
@export var weak_point_hp := 22
@export var weak_point_radius := 1.7
@export var flap_speed := 6.0
@export var flap_reach := 0.5
@export var wave_interval := 0.7
@export var wave_damage := 1.0
@export var wave_thickness := 2.4
@export var wave_duration := 2.1
@export var wave_start_radius := 2.4
@export var defeat_score_bonus := 30000
@export var topup_interval := 1.4
@export var form_time := 1.4

var manager: GameManager
var player: PlayerController
var active := false
var built := false

var sphere_center := Vector3.ZERO
var sphere_radius := 38.0
var center := Vector3.ZERO

var slots: Array = []
var weak_points: Array = []
var waves: Array[Dictionary] = []
var topup_timer := 0.0
var flap_phase := 0.0
var wave_timer := 0.0
var wave_dir_index := 0
var form_timer := 0.0

# Cached orientation, refreshed each frame so the butterfly faces the player.
var wing_axis := Vector3.RIGHT
var body_up := Vector3.UP
var facing := Vector3.FORWARD


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
	center = sphere_center
	if not built:
		_build_slots()
		_build_weak_points()
		built = true
	for slot in slots:
		slot["enemy"] = null
	for weak_point in weak_points:
		weak_point["hp"] = weak_point_hp
		weak_point["alive"] = true
		_apply_weak_color(weak_point, true)
	waves.clear()
	flap_phase = 0.0
	wave_timer = wave_interval
	wave_dir_index = 0
	form_timer = form_time
	topup_timer = 0.0
	active = true
	visible = true
	_refresh_basis()
	_topup_slots()
	for enemy in manager.active_enemies:
		if enemy.active and not enemy.formation_active:
			manager.spawn_burst(enemy.global_position, Color(1.0, 0.5, 0.7), enemy.body_radius * 1.4, 0.18)
			enemy.deactivate()
	if manager and manager.ui:
		manager.ui.boss_alert("boss_incoming_butterfly")
		manager.spawn_burst(center, Color(1.0, 0.4, 0.7), 9.0, 0.7)


func stop() -> void:
	active = false
	visible = false
	waves.clear()
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
	_refresh_basis()
	flap_phase += flap_speed * delta
	topup_timer -= delta
	if topup_timer <= 0.0:
		_topup_slots()
		topup_timer = topup_interval
	_update_formation()
	_update_weak_points(delta)
	_update_waves(delta)
	if form_timer > 0.0:
		form_timer -= delta
	else:
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_timer = wave_interval
			_emit_wave_burst()


func _refresh_basis() -> void:
	var to_player: Vector3 = player.global_position - center
	facing = to_player.normalized() if to_player.length_squared() > 0.01 else Vector3.FORWARD
	var up_ref: Vector3 = center - sphere_center
	if up_ref.length_squared() <= 0.01:
		up_ref = Vector3.UP
	body_up = (up_ref - facing * up_ref.dot(facing))
	if body_up.length_squared() <= 0.01:
		body_up = facing.cross(Vector3.RIGHT)
	body_up = body_up.normalized()
	wing_axis = body_up.cross(facing).normalized()


func _slot_world(local: Vector2) -> Vector3:
	# local.x = spread along the wing axis, local.y = vertical along the body axis.
	# Wings beat by pushing their tips along the facing axis proportional to spread.
	var flap_offset: float = sin(flap_phase) * flap_reach * abs(local.x)
	return center + wing_axis * local.x + body_up * local.y + facing * flap_offset


func _build_slots() -> void:
	slots.clear()
	# Body: a short column down the middle.
	var body_points := 6
	for i in range(body_points):
		var y: float = lerp(-wing_height * 0.55, wing_height * 0.6, float(i) / float(body_points - 1))
		slots.append({"local": Vector2(0.0, y), "enemy": null})
	# Wings: sample a grid and keep points inside either lobe of each side.
	var steps := 9
	for side in [-1.0, 1.0]:
		for ix in range(1, steps + 1):
			for iy in range(steps):
				var wx: float = side * wing_span * float(ix) / float(steps)
				var wy: float = lerp(-wing_height, wing_height, float(iy) / float(steps - 1))
				if _inside_wing(abs(wx), wy):
					slots.append({"local": Vector2(wx, wy), "enemy": null})


func _inside_wing(ax: float, wy: float) -> bool:
	# Two stacked lobes per side make a rounded butterfly-wing silhouette.
	var upper := _inside_lobe(ax, wy, wing_span * 0.5, wing_height * 0.42, wing_span * 0.55, wing_height * 0.5)
	var lower := _inside_lobe(ax, wy, wing_span * 0.42, -wing_height * 0.42, wing_span * 0.46, wing_height * 0.42)
	return upper or lower


func _inside_lobe(ax: float, wy: float, cx: float, cy: float, rx: float, ry: float) -> bool:
	var dx: float = (ax - cx) / rx
	var dy: float = (wy - cy) / ry
	return dx * dx + dy * dy <= 1.0


func _topup_slots() -> void:
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
		var target: Vector3 = _slot_world(slot["local"])
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
			enemy.set_formation_target(_slot_world(slot["local"]))
		else:
			slot["enemy"] = null


func _update_weak_points(delta: float) -> void:
	for weak_point in weak_points:
		var root: Node3D = weak_point["root"]
		root.global_position = _slot_world(weak_point["local"])
		if weak_point["alive"]:
			weak_point["pulse"] = float(weak_point["pulse"]) + delta
			var pulse: float = 1.0 + sin(float(weak_point["pulse"]) * 6.0) * 0.14
			weak_point["mesh"].scale = Vector3.ONE * pulse


# --- Waves -----------------------------------------------------------------

func _emit_wave_burst() -> void:
	# Two waves per beat, fanned in directions that rotate each beat so they sweep
	# the arena from several angles over time.
	var base_angle: float = float(wave_dir_index) * 0.7
	wave_dir_index += 1
	for k in range(2):
		var angle: float = base_angle + (PI if k == 1 else 0.0)
		var normal: Vector3 = (wing_axis * cos(angle) + body_up * sin(angle)).normalized()
		_spawn_wave(normal)


func _spawn_wave(normal: Vector3) -> void:
	if normal.length_squared() <= 0.01:
		return
	var max_radius: float = sphere_radius * 2.0
	waves.append({
		"origin": center,
		"normal": normal.normalized(),
		"age": 0.0,
		"prev_radius": wave_start_radius,
		"max_radius": max_radius,
	})
	if manager:
		manager.spawn_laser_ring(center, normal, wave_start_radius, max_radius, Color(1.0, 0.3, 0.45, 0.95), wave_duration, 0.7, 0.026)


func _update_waves(delta: float) -> void:
	for i in range(waves.size() - 1, -1, -1):
		var wave: Dictionary = waves[i]
		var age: float = float(wave["age"]) + delta
		var max_radius: float = float(wave["max_radius"])
		var prev_radius: float = float(wave["prev_radius"])
		var progress: float = clamp(age / max(0.001, wave_duration), 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 2.0)
		var radius: float = lerp(wave_start_radius, max_radius, eased)
		_damage_player_with_wave(wave["origin"], wave["normal"], prev_radius, radius)
		if progress >= 1.0:
			waves.remove_at(i)
		else:
			wave["age"] = age
			wave["prev_radius"] = radius
			waves[i] = wave


func _damage_player_with_wave(origin: Vector3, normal: Vector3, previous_radius: float, current_radius: float) -> void:
	if not player or player.is_dead():
		return
	var offset: Vector3 = player.global_position - origin
	var contact: float = wave_thickness + 0.6
	if abs(offset.dot(normal)) > contact:
		return
	var radial_distance: float = offset.slide(normal).length()
	var min_radius: float = min(previous_radius, current_radius)
	var max_radius: float = max(previous_radius, current_radius)
	if radial_distance + contact < min_radius:
		return
	if radial_distance - contact > max_radius:
		return
	player.apply_damage(wave_damage, origin)


# --- Damage ----------------------------------------------------------------

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
		manager.spawn_burst(root.global_position, Color(1.0, 0.3, 0.45), weak_point_radius * 1.2, 0.16)
	if int(weak_point["hp"]) <= 0:
		weak_point["alive"] = false
		weak_point["mesh"].scale = Vector3.ONE
		_apply_weak_color(weak_point, false)
		if manager:
			manager.spawn_burst(root.global_position, Color(1.0, 0.85, 0.5), weak_point_radius * 2.4, 0.5)
		_check_defeat()


func _check_defeat() -> void:
	for weak_point in weak_points:
		if weak_point["alive"]:
			return
	_defeat()


func _defeat() -> void:
	active = false
	visible = false
	waves.clear()
	_release_all_enemies()
	if manager:
		manager.add_boss_reward(defeat_score_bonus)
		manager.spawn_burst(center, Color(1.0, 0.8, 0.5), 14.0, 0.9)
		if manager.ui:
			manager.ui.boss_alert("boss_defeated_butterfly")


# --- Visuals ---------------------------------------------------------------

func _build_weak_points() -> void:
	weak_points.clear()
	var positions := [
		Vector2(wing_span * 0.55, wing_height * 0.45),
		Vector2(wing_span * 0.5, -wing_height * 0.4),
		Vector2(-wing_span * 0.55, wing_height * 0.45),
		Vector2(-wing_span * 0.5, -wing_height * 0.4),
	]
	for local in positions:
		var root := Node3D.new()
		add_child(root)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		material.render_priority = 3
		material.emission_enabled = true
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = weak_point_radius
		sphere.height = weak_point_radius * 2.0
		sphere.radial_segments = 10
		sphere.rings = 6
		mesh.mesh = sphere
		mesh.material_override = material
		root.add_child(mesh)
		var weak_point := {
			"local": local,
			"root": root,
			"mesh": mesh,
			"material": material,
			"hp": weak_point_hp,
			"alive": true,
			"pulse": randf_range(0.0, TAU),
		}
		_apply_weak_color(weak_point, true)
		weak_points.append(weak_point)


func _apply_weak_color(weak_point: Dictionary, alive: bool) -> void:
	var material: StandardMaterial3D = weak_point["material"]
	if alive:
		material.albedo_color = Color(1.0, 0.12, 0.12)
		material.emission = Color(1.0, 0.2, 0.12)
		material.emission_energy_multiplier = 3.6
	else:
		material.albedo_color = Color(0.2, 0.21, 0.24)
		material.emission = Color(0.05, 0.05, 0.06)
		material.emission_energy_multiplier = 0.4

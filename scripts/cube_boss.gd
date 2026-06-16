class_name CubeBoss
extends Node3D

# Second boss: the whole swarm assembles into a dense hollow cube with a single
# glowing red weak point sealed in the centre. The cube hovers for a few seconds,
# locks the player's spot on the ground, telegraphs with a wind-up, then slams
# across the arena toward that spot. The player dodges / shields the charge and
# uses the extra shot to blast a temporary hole in the shell, then pours normal
# fire through the gap onto the core to kill it.

@export var cube_half := 6.0
@export var grid_per_axis := 5
@export var weak_point_hp := 60
@export var weak_point_radius := 2.3
@export var idle_time := 3.0
@export var telegraph_time := 1.25
@export var telegraph_pullback := 4.5
@export var charge_speed := 48.0
@export var charge_timeout := 1.7
@export var recover_time := 1.1
@export var contact_damage := 2.0
@export var contact_margin := 1.6
@export var defeat_score_bonus := 30000
@export var topup_interval := 2.6

var manager: GameManager
var player: PlayerController
var active := false
var built := false

var sphere_center := Vector3.ZERO
var sphere_radius := 38.0

var cube_center := Vector3.ZERO
var hover_center := Vector3.ZERO

var slots: Array = []
var topup_timer := 0.0

var weak_root: Node3D
var weak_mesh: MeshInstance3D
var weak_material: StandardMaterial3D
var ring_root: Node3D
var edge_root: Node3D
var edge_material: StandardMaterial3D
var weak_hp := 0
var weak_alive := true
var pulse := 0.0

var state := "form"
var state_timer := 0.0
var charge_dir := Vector3.FORWARD
var charge_target := Vector3.ZERO


func configure(_manager: GameManager, _player: PlayerController) -> void:
	manager = _manager
	player = _player
	visible = false
	set_process(true)


func is_active() -> bool:
	return active


func health_fraction() -> float:
	return clamp(float(weak_hp) / float(maxi(1, weak_point_hp)), 0.0, 1.0)


func start() -> void:
	if not player:
		return
	sphere_center = player.sphere_center
	sphere_radius = player.sphere_radius
	if not built:
		_build_visuals()
		_build_slots()
		built = true
	hover_center = sphere_center
	cube_center = sphere_center
	weak_hp = weak_point_hp
	weak_alive = true
	_apply_weak_color(true)
	pulse = 0.0
	state = "form"
	state_timer = 1.2
	topup_timer = 0.0
	active = true
	visible = true
	for slot in slots:
		slot["enemy"] = null
	_topup_slots()
	for enemy in manager.active_enemies:
		if enemy.active and not enemy.formation_active:
			manager.spawn_burst(enemy.global_position, Color(1.0, 0.4, 0.3), enemy.body_radius * 1.4, 0.18)
			enemy.deactivate()
	if manager and manager.ui:
		manager.ui.boss_alert("boss_incoming_cube")
		manager.spawn_burst(cube_center, Color(1.0, 0.3, 0.2), 9.0, 0.7)


func stop() -> void:
	active = false
	visible = false
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
	topup_timer -= delta
	if topup_timer <= 0.0:
		_topup_slots()
		topup_timer = topup_interval
	_update_state(delta)
	_update_formation()
	pulse += delta
	if weak_root:
		weak_root.global_position = cube_center
	if ring_root:
		ring_root.rotation.y += delta * 1.8
		ring_root.rotation.x += delta * 1.1
	if weak_alive and weak_mesh:
		weak_mesh.scale = Vector3.ONE * (1.0 + sin(pulse * 5.0) * 0.12)
	if edge_root:
		edge_root.global_position = cube_center


func _update_state(delta: float) -> void:
	state_timer -= delta
	match state:
		"form":
			cube_center = cube_center.lerp(hover_center, clamp(3.0 * delta, 0.0, 1.0))
			if state_timer <= 0.0:
				state = "idle"
				state_timer = idle_time
		"idle":
			cube_center = cube_center.lerp(hover_center, clamp(1.6 * delta, 0.0, 1.0))
			if state_timer <= 0.0:
				charge_target = _player_ground_point()
				var to_target: Vector3 = charge_target - hover_center
				charge_dir = to_target.normalized() if to_target.length_squared() > 0.01 else Vector3.FORWARD
				state = "telegraph"
				state_timer = telegraph_time
				_set_edge_alert(true)
				if manager:
					manager.spawn_burst(cube_center, Color(1.0, 0.85, 0.2), cube_half * 1.2, 0.4)
		"telegraph":
			var progress: float = 1.0 - clamp(state_timer / max(0.01, telegraph_time), 0.0, 1.0)
			var shake: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * progress * 0.4
			cube_center = hover_center - charge_dir * telegraph_pullback * progress + shake
			if state_timer <= 0.0:
				state = "charge"
				state_timer = charge_timeout
		"charge":
			cube_center += charge_dir * charge_speed * delta
			_apply_charge_contact()
			if state_timer <= 0.0 or cube_center.distance_to(charge_target) <= cube_half:
				state = "recover"
				state_timer = recover_time
				_set_edge_alert(false)
		"recover":
			cube_center = cube_center.lerp(hover_center, clamp(2.0 * delta, 0.0, 1.0))
			if state_timer <= 0.0:
				state = "idle"
				state_timer = idle_time


func _apply_charge_contact() -> void:
	if not player or player.is_dead():
		return
	if player.global_position.distance_to(cube_center) <= cube_half + contact_margin:
		player.apply_damage(contact_damage, cube_center)


func _player_ground_point() -> Vector3:
	var radial: Vector3 = player.global_position - sphere_center
	if radial.length_squared() <= 0.001:
		return player.global_position
	return sphere_center + radial.normalized() * sphere_radius


func _build_slots() -> void:
	slots.clear()
	var n: int = max(2, grid_per_axis)
	for i in range(n):
		for j in range(n):
			for k in range(n):
				var on_surface: bool = i == 0 or i == n - 1 or j == 0 or j == n - 1 or k == 0 or k == n - 1
				if not on_surface:
					continue
				var local := Vector3(
					lerp(-cube_half, cube_half, float(i) / float(n - 1)),
					lerp(-cube_half, cube_half, float(j) / float(n - 1)),
					lerp(-cube_half, cube_half, float(k) / float(n - 1))
				)
				slots.append({"local": local, "enemy": null})


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
		var target: Vector3 = cube_center + slot["local"]
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
			enemy.set_formation_target(cube_center + slot["local"])
		else:
			slot["enemy"] = null


func try_hit(hit_position: Vector3, radius: float) -> bool:
	# Normal fire kills the core, but only shots that slip through a hole the player
	# has blasted in the dense shell ever reach the centre.
	if not active or not weak_alive or not weak_root:
		return false
	if weak_root.global_position.distance_to(hit_position) <= weak_point_radius + radius:
		_damage_weak_point(1)
		return true
	return false


func try_beam_hit(_origin: Vector3, _direction: Vector3, _radius: float, _beam_range: float) -> void:
	# The extra shot's job is to clear a temporary hole in the shell (handled by the
	# manager killing the formation enemies in the beam), not to nuke the core, so it
	# does no direct damage to the weak point.
	pass


func _damage_weak_point(amount: int) -> void:
	if not weak_alive:
		return
	weak_hp -= amount
	if manager:
		manager.spawn_burst(cube_center, Color(1.0, 0.3, 0.18), weak_point_radius * 1.2, 0.16)
	if weak_hp <= 0:
		weak_hp = 0
		weak_alive = false
		_apply_weak_color(false)
		_defeat()


func _defeat() -> void:
	active = false
	visible = false
	_release_all_enemies()
	if manager:
		manager.add_boss_reward(defeat_score_bonus)
		manager.spawn_burst(cube_center, Color(1.0, 0.8, 0.35), 14.0, 0.9)
		if manager.ui:
			manager.ui.boss_alert("boss_defeated_cube")


# --- Visuals ---------------------------------------------------------------

func _build_visuals() -> void:
	weak_root = Node3D.new()
	add_child(weak_root)
	weak_material = StandardMaterial3D.new()
	weak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	weak_material.no_depth_test = true
	weak_material.render_priority = 3
	weak_material.emission_enabled = true
	weak_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = weak_point_radius
	sphere.height = weak_point_radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	weak_mesh.mesh = sphere
	weak_mesh.material_override = weak_material
	weak_root.add_child(weak_mesh)
	ring_root = Node3D.new()
	weak_root.add_child(ring_root)
	var ring_material := _make_unshaded(Color(1.0, 0.5, 0.3, 0.85), Color(1.0, 0.4, 0.2), 3.0, true)
	_add_ring(ring_root, weak_point_radius * 1.7, weak_point_radius * 0.12, ring_material, Vector3.ZERO)
	_add_ring(ring_root, weak_point_radius * 2.1, weak_point_radius * 0.09, ring_material, Vector3(PI * 0.5, 0.0, 0.0))
	_apply_weak_color(true)

	edge_root = Node3D.new()
	add_child(edge_root)
	edge_material = _make_unshaded(Color(0.95, 0.25, 0.2, 0.9), Color(1.0, 0.2, 0.15), 2.2, false)
	_build_edges()


func _build_edges() -> void:
	var thickness := 0.28
	for axis in range(3):
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				var size := Vector3(thickness, thickness, thickness)
				var pos := Vector3.ZERO
				match axis:
					0:
						size.x = cube_half * 2.0
						pos = Vector3(0.0, sa * cube_half, sb * cube_half)
					1:
						size.y = cube_half * 2.0
						pos = Vector3(sa * cube_half, 0.0, sb * cube_half)
					_:
						size.z = cube_half * 2.0
						pos = Vector3(sa * cube_half, sb * cube_half, 0.0)
				var box := BoxMesh.new()
				box.size = size
				var part := MeshInstance3D.new()
				part.mesh = box
				part.material_override = edge_material
				part.position = pos
				edge_root.add_child(part)


func _set_edge_alert(alerting: bool) -> void:
	if not edge_material:
		return
	if alerting:
		edge_material.albedo_color = Color(1.0, 0.78, 0.2, 0.95)
		edge_material.emission = Color(1.0, 0.7, 0.1)
		edge_material.emission_energy_multiplier = 4.0
	else:
		edge_material.albedo_color = Color(0.95, 0.25, 0.2, 0.9)
		edge_material.emission = Color(1.0, 0.2, 0.15)
		edge_material.emission_energy_multiplier = 2.2


func _apply_weak_color(alive: bool) -> void:
	if not weak_material:
		return
	if alive:
		weak_material.albedo_color = Color(1.0, 0.12, 0.12)
		weak_material.emission = Color(1.0, 0.2, 0.12)
		weak_material.emission_energy_multiplier = 3.6
	else:
		weak_material.albedo_color = Color(0.2, 0.21, 0.24)
		weak_material.emission = Color(0.05, 0.05, 0.06)
		weak_material.emission_energy_multiplier = 0.4


func _make_unshaded(albedo: Color, emission: Color, energy: float, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 3
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _add_ring(parent: Node3D, radius: float, half_width: float, material: Material, local_rotation: Vector3) -> void:
	var mesh := ImmediateMesh.new()
	var segments := 48
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

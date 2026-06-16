class_name OverdriveOrb
extends Node3D

# Rare power-up. Shooting it wakes it and reels it toward the player (the projectile
# also ricochets off it, handled by the projectile), so you "fish" it in with fire.
# Collecting it grants a few seconds of doubled fire rate and instantly recharges
# every ability to full.

@export var body_radius := 2.1
@export var collect_radius := 2.9
@export var attract_speed := 34.0
@export var attract_acceleration := 14.0
@export var wake_duration := 9.0
@export var idle_drift_speed := 1.4
@export var overdrive_duration := 6.0

var manager: GameManager
var player: PlayerController
var active := false
var wake_timer := 0.0
var velocity := Vector3.ZERO
var idle_target_velocity := Vector3.ZERO
var idle_timer := 0.0
var visual_root: Node3D
var ring_root: Node3D
var pulse := 0.0


func _ready() -> void:
	_create_visual()
	deactivate()


func activate(_manager: GameManager, _player: PlayerController, spawn_position: Vector3) -> void:
	manager = _manager
	player = _player
	global_position = spawn_position
	active = true
	visible = true
	wake_timer = 0.0
	velocity = _random_drift()
	idle_target_velocity = _random_drift()
	idle_timer = randf_range(0.8, 1.8)
	pulse = randf_range(0.0, TAU)
	set_physics_process(true)


func deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)


func on_primary_hit(hit_direction: Vector3) -> void:
	_wake_toward_player(hit_direction, 1.0)


func on_extra_hit() -> void:
	_wake_toward_player(Vector3.ZERO, 1.3)


func _wake_toward_player(hit_direction: Vector3, speed_scale: float) -> void:
	if not active:
		return
	wake_timer = max(wake_timer, wake_duration)
	if player:
		var to_player: Vector3 = player.global_position - global_position
		if to_player.length_squared() > 0.01:
			velocity = to_player.normalized() * attract_speed * speed_scale
	if hit_direction.length_squared() > 0.01:
		velocity += hit_direction.normalized() * 2.0
	if manager:
		manager.spawn_burst(global_position, Color(1.0, 0.85, 0.3), body_radius * 1.2, 0.18)


func _physics_process(delta: float) -> void:
	if not active:
		return
	if manager and not manager.is_playing():
		return
	pulse += delta
	if visual_root:
		visual_root.rotation.y += delta * 1.9
		visual_root.rotation.x += delta * 0.7
		var scale_pulse: float = 1.0 + sin(pulse * 5.0) * (0.05 if wake_timer > 0.0 else 0.025)
		visual_root.scale = Vector3.ONE * scale_pulse
	if ring_root:
		ring_root.rotation.y -= delta * 2.7
		ring_root.rotation.z += delta * 1.4
	if wake_timer > 0.0 and player:
		wake_timer = max(0.0, wake_timer - delta)
		var to_player: Vector3 = player.global_position - global_position
		if to_player.length_squared() > 0.01:
			var desired_velocity: Vector3 = to_player.normalized() * attract_speed
			velocity = velocity.lerp(desired_velocity, clamp(attract_acceleration * delta, 0.0, 1.0))
	else:
		idle_timer -= delta
		if idle_timer <= 0.0:
			idle_target_velocity = _random_drift()
			idle_timer = randf_range(0.8, 1.8)
		velocity = velocity.move_toward(idle_target_velocity, idle_drift_speed * delta)
	global_position += velocity * delta
	if player and global_position.distance_squared_to(player.global_position) <= collect_radius * collect_radius:
		_collect()


func _collect() -> void:
	if player:
		player.apply_overdrive(overdrive_duration)
		player.refill_all_charges()
	if manager:
		manager.spawn_burst(global_position, Color(1.0, 0.9, 0.35), body_radius * 2.2, 0.4)
		if manager.ui:
			manager.ui.power_surge_feedback()
	deactivate()


func _create_visual() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)

	var core_material := _make_material(Color(1.0, 0.85, 0.2), Color(1.0, 0.78, 0.1), 2.8)
	var dark_material := _make_material(Color(0.12, 0.1, 0.04), Color(0.5, 0.4, 0.08), 0.8)

	var core_mesh := SphereMesh.new()
	core_mesh.radius = body_radius * 0.6
	core_mesh.height = body_radius * 1.2
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	var core := MeshInstance3D.new()
	core.mesh = core_mesh
	core.material_override = core_material
	visual_root.add_child(core)

	for i in range(4):
		var spike_angle: float = TAU * float(i) / 4.0
		var spike := BoxMesh.new()
		spike.size = Vector3(body_radius * 0.22, body_radius * 0.22, body_radius * 1.3)
		var part := MeshInstance3D.new()
		part.mesh = spike
		part.material_override = dark_material
		part.position = Vector3(cos(spike_angle), 0.0, sin(spike_angle)) * body_radius * 0.55
		part.rotation = Vector3(0.0, spike_angle, 0.0)
		visual_root.add_child(part)

	ring_root = Node3D.new()
	visual_root.add_child(ring_root)
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_material.albedo_color = Color(1.0, 0.95, 0.55, 0.8)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.85, 0.3)
	ring_material.emission_energy_multiplier = 3.2
	_add_ring(body_radius * 1.5, body_radius * 0.08, ring_material, Vector3.ZERO)
	_add_ring(body_radius * 1.85, body_radius * 0.06, ring_material, Vector3(PI * 0.5, 0.0, 0.0))


func _add_ring(radius: float, half_width: float, material: Material, local_rotation: Vector3) -> void:
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
	ring_root.add_child(ring)


func _make_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _random_drift() -> Vector3:
	var drift := Vector3(randf_range(-1.0, 1.0), randf_range(-0.65, 0.65), randf_range(-1.0, 1.0))
	if drift.length_squared() <= 0.01:
		return Vector3.ZERO
	return drift.normalized() * randf_range(0.25, idle_drift_speed)

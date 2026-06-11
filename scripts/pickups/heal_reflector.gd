class_name HealReflector
extends Node3D

@export var body_radius := 2.35
@export var collect_radius := 3.05
@export var touch_heal := 0.75
@export var attract_speed := 32.0
@export var attract_acceleration := 14.0
@export var wake_duration := 9.0
@export var idle_drift_speed := 1.4

var manager: GameManager
var player: PlayerController
var active := false
var wake_timer := 0.0
var velocity := Vector3.ZERO
var idle_target_velocity := Vector3.ZERO
var idle_timer := 0.0
var visual_root: Node3D
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
	if not active:
		return
	wake_timer = max(wake_timer, wake_duration)
	if player:
		var to_player: Vector3 = player.global_position - global_position
		if to_player.length_squared() > 0.01:
			velocity = to_player.normalized() * attract_speed
	if hit_direction.length_squared() > 0.01:
		velocity += hit_direction.normalized() * 2.0
	if manager:
		manager.spawn_burst(global_position, Color(1.0, 0.58, 0.12), body_radius * 1.05, 0.18)


func on_extra_hit() -> void:
	if not active:
		return
	wake_timer = max(wake_timer, wake_duration)
	if player:
		var to_player: Vector3 = player.global_position - global_position
		if to_player.length_squared() > 0.01:
			velocity = to_player.normalized() * attract_speed * 1.25
	if manager:
		manager.spawn_burst(global_position, Color(1.0, 0.42, 0.08), body_radius * 2.4, 0.36)


func _physics_process(delta: float) -> void:
	if not active:
		return
	if manager and not manager.is_playing():
		return
	pulse += delta
	if visual_root:
		visual_root.rotation.y += delta * 1.7
		visual_root.rotation.x += delta * 0.65
		var scale_pulse: float = 1.0 + sin(pulse * 5.0) * (0.035 if wake_timer > 0.0 else 0.018)
		visual_root.scale = Vector3.ONE * scale_pulse
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
		_heal_player_and_emit_waves(touch_heal)
		if manager:
			manager.spawn_burst(global_position, Color(0.45, 1.0, 0.35), body_radius * 1.8, 0.32)
		deactivate()


func _heal_player_and_emit_waves(amount: float) -> void:
	if not player:
		return
	player.heal(amount)
	if manager:
		manager.spawn_heal_cross_waves(player.global_position)


func _create_visual() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)

	var core_material: StandardMaterial3D = _make_material(Color(1.0, 0.42, 0.07), Color(1.0, 0.26, 0.02), 1.8)
	var dark_material: StandardMaterial3D = _make_material(Color(0.12, 0.08, 0.045), Color(0.55, 0.2, 0.04), 0.9)
	var heal_material: StandardMaterial3D = _make_material(Color(0.55, 1.0, 0.34), Color(0.38, 1.0, 0.18), 2.4)

	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = body_radius * 0.58
	core_mesh.height = body_radius * 1.16
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	_add_piece(core_mesh, core_material, Vector3.ZERO, Vector3(1.25, 0.95, 1.25), Vector3.ZERO)

	for i in range(6):
		var panel_angle: float = TAU * float(i) / 6.0
		var panel_mesh: BoxMesh = BoxMesh.new()
		panel_mesh.size = Vector3(body_radius * 0.58, body_radius * 0.3, body_radius * 0.9)
		var panel_offset: Vector3 = Vector3(cos(panel_angle), 0.0, sin(panel_angle)) * body_radius * 0.58
		_add_piece(panel_mesh, dark_material, panel_offset, Vector3.ONE, Vector3(0.0, panel_angle, 0.7))

	for i in range(4):
		var shard_angle: float = TAU * float(i) / 4.0 + PI * 0.25
		var shard_mesh: BoxMesh = BoxMesh.new()
		shard_mesh.size = Vector3(body_radius * 0.18, body_radius * 0.75, body_radius * 0.18)
		var shard_offset: Vector3 = Vector3(cos(shard_angle), 0.45, sin(shard_angle)) * body_radius * 0.9
		_add_piece(shard_mesh, heal_material, shard_offset, Vector3.ONE, Vector3(0.65, shard_angle, 0.0))


func _add_piece(mesh: Mesh, material: Material, local_position: Vector3, local_scale: Vector3, local_rotation: Vector3) -> void:
	var piece: MeshInstance3D = MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.position = local_position
	piece.scale = local_scale
	piece.rotation = local_rotation
	visual_root.add_child(piece)


func _make_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _random_drift() -> Vector3:
	var drift: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-0.65, 0.65), randf_range(-1.0, 1.0))
	if drift.length_squared() <= 0.01:
		return Vector3.ZERO
	return drift.normalized() * randf_range(0.25, idle_drift_speed)

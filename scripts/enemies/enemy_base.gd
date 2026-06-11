class_name EnemyBase
extends Node3D

@export var move_speed := 7.0
@export var turn_speed := 7.0
@export var body_radius := 0.42
@export var platform_height := 0.45
@export var score_value := 10
@export var shard_drop_min := 1
@export var shard_drop_max := 3
@export var max_lifetime := 40.0
@export var max_distance_from_player := 135.0
@export var can_be_platform := true
@export var mesh_shape := "sphere"
@export var visual_color := Color(0.95, 0.2, 0.28)
@export var spin_speed := 2.2

var manager: GameManager
var player: PlayerController
var active := false
var velocity := Vector3.ZERO
var age := 0.0
var visual: MeshInstance3D
var material: StandardMaterial3D


func _ready() -> void:
	_create_visual()
	deactivate()


func activate(_manager: GameManager, _player: PlayerController, spawn_position: Vector3) -> void:
	manager = _manager
	player = _player
	global_position = spawn_position
	velocity = Vector3.ZERO
	age = 0.0
	active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	_on_activated()


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)
	set_physics_process(false)


func kill(source: String = "primary", spawn_pickups: bool = true) -> void:
	if not active:
		return
	if manager:
		manager.on_enemy_killed(self, source, spawn_pickups)
	deactivate()


func _physics_process(delta: float) -> void:
	if not active or not player:
		return
	if manager and not manager.is_playing():
		return
	age += delta
	if age > max_lifetime or global_position.distance_to(player.global_position) > max_distance_from_player:
		deactivate()
		return
	_update_movement(delta)
	global_position += velocity * delta
	if visual:
		visual.rotate_y(spin_speed * delta)


func _update_movement(_delta: float) -> void:
	var desired: Vector3 = _direction_to_player() * move_speed
	velocity = velocity.lerp(desired, 0.2)


func _direction_to_player() -> Vector3:
	if not player:
		return Vector3.ZERO
	var target: Vector3 = player.global_position + Vector3(0.0, 0.35, 0.0)
	var direction: Vector3 = target - global_position
	if direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return direction.normalized()


func _on_activated() -> void:
	pass


func _create_visual() -> void:
	if visual:
		return
	visual = MeshInstance3D.new()
	visual.mesh = _build_mesh()
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = visual_color
	material.emission_enabled = true
	material.emission = visual_color
	material.emission_energy_multiplier = 0.85
	visual.material_override = material
	add_child(visual)


func _build_mesh() -> Mesh:
	match mesh_shape:
		"box":
			var box := BoxMesh.new()
			box.size = Vector3.ONE * body_radius * 2.0
			return box
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = body_radius * 0.62
			capsule.height = body_radius * 2.4
			return capsule
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = body_radius * 0.85
			cylinder.bottom_radius = body_radius * 0.85
			cylinder.height = body_radius * 1.9
			cylinder.radial_segments = 8
			return cylinder
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = body_radius
			cone.height = body_radius * 2.2
			cone.radial_segments = 5
			return cone
		_:
			var sphere := SphereMesh.new()
			sphere.radius = body_radius
			sphere.height = body_radius * 2.0
			sphere.radial_segments = 8
			sphere.rings = 4
			return sphere

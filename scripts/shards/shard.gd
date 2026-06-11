class_name ScoreShard
extends Node3D

@export var lifetime := 7.5
@export var attract_radius := 9.0
@export var collect_radius := 1.05
@export var attract_acceleration := 34.0
@export var damping := 2.1

var manager: GameManager
var player: PlayerController
var active := false
var velocity := Vector3.ZERO
var age := 0.0
var value := 5
var visual: MeshInstance3D


func _ready() -> void:
	_create_visual()
	deactivate()


func activate(_manager: GameManager, _player: PlayerController, origin: Vector3, impulse: Vector3, shard_value: int) -> void:
	manager = _manager
	player = _player
	global_position = origin
	velocity = impulse
	value = shard_value
	age = 0.0
	active = true
	visible = true
	set_physics_process(true)


func deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not active:
		return
	if manager and not manager.is_playing():
		return
	age += delta
	if age >= lifetime or not player:
		deactivate()
		return
	var to_player: Vector3 = player.global_position + Vector3(0.0, 0.3, 0.0) - global_position
	var distance: float = to_player.length()
	if distance <= collect_radius:
		manager.collect_shard(value)
		manager.spawn_burst(global_position, Color(0.95, 0.95, 0.35), 0.55, 0.16)
		deactivate()
		return
	if distance <= attract_radius:
		var pull: float = 1.0 - clamp(distance / attract_radius, 0.0, 1.0)
		velocity += to_player.normalized() * attract_acceleration * pull * delta
	velocity = velocity.lerp(Vector3.ZERO, clamp(damping * delta, 0.0, 0.8))
	global_position += velocity * delta
	rotate_y(8.0 * delta)
	rotate_x(5.0 * delta)


func _create_visual() -> void:
	visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.18, 0.18)
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.92, 0.26)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.82, 0.18)
	material.emission_energy_multiplier = 1.2
	visual.material_override = material
	add_child(visual)

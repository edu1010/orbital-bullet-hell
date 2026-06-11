class_name ScoreShard
extends Node3D

@export var lifetime := 7.5
@export var attract_radius := 12.0
@export var collect_radius := 1.3
@export var attract_acceleration := 16.0
@export var magnet_acceleration := 8.5
@export var magnet_speed := 28.0
@export var damping := 2.1
@export var visual_size := 0.52
@export var pulse_amount := 0.18

var manager: GameManager
var player: PlayerController
var active := false
var velocity := Vector3.ZERO
var age := 0.0
var value := 5
var magnetized := false
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
	magnetized = false
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
	if age >= lifetime and not magnetized:
		deactivate()
		return
	if not player:
		deactivate()
		return
	var to_player: Vector3 = player.global_position + Vector3(0.0, 0.3, 0.0) - global_position
	var distance: float = to_player.length()
	if distance <= collect_radius:
		manager.collect_shard(value)
		manager.spawn_burst(global_position, Color(0.95, 0.95, 0.35), 0.55, 0.16)
		deactivate()
		return
	if magnetized:
		var desired_velocity: Vector3 = to_player.normalized() * magnet_speed
		velocity = velocity.lerp(desired_velocity, clamp(magnet_acceleration * delta, 0.0, 1.0))
	elif distance <= attract_radius:
		var pull: float = 1.0 - clamp(distance / attract_radius, 0.0, 1.0)
		velocity += to_player.normalized() * attract_acceleration * pull * delta
	if not magnetized:
		velocity = velocity.lerp(Vector3.ZERO, clamp(damping * delta, 0.0, 0.8))
	global_position += velocity * delta
	visual.scale = Vector3.ONE * (1.0 + sin(age * 9.0) * pulse_amount)
	rotate_y(8.0 * delta)
	rotate_x(5.0 * delta)


func magnetize() -> void:
	if not active:
		return
	magnetized = true
	age = min(age, lifetime * 0.35)


func _create_visual() -> void:
	visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * visual_size
	visual.mesh = mesh
	visual.rotation_degrees = Vector3(45.0, 0.0, 45.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.96, 0.18)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.9, 0.08)
	material.emission_energy_multiplier = 2.4
	visual.material_override = material
	add_child(visual)

class_name PlayerProjectile
extends Node3D

@export var hit_radius := 0.42
@export var lifetime := 1.35
@export var visual_length := 0.8

var manager: GameManager
var active := false
var direction: Vector3 = Vector3.FORWARD
var speed := 50.0
var age := 0.0
var visual: MeshInstance3D
var reflect_cooldown := 0.0
var ignored_reflector: HealReflector


func _ready() -> void:
	_create_visual()
	deactivate()


func activate(_manager: GameManager, origin: Vector3, _direction: Vector3, _speed: float) -> void:
	manager = _manager
	global_position = origin
	direction = _direction.normalized()
	speed = _speed
	age = 0.0
	reflect_cooldown = 0.0
	ignored_reflector = null
	active = true
	visible = true
	set_physics_process(true)
	look_at(global_position + direction, Vector3.UP)


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
	reflect_cooldown = max(0.0, reflect_cooldown - delta)
	if reflect_cooldown <= 0.0:
		ignored_reflector = null
	global_position += direction * speed * delta
	if age >= lifetime:
		deactivate()
		return
	var reflector: HealReflector = manager.find_reflector_hit(global_position, hit_radius)
	if reflector and reflector != ignored_reflector:
		reflector.on_primary_hit(direction)
		direction = -direction
		reflect_cooldown = 0.16
		ignored_reflector = reflector
		global_position += direction * (hit_radius + reflector.body_radius + 0.15)
		look_at(global_position + direction, Vector3.UP)
		return
	var enemy: EnemyBase = manager.find_enemy_hit(global_position, hit_radius, true)
	if enemy:
		if enemy is BombEnemy:
			manager.detonate_bomb(enemy as BombEnemy, "primary")
		else:
			enemy.kill("primary", true)
		deactivate()


func _create_visual() -> void:
	visual = MeshInstance3D.new()
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.055
	mesh.height = visual_length
	mesh.radial_segments = 6
	visual.mesh = mesh
	visual.rotation_degrees.x = 90.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.65, 0.95, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.35, 0.9, 1.0)
	material.emission_energy_multiplier = 1.6
	visual.material_override = material
	add_child(visual)

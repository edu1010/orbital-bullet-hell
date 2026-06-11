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
@export var max_distance_from_player := 215.0
@export var can_be_platform := true
@export var mesh_shape := "sphere"
@export var visual_style := "swarm_mask"
@export var visual_color := Color(0.95, 0.2, 0.28)
@export var accent_color := Color(0.75, 1.0, 0.2)
@export var dark_color := Color(0.025, 0.02, 0.035)
@export var spin_speed := 2.2

var manager: GameManager
var player: PlayerController
var active := false
var velocity := Vector3.ZERO
var age := 0.0
var visual: Node3D
var material: StandardMaterial3D
var dark_material: StandardMaterial3D
var accent_material: StandardMaterial3D


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
	visual = Node3D.new()
	material = _make_low_poly_material(visual_color, 0.36)
	dark_material = _make_low_poly_material(dark_color, 0.08)
	accent_material = _make_glow_material(accent_color, 1.7)
	add_child(visual)
	match visual_style:
		"charger_mask":
			_build_charger_visual()
		"avoider_shard":
			_build_avoider_visual()
		"bomb_relic":
			_build_bomb_visual()
		_:
			_build_swarmer_visual()


func _make_low_poly_material(color: Color, emission_strength: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission_strength
	return mat


func _make_glow_material(color: Color, emission_strength: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission_strength
	return mat


func _add_mesh(mesh: Mesh, mat: Material, local_position: Vector3 = Vector3.ZERO, local_rotation_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = local_position
	part.rotation_degrees = local_rotation_degrees
	visual.add_child(part)
	return part


func _box_mesh(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


func _sphere_mesh(radius: float, segments: int = 8, rings: int = 4) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = segments
	sphere.rings = rings
	return sphere


func _cone_mesh(radius: float, height: float, sides: int = 4) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = sides
	return cone


func _cylinder_mesh(radius: float, height: float, sides: int = 6) -> CylinderMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = sides
	return cylinder


func _add_diamond(radius: float, height: float, mat: Material, local_position: Vector3 = Vector3.ZERO, local_rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	var holder: Node3D = Node3D.new()
	holder.position = local_position
	holder.rotation_degrees = local_rotation_degrees
	visual.add_child(holder)
	var top: MeshInstance3D = MeshInstance3D.new()
	top.mesh = _cone_mesh(radius, height * 0.5, 4)
	top.material_override = mat
	top.position = Vector3.UP * height * 0.25
	top.name = "DiamondTop"
	holder.add_child(top)
	var bottom: MeshInstance3D = MeshInstance3D.new()
	bottom.mesh = _cone_mesh(radius, height * 0.5, 4)
	bottom.material_override = mat
	bottom.position = Vector3.DOWN * height * 0.25
	bottom.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	bottom.name = "DiamondBottom"
	holder.add_child(bottom)


func _build_swarmer_visual() -> void:
	_add_mesh(_sphere_mesh(body_radius * 0.9, 7, 4), dark_material)
	_add_mesh(_sphere_mesh(body_radius * 0.55, 6, 3), material, Vector3(0.0, 0.0, body_radius * 0.26))
	_add_diamond(body_radius * 0.22, body_radius * 0.95, accent_material, Vector3(0.0, body_radius * 0.92, 0.0), Vector3(0.0, 45.0, 0.0))
	_add_diamond(body_radius * 0.14, body_radius * 0.55, accent_material, Vector3(body_radius * 0.95, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))
	_add_diamond(body_radius * 0.14, body_radius * 0.55, accent_material, Vector3(-body_radius * 0.95, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))


func _build_charger_visual() -> void:
	_add_mesh(_box_mesh(Vector3(body_radius * 1.65, body_radius * 1.05, body_radius * 1.25)), material, Vector3.ZERO, Vector3(0.0, 45.0, 12.0))
	_add_mesh(_box_mesh(Vector3(body_radius * 0.9, body_radius * 0.7, body_radius * 0.96)), dark_material, Vector3(0.0, 0.0, body_radius * 0.46), Vector3(0.0, 45.0, 0.0))
	_add_mesh(_box_mesh(Vector3(body_radius * 0.28, body_radius * 1.55, body_radius * 0.36)), material, Vector3(body_radius * 0.95, 0.0, 0.0), Vector3(0.0, 0.0, -24.0))
	_add_mesh(_box_mesh(Vector3(body_radius * 0.28, body_radius * 1.55, body_radius * 0.36)), material, Vector3(-body_radius * 0.95, 0.0, 0.0), Vector3(0.0, 0.0, 24.0))
	_add_diamond(body_radius * 0.18, body_radius * 0.7, accent_material, Vector3(0.0, body_radius * 0.95, body_radius * 0.25), Vector3(0.0, 45.0, 0.0))


func _build_avoider_visual() -> void:
	_add_diamond(body_radius * 0.72, body_radius * 1.9, material, Vector3.ZERO, Vector3(0.0, 20.0, 0.0))
	_add_mesh(_sphere_mesh(body_radius * 0.42, 6, 3), dark_material, Vector3(0.0, 0.0, body_radius * 0.36))
	_add_mesh(_box_mesh(Vector3(body_radius * 0.34, body_radius * 0.12, body_radius * 1.45)), accent_material, Vector3(body_radius * 0.78, 0.0, 0.0), Vector3(0.0, 22.0, 28.0))
	_add_mesh(_box_mesh(Vector3(body_radius * 0.34, body_radius * 0.12, body_radius * 1.45)), accent_material, Vector3(-body_radius * 0.78, 0.0, 0.0), Vector3(0.0, -22.0, -28.0))


func _build_bomb_visual() -> void:
	_add_diamond(body_radius * 0.9, body_radius * 1.65, material, Vector3.ZERO, Vector3(0.0, 45.0, 0.0))
	_add_mesh(_sphere_mesh(body_radius * 0.56, 7, 4), dark_material, Vector3.ZERO)
	for i in range(6):
		var angle: float = TAU * float(i) / 6.0
		var pos: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * body_radius * 1.18
		var rot: Vector3 = Vector3(0.0, -rad_to_deg(angle), 90.0)
		_add_diamond(body_radius * 0.12, body_radius * 0.62, accent_material, pos, rot)


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

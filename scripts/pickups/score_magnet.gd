class_name ScoreMagnet
extends Node3D

@export var body_radius := 1.25
@export var collect_radius := 2.4
@export var lifetime := 14.0
@export var hover_amplitude := 0.32
@export var hover_speed := 2.2

var manager: GameManager
var player: PlayerController
var active := false
var age := 0.0
var base_position := Vector3.ZERO
var visual_root: Node3D
var ring_root: Node3D


func _ready() -> void:
	_create_visual()
	deactivate()


func activate(_manager: GameManager, _player: PlayerController, spawn_position: Vector3) -> void:
	manager = _manager
	player = _player
	global_position = spawn_position
	base_position = spawn_position
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
	var radial: Vector3 = global_position - player.sphere_center
	var hover_axis: Vector3 = Vector3.UP
	if radial.length_squared() > 0.001:
		hover_axis = -radial.normalized()
	global_position = base_position + hover_axis * sin(age * hover_speed) * hover_amplitude
	if visual_root:
		visual_root.rotate_y(delta * 1.8)
		visual_root.rotate_x(delta * 0.65)
	if ring_root:
		ring_root.rotate_y(delta * 2.6)
		ring_root.rotate_z(delta * 1.2)
	if global_position.distance_squared_to(player.global_position) <= collect_radius * collect_radius:
		manager.attract_all_shards()
		manager.spawn_burst(global_position, Color(0.85, 0.35, 1.0), body_radius * 2.4, 0.32)
		deactivate()


func _create_visual() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)

	var core_material := StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.albedo_color = Color(0.74, 0.28, 1.0)
	core_material.emission_enabled = true
	core_material.emission = Color(0.78, 0.24, 1.0)
	core_material.emission_energy_multiplier = 2.7

	var core_mesh := SphereMesh.new()
	core_mesh.radius = body_radius
	core_mesh.height = body_radius * 2.0
	core_mesh.radial_segments = 7
	core_mesh.rings = 4
	var core := MeshInstance3D.new()
	core.mesh = core_mesh
	core.material_override = core_material
	visual_root.add_child(core)

	ring_root = Node3D.new()
	visual_root.add_child(ring_root)
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_material.albedo_color = Color(0.95, 0.62, 1.0, 0.78)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.95, 0.45, 1.0, 0.9)
	ring_material.emission_energy_multiplier = 3.2
	_add_ring(body_radius * 1.55, body_radius * 0.08, ring_material, Vector3.ZERO)
	_add_ring(body_radius * 1.9, body_radius * 0.06, ring_material, Vector3(PI * 0.5, 0.0, 0.0))
	_add_ring(body_radius * 1.28, body_radius * 0.05, ring_material, Vector3(0.0, PI * 0.5, PI * 0.25))


func _add_ring(radius: float, half_width: float, material: Material, local_rotation: Vector3) -> void:
	var mesh := ImmediateMesh.new()
	var segments := 72
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var inner_radius := radius - half_width
		var outer_radius := radius + half_width
		var inner0 := Vector3(cos(a0) * inner_radius, sin(a0) * inner_radius, 0.0)
		var outer0 := Vector3(cos(a0) * outer_radius, sin(a0) * outer_radius, 0.0)
		var inner1 := Vector3(cos(a1) * inner_radius, sin(a1) * inner_radius, 0.0)
		var outer1 := Vector3(cos(a1) * outer_radius, sin(a1) * outer_radius, 0.0)
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

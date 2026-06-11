class_name LaserRingEffect
extends Node3D

@export var ring_segments := 72
@export var line_width_hint := 0.04

var active := false
var age := 0.0
var lifetime := 0.42
var start_radius := 0.35
var end_radius := 6.0
var ring_color: Color = Color(0.4, 0.95, 1.0, 1.0)
var mesh_instance: MeshInstance3D
var mesh: ImmediateMesh
var material: StandardMaterial3D


func _ready() -> void:
	_create_visual()
	deactivate()


func activate(position: Vector3, direction: Vector3, _start_radius: float, _end_radius: float, color: Color, duration: float) -> void:
	global_position = position
	start_radius = _start_radius
	end_radius = _end_radius
	ring_color = color
	lifetime = max(0.05, duration)
	age = 0.0
	active = true
	visible = true
	set_process(true)
	_face_direction(direction.normalized())
	_redraw(0.0)


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not active:
		return
	age += delta
	var progress: float = clamp(age / lifetime, 0.0, 1.0)
	_redraw(progress)
	if progress >= 1.0:
		deactivate()


func _create_visual() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh = ImmediateMesh.new()
	mesh_instance.mesh = mesh
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = ring_color
	material.emission_enabled = true
	material.emission = ring_color
	material.emission_energy_multiplier = 2.2
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	var up_hint: Vector3 = Vector3.UP
	if abs(direction.dot(up_hint)) > 0.94:
		up_hint = Vector3.RIGHT
	look_at(global_position + direction, up_hint)


func _redraw(progress: float) -> void:
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	var radius: float = lerp(start_radius, end_radius, eased)
	var alpha: float = (1.0 - progress) * ring_color.a
	var color: Color = Color(ring_color.r, ring_color.g, ring_color.b, alpha)
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = lerp(2.4, 0.35, progress)
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(ring_segments + 1):
		var angle: float = TAU * float(i) / float(ring_segments)
		mesh.surface_add_vertex(Vector3(cos(angle) * radius, sin(angle) * radius, 0.0))
	mesh.surface_end()

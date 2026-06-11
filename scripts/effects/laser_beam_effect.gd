class_name LaserBeamEffect
extends Node3D

var active := false
var age := 0.0
var lifetime := 0.18
var beam_color: Color = Color(0.45, 0.95, 1.0, 0.9)
var material: StandardMaterial3D
var mesh_instance: MeshInstance3D


func _ready() -> void:
	_create_visual()
	deactivate()


func activate(origin: Vector3, direction: Vector3, length: float, radius: float, color: Color, duration: float) -> void:
	beam_color = color
	lifetime = max(0.04, duration)
	age = 0.0
	active = true
	visible = true
	set_process(true)
	var normalized_direction: Vector3 = direction.normalized()
	global_position = origin + normalized_direction * length * 0.5
	_face_direction(normalized_direction)
	var box_mesh: BoxMesh = mesh_instance.mesh as BoxMesh
	box_mesh.size = Vector3(radius * 2.0, radius * 2.0, length)
	_update_material(0.0)


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not active:
		return
	age += delta
	var progress: float = clamp(age / lifetime, 0.0, 1.0)
	_update_material(progress)
	if progress >= 1.0:
		deactivate()


func _create_visual() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = beam_color
	material.emission_enabled = true
	material.emission = beam_color
	material.emission_energy_multiplier = 3.0
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	var up_hint: Vector3 = Vector3.UP
	if abs(direction.dot(up_hint)) > 0.94:
		up_hint = Vector3.RIGHT
	look_at(global_position + direction, up_hint)


func _update_material(progress: float) -> void:
	var alpha: float = (1.0 - progress) * beam_color.a
	var color: Color = Color(beam_color.r, beam_color.g, beam_color.b, alpha)
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = lerp(3.6, 0.5, progress)

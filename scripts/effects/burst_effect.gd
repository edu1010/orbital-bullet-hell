class_name BurstEffect
extends Node3D

var active := false
var age := 0.0
var lifetime := 0.3
var start_scale := 1.0
var visual: MeshInstance3D
var material: StandardMaterial3D


func _ready() -> void:
	_create_visual()
	deactivate()


func activate(origin: Vector3, color: Color, burst_scale: float, duration: float) -> void:
	global_position = origin
	start_scale = max(0.05, burst_scale)
	lifetime = max(0.05, duration)
	age = 0.0
	active = true
	visible = true
	set_process(true)
	material.albedo_color = Color(color.r, color.g, color.b, 0.62)
	material.emission = color
	scale = Vector3.ONE * start_scale * 0.25


func deactivate() -> void:
	active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not active:
		return
	age += delta
	var t: float = clamp(age / lifetime, 0.0, 1.0)
	scale = Vector3.ONE * lerp(start_scale * 0.25, start_scale * 1.35, t)
	var c := material.albedo_color
	c.a = lerp(0.62, 0.0, t)
	material.albedo_color = c
	if age >= lifetime:
		deactivate()


func _create_visual() -> void:
	visual = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	visual.mesh = mesh
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 1, 1, 0.0)
	material.emission_enabled = true
	material.emission_energy_multiplier = 1.2
	visual.material_override = material
	add_child(visual)

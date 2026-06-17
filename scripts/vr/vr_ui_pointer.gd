extends Node3D
## Puntero láser para interactuar con el menú en VR. Lanza un rayo desde el mando
## y, al apretar el gatillo, "clica" sobre un panel de UI en 3D.
##
## Para que el menú 2D sea clicable en VR debe mostrarse en un quad 3D mediante un
## SubViewport (nodo en el grupo "vr_ui" con un método `vr_click(world_point)`).
## Ese montaje del menú-en-3D es la parte que hay que afinar CON CASCO; ver
## VR_README.md. El puntero en sí ya queda listo aquí.

const RAY_LENGTH := 6.0
@export var click_action := "trigger_click"

var ray: RayCast3D
var beam: MeshInstance3D


func _ready() -> void:
	ray = RayCast3D.new()
	ray.target_position = Vector3(0.0, 0.0, -RAY_LENGTH)
	ray.collision_mask = 0xFFFFFFFF
	ray.enabled = true
	add_child(ray)

	beam = _make_beam()
	add_child(beam)

	var controller := get_parent()
	if controller and controller.has_signal("button_pressed"):
		controller.connect("button_pressed", _on_button_pressed)


func _make_beam() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.004
	cyl.bottom_radius = 0.004
	cyl.height = RAY_LENGTH
	mi.mesh = cyl
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # eje del cilindro a lo largo de -Z
	mi.position = Vector3(0.0, 0.0, -RAY_LENGTH * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.9, 1.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.9, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	return mi


func _process(_delta: float) -> void:
	if ray and ray.is_colliding():
		var point: Vector3 = ray.get_collision_point()
		_set_beam_length(global_position.distance_to(point))
		# Mueve el "ratón" sobre el panel para resaltar el botón apuntado.
		var collider := ray.get_collider()
		if collider and collider.is_in_group("vr_ui") and collider.has_method("vr_hover"):
			collider.vr_hover(point)
	else:
		_set_beam_length(RAY_LENGTH)


func _set_beam_length(length: float) -> void:
	if beam and beam.mesh is CylinderMesh:
		(beam.mesh as CylinderMesh).height = length
		beam.position = Vector3(0.0, 0.0, -length * 0.5)


func _on_button_pressed(action_name: String) -> void:
	if action_name != click_action:
		return
	if ray and ray.is_colliding():
		var collider := ray.get_collider()
		if collider and collider.is_in_group("vr_ui") and collider.has_method("vr_click"):
			collider.vr_click(ray.get_collision_point())

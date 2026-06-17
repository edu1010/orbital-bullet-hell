extends StaticBody3D
## Panel 3D que muestra la UI 2D del juego (un SubViewport pintado en un quad) y
## deja clicarla con el puntero láser. Está en el grupo "vr_ui" y expone
## vr_hover()/vr_click() que el puntero llama con el punto de impacto del rayo.
##
## XRManager reparenta aquí dentro el CanvasLayer de la GameUI, así el MISMO menú
## del juego (PLAY, BOSS RUSH, RANKING, AJUSTES...) aparece flotando y clicable.

@export var panel_width := 1.8    # metros
@export var panel_height := 1.0125  # 16:9
@export var resolution := Vector2i(1280, 720)

var viewport: SubViewport
var quad: MeshInstance3D


func _ready() -> void:
	add_to_group("vr_ui")

	viewport = SubViewport.new()
	viewport.size = resolution
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = false
	add_child(viewport)

	quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(panel_width, panel_height)
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport.get_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material_override = mat
	add_child(quad)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(panel_width, panel_height, 0.02)
	col.shape = box
	add_child(col)


## Mete el CanvasLayer de la GameUI dentro de nuestro SubViewport.
func host_ui(ui_node: Node) -> void:
	if ui_node == null:
		return
	var prev := ui_node.get_parent()
	if prev:
		prev.remove_child(ui_node)
	viewport.add_child(ui_node)


func _world_to_viewport(world_point: Vector3) -> Vector2:
	var local: Vector3 = quad.to_local(world_point)
	var u: float = clampf(local.x / panel_width + 0.5, 0.0, 1.0)
	var v: float = clampf(0.5 - local.y / panel_height, 0.0, 1.0)
	return Vector2(u * resolution.x, v * resolution.y)


func vr_hover(world_point: Vector3) -> void:
	if viewport == null:
		return
	var pos := _world_to_viewport(world_point)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	viewport.push_input(ev)


func vr_click(world_point: Vector3) -> void:
	if viewport == null:
		return
	var pos := _world_to_viewport(world_point)
	for is_pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = is_pressed
		ev.position = pos
		ev.global_position = pos
		viewport.push_input(ev)

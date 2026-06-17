extends Node
## XRManager (autoload) — arranca OpenXR si hay casco + runtime; si no, modo plano.
##
## Es ADITIVO: si no hay VR, el juego corre exactamente igual que en plano, así
## que esta rama sigue siendo jugable sin casco. Cuando hay VR, activa el render
## XR en el viewport y monta el rig (cámara del casco + dos manos con arma).
##
## OJO: un port VR completo del juego (locomoción cómoda sobre el interior de la
## esfera, menú 2D en 3D, etc.) es iterativo y necesita probarse CON CASCO. Esto
## es la base. Ver VR_README.md.

signal xr_state_changed(active: bool)

const VR_RIG := preload("res://scripts/vr/vr_rig.gd")
const VR_UI_PANEL := preload("res://scripts/vr/vr_ui_panel.gd")

var xr_interface: XRInterface = null
var xr_active := false
var rig: XROrigin3D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_try_init_xr()

func _try_init_xr() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		print("[VR] OpenXR no disponible — modo plano (el juego corre igual).")
		return
	if not xr_interface.is_initialized():
		if not xr_interface.initialize():
			print("[VR] OpenXR no se pudo inicializar (¿casco conectado? ¿runtime abierto?). Modo plano.")
			xr_interface = null
			return
	get_viewport().use_xr = true
	# OpenXR controla su propia cadencia; el vsync del escritorio estorba.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	xr_active = true
	print("[VR] OpenXR activo.")
	# El rig se monta cuando la escena principal ya existe.
	call_deferred("_attach_rig")
	xr_state_changed.emit(true)

func _attach_rig() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.has_node("Player/VRRig") or scene.has_node("VRRig"):
		return  # ya montado
	var player := scene.get_node_or_null("Player")
	var mgr := scene.get_node_or_null("GameManager")
	rig = VR_RIG.new()
	rig.name = "VRRig"
	if mgr:
		rig.set("manager", mgr)
	# Lo colgamos del jugador (así sigue su locomoción); si no, de la escena.
	if player:
		player.add_child(rig)
	else:
		scene.add_child(rig)
	print("[VR] Rig VR montado.")

	# Panel 3D con el MENÚ del juego (la GameUI 2D metida en un SubViewport).
	var ui_node: Node = null
	if mgr and "ui" in mgr:
		ui_node = mgr.ui
	if ui_node == null:
		ui_node = scene.get_node_or_null("UI")
	if ui_node:
		var panel := VR_UI_PANEL.new()
		panel.name = "VRUIPanel"
		panel.position = Vector3(0.0, 1.3, -1.4)  # frente al jugador, a la altura de la vista
		rig.add_child(panel)
		panel.call("host_ui", ui_node)
		rig.set("ui_panel", panel)
		print("[VR] Menú 3D montado.")

func is_active() -> bool:
	return xr_active

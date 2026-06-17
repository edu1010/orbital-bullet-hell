extends XROrigin3D
## Rig de VR construido por código (encaja con el estilo del proyecto: todo
## generado, sin .tscn frágiles).
##
##   XROrigin3D (este nodo, colgado del Player)
##    ├─ XRCamera3D        -> el casco
##    ├─ LeftHand  (XRController3D "left_hand")  -> Weapon (vr_hand.gd, auto-dispara)
##    └─ RightHand (XRController3D "right_hand") -> Weapon (vr_hand.gd) + UIPointer
##
## Controles (mismo juego, ahora en VR):
##   - Joystick IZQUIERDO  -> moverte por la esfera (alimenta el input del jugador)
##   - Joystick DERECHO X  -> girar (giro suave, como el mouse-look)
##   - Botón A/X           -> saltar
##   - Las dos manos AUTO-DISPARAN mientras juegas (vr_hand.gd)
##
## `manager` (GameManager) lo asigna XRManager antes de entrar al árbol.

const VR_HAND := preload("res://scripts/vr/vr_hand.gd")
const VR_POINTER := preload("res://scripts/vr/vr_ui_pointer.gd")

@export var turn_speed := 2.6        # rad/s del giro suave
@export var stick_deadzone := 0.15
@export var jump_action := "ax_button"   # A / X

var manager = null
var camera: XRCamera3D
var left_hand: XRController3D
var right_hand: XRController3D
var ui_pointer: Node3D
var ui_panel: Node3D  # lo asigna XRManager (el menú 2D en 3D)


func _ready() -> void:
	camera = XRCamera3D.new()
	camera.name = "XRCamera"
	add_child(camera)

	left_hand = _make_controller("LeftHand", "left_hand")
	right_hand = _make_controller("RightHand", "right_hand")

	# Puntero láser para el menú, en la mano derecha.
	ui_pointer = Node3D.new()
	ui_pointer.name = "UIPointer"
	ui_pointer.set_script(VR_POINTER)
	right_hand.add_child(ui_pointer)

	# Botones de las manos (el 2º argumento identifica qué mano).
	left_hand.connect("button_pressed", _on_hand_button.bind("left"))
	right_hand.connect("button_pressed", _on_hand_button.bind("right"))


func _make_controller(node_name: String, tracker: String) -> XRController3D:
	var controller := XRController3D.new()
	controller.name = node_name
	controller.tracker = tracker
	add_child(controller)
	var weapon := Node3D.new()
	weapon.name = "Weapon"
	weapon.set_script(VR_HAND)
	weapon.set("manager", manager)  # ANTES de entrar al árbol (para que _ready lo vea)
	controller.add_child(weapon)
	return controller


func _process(delta: float) -> void:
	if manager == null:
		return
	var player = manager.player
	if player == null:
		return
	player.set("vr_active", true)

	# Locomoción: joystick izquierdo. Convención del juego: y+ = atrás.
	if left_hand:
		var move: Vector2 = left_hand.get_vector2("primary")
		if move.length() < stick_deadzone:
			move = Vector2.ZERO
		player.set("vr_move_input", Vector2(move.x, -move.y))

	# Giro suave: eje X del joystick derecho.
	if right_hand:
		var turn: Vector2 = right_hand.get_vector2("primary")
		if absf(turn.x) > stick_deadzone:
			player.call("apply_vr_turn", -turn.x * turn_speed * delta)

	# El menú 3D y el puntero solo se ven fuera de partida.
	var playing: bool = manager.has_method("is_playing") and manager.is_playing()
	if ui_pointer:
		ui_pointer.visible = not playing
	if ui_panel:
		ui_panel.visible = not playing


func _on_hand_button(action_name: String, hand: String) -> void:
	if manager == null:
		return
	var playing: bool = manager.has_method("is_playing") and manager.is_playing()

	# --- En el MENÚ: el gatillo CLICA los botones del menú 3D (lo hace el puntero
	# láser, vr_ui_pointer). El botón B/Y queda como atajo de emergencia para
	# arrancar una partida normal por si el menú diera problemas.
	if not playing:
		if action_name == "by_button" and manager.has_method("start_run"):
			manager.start_run()
		return

	# --- En PARTIDA: acciones del jugador ---
	var player = manager.player
	if player == null:
		return
	match action_name:
		jump_action:
			if player.has_method("vr_jump"):
				player.vr_jump()
		"trigger_click":
			# Gatillo derecho = disparo extra; izquierdo = escudo orbital.
			if hand == "right" and player.has_method("try_fire_extra"):
				player.try_fire_extra()
			elif hand == "left" and player.has_method("try_fire_orbital_shield"):
				player.try_fire_orbital_shield()
		"grip_click":
			if player.has_method("try_boost"):
				player.try_boost()

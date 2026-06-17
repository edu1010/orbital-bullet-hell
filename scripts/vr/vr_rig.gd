extends XROrigin3D
## Rig de VR construido por código (encaja con el estilo del proyecto: todo
## generado, sin .tscn frágiles).
##
##   XROrigin3D (este nodo)
##    ├─ XRCamera3D        -> el casco
##    ├─ LeftHand  (XRController3D "left_hand")  -> Weapon (vr_hand.gd)
##    └─ RightHand (XRController3D "right_hand") -> Weapon (vr_hand.gd) + UIPointer
##
## `manager` (GameManager) se asigna desde XRManager antes de entrar al árbol.

const VR_HAND := preload("res://scripts/vr/vr_hand.gd")
const VR_POINTER := preload("res://scripts/vr/vr_ui_pointer.gd")

var manager = null
var camera: XRCamera3D
var left_hand: XRController3D
var right_hand: XRController3D

func _ready() -> void:
	camera = XRCamera3D.new()
	camera.name = "XRCamera"
	add_child(camera)

	left_hand = _make_controller("LeftHand", "left_hand")
	right_hand = _make_controller("RightHand", "right_hand")

	# Puntero láser para el menú, en la mano derecha.
	var pointer := Node3D.new()
	pointer.name = "UIPointer"
	pointer.set_script(VR_POINTER)
	right_hand.add_child(pointer)


func _make_controller(node_name: String, tracker: String) -> XRController3D:
	var controller := XRController3D.new()
	controller.name = node_name
	controller.tracker = tracker
	add_child(controller)
	var weapon := Node3D.new()
	weapon.name = "Weapon"
	weapon.set_script(VR_HAND)
	controller.add_child(weapon)
	weapon.set("manager", manager)
	return controller

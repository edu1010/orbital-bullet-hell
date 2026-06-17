extends Node3D
## Arma sujeta a un mando VR. Dispara con el gatillo reutilizando el sistema de
## proyectiles del juego (GameManager.request_projectile), igual que el disparo
## primario en plano. Se construye una malla primitiva como "arma".

@export var fire_action := "trigger_click"   # acción booleana del gatillo (OpenXR)
@export var fire_rate := 7.0                 # disparos por segundo manteniendo el gatillo
@export var projectile_speed := 90.0

var manager = null            # GameManager (sin tipo: llamada dinámica)
var muzzle: Marker3D
var _trigger_held := false
var _fire_timer := 0.0


func _ready() -> void:
	_build_weapon()
	var controller := get_parent()
	if controller and controller.has_signal("button_pressed"):
		controller.connect("button_pressed", _on_button_pressed)
		controller.connect("button_released", _on_button_released)


func _build_weapon() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.22)
	body.mesh = box
	body.position = Vector3(0.0, 0.0, -0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.14, 0.2)
	mat.metallic = 0.6
	mat.roughness = 0.35
	body.material_override = mat
	add_child(body)

	muzzle = Marker3D.new()
	muzzle.position = Vector3(0.0, 0.0, -0.22)
	add_child(muzzle)


func _process(delta: float) -> void:
	if not _trigger_held:
		return
	_fire_timer += delta
	var interval: float = 1.0 / max(0.1, fire_rate)
	while _fire_timer >= interval:
		_fire_timer -= interval
		_fire()


func _on_button_pressed(action_name: String) -> void:
	if action_name == fire_action:
		_trigger_held = true
		_fire_timer = 1.0 / max(0.1, fire_rate)  # dispara de inmediato


func _on_button_released(action_name: String) -> void:
	if action_name == fire_action:
		_trigger_held = false


func _fire() -> void:
	if manager == null or muzzle == null:
		return
	if not manager.has_method("request_projectile"):
		return
	var origin: Vector3 = muzzle.global_position
	var direction: Vector3 = -muzzle.global_transform.basis.z.normalized()
	manager.request_projectile(origin, direction, projectile_speed)

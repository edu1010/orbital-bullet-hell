extends Node3D
## Arma sujeta a un mando VR. Es "el arma principal del juego, pero en tu mano":
## AUTO-DISPARA mientras hay partida (igual que el disparo primario automático),
## hacia donde apunta la mano, reutilizando GameManager.request_projectile.
## Con dos manos = dos cañones.

@export var fire_rate := 6.0          # disparos por segundo de ESTA mano
@export var projectile_speed := 90.0  # se sobrescribe con el del jugador si existe

var manager = null            # GameManager (sin tipo: llamada dinámica)
var muzzle: Marker3D
var _fire_timer := 0.0


func _ready() -> void:
	_build_weapon()
	# Igualar la velocidad de proyectil a la del jugador para un feel idéntico.
	if manager and manager.player and "projectile_speed" in manager.player:
		projectile_speed = manager.player.projectile_speed


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
	if not _is_playing():
		_fire_timer = 0.0
		return
	_fire_timer += delta
	var interval: float = 1.0 / max(0.1, fire_rate)
	while _fire_timer >= interval:
		_fire_timer -= interval
		_fire()


func _is_playing() -> bool:
	return manager != null and manager.has_method("is_playing") and manager.is_playing()


func _fire() -> void:
	if manager == null or muzzle == null:
		return
	if not manager.has_method("request_projectile"):
		return
	var origin: Vector3 = muzzle.global_position
	var direction: Vector3 = -muzzle.global_transform.basis.z.normalized()
	manager.request_projectile(origin, direction, projectile_speed)

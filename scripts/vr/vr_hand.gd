extends Node3D
## Arma de cada mano VR: la MISMA gatling del juego (la construye el jugador con
## build_gatling_viewmodel), que gira y suelta fogonazo desde su cañón. AUTO-DISPARA
## mientras hay partida, hacia donde apunta la mano. Dos manos = dos cañones.
##
## La gatling se construye de forma DIFERIDA: el `manager`/`player` puede no estar
## disponible aún en _ready (según el orden de init), así que se intenta cada frame
## hasta que el jugador exista.

@export var fire_rate := 6.0          # disparos por segundo de ESTA mano
@export var projectile_speed := 90.0  # se iguala al del jugador
@export var spin_speed := 18.0        # giro del cluster de cañones
@export var model_scale := 0.6        # tamaño de la gatling en la mano

var manager = null            # GameManager (sin tipo: llamada dinámica)
var muzzle: Marker3D
var _spin: Node3D
var _flash: MeshInstance3D
var _fire_timer := 0.0
var _flash_timer := 0.0
var _built := false


func _ready() -> void:
	_try_build()


func _try_build() -> void:
	if _built:
		return
	if manager == null or manager.player == null:
		return
	if not manager.player.has_method("build_gatling_viewmodel"):
		return
	_built = true
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * model_scale
	holder.position = Vector3(0.0, 0.0, -0.04)
	add_child(holder)
	var parts: Dictionary = manager.player.build_gatling_viewmodel(holder)
	_spin = parts.get("spin")
	muzzle = parts.get("muzzle")
	_flash = parts.get("flash")
	if "projectile_speed" in manager.player:
		projectile_speed = manager.player.projectile_speed


func _process(delta: float) -> void:
	if not _built:
		_try_build()
		return
	if _spin:
		_spin.rotate_object_local(Vector3(0.0, 0.0, 1.0), spin_speed * delta)
	if _flash:
		if _flash_timer > 0.0:
			_flash_timer = max(0.0, _flash_timer - delta)
			_flash.visible = true
			var f: float = _flash_timer / 0.05
			_flash.scale = Vector3.ONE * (0.55 + f * 0.95)
		elif _flash.visible:
			_flash.visible = false

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
	if manager == null or muzzle == null or not manager.has_method("request_projectile"):
		return
	var origin: Vector3 = muzzle.global_position
	var direction: Vector3 = -muzzle.global_transform.basis.z.normalized()
	manager.request_projectile(origin, direction, projectile_speed)
	_flash_timer = 0.05

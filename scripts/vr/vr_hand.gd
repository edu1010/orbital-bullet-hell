extends Node3D
## Arma de cada mano VR: la MISMA gatling del juego (la construye el jugador con
## build_gatling_viewmodel), que gira y suelta fogonazo desde su cañón. AUTO-DISPARA
## mientras hay partida, hacia donde apunta la mano. Dos manos = dos cañones.

@export var fire_rate := 6.0          # disparos por segundo de ESTA mano
@export var projectile_speed := 90.0  # se iguala al del jugador si existe
@export var spin_speed := 18.0        # giro del cluster de cañones
@export var model_scale := 0.6        # tamaño de la gatling en la mano

var manager = null            # GameManager (sin tipo: llamada dinámica)
var muzzle: Marker3D
var _spin: Node3D
var _flash: MeshInstance3D
var _fire_timer := 0.0
var _flash_timer := 0.0


func _ready() -> void:
	_build_weapon()
	if manager and manager.player and "projectile_speed" in manager.player:
		projectile_speed = manager.player.projectile_speed


func _build_weapon() -> void:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * model_scale
	holder.position = Vector3(0.0, 0.0, -0.04)
	add_child(holder)
	# Reutiliza la gatling real del juego.
	if manager and manager.player and manager.player.has_method("build_gatling_viewmodel"):
		var parts: Dictionary = manager.player.build_gatling_viewmodel(holder)
		_spin = parts.get("spin")
		muzzle = parts.get("muzzle")
		_flash = parts.get("flash")
	# Fallback si no hay jugador (no debería pasar): un marcador simple.
	if muzzle == null:
		muzzle = Marker3D.new()
		muzzle.position = Vector3(0.0, 0.0, -0.4)
		holder.add_child(muzzle)


func _process(delta: float) -> void:
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

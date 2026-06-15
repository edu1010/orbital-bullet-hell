class_name TutorialController
extends Node

# Guided tutorial: a sequence of self-contained "scenes", one per game element.
# Each scene drops the player into a controlled sandbox, states an objective, and
# only advances once the matching mechanic is actually performed. Contact is made
# non-lethal while a tutorial is active (see GameManager._handle_player_enemy_contacts),
# so the player is free to practice without ending the lesson.

const COMPLETE_HOLD := 1.5
const FINISH_HOLD := 3.0
const MOVE_DISTANCE_GOAL := 16.0

const STAGES: Array[Dictionary] = [
	{
		"id": "move",
		"title": "MOVIMIENTO",
		"objective": "Muévete con [W][A][S][D] y mira con el [RATÓN].",
	},
	{
		"id": "jump",
		"title": "SALTO",
		"objective": "Pulsa [ESPACIO] para saltar. Púlsalo de nuevo en el aire para el doble salto.",
	},
	{
		"id": "shoot",
		"title": "DISPARO PRIMARIO",
		"objective": "Tu arma dispara sola. Apunta al enemigo y destrúyelo.",
	},
	{
		"id": "enemy_jump",
		"title": "SALTO SOBRE ENEMIGO",
		"objective": "Sube encima del enemigo y rebota con [ESPACIO] para recargar el escudo.",
	},
	{
		"id": "extra",
		"title": "DISPARO EXTRA",
		"objective": "Carga lista. Pulsa [CLIC IZQ] para lanzar el rayo y barrer a los enemigos.",
	},
	{
		"id": "shield",
		"title": "ESCUDO ORBITAL",
		"objective": "Carga lista. Pulsa [CLIC DER] para lanzar el escudo y elevarte.",
	},
	{
		"id": "boost",
		"title": "IMPULSO",
		"objective": "Carga lista. Pulsa [SHIFT] para impulsarte a gran velocidad.",
	},
	{
		"id": "charger",
		"title": "ENEMIGO: CARGADOR",
		"objective": "Destruye al Cargador. Zigzaguea para alcanzarte: síguelo con la mira.",
	},
	{
		"id": "avoider",
		"title": "ENEMIGO: ESQUIVADOR",
		"objective": "Destruye al Esquivador. Esquiva tus balas, ¡acércate y acorrálalo!",
	},
	{
		"id": "bomb",
		"title": "BOMBA",
		"objective": "Detona la Bomba disparándole desde lejos. ¡Jamás la toques en una partida real!",
	},
	{
		"id": "reflector",
		"title": "REFLECTOR DE CURA",
		"objective": "Dispárale al Reflector para atraerlo: te curará y lanzará rayos sanadores.",
	},
	{
		"id": "magnet",
		"title": "IMÁN DE PUNTOS",
		"objective": "Recoge el Imán para atraer hacia ti todos los fragmentos de puntos.",
	},
]

var manager: GameManager
var player: PlayerController
var ui: GameUI

var active := false
var stage_index := 0
var phase := "idle"  # "playing", "complete", "finished"
var hold_timer := 0.0
var stage_objects: Array = []
var move_accumulated := 0.0
var last_player_position := Vector3.ZERO
var baselines: Dictionary = {}
var respawn_timer := 0.0


func configure(_manager: GameManager, _player: PlayerController, _ui: GameUI) -> void:
	manager = _manager
	player = _player
	ui = _ui
	set_process(false)


func start_tutorial() -> void:
	if not manager or not player or not ui:
		return
	Engine.time_scale = 1.0
	manager.clear_active_field()
	manager.score = 0
	manager.combo = 1.0
	manager.survival_time = 0.0
	manager.kills_this_run = 0
	manager.score_magnets_collected = 0
	manager.state = GameManager.RunState.TUTORIAL
	player.reset_for_run(player.get_default_spawn_position())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ui.show_state(GameManager.RunState.TUTORIAL)
	ui.show_tutorial_panel(true)
	active = true
	stage_index = 0
	set_process(true)
	_setup_stage()
	manager.run_state_changed.emit(manager.state)


func stop_tutorial() -> void:
	active = false
	set_process(false)
	phase = "idle"
	_clear_stage_objects()
	manager.clear_active_field()
	if ui:
		ui.show_tutorial_panel(false)
	manager.show_main_menu()


func skip_stage() -> void:
	if not active or phase != "playing":
		return
	_complete_current_stage()


func _process(delta: float) -> void:
	if not active or not manager or manager.state != GameManager.RunState.TUTORIAL:
		return
	match phase:
		"playing":
			_maintain_stage(delta)
			if _check_stage():
				_complete_current_stage()
		"complete":
			hold_timer -= delta
			if hold_timer <= 0.0:
				_advance_stage()
		"finished":
			hold_timer -= delta
			if hold_timer <= 0.0:
				stop_tutorial()


func _current_stage() -> Dictionary:
	return STAGES[stage_index]


func _setup_stage() -> void:
	phase = "playing"
	_clear_stage_objects()
	move_accumulated = 0.0
	respawn_timer = 0.0
	last_player_position = player.global_position
	baselines = {
		"kills": manager.kills_this_run,
		"jumps": player.stat_jumps,
		"air_jumps": player.stat_air_jumps,
		"enemy_jumps": player.stat_enemy_jumps,
		"extra": player.stat_extra_shots,
		"shield": player.stat_shield_shots,
		"boost": player.stat_boosts,
		"magnets": manager.score_magnets_collected,
	}
	var stage: Dictionary = _current_stage()
	match stage["id"]:
		"shoot":
			_spawn_tracked("swarmer", _front_point(14.0, 1.2))
		"enemy_jump":
			_spawn_tracked("charger", _front_point(5.0, 1.0))
		"extra":
			for i in range(5):
				var offset: float = float(i - 2) * 3.2
				_spawn_tracked("swarmer", _front_point(20.0 + abs(offset), 1.4) + player.get_tangent_right() * offset)
			player.extra_charge = player.extra_shot_charge_max
			player.ready_cue_played = true
		"shield":
			for i in range(6):
				var angle: float = TAU * float(i) / 6.0
				var ring: Vector3 = player.get_tangent_right() * cos(angle) + player.get_tangent_forward() * sin(angle)
				_spawn_tracked("swarmer", player.project_inside_sphere(player.global_position + ring * 5.0, 1.2))
			player.orbital_shield_charge = player.orbital_shield_charge_max
			player.orbital_shield_ready_cue_played = true
		"boost":
			player.boost_charge = player.boost_charge_max
			player.boost_ready_cue_played = true
		"charger":
			_spawn_tracked("charger", _front_point(16.0, 1.4))
		"avoider":
			_spawn_tracked("avoider", _front_point(15.0, 1.4))
		"bomb":
			_spawn_bomb_tracked(_front_point(20.0, 8.0))
		"reflector":
			player.hp = max(1.0, player.max_hp - 1.0)
			_spawn_reflector_tracked(_front_point(15.0, 5.0))
		"magnet":
			_spawn_magnet_demo()
	ui.set_tutorial_stage(stage_index + 1, STAGES.size(), stage["title"], stage["objective"])


func _maintain_stage(_delta: float) -> void:
	var stage_id: String = _current_stage()["id"]
	match stage_id:
		"move":
			var moved: float = player.global_position.distance_to(last_player_position)
			# Ignore large teleport-like jumps from gravity re-alignment.
			if moved < 4.0:
				move_accumulated += moved
			last_player_position = player.global_position
		"extra":
			player.extra_charge = player.extra_shot_charge_max
		"shield":
			player.orbital_shield_charge = player.orbital_shield_charge_max
		"boost":
			player.boost_charge = player.boost_charge_max
		"magnet":
			respawn_timer -= _delta
			if respawn_timer <= 0.0 and not _has_active_object():
				_spawn_magnet_demo()


func _check_stage() -> bool:
	var stage_id: String = _current_stage()["id"]
	match stage_id:
		"move":
			return move_accumulated >= MOVE_DISTANCE_GOAL
		"jump":
			return player.stat_jumps - int(baselines["jumps"]) >= 1 and player.stat_air_jumps - int(baselines["air_jumps"]) >= 1
		"shoot", "charger", "avoider":
			return manager.kills_this_run - int(baselines["kills"]) >= 1
		"enemy_jump":
			return player.stat_enemy_jumps - int(baselines["enemy_jumps"]) >= 1
		"extra":
			return player.stat_extra_shots - int(baselines["extra"]) >= 1
		"shield":
			return player.stat_shield_shots - int(baselines["shield"]) >= 1
		"boost":
			return player.stat_boosts - int(baselines["boost"]) >= 1
		"bomb", "reflector":
			return not _has_active_object()
		"magnet":
			return manager.score_magnets_collected - int(baselines["magnets"]) >= 1
	return false


func _complete_current_stage() -> void:
	phase = "complete"
	hold_timer = COMPLETE_HOLD
	_clear_stage_objects()
	if ui:
		ui.tutorial_stage_complete()
	if player and manager:
		manager.spawn_burst(player.global_position, Color(0.45, 1.0, 0.55), 3.0, 0.4)


func _advance_stage() -> void:
	stage_index += 1
	if stage_index >= STAGES.size():
		phase = "finished"
		hold_timer = FINISH_HOLD
		if ui:
			ui.tutorial_finished()
		return
	_setup_stage()


# --- Spawning helpers ------------------------------------------------------

func _front_point(distance: float, altitude: float) -> Vector3:
	var approx: Vector3 = player.global_position + player.get_tangent_forward() * distance
	return player.project_inside_sphere(approx, altitude)


func _spawn_tracked(enemy_type: String, spawn_position: Vector3) -> void:
	var enemy: EnemyBase = manager.spawn_enemy(enemy_type, spawn_position)
	if enemy:
		stage_objects.append(enemy)


func _spawn_bomb_tracked(spawn_position: Vector3) -> void:
	var bomb: BombEnemy = manager.spawn_bomb(spawn_position)
	if bomb:
		stage_objects.append(bomb)


func _spawn_reflector_tracked(spawn_position: Vector3) -> void:
	var reflector: HealReflector = manager.spawn_heal_reflector(spawn_position)
	if reflector:
		stage_objects.append(reflector)


func _spawn_magnet_demo() -> void:
	respawn_timer = 6.0
	var magnet: ScoreMagnet = manager.spawn_score_magnet(_front_point(6.0, 3.0))
	if magnet:
		stage_objects.append(magnet)
	# Far-flung shards so the magnet's pull is visible instead of auto-collected.
	manager.spawn_shards(_front_point(22.0, 2.0), 10, manager.shard_base_value, 5.0)
	manager.spawn_shards(player.global_position - player.get_tangent_forward() * 20.0, 8, manager.shard_base_value, 5.0)


func _has_active_object() -> bool:
	for object in stage_objects:
		if object and object.active:
			return true
	return false


func _clear_stage_objects() -> void:
	for object in stage_objects:
		if object and object.active:
			object.deactivate()
	stage_objects.clear()

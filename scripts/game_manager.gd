class_name GameManager
extends Node

signal run_state_changed(state: int)

enum RunState { MENU, PLAYING, PAUSED, GAME_OVER, TUTORIAL, REPLAY }

# Central run coordinator: owns state, score, combo, high score, pooled objects,
# and cross-system collision rules that are cheaper as distance checks.
@export_group("Pools")
@export var max_active_enemies := 2400
@export var max_active_projectiles := 180
@export var max_active_shards := 700
@export var projectile_pool_initial := 90
@export var shard_pool_initial := 180
@export var effect_pool_initial := 36
@export var laser_beam_pool_initial := 8
@export var laser_ring_pool_initial := 56
@export var heal_reflector_pool_initial := 18
@export var score_magnet_pool_initial := 6
@export var swarmer_pool_initial := 460
@export var charger_pool_initial := 150
@export var avoider_pool_initial := 150
@export var bomb_pool_initial := 24
@export var max_active_reflectors := 18
@export var max_active_score_magnets := 6
@export var max_active_overdrive_orbs := 2
@export var overdrive_orb_pool_initial := 2

@export_group("Scoring")
@export var shard_base_value := 5
@export var combo_kill_gain := 0.08
@export var combo_shard_gain := 0.025
@export var combo_decay_delay := 2.2
@export var combo_decay_rate := 0.9
@export var combo_max := 12.0
@export var score_magnet_drop_chance := 0.035

@export_group("Power Surge")
@export var score_milestone_step := 10000
@export var power_surge_time_scale := 0.28
@export var power_surge_duration_seconds := 2.4

@export_group("Heal Waves")
@export var heal_wave_duration := 2.4
@export var heal_wave_start_radius := 2.2
@export var heal_wave_thickness := 2.6
@export var heal_wave_visual_width := 0.75
@export var heal_wave_visual_width_scale := 0.028

const PROJECTILE_SCENE := preload("res://scenes/projectiles/Projectile.tscn")
const SHARD_SCENE := preload("res://scenes/shards/Shard.tscn")
const BURST_SCENE := preload("res://scenes/effects/BurstEffect.tscn")
const LASER_BEAM_SCENE := preload("res://scenes/effects/LaserBeamEffect.tscn")
const LASER_RING_SCENE := preload("res://scenes/effects/LaserRingEffect.tscn")
const HEAL_REFLECTOR_SCENE := preload("res://scenes/pickups/HealReflector.tscn")
const SCORE_MAGNET_SCENE := preload("res://scenes/pickups/ScoreMagnet.tscn")
const OVERDRIVE_ORB_SCENE := preload("res://scenes/pickups/OverdriveOrb.tscn")
const ENEMY_SCENES := {
	"swarmer": preload("res://scenes/enemies/Swarmer.tscn"),
	"charger": preload("res://scenes/enemies/Charger.tscn"),
	"avoider": preload("res://scenes/enemies/Avoider.tscn"),
	"bomb": preload("res://scenes/enemies/Bomb.tscn"),
}

var state: int = RunState.MENU
var score := 0
var high_score := 0
var combo := 1.0
var combo_decay_timer := 0.0
var survival_time := 0.0

var player: PlayerController
var spawn_manager: SpawnManager
var ui: GameUI
var tutorial: TutorialController
var boss: BossController
var replay: ReplayController
var enemies_container: Node3D
var projectiles_container: Node3D
var shards_container: Node3D
var effects_container: Node3D
var reflectors_container: Node3D

var enemy_pools := {}
var projectile_pool: Array[PlayerProjectile] = []
var shard_pool: Array[ScoreShard] = []
var effect_pool: Array[BurstEffect] = []
var laser_beam_pool: Array[LaserBeamEffect] = []
var laser_ring_pool: Array[LaserRingEffect] = []
var heal_reflector_pool: Array[HealReflector] = []
var score_magnet_pool: Array[ScoreMagnet] = []
var overdrive_orb_pool: Array[OverdriveOrb] = []
var active_enemies: Array[EnemyBase] = []
var active_projectiles: Array[PlayerProjectile] = []
var active_shards: Array[ScoreShard] = []
var active_reflectors: Array[HealReflector] = []
var active_score_magnets: Array[ScoreMagnet] = []
var active_overdrive_orbs: Array[OverdriveOrb] = []
var active_heal_waves: Array[Dictionary] = []
var kills_this_run := 0
var kills_in_sample := 0
var kill_rate_sample_timer := 0.0
var recent_kill_rate := 0.0
var next_power_surge_score := 10000
var power_surge_end_msec := 0
var start_controls_hint_visible := false
var score_magnets_collected := 0
var enemy_warn_radius := 46.0
var warn_active := false
var warn_position := Vector3.ZERO
var warn_distance := 0.0
var warn_is_bomb := false
var boss_score_threshold := 40000
var boss_started := false
var game_mode := "normal"


func configure(
	_player: PlayerController,
	_spawn_manager: SpawnManager,
	_ui: GameUI,
	_enemies_container: Node3D,
	_projectiles_container: Node3D,
	_shards_container: Node3D,
	_effects_container: Node3D,
	_reflectors_container: Node3D
) -> void:
	player = _player
	spawn_manager = _spawn_manager
	ui = _ui
	enemies_container = _enemies_container
	projectiles_container = _projectiles_container
	shards_container = _shards_container
	effects_container = _effects_container
	reflectors_container = _reflectors_container
	_load_high_score()
	_setup_pools()
	_update_ui()


func can_replay() -> bool:
	return replay != null and replay.has_replay()


func start_replay() -> void:
	if not can_replay():
		return
	Engine.time_scale = 1.0
	power_surge_end_msec = 0
	if boss:
		boss.stop()
	_deactivate_all()
	if player:
		player.visible = false
	state = RunState.REPLAY
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	ui.show_state(state)
	replay.start_playback()
	run_state_changed.emit(state)


func exit_replay() -> void:
	if state != RunState.REPLAY:
		return
	if replay:
		replay.stop_playback()
	if player:
		player.visible = true
	return_to_main_menu()


func add_boss_reward(amount: int) -> void:
	_add_score(amount)
	if player:
		spawn_burst(player.global_position, Color(1.0, 0.85, 0.4), 6.0, 0.6)


func show_main_menu() -> void:
	Engine.time_scale = 1.0
	if boss:
		boss.stop()
	boss_started = false
	power_surge_end_msec = 0
	start_controls_hint_visible = false
	state = RunState.MENU
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if ui:
		ui.show_start_controls_hint(false)
		ui.show_state(state)
	run_state_changed.emit(state)


func start_run() -> void:
	_begin_run("normal")


func start_boss_rush() -> void:
	_begin_run("boss_rush")


func restart_run() -> void:
	# Retry from game over in whatever mode was being played, not always normal.
	_begin_run(game_mode)


func is_boss_rush() -> bool:
	return game_mode == "boss_rush"


func _begin_run(mode: String) -> void:
	if not player:
		return
	Engine.time_scale = 1.0
	# Pools stay allocated across runs; only active objects are hidden/reset.
	_deactivate_all()
	game_mode = mode
	score = 0
	next_power_surge_score = maxi(1, score_milestone_step)
	power_surge_end_msec = 0
	start_controls_hint_visible = true
	combo = 1.0
	combo_decay_timer = 0.0
	survival_time = 0.0
	kills_this_run = 0
	kills_in_sample = 0
	kill_rate_sample_timer = 0.0
	recent_kill_rate = 0.0
	score_magnets_collected = 0
	boss_started = false
	if boss:
		boss.reset_for_run(mode)
	state = RunState.PLAYING
	if replay:
		replay.begin_recording()
	player.reset_for_run(player.get_default_spawn_position())
	spawn_manager.reset_for_run()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ui.show_state(state)
	ui.show_start_controls_hint(true)
	run_state_changed.emit(state)
	_update_ui()


func toggle_pause() -> void:
	if state == RunState.PLAYING:
		state = RunState.PAUSED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif state == RunState.PAUSED:
		state = RunState.PLAYING
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		return
	ui.show_state(state)
	run_state_changed.emit(state)


func resume_from_pause() -> void:
	if state != RunState.PAUSED:
		return
	state = RunState.PLAYING
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ui.show_state(state)
	run_state_changed.emit(state)


func return_to_main_menu() -> void:
	if state != RunState.MENU:
		high_score = max(high_score, score)
		_save_high_score()
		_deactivate_all()
	show_main_menu()
	_update_ui()


func end_run() -> void:
	if state == RunState.GAME_OVER:
		return
	Engine.time_scale = 1.0
	if boss:
		boss.stop()
	if replay:
		replay.stop_recording()
	power_surge_end_msec = 0
	start_controls_hint_visible = false
	state = RunState.GAME_OVER
	high_score = max(high_score, score)
	_save_high_score()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	ui.show_start_controls_hint(false)
	ui.show_state(state)
	run_state_changed.emit(state)
	_update_ui()


func is_playing() -> bool:
	# Tutorial reuses the live simulation (player, enemies, pickups) so the
	# moving parts that gate on is_playing() keep running while teaching.
	return state == RunState.PLAYING or state == RunState.TUTORIAL


func is_tutorial() -> bool:
	return state == RunState.TUTORIAL


func start_tutorial() -> void:
	if tutorial:
		tutorial.start_tutorial()


func stop_tutorial() -> void:
	if tutorial:
		tutorial.stop_tutorial()


func clear_active_field() -> void:
	_deactivate_all()


func dismiss_start_controls_hint() -> void:
	if not start_controls_hint_visible:
		return
	start_controls_hint_visible = false
	if ui:
		ui.show_start_controls_hint(false)


func get_bound_key(action_name: String, fallback: int) -> int:
	if ui:
		return ui.get_bound_key(action_name, fallback)
	return fallback


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var menu_key: int = get_bound_key("menu", KEY_ESCAPE)
		if state == RunState.TUTORIAL:
			if event.keycode == menu_key:
				stop_tutorial()
			elif tutorial and event.keycode == KEY_N:
				tutorial.skip_stage()
			return
		if state == RunState.REPLAY:
			if event.keycode == menu_key:
				exit_replay()
			return
		if event.keycode == menu_key:
			if (state == RunState.MENU or state == RunState.PAUSED) and ui and not ui.is_base_menu_screen():
				ui.return_to_main_menu_screen()
			else:
				toggle_pause()
		elif state == RunState.GAME_OVER and event.keycode == KEY_R:
			restart_run()
		elif state == RunState.MENU and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			if not ui or ui.is_main_menu_screen():
				start_run()


func _process(delta: float) -> void:
	_update_power_surge_state()
	if not is_playing():
		return
	if not is_tutorial():
		survival_time += delta
		if combo_decay_timer > 0.0:
			combo_decay_timer -= delta
		else:
			combo = max(1.0, combo - combo_decay_rate * delta)
		_update_kill_rate(delta)
		if replay:
			replay.record(delta)
	_update_heal_waves(delta)
	_handle_player_enemy_contacts()
	_update_ui()


func _setup_pools() -> void:
	# Small pools are prewarmed but can grow until their active caps are reached.
	enemy_pools.clear()
	for enemy_type in ENEMY_SCENES.keys():
		enemy_pools[enemy_type] = []
	_prewarm_enemy_pool("swarmer", swarmer_pool_initial)
	_prewarm_enemy_pool("charger", charger_pool_initial)
	_prewarm_enemy_pool("avoider", avoider_pool_initial)
	_prewarm_enemy_pool("bomb", bomb_pool_initial)
	_prewarm_pool(projectile_pool, PROJECTILE_SCENE, projectiles_container, projectile_pool_initial)
	_prewarm_pool(shard_pool, SHARD_SCENE, shards_container, shard_pool_initial)
	_prewarm_pool(effect_pool, BURST_SCENE, effects_container, effect_pool_initial)
	_prewarm_pool(laser_beam_pool, LASER_BEAM_SCENE, effects_container, laser_beam_pool_initial)
	_prewarm_pool(laser_ring_pool, LASER_RING_SCENE, effects_container, laser_ring_pool_initial)
	_prewarm_pool(heal_reflector_pool, HEAL_REFLECTOR_SCENE, reflectors_container, heal_reflector_pool_initial)
	_prewarm_pool(score_magnet_pool, SCORE_MAGNET_SCENE, reflectors_container, score_magnet_pool_initial)
	_prewarm_pool(overdrive_orb_pool, OVERDRIVE_ORB_SCENE, reflectors_container, overdrive_orb_pool_initial)


func _prewarm_enemy_pool(enemy_type: String, count: int) -> void:
	_prewarm_pool(enemy_pools[enemy_type], ENEMY_SCENES[enemy_type], enemies_container, count)


func _prewarm_pool(pool: Array, scene: PackedScene, container: Node, count: int) -> void:
	for i in range(count):
		var node = scene.instantiate()
		container.add_child(node)
		if node.has_method("deactivate"):
			node.deactivate()
		pool.append(node)


func _get_from_pool(pool: Array, scene: PackedScene, container: Node, max_active: int = -1) -> Node:
	for node in pool:
		if not node.active:
			return node
	if max_active > 0 and _count_active(pool) >= max_active:
		return null
	var node = scene.instantiate()
	container.add_child(node)
	if node.has_method("deactivate"):
		node.deactivate()
	pool.append(node)
	return node


func _count_active(pool: Array) -> int:
	var count := 0
	for node in pool:
		if node.active:
			count += 1
	return count


func _deactivate_all() -> void:
	for enemy_type in enemy_pools.keys():
		for enemy in enemy_pools[enemy_type]:
			enemy.deactivate()
	for projectile in projectile_pool:
		projectile.deactivate()
	for shard in shard_pool:
		shard.deactivate()
	for effect in effect_pool:
		effect.deactivate()
	for beam in laser_beam_pool:
		beam.deactivate()
	for ring in laser_ring_pool:
		ring.deactivate()
	for reflector in heal_reflector_pool:
		reflector.deactivate()
	for magnet in score_magnet_pool:
		magnet.deactivate()
	for orb in overdrive_orb_pool:
		orb.deactivate()
	active_enemies.clear()
	active_projectiles.clear()
	active_shards.clear()
	active_reflectors.clear()
	active_score_magnets.clear()
	active_overdrive_orbs.clear()
	active_heal_waves.clear()


func spawn_enemy(enemy_type: String, spawn_position: Vector3) -> EnemyBase:
	if active_enemy_count() >= max_active_enemies:
		return null
	if not enemy_pools.has(enemy_type):
		return null
	var enemy: EnemyBase = _get_from_pool(enemy_pools[enemy_type], ENEMY_SCENES[enemy_type], enemies_container, max_active_enemies) as EnemyBase
	if not enemy:
		return null
	enemy.activate(self, player, spawn_position)
	if not active_enemies.has(enemy):
		active_enemies.append(enemy)
	return enemy


func spawn_bomb(spawn_position: Vector3) -> BombEnemy:
	return spawn_enemy("bomb", spawn_position) as BombEnemy


func request_projectile(origin: Vector3, direction: Vector3, speed: float) -> void:
	var projectile: PlayerProjectile = _get_from_pool(projectile_pool, PROJECTILE_SCENE, projectiles_container, max_active_projectiles) as PlayerProjectile
	if not projectile:
		return
	projectile.activate(self, origin, direction, speed)
	if not active_projectiles.has(projectile):
		active_projectiles.append(projectile)


func spawn_shards(origin: Vector3, count: int, value: int = -1, spread: float = 3.0) -> void:
	if value < 0:
		value = shard_base_value
	for i in range(count):
		if active_shard_count() >= max_active_shards:
			return
		var shard: ScoreShard = _get_from_pool(shard_pool, SHARD_SCENE, shards_container, max_active_shards) as ScoreShard
		if not shard:
			return
		var impulse := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.1, 1.25),
			randf_range(-1.0, 1.0)
		).normalized() * randf_range(1.0, spread)
		shard.activate(self, player, origin + impulse * 0.16, impulse, value)
		if not active_shards.has(shard):
			active_shards.append(shard)


func spawn_burst(origin: Vector3, color: Color, burst_scale: float = 1.0, lifetime: float = 0.28) -> void:
	var effect: BurstEffect = _get_from_pool(effect_pool, BURST_SCENE, effects_container) as BurstEffect
	if not effect:
		return
	effect.activate(origin, color, burst_scale, lifetime)


func spawn_laser_beam(origin: Vector3, direction: Vector3, length: float, radius: float, color: Color, lifetime: float) -> void:
	var beam: LaserBeamEffect = _get_from_pool(laser_beam_pool, LASER_BEAM_SCENE, effects_container) as LaserBeamEffect
	if not beam:
		return
	beam.activate(origin, direction, length, radius, color, lifetime)


func spawn_laser_ring(
	origin: Vector3,
	direction: Vector3,
	start_radius: float,
	end_radius: float,
	color: Color,
	lifetime: float,
	width_hint: float = -1.0,
	width_scale: float = -1.0
) -> void:
	var ring: LaserRingEffect = _get_from_pool(laser_ring_pool, LASER_RING_SCENE, effects_container) as LaserRingEffect
	if not ring:
		return
	ring.activate(origin, direction, start_radius, end_radius, color, lifetime, width_hint, width_scale)


func spawn_orbital_shield_visual(origin: Vector3, axis: Vector3, radius: float) -> void:
	var shield_color := Color(0.38, 0.94, 1.0, 0.92)
	var normalized_axis: Vector3 = axis.normalized()
	if normalized_axis.length_squared() <= 0.001:
		normalized_axis = Vector3.UP
	var tangent: Vector3 = normalized_axis.cross(Vector3.UP)
	if tangent.length_squared() <= 0.001:
		tangent = normalized_axis.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent: Vector3 = normalized_axis.cross(tangent).normalized()
	spawn_burst(origin, shield_color, radius * 1.15, 0.5)
	for ring_direction in [normalized_axis, tangent, bitangent]:
		spawn_laser_ring(origin, ring_direction, radius * 0.25, radius * 1.08, shield_color, 0.42)


func spawn_heal_cross_waves(origin: Vector3) -> void:
	if not player:
		return
	var view_basis: Basis = player.get_view_basis()
	var forward: Vector3 = -view_basis.z
	if forward.length_squared() <= 0.001:
		forward = player.get_tangent_forward()
	forward = forward.normalized()
	var right: Vector3 = view_basis.x
	if right.length_squared() <= 0.001:
		right = player.get_tangent_right()
	right = right.normalized()
	var max_radius: float = player.sphere_radius * 2.0
	var wave_normals := [(forward + right * 0.35).normalized(), (forward - right * 0.35).normalized()]
	var wave_color := Color(0.55, 0.98, 1.0, 0.98)
	for i in range(wave_normals.size()):
		var normal: Vector3 = wave_normals[i]
		active_heal_waves.append({
			"origin": origin,
			"normal": normal,
			"age": 0.0,
			"prev_radius": heal_wave_start_radius,
			"max_radius": max_radius,
		})
		spawn_laser_ring(
			origin,
			normal,
			heal_wave_start_radius,
			max_radius,
			wave_color,
			heal_wave_duration,
			heal_wave_visual_width,
			heal_wave_visual_width_scale
		)
	spawn_burst(origin, wave_color, heal_wave_start_radius * 1.7, 0.28)


func spawn_heal_reflector(spawn_position: Vector3) -> HealReflector:
	if active_reflector_count() >= max_active_reflectors:
		return null
	var reflector: HealReflector = _get_from_pool(heal_reflector_pool, HEAL_REFLECTOR_SCENE, reflectors_container, max_active_reflectors) as HealReflector
	if not reflector:
		return null
	reflector.activate(self, player, spawn_position)
	if not active_reflectors.has(reflector):
		active_reflectors.append(reflector)
	return reflector


func spawn_score_magnet(spawn_position: Vector3) -> ScoreMagnet:
	if active_score_magnet_count() >= max_active_score_magnets:
		return null
	var magnet: ScoreMagnet = _get_from_pool(score_magnet_pool, SCORE_MAGNET_SCENE, reflectors_container, max_active_score_magnets) as ScoreMagnet
	if not magnet:
		return null
	magnet.activate(self, player, spawn_position)
	if not active_score_magnets.has(magnet):
		active_score_magnets.append(magnet)
	return magnet


func spawn_overdrive_orb(spawn_position: Vector3) -> OverdriveOrb:
	if active_overdrive_orb_count() >= max_active_overdrive_orbs:
		return null
	var orb: OverdriveOrb = _get_from_pool(overdrive_orb_pool, OVERDRIVE_ORB_SCENE, reflectors_container, max_active_overdrive_orbs) as OverdriveOrb
	if not orb:
		return null
	orb.activate(self, player, spawn_position)
	if not active_overdrive_orbs.has(orb):
		active_overdrive_orbs.append(orb)
	return orb


func on_enemy_killed(enemy: EnemyBase, source: String, spawn_pickups: bool = true) -> void:
	# Kills feed score, combo, shards, and extra-shot charge from one place.
	kills_this_run += 1
	kills_in_sample += 1
	var gain: int = int(round(float(enemy.score_value) * combo))
	_add_score(gain)
	combo = min(combo_max, combo + combo_kill_gain)
	combo_decay_timer = combo_decay_delay
	if spawn_pickups:
		var shard_count: int = randi_range(enemy.shard_drop_min, enemy.shard_drop_max)
		spawn_shards(enemy.global_position, shard_count, shard_base_value, 3.1)
		_try_spawn_score_magnet(enemy.global_position)
	if player:
		player.add_kill_charge(source, combo)
	spawn_burst(enemy.global_position, enemy.visual_color, enemy.body_radius * 1.6, 0.24)


func _try_spawn_score_magnet(origin: Vector3) -> void:
	if randf() > score_magnet_drop_chance:
		return
	var magnet_position := origin
	if player:
		magnet_position = player.project_inside_sphere(origin, 4.0)
	var magnet: ScoreMagnet = spawn_score_magnet(magnet_position)
	if magnet:
		spawn_burst(magnet_position, Color(0.85, 0.35, 1.0), 2.6, 0.26)


func collect_shard(value: int) -> void:
	_add_score(int(round(float(value) * combo)))
	combo = min(combo_max, combo + combo_shard_gain)
	combo_decay_timer = combo_decay_delay
	if player:
		player.add_orbital_shield_charge(float(value) * player.orbital_shield_shard_charge_per_point)


func attract_all_shards() -> void:
	# Only score magnets call this, so it doubles as a "magnet collected" signal.
	score_magnets_collected += 1
	for shard in active_shards:
		if shard.active:
			shard.magnetize()


func _add_score(amount: int) -> void:
	if amount <= 0:
		return
	score += amount
	# Boss waves are driven by the BossController, which watches the score itself.
	# The gap to the next power surge scales with the current combo: a high multiplier
	# rakes in score far faster (and the surge's slow-mo makes scoring easier still),
	# so the score needed for the next surge rises in lockstep with the combo. At x12
	# the gap is the base step x12, keeping surges roughly as rare as at x1.
	var step: int = maxi(1, int(round(float(score_milestone_step) * combo)))
	if next_power_surge_score <= 0:
		next_power_surge_score = step
	var should_activate := false
	while score >= next_power_surge_score:
		should_activate = true
		next_power_surge_score += step
	if should_activate:
		_activate_power_surge()


func _activate_power_surge() -> void:
	power_surge_end_msec = Time.get_ticks_msec() + int(power_surge_duration_seconds * 1000.0)
	Engine.time_scale = clamp(power_surge_time_scale, 0.05, 1.0)
	if player:
		player.refill_all_charges()
		player.add_camera_shake(0.22, 0.18)
		spawn_burst(player.global_position, Color(0.35, 0.95, 1.0), 6.0, 0.55)
		spawn_laser_ring(player.global_position, -player.get_gravity_down(), 1.2, 14.0, Color(0.6, 1.0, 0.95, 0.95), 0.7, 0.35, 0.018)
	if ui:
		ui.power_surge_feedback()


func _update_power_surge_state() -> void:
	if power_surge_end_msec <= 0:
		return
	if Time.get_ticks_msec() < power_surge_end_msec:
		return
	Engine.time_scale = 1.0
	power_surge_end_msec = 0


func find_enemy_hit(position: Vector3, radius: float, include_bombs := true) -> EnemyBase:
	for enemy in active_enemies:
		if not enemy.active:
			continue
		if not include_bombs and enemy is BombEnemy:
			continue
		var hit_radius := radius + enemy.body_radius
		if enemy.global_position.distance_squared_to(position) <= hit_radius * hit_radius:
			return enemy
	return null


func get_nearby_projectiles(position: Vector3, radius: float) -> Array[PlayerProjectile]:
	var nearby: Array[PlayerProjectile] = []
	var radius_sq := radius * radius
	for projectile in active_projectiles:
		if projectile.active and projectile.global_position.distance_squared_to(position) <= radius_sq:
			nearby.append(projectile)
	return nearby


func find_reflector_hit(position: Vector3, radius: float) -> HealReflector:
	for reflector in active_reflectors:
		if not reflector.active:
			continue
		var hit_radius: float = radius + reflector.body_radius
		if reflector.global_position.distance_squared_to(position) <= hit_radius * hit_radius:
			return reflector
	return null


func find_score_magnet_hit(position: Vector3, radius: float) -> ScoreMagnet:
	for magnet in active_score_magnets:
		if not magnet.active:
			continue
		var hit_radius: float = radius + magnet.body_radius
		if magnet.global_position.distance_squared_to(position) <= hit_radius * hit_radius:
			return magnet
	return null


func find_overdrive_orb_hit(position: Vector3, radius: float) -> OverdriveOrb:
	for orb in active_overdrive_orbs:
		if not orb.active:
			continue
		var hit_radius: float = radius + orb.body_radius
		if orb.global_position.distance_squared_to(position) <= hit_radius * hit_radius:
			return orb
	return null


func find_enemy_platform(feet_position: Vector3, gravity_down: Vector3, platform_radius: float, probe_distance: float = 0.85) -> EnemyBase:
	var best_enemy: EnemyBase = null
	var best_delta: float = 999.0
	for enemy in active_enemies:
		if not enemy.active or not enemy.can_be_platform:
			continue
		var top_point: Vector3 = enemy.global_position - gravity_down * enemy.platform_height
		var delta_to_top: Vector3 = feet_position - top_point
		var vertical_delta: float = delta_to_top.dot(gravity_down)
		if vertical_delta > 0.45 or vertical_delta < -probe_distance:
			continue
		var horizontal: Vector3 = delta_to_top.slide(gravity_down)
		var allowed: float = platform_radius + enemy.body_radius
		var absolute_delta: float = abs(vertical_delta)
		if horizontal.length_squared() <= allowed * allowed and absolute_delta < best_delta:
			best_delta = absolute_delta
			best_enemy = enemy
	return best_enemy


func perform_extra_shot(origin: Vector3, direction: Vector3, beam_radius: float, beam_range: float) -> int:
	# The extra shot is a widened ray/capsule check with a straight laser visual.
	var killed := 0
	var snapshot: Array = active_enemies.duplicate()
	_spawn_extra_laser_visual(origin, direction, beam_radius, beam_range)
	for raw_enemy in snapshot:
		var enemy: EnemyBase = raw_enemy as EnemyBase
		if not enemy:
			continue
		if not enemy.active:
			continue
		var to_enemy: Vector3 = enemy.global_position - origin
		var forward: float = to_enemy.dot(direction)
		if forward < -1.0 or forward > beam_range:
			continue
		var closest: Vector3 = origin + direction * forward
		var distance: float = enemy.global_position.distance_to(closest)
		var widened_radius: float = beam_radius + enemy.body_radius + (forward / beam_range) * beam_radius * 0.45
		if distance <= widened_radius:
			if enemy is BombEnemy:
				killed += detonate_bomb(enemy as BombEnemy, "extra")
			else:
				enemy.kill("extra", true)
				killed += 1
	var reflector_snapshot: Array = active_reflectors.duplicate()
	for raw_reflector in reflector_snapshot:
		var reflector: HealReflector = raw_reflector as HealReflector
		if not reflector or not reflector.active:
			continue
		var to_reflector: Vector3 = reflector.global_position - origin
		var forward_reflector: float = to_reflector.dot(direction)
		if forward_reflector < -1.0 or forward_reflector > beam_range:
			continue
		var reflector_closest: Vector3 = origin + direction * forward_reflector
		var reflector_distance: float = reflector.global_position.distance_to(reflector_closest)
		var reflector_radius: float = beam_radius + reflector.body_radius + (forward_reflector / beam_range) * beam_radius * 0.45
		if reflector_distance <= reflector_radius:
			reflector.on_extra_hit()
	var magnet_snapshot: Array = active_score_magnets.duplicate()
	for raw_magnet in magnet_snapshot:
		var magnet: ScoreMagnet = raw_magnet as ScoreMagnet
		if not magnet or not magnet.active:
			continue
		var to_magnet: Vector3 = magnet.global_position - origin
		var magnet_forward: float = to_magnet.dot(direction)
		if magnet_forward < -1.0 or magnet_forward > beam_range:
			continue
		var magnet_closest: Vector3 = origin + direction * magnet_forward
		var magnet_distance: float = magnet.global_position.distance_to(magnet_closest)
		var magnet_radius: float = beam_radius + magnet.body_radius + (magnet_forward / beam_range) * beam_radius * 0.45
		if magnet_distance <= magnet_radius:
			magnet.on_extra_hit(direction)
	var orb_snapshot: Array = active_overdrive_orbs.duplicate()
	for raw_orb in orb_snapshot:
		var orb: OverdriveOrb = raw_orb as OverdriveOrb
		if not orb or not orb.active:
			continue
		var to_orb: Vector3 = orb.global_position - origin
		var orb_forward: float = to_orb.dot(direction)
		if orb_forward < -1.0 or orb_forward > beam_range:
			continue
		var orb_closest: Vector3 = origin + direction * orb_forward
		var orb_radius: float = beam_radius + orb.body_radius + (orb_forward / beam_range) * beam_radius * 0.45
		if orb.global_position.distance_to(orb_closest) <= orb_radius:
			orb.on_extra_hit()
	if boss and boss.is_active():
		boss.try_beam_hit(origin, direction, beam_radius, beam_range)
	if player:
		player.add_camera_shake(0.24, 0.18)
	return killed


func perform_orbital_shield(origin: Vector3, radius: float) -> int:
	var killed := 0
	var snapshot: Array = active_enemies.duplicate()
	for raw_enemy in snapshot:
		var enemy: EnemyBase = raw_enemy as EnemyBase
		if not enemy or not enemy.active:
			continue
		if enemy.global_position.distance_to(origin) > radius + enemy.body_radius:
			continue
		if enemy is BombEnemy:
			killed += detonate_bomb(enemy as BombEnemy, "shield")
		else:
			enemy.kill("shield", true)
			killed += 1
	return killed


func _update_heal_waves(delta: float) -> void:
	for i in range(active_heal_waves.size() - 1, -1, -1):
		var wave: Dictionary = active_heal_waves[i]
		var age: float = float(wave.get("age", 0.0)) + delta
		var max_radius: float = float(wave.get("max_radius", heal_wave_start_radius))
		var prev_radius: float = float(wave.get("prev_radius", heal_wave_start_radius))
		var origin: Vector3 = wave.get("origin", Vector3.ZERO)
		var normal: Vector3 = wave.get("normal", Vector3.UP)
		var progress: float = clamp(age / max(0.001, heal_wave_duration), 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 2.0)
		var radius: float = lerp(heal_wave_start_radius, max_radius, eased)
		_kill_enemies_touched_by_heal_wave(origin, normal, prev_radius, radius)
		if progress >= 1.0:
			active_heal_waves.remove_at(i)
		else:
			wave["age"] = age
			wave["prev_radius"] = radius
			active_heal_waves[i] = wave


func _kill_enemies_touched_by_heal_wave(origin: Vector3, normal: Vector3, previous_radius: float, current_radius: float) -> void:
	if normal.length_squared() <= 0.001:
		return
	normal = normal.normalized()
	var min_radius: float = min(previous_radius, current_radius)
	var max_radius: float = max(previous_radius, current_radius)
	var snapshot: Array = active_enemies.duplicate()
	for raw_enemy in snapshot:
		var enemy: EnemyBase = raw_enemy as EnemyBase
		if not enemy or not enemy.active:
			continue
		var offset: Vector3 = enemy.global_position - origin
		var contact_radius: float = heal_wave_thickness + enemy.body_radius
		if abs(offset.dot(normal)) > contact_radius:
			continue
		var radial_distance: float = offset.slide(normal).length()
		if radial_distance + contact_radius < min_radius:
			continue
		if radial_distance - contact_radius > max_radius:
			continue
		if enemy is BombEnemy:
			detonate_bomb(enemy as BombEnemy, "heal_wave")
		else:
			enemy.kill("heal_wave", true)


func _spawn_extra_laser_visual(origin: Vector3, direction: Vector3, beam_radius: float, beam_range: float) -> void:
	var laser_color: Color = Color(0.42, 0.93, 1.0, 0.88)
	spawn_laser_beam(origin + direction * 1.5, direction, beam_range, 0.16, laser_color, 0.2)
	var ring_count := 13
	for i in range(ring_count):
		var t: float = float(i) / float(maxi(1, ring_count - 1))
		var distance: float = lerp(5.0, beam_range, t)
		var ring_position: Vector3 = origin + direction * distance
		var ring_end_radius: float = beam_radius * lerp(0.75, 1.9, t)
		var ring_lifetime: float = lerp(0.28, 0.52, t)
		spawn_laser_ring(ring_position, direction, 0.22, ring_end_radius, Color(0.55, 0.98, 1.0, 0.9), ring_lifetime)
	spawn_burst(origin + direction * min(10.0, beam_range * 0.14), Color(0.55, 0.95, 1.0), beam_radius * 1.0, 0.24)
	spawn_burst(origin + direction * beam_range, Color(0.25, 0.75, 1.0), beam_radius * 1.55, 0.36)


func detonate_bomb(bomb: BombEnemy, _source: String = "bomb") -> int:
	if not bomb or not bomb.active:
		return 0
	# Bomb kills score normally but consolidate shard output into one large burst.
	var origin: Vector3 = bomb.global_position
	var radius: float = bomb.explosion_radius
	bomb.deactivate()
	_add_score(int(round(float(bomb.score_value) * combo)))
	combo = min(combo_max, combo + combo_kill_gain * 2.0)
	combo_decay_timer = combo_decay_delay
	spawn_burst(origin, Color(1.0, 0.42, 0.12), radius * 0.45, 0.58)
	if player:
		player.add_camera_shake(0.45, 0.32)
	var killed := 0
	var snapshot: Array = active_enemies.duplicate()
	for raw_enemy in snapshot:
		var enemy: EnemyBase = raw_enemy as EnemyBase
		if not enemy:
			continue
		if not enemy.active or enemy == bomb:
			continue
		if enemy.global_position.distance_to(origin) <= radius + enemy.body_radius:
			enemy.kill("bomb", false)
			killed += 1
	var shard_count: int = clampi(8 + killed * bomb.shards_per_kill, 10, 120)
	spawn_shards(origin, shard_count, shard_base_value + 3, 7.0)
	return killed


func active_enemy_count() -> int:
	var count := 0
	for enemy in active_enemies:
		if enemy.active:
			count += 1
	return count


func active_shard_count() -> int:
	var count := 0
	for shard in active_shards:
		if shard.active:
			count += 1
	return count


func active_reflector_count() -> int:
	var count := 0
	for reflector in active_reflectors:
		if reflector.active:
			count += 1
	return count


func active_score_magnet_count() -> int:
	var count := 0
	for magnet in active_score_magnets:
		if magnet.active:
			count += 1
	return count


func active_overdrive_orb_count() -> int:
	var count := 0
	for orb in active_overdrive_orbs:
		if orb.active:
			count += 1
	return count


func get_recent_kill_rate() -> float:
	return recent_kill_rate


func _update_kill_rate(delta: float) -> void:
	kill_rate_sample_timer += delta
	if kill_rate_sample_timer < 1.0:
		return
	var sample_rate: float = float(kills_in_sample) / max(0.001, kill_rate_sample_timer)
	recent_kill_rate = lerp(recent_kill_rate, sample_rate, 0.35)
	kills_in_sample = 0
	kill_rate_sample_timer = 0.0


func _handle_player_enemy_contacts() -> void:
	if not player or player.is_dead():
		return
	# The tutorial is a safe sandbox: contact never kills, so a missed shot or a
	# brushed enemy does not abort the lesson the player is practicing.
	var safe: bool = is_tutorial()
	var player_hit_point: Vector3 = player.global_position
	# Reuse this single pass over the swarm to also find the nearest threat for the
	# crosshair proximity warning instead of looping the (potentially huge) list again.
	var nearest_distance: float = INF
	var nearest_enemy: EnemyBase = null
	for enemy in active_enemies:
		if not enemy.active:
			continue
		# Enemies woven into the dragon's body are inert; only the laser hurts you.
		if enemy.formation_active:
			continue
		var distance: float = enemy.global_position.distance_to(player_hit_point)
		if distance < nearest_distance and not player.is_enemy_platform_contact(enemy):
			nearest_distance = distance
			nearest_enemy = enemy
		if enemy is BombEnemy:
			if distance <= (enemy as BombEnemy).contact_radius:
				if not safe:
					player.apply_damage(player.max_hp, enemy.global_position)
				detonate_bomb(enemy as BombEnemy, "touch")
			continue
		if player.is_enemy_platform_contact(enemy):
			continue
		if distance <= enemy.body_radius:
			if not safe:
				# Touching a regular enemy chips one point (invuln frames space the hits)
				# rather than being an instant kill, so the player can survive a few bumps.
				player.apply_damage(1.0, enemy.global_position)
				break
	if nearest_enemy and nearest_distance <= enemy_warn_radius:
		warn_active = true
		warn_position = nearest_enemy.global_position
		warn_distance = nearest_distance
		warn_is_bomb = nearest_enemy is BombEnemy
	else:
		warn_active = false


func _update_ui() -> void:
	if not ui or not player:
		return
	ui.update_hud({
		"score": score,
		"high_score": high_score,
		"hp": player.hp,
		"max_hp": player.max_hp,
		"charge": player.extra_charge,
		"charge_max": player.extra_shot_charge_max,
		"shield": player.orbital_shield_charge,
		"shield_max": player.orbital_shield_charge_max,
		"shield_active": player.orbital_shield_timer > 0.0,
		"boost": player.boost_charge,
		"boost_max": player.boost_charge_max,
		"boost_active": player.boost_timer > 0.0,
		"combo": combo,
		"time": survival_time,
		"enemies": active_enemy_count(),
		"invulnerable": player.is_invulnerable(),
		"warn_active": warn_active,
		"warn_position": warn_position,
		"warn_distance": warn_distance,
		"warn_is_bomb": warn_is_bomb,
		"warn_radius": enemy_warn_radius,
		"boss_active": boss != null and boss.is_active(),
		"boss_health": boss.health_fraction() if boss else 0.0,
		"round_active": boss != null and boss.is_round_active(),
		"round_time": boss.round_time_left() if boss else 0.0,
	})


func _load_high_score() -> void:
	var config := ConfigFile.new()
	if config.load("user://abstract_swarm_highscore.cfg") == OK:
		high_score = int(config.get_value("scores", "high_score", 0))


func _save_high_score() -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "high_score", high_score)
	config.save("user://abstract_swarm_highscore.cfg")

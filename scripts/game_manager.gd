class_name GameManager
extends Node

signal run_state_changed(state: int)

enum RunState { MENU, PLAYING, PAUSED, GAME_OVER }

# Central run coordinator: owns state, score, combo, high score, pooled objects,
# and cross-system collision rules that are cheaper as distance checks.
@export_group("Pools")
@export var max_active_enemies := 900
@export var max_active_projectiles := 180
@export var max_active_shards := 700
@export var projectile_pool_initial := 90
@export var shard_pool_initial := 180
@export var effect_pool_initial := 36
@export var swarmer_pool_initial := 120
@export var charger_pool_initial := 44
@export var avoider_pool_initial := 44
@export var bomb_pool_initial := 12

@export_group("Scoring")
@export var shard_base_value := 5
@export var combo_kill_gain := 0.08
@export var combo_shard_gain := 0.025
@export var combo_decay_delay := 2.2
@export var combo_decay_rate := 0.9
@export var combo_max := 12.0

const PROJECTILE_SCENE := preload("res://scenes/projectiles/Projectile.tscn")
const SHARD_SCENE := preload("res://scenes/shards/Shard.tscn")
const BURST_SCENE := preload("res://scenes/effects/BurstEffect.tscn")
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
var enemies_container: Node3D
var projectiles_container: Node3D
var shards_container: Node3D
var effects_container: Node3D

var enemy_pools := {}
var projectile_pool: Array[PlayerProjectile] = []
var shard_pool: Array[ScoreShard] = []
var effect_pool: Array[BurstEffect] = []
var active_enemies: Array[EnemyBase] = []
var active_projectiles: Array[PlayerProjectile] = []
var active_shards: Array[ScoreShard] = []


func configure(
	_player: PlayerController,
	_spawn_manager: SpawnManager,
	_ui: GameUI,
	_enemies_container: Node3D,
	_projectiles_container: Node3D,
	_shards_container: Node3D,
	_effects_container: Node3D
) -> void:
	player = _player
	spawn_manager = _spawn_manager
	ui = _ui
	enemies_container = _enemies_container
	projectiles_container = _projectiles_container
	shards_container = _shards_container
	effects_container = _effects_container
	_load_high_score()
	_setup_pools()
	_update_ui()


func show_main_menu() -> void:
	state = RunState.MENU
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if ui:
		ui.show_state(state)
	run_state_changed.emit(state)


func start_run() -> void:
	if not player:
		return
	# Pools stay allocated across runs; only active objects are hidden/reset.
	_deactivate_all()
	score = 0
	combo = 1.0
	combo_decay_timer = 0.0
	survival_time = 0.0
	state = RunState.PLAYING
	player.reset_for_run(Vector3(0.0, 2.0, 0.0))
	spawn_manager.reset_for_run()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ui.show_state(state)
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


func end_run() -> void:
	if state == RunState.GAME_OVER:
		return
	state = RunState.GAME_OVER
	high_score = max(high_score, score)
	_save_high_score()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	ui.show_state(state)
	run_state_changed.emit(state)
	_update_ui()


func is_playing() -> bool:
	return state == RunState.PLAYING


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle_pause()
		elif state == RunState.GAME_OVER and event.keycode == KEY_R:
			start_run()
		elif state == RunState.MENU and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			start_run()
	elif event is InputEventMouseButton and event.pressed:
		if state == RunState.MENU and event.button_index == MOUSE_BUTTON_LEFT:
			start_run()


func _process(delta: float) -> void:
	if not is_playing():
		return
	survival_time += delta
	if combo_decay_timer > 0.0:
		combo_decay_timer -= delta
	else:
		combo = max(1.0, combo - combo_decay_rate * delta)
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
	active_enemies.clear()
	active_projectiles.clear()
	active_shards.clear()


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


func on_enemy_killed(enemy: EnemyBase, source: String, spawn_pickups: bool = true) -> void:
	# Kills feed score, combo, shards, and extra-shot charge from one place.
	var gain := int(round(float(enemy.score_value) * combo))
	score += gain
	combo = min(combo_max, combo + combo_kill_gain)
	combo_decay_timer = combo_decay_delay
	if spawn_pickups:
		var shard_count := randi_range(enemy.shard_drop_min, enemy.shard_drop_max)
		spawn_shards(enemy.global_position, shard_count, shard_base_value, 3.1)
	if player:
		player.add_kill_charge(source, combo)
	spawn_burst(enemy.global_position, enemy.visual_color, enemy.body_radius * 1.6, 0.24)


func collect_shard(value: int) -> void:
	score += int(round(float(value) * combo))
	combo = min(combo_max, combo + combo_shard_gain)
	combo_decay_timer = combo_decay_delay


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


func find_enemy_platform(player_position: Vector3, feet_y: float, platform_radius: float) -> EnemyBase:
	var best_enemy: EnemyBase = null
	var best_delta := 999.0
	for enemy in active_enemies:
		if not enemy.active or not enemy.can_be_platform:
			continue
		var top_y: float = enemy.global_position.y + enemy.platform_height
		var vertical_delta: float = abs(feet_y - top_y)
		if feet_y > top_y + 0.45 or feet_y < top_y - 0.8:
			continue
		var horizontal := Vector2(
			player_position.x - enemy.global_position.x,
			player_position.z - enemy.global_position.z
		)
		var allowed := platform_radius + enemy.body_radius
		if horizontal.length_squared() <= allowed * allowed and vertical_delta < best_delta:
			best_delta = vertical_delta
			best_enemy = enemy
	return best_enemy


func perform_extra_shot(origin: Vector3, direction: Vector3, beam_radius: float, beam_range: float) -> int:
	# The extra shot is a widened ray/capsule check, enough for a fast greybox beam.
	var killed := 0
	var snapshot: Array = active_enemies.duplicate()
	var end_position := origin + direction * beam_range
	spawn_burst(origin + direction * min(12.0, beam_range * 0.15), Color(0.55, 0.95, 1.0), beam_radius * 1.2, 0.34)
	spawn_burst(end_position, Color(0.25, 0.75, 1.0), beam_radius * 1.7, 0.42)
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
	if player:
		player.add_camera_shake(0.24, 0.18)
	return killed


func detonate_bomb(bomb: BombEnemy, source: String = "bomb") -> int:
	if not bomb or not bomb.active:
		return 0
	# Bomb kills score normally but consolidate shard output into one large burst.
	var origin: Vector3 = bomb.global_position
	var radius: float = bomb.explosion_radius
	bomb.deactivate()
	score += int(round(float(bomb.score_value) * combo))
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


func _handle_player_enemy_contacts() -> void:
	if not player or player.is_dead():
		return
	# Contact severity is radial: inner body hit is 1 damage, outer graze is 0.5.
	var body_position: Vector3 = player.global_position + Vector3(0.0, 0.05, 0.0)
	for enemy in active_enemies:
		if not enemy.active:
			continue
		if enemy is BombEnemy:
			if enemy.global_position.distance_to(body_position) <= (enemy as BombEnemy).contact_radius:
				player.apply_damage(0.5, enemy.global_position)
				detonate_bomb(enemy as BombEnemy, "touch")
			continue
		if player.is_enemy_platform_contact(enemy):
			continue
		var distance: float = enemy.global_position.distance_to(body_position)
		var full_radius: float = player.full_hit_radius + enemy.body_radius * 0.62
		var graze_radius: float = player.graze_radius + enemy.body_radius
		if distance <= full_radius:
			if player.apply_damage(1.0, enemy.global_position):
				enemy.kill("body", false)
			break
		elif distance <= graze_radius:
			if player.apply_damage(0.5, enemy.global_position):
				player.add_camera_shake(0.12, 0.12)
			break


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
		"combo": combo,
		"time": survival_time,
		"enemies": active_enemy_count(),
		"invulnerable": player.is_invulnerable(),
	})


func _load_high_score() -> void:
	var config := ConfigFile.new()
	if config.load("user://abstract_swarm_highscore.cfg") == OK:
		high_score = int(config.get_value("scores", "high_score", 0))


func _save_high_score() -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "high_score", high_score)
	config.save("user://abstract_swarm_highscore.cfg")

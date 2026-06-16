class_name BossController
extends Node3D

# Owns every boss and drives the boss progression. In a normal run a boss wave is
# triggered each time the score climbs another threshold_step after the previous
# wave is cleared, cycling Dragon -> Cube -> two Dragons -> Butterfly -> random.
# In Boss Rush mode the same waves are chained back-to-back, and every couple of
# bosses there is a chance of a timed normal-enemy round (with an on-screen clock).
#
# It also presents the single "boss" interface GameManager/projectiles expect
# (is_active / health_fraction / try_hit / try_beam_hit / stop), fanning those
# calls out to whichever bosses are currently fighting.

@export var threshold_step := 40000
@export var rush_round_duration := 90.0
@export var rush_interlude_chance := 0.6

var manager: GameManager
var player: PlayerController

var dragon_a: DragonBoss
var dragon_b: DragonBoss
var cube: CubeBoss
var butterfly: ButterflyBoss
var all_bosses: Array = []

var mode := "normal"
var wave_active := false
var current_wave: Array = []
var sequence_step := 0
var next_threshold := 0

var rush_index := 0
var bosses_since_round := 0
var round_active := false
var round_timer := 0.0


func configure(_manager: GameManager, _player: PlayerController, _dragon_a: DragonBoss) -> void:
	manager = _manager
	player = _player
	dragon_a = _dragon_a
	if dragon_a:
		dragon_a.configure(manager, player)
	dragon_b = DragonBoss.new()
	add_child(dragon_b)
	dragon_b.configure(manager, player)
	cube = CubeBoss.new()
	add_child(cube)
	cube.configure(manager, player)
	butterfly = ButterflyBoss.new()
	add_child(butterfly)
	butterfly.configure(manager, player)
	all_bosses = [dragon_a, dragon_b, cube, butterfly]
	set_process(true)


func reset_for_run(_mode: String) -> void:
	mode = _mode
	stop()
	sequence_step = 0
	next_threshold = manager.boss_score_threshold if manager else threshold_step
	rush_index = 0
	bosses_since_round = 0


func stop() -> void:
	for boss in all_bosses:
		if boss and boss.is_active():
			boss.stop()
	current_wave.clear()
	wave_active = false
	round_active = false
	round_timer = 0.0


func is_active() -> bool:
	for boss in current_wave:
		if boss and boss.is_active():
			return true
	return false


func health_fraction() -> float:
	var total := 0.0
	var count := 0
	for boss in current_wave:
		if boss:
			total += boss.health_fraction()
			count += 1
	if count == 0:
		return 0.0
	return total / float(count)


func try_hit(hit_position: Vector3, radius: float) -> bool:
	var hit := false
	for boss in current_wave:
		if boss and boss.is_active() and boss.try_hit(hit_position, radius):
			hit = true
	return hit


func try_beam_hit(origin: Vector3, direction: Vector3, radius: float, beam_range: float) -> void:
	for boss in current_wave:
		if boss and boss.is_active():
			boss.try_beam_hit(origin, direction, radius, beam_range)


func get_active_dragon() -> DragonBoss:
	# The replay system records dragon-specific visuals; hand it the live dragon if a
	# dragon wave is the one currently fighting (null otherwise, e.g. cube/butterfly).
	for boss in current_wave:
		if boss is DragonBoss and boss.is_active():
			return boss
	return null


func boss_rush_spawns_allowed() -> bool:
	# In Boss Rush, normal enemies only spawn during a timed interlude round.
	return mode == "boss_rush" and round_active


func is_round_active() -> bool:
	return round_active


func round_time_left() -> float:
	return round_timer if round_active else 0.0


func _process(delta: float) -> void:
	if not manager or not manager.is_playing():
		return
	if mode == "boss_rush":
		_process_rush(delta)
	else:
		_process_normal(delta)


func _process_normal(_delta: float) -> void:
	if wave_active:
		if not is_active():
			wave_active = false
			sequence_step += 1
			next_threshold = manager.score + threshold_step
	elif manager.score >= next_threshold:
		_start_wave(_wave_for_step(sequence_step))


func _process_rush(delta: float) -> void:
	if wave_active:
		if not is_active():
			wave_active = false
			bosses_since_round += 1
			if bosses_since_round >= 2 and randf() < rush_interlude_chance:
				bosses_since_round = 0
				round_active = true
				round_timer = rush_round_duration
	elif round_active:
		round_timer -= delta
		if round_timer <= 0.0:
			round_active = false
			_clear_loose_enemies()
			_start_wave(_rush_next_wave())
	else:
		_start_wave(_rush_next_wave())


func _wave_for_step(step: int) -> Array:
	match step:
		0:
			return [dragon_a]
		1:
			return [cube]
		2:
			return [dragon_a, dragon_b]
		3:
			return [butterfly]
		_:
			return _random_wave()


func _random_wave() -> Array:
	match randi() % 4:
		0:
			return [dragon_a]
		1:
			return [cube]
		2:
			return [dragon_a, dragon_b]
		_:
			return [butterfly]


func _rush_next_wave() -> Array:
	var wave: Array = _wave_for_step(rush_index)
	rush_index += 1
	return wave


func _start_wave(bosses: Array) -> void:
	current_wave = bosses
	wave_active = true
	for boss in bosses:
		if boss:
			boss.start()


func _clear_loose_enemies() -> void:
	if not manager:
		return
	for enemy in manager.active_enemies:
		if enemy.active and not enemy.formation_active:
			enemy.deactivate()

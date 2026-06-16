class_name SpawnManager
extends Node

# Spawns are distributed across the whole sphere. Enemy pressure ramps
# exponentially, then settles toward the player's recent kill rate.
@export_group("Spawn Rate")
@export var base_spawn_rate_per_second := 12.0
@export var exponential_growth_base := 1.28
@export var exponential_growth_period := 8.0
@export var score_spawn_scale := 0.000012
@export var max_exponential_spawn_rate := 165.0
@export var equilibrium_start_time := 85.0
@export var equilibrium_spawn_to_kill_ratio := 1.05
@export var equilibrium_min_spawn_rate := 18.0
@export var max_spawn_per_frame := 80
@export var active_count_soft_cap := 2150
@export var soft_cap_throttle_start := 0.78

@export_group("Spawn Placement")
@export var outside_sphere_spawn_min := 8.0
@export var outside_sphere_spawn_max := 24.0
@export var min_angle_from_player_feet_degrees := 28.0
@export var spawn_height_min := 0.45
@export var spawn_height_max := 3.2

@export_group("Enemy Mix")
@export var charger_start_time := 18.0
@export var avoider_start_time := 30.0
@export var charger_weight := 0.18
@export var avoider_weight := 0.16

@export_group("Bombs")
@export var bomb_spawn_interval := 7.5
@export var bomb_spawn_interval_min := 3.2
@export var bomb_height_min := 2.4
@export var bomb_height_max := 10.0

@export_group("Heal Reflectors")
@export var reflector_spawn_interval := 11.5
@export var reflector_spawn_interval_min := 5.0
@export var reflector_height_min := 7.0
@export var reflector_height_max := 24.0

@export_group("Overdrive Orb")
@export var orb_spawn_interval := 42.0
@export var orb_spawn_interval_min := 26.0
@export var orb_height_min := 8.0
@export var orb_height_max := 22.0

var manager: GameManager
var player: PlayerController
var spawn_credit: float = 0.0
var bomb_timer: float = 0.0
var reflector_timer: float = 0.0
var orb_timer: float = 0.0


func configure(_manager: GameManager, _player: PlayerController) -> void:
	manager = _manager
	player = _player


func reset_for_run() -> void:
	spawn_credit = 0.0
	bomb_timer = 4.5
	reflector_timer = 6.0
	orb_timer = orb_spawn_interval


func _process(delta: float) -> void:
	if not manager or not manager.is_playing():
		return
	# The tutorial drives its own controlled spawns; automatic pressure stays off.
	if manager.is_tutorial():
		return
	# During a boss the boss owns the whole enemy population (its body).
	if manager.boss and manager.boss.is_active():
		return
	# In Boss Rush, normal enemies only appear during a timed interlude round.
	if manager.is_boss_rush() and not (manager.boss and manager.boss.boss_rush_spawns_allowed()):
		return
	bomb_timer -= delta
	reflector_timer -= delta
	orb_timer -= delta
	_update_enemy_spawning(delta)
	if bomb_timer <= 0.0:
		_spawn_bomb()
		var pressure: float = 1.0 + manager.survival_time * 0.01 + float(manager.score) * 0.00001
		bomb_timer = max(bomb_spawn_interval_min, bomb_spawn_interval / pressure)
	if reflector_timer <= 0.0:
		_spawn_heal_reflector()
		var reflector_pressure: float = 1.0 + manager.survival_time * 0.012 + float(manager.score) * 0.000006
		reflector_timer = max(reflector_spawn_interval_min, reflector_spawn_interval / reflector_pressure)
	if orb_timer <= 0.0:
		_spawn_overdrive_orb()
		var orb_pressure: float = 1.0 + manager.survival_time * 0.004
		orb_timer = max(orb_spawn_interval_min, orb_spawn_interval / orb_pressure)


func _update_enemy_spawning(delta: float) -> void:
	var active_count: int = manager.active_enemy_count()
	if active_count >= manager.max_active_enemies:
		spawn_credit = min(spawn_credit, 1.0)
		return
	var spawn_rate: float = _current_spawn_rate_per_second(active_count)
	spawn_credit += spawn_rate * delta
	var requested_count: int = clampi(int(spawn_credit), 0, max_spawn_per_frame)
	if requested_count <= 0:
		return
	var available_capacity: int = manager.max_active_enemies - active_count
	var spawn_count: int = mini(requested_count, available_capacity)
	for i in range(spawn_count):
		manager.spawn_enemy(_pick_enemy_type(), _pick_outside_spawn_position())
	spawn_credit -= float(spawn_count)


func _current_spawn_rate_per_second(active_count: int) -> float:
	var time_factor: float = pow(exponential_growth_base, manager.survival_time / max(0.1, exponential_growth_period))
	var score_factor: float = 1.0 + float(manager.score) * score_spawn_scale
	var spawn_rate: float = min(max_exponential_spawn_rate, base_spawn_rate_per_second * time_factor * score_factor)
	if manager.survival_time >= equilibrium_start_time:
		var kill_rate: float = manager.get_recent_kill_rate()
		spawn_rate = clamp(kill_rate * equilibrium_spawn_to_kill_ratio, equilibrium_min_spawn_rate, max_exponential_spawn_rate)
	if active_count >= active_count_soft_cap:
		return min(max_exponential_spawn_rate, manager.get_recent_kill_rate() * equilibrium_spawn_to_kill_ratio)
	var throttle_start: float = float(active_count_soft_cap) * soft_cap_throttle_start
	if float(active_count) >= throttle_start:
		var throttle_range: float = max(1.0, float(active_count_soft_cap) - throttle_start)
		var throttle: float = clamp((float(active_count_soft_cap) - float(active_count)) / throttle_range, 0.0, 1.0)
		spawn_rate *= throttle
	return max(0.0, spawn_rate)


func _spawn_bomb() -> void:
	if manager.active_enemy_count() >= manager.max_active_enemies:
		return
	var position: Vector3 = _pick_spawn_position(randf_range(bomb_height_min, bomb_height_max))
	manager.spawn_bomb(position)


func _spawn_heal_reflector() -> void:
	var position: Vector3 = _pick_spawn_position(randf_range(reflector_height_min, reflector_height_max))
	manager.spawn_heal_reflector(position)


func _spawn_overdrive_orb() -> void:
	var position: Vector3 = _pick_spawn_position(randf_range(orb_height_min, orb_height_max))
	manager.spawn_overdrive_orb(position)


func _pick_enemy_type() -> String:
	var roll: float = randf()
	var charger_available: bool = manager.survival_time >= charger_start_time
	var avoider_available: bool = manager.survival_time >= avoider_start_time
	var total_charger: float = charger_weight if charger_available else 0.0
	var total_avoider: float = avoider_weight if avoider_available else 0.0
	if roll < total_avoider:
		return "avoider"
	if roll < total_avoider + total_charger:
		return "charger"
	return "swarmer"


func _pick_spawn_position(altitude_from_wall: float) -> Vector3:
	var direction: Vector3 = _pick_global_sphere_direction()
	var radius: float = max(1.0, player.sphere_radius - altitude_from_wall)
	return player.sphere_center + direction * radius


func _pick_outside_spawn_position() -> Vector3:
	var direction: Vector3 = _pick_global_sphere_direction()
	var outside_distance: float = randf_range(outside_sphere_spawn_min, outside_sphere_spawn_max)
	return player.sphere_center + direction * (player.sphere_radius + outside_distance)


func _pick_global_sphere_direction() -> Vector3:
	var player_feet_direction: Vector3 = player.get_gravity_down().normalized()
	var max_feet_dot: float = cos(deg_to_rad(min_angle_from_player_feet_degrees))
	for i in range(16):
		var direction: Vector3 = _random_sphere_direction()
		if direction.dot(player_feet_direction) <= max_feet_dot:
			return direction
	return -player_feet_direction


func _random_sphere_direction() -> Vector3:
	var y: float = randf_range(-1.0, 1.0)
	var angle: float = randf_range(0.0, TAU)
	var ring_radius: float = sqrt(max(0.0, 1.0 - y * y))
	return Vector3(
		ring_radius * cos(angle),
		y,
		ring_radius * sin(angle)
	).normalized()

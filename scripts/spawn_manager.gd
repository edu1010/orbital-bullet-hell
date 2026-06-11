class_name SpawnManager
extends Node

# Spawns are distributed across the whole sphere, then ramp cadence and batch
# size by survival time and score.
@export_group("Spawn Rate")
@export var base_spawn_interval := 0.62
@export var min_spawn_interval := 0.035
@export var difficulty_time_scale := 0.035
@export var difficulty_score_scale := 0.000035
@export var batch_size_min := 14
@export var batch_size_max := 26
@export var batch_growth_per_minute := 46.0
@export var active_count_soft_cap := 1450

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

var manager: GameManager
var player: PlayerController
var spawn_timer := 0.0
var bomb_timer := 0.0


func configure(_manager: GameManager, _player: PlayerController) -> void:
	manager = _manager
	player = _player


func reset_for_run() -> void:
	spawn_timer = 0.45
	bomb_timer = 4.5


func _process(delta: float) -> void:
	if not manager or not manager.is_playing():
		return
	spawn_timer -= delta
	bomb_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave()
		spawn_timer = _current_spawn_interval()
	if bomb_timer <= 0.0:
		_spawn_bomb()
		var pressure := 1.0 + manager.survival_time * 0.01 + float(manager.score) * 0.00001
		bomb_timer = max(bomb_spawn_interval_min, bomb_spawn_interval / pressure)


func _current_spawn_interval() -> float:
	var pressure := 1.0 + manager.survival_time * difficulty_time_scale + float(manager.score) * difficulty_score_scale
	return max(min_spawn_interval, base_spawn_interval / pressure)


func _spawn_wave() -> void:
	if manager.active_enemy_count() >= active_count_soft_cap:
		return
	var growth := int(manager.survival_time / 60.0 * batch_growth_per_minute)
	var count := randi_range(batch_size_min, batch_size_max) + growth
	count = mini(count, manager.max_active_enemies - manager.active_enemy_count())
	for i in range(count):
		manager.spawn_enemy(_pick_enemy_type(), _pick_outside_spawn_position())


func _spawn_bomb() -> void:
	if manager.active_enemy_count() >= manager.max_active_enemies:
		return
	var position: Vector3 = _pick_spawn_position(randf_range(bomb_height_min, bomb_height_max))
	manager.spawn_bomb(position)


func _pick_enemy_type() -> String:
	var roll := randf()
	var charger_available := manager.survival_time >= charger_start_time
	var avoider_available := manager.survival_time >= avoider_start_time
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

class_name SpawnManager
extends Node

# Spawns bias toward where the player is looking and moving, then ramps cadence
# and batch size by survival time and score.
@export_group("Spawn Rate")
@export var base_spawn_interval := 1.25
@export var min_spawn_interval := 0.08
@export var difficulty_time_scale := 0.035
@export var difficulty_score_scale := 0.000035
@export var batch_size_min := 4
@export var batch_size_max := 10
@export var batch_growth_per_minute := 18.0
@export var active_count_soft_cap := 820

@export_group("Spawn Placement")
@export var spawn_distance_min := 34.0
@export var spawn_distance_max := 62.0
@export var spawn_arc_degrees := 100.0
@export var facing_bias := 1.0
@export var movement_bias := 0.65
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
		manager.spawn_enemy(_pick_enemy_type(), _pick_spawn_position(randf_range(spawn_height_min, spawn_height_max)))


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
	var forward: Vector3 = player.get_tangent_forward()
	var movement: Vector3 = player.get_horizontal_velocity_direction()
	var random_dir: Vector3 = player.get_random_tangent_direction()
	var bias: Vector3 = forward * facing_bias + movement * movement_bias + random_dir * 0.35
	if bias.length_squared() < 0.01:
		bias = random_dir
	bias = bias.normalized()
	var angle: float = deg_to_rad(randf_range(-spawn_arc_degrees * 0.5, spawn_arc_degrees * 0.5))
	var direction: Vector3 = bias.rotated(player.get_gravity_down(), angle).normalized()
	var distance: float = randf_range(spawn_distance_min, spawn_distance_max)
	var approximate_position: Vector3 = player.global_position + direction * distance
	return player.project_inside_sphere(approximate_position, altitude_from_wall)

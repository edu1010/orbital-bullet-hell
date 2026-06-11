class_name ChargerEnemy
extends EnemyBase

@export var prediction_time := 0.68
@export var wave_strength := 4.2
@export var wave_frequency := 4.0

var phase := 0.0


func _ready() -> void:
	move_speed = 8.0
	turn_speed = 4.8
	body_radius = 1.38
	platform_height = 1.42
	score_value = 18
	shard_drop_min = 2
	shard_drop_max = 5
	mesh_shape = "box"
	visual_style = "charger_mask"
	visual_color = Color(1.0, 0.55, 0.18)
	accent_color = Color(0.92, 1.0, 0.22)
	dark_color = Color(0.045, 0.028, 0.02)
	spin_speed = 2.2
	super._ready()


func _on_activated() -> void:
	phase = randf_range(0.0, TAU)


func _update_movement(delta: float) -> void:
	if not player:
		return
	var target: Vector3 = player.global_position + player.velocity * prediction_time
	var to_target: Vector3 = target - global_position
	if to_target.length_squared() <= 0.001:
		return
	var direction: Vector3 = to_target.normalized()
	var lateral: Vector3 = direction.cross(Vector3.UP)
	if lateral.length_squared() <= 0.001:
		lateral = Vector3.RIGHT
	lateral = lateral.normalized()
	var wave: Vector3 = lateral * sin(age * wave_frequency + phase) * wave_strength
	var desired: Vector3 = direction * move_speed + wave
	velocity = velocity.lerp(desired, clamp(turn_speed * delta, 0.0, 1.0))

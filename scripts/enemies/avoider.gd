class_name AvoiderEnemy
extends EnemyBase

@export var bullet_avoid_radius := 8.0
@export var bullet_avoid_strength := 9.0
@export var lateral_frequency := 3.5

var phase := 0.0


func _ready() -> void:
	move_speed = 8.8
	turn_speed = 7.2
	body_radius = 0.78
	platform_height = 0.8
	score_value = 16
	shard_drop_min = 1
	shard_drop_max = 4
	mesh_shape = "cone"
	visual_color = Color(0.2, 1.0, 0.74)
	spin_speed = 4.0
	super._ready()


func _on_activated() -> void:
	phase = randf_range(0.0, TAU)


func _update_movement(delta: float) -> void:
	var chase := _direction_to_player() * move_speed
	var avoid := Vector3.ZERO
	if manager:
		for projectile in manager.get_nearby_projectiles(global_position, bullet_avoid_radius):
			var away: Vector3 = global_position - projectile.global_position
			var distance: float = max(0.01, away.length())
			away.y *= 0.25
			avoid += away.normalized() * (1.0 - clamp(distance / bullet_avoid_radius, 0.0, 1.0))
	var lateral := _direction_to_player().cross(Vector3.UP)
	if lateral.length_squared() > 0.001:
		lateral = lateral.normalized() * sin(age * lateral_frequency + phase) * 2.2
	var desired := chase + lateral
	if avoid.length_squared() > 0.001:
		desired += avoid.normalized() * bullet_avoid_strength
	var max_speed := move_speed * 1.45
	if desired.length() > max_speed:
		desired = desired.normalized() * max_speed
	velocity = velocity.lerp(desired, clamp(turn_speed * delta, 0.0, 1.0))

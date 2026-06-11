class_name SwarmerEnemy
extends EnemyBase


func _ready() -> void:
	move_speed = 10.5
	turn_speed = 8.5
	body_radius = 0.62
	platform_height = 0.64
	score_value = 10
	shard_drop_min = 1
	shard_drop_max = 3
	mesh_shape = "sphere"
	visual_color = Color(1.0, 0.16, 0.28)
	spin_speed = 5.5
	super._ready()


func _update_movement(delta: float) -> void:
	var desired: Vector3 = _direction_to_player() * move_speed
	velocity = velocity.lerp(desired, clamp(turn_speed * delta, 0.0, 1.0))

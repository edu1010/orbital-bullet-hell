class_name SwarmerEnemy
extends EnemyBase


func _ready() -> void:
	move_speed = 10.5
	turn_speed = 8.5
	body_radius = 0.82
	platform_height = 0.86
	score_value = 10
	shard_drop_min = 1
	shard_drop_max = 3
	mesh_shape = "sphere"
	visual_style = "swarm_mask"
	visual_color = Color(0.86, 0.68, 0.48)
	accent_color = Color(0.55, 1.0, 0.2)
	dark_color = Color(0.035, 0.028, 0.04)
	spin_speed = 5.5
	super._ready()


func _update_movement(delta: float) -> void:
	var desired: Vector3 = _direction_to_player() * move_speed
	velocity = velocity.lerp(desired, clamp(turn_speed * delta, 0.0, 1.0))

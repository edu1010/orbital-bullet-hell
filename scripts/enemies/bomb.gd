class_name BombEnemy
extends EnemyBase

@export var explosion_radius := 14.5
@export var shards_per_kill := 2
@export var contact_radius := 3.1
@export var hover_amplitude := 0.45
@export var hover_speed := 1.7

var base_position := Vector3.ZERO
var hover_axis := Vector3.UP
var phase := 0.0


func _ready() -> void:
	move_speed = 0.0
	body_radius = 2.15
	platform_height = 1.95
	score_value = 40
	shard_drop_min = 6
	shard_drop_max = 12
	can_be_platform = false
	mesh_shape = "cylinder"
	visual_style = "bomb_relic"
	visual_color = Color(0.92, 0.44, 0.2)
	accent_color = Color(0.5, 1.0, 0.16)
	dark_color = Color(0.04, 0.02, 0.055)
	spin_speed = 1.4
	max_lifetime = 34.0
	super._ready()


func _on_activated() -> void:
	base_position = global_position
	if player:
		var radial: Vector3 = global_position - player.sphere_center
		if radial.length_squared() > 0.001:
			hover_axis = -radial.normalized()
		else:
			hover_axis = -player.get_gravity_down()
	phase = randf_range(0.0, TAU)


func _update_movement(_delta: float) -> void:
	velocity = Vector3.ZERO
	global_position = base_position + hover_axis * sin(age * hover_speed + phase) * hover_amplitude

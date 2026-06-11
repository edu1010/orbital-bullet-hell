class_name PlayerController
extends CharacterBody3D

# Arcade first-person controller with coyote time, buffered jumps, double jump,
# enemy-body platform resets, automatic primary fire, and charged extra shot.
@export_group("Movement")
@export var move_speed := 15.5
@export var ground_acceleration := 16.0
@export var air_acceleration := 8.5
@export var ground_friction := 12.0
@export var gravity := 20.0
@export var jump_force := 9.2
@export var double_jump_count := 1
@export var enemy_jump_resets := true
@export var coyote_time := 0.14
@export var jump_buffer_time := 0.16
@export var enemy_platform_radius := 0.55
@export var body_half_height := 0.9

@export_group("Look")
@export var mouse_sensitivity := 0.0022
@export var max_pitch_degrees := 84.0
@export var base_fov := 86.0
@export var movement_fov_kick := 5.0
@export var action_fov_recovery := 8.0

@export_group("Health")
@export var max_hp := 3.0
@export var full_hit_radius := 0.72
@export var graze_radius := 1.28
@export var invulnerability_time := 0.4

@export_group("Primary Fire")
@export var primary_fire_rate := 8.5
@export var projectile_speed := 62.0

@export_group("Extra Shot")
@export var extra_shot_charge_max := 100.0
@export var passive_charge_rate := 4.0
@export var kill_charge_bonus := 1.0
@export var bomb_kill_charge_bonus := 0.25
@export var combo_charge_bonus_scale := 0.08
@export var extra_shot_radius := 5.0
@export var extra_shot_range := 88.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var muzzle: Marker3D = $Head/Muzzle

var manager: GameManager
var hp := 3.0
var extra_charge := 0.0
var invulnerability_timer := 0.0
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var jumps_remaining := 1
var fire_timer := 0.0
var pitch := 0.0
var fov_kick := 0.0
var shake_timer := 0.0
var shake_strength := 0.0
var camera_base_position := Vector3.ZERO
var current_platform_enemy: EnemyBase
var ready_cue_played := false


func configure(_manager: GameManager) -> void:
	manager = _manager


func _ready() -> void:
	camera_base_position = camera.position
	camera.fov = base_fov
	hp = max_hp
	set_physics_process(true)


func reset_for_run(start_position: Vector3) -> void:
	global_position = start_position
	rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	pitch = 0.0
	velocity = Vector3.ZERO
	hp = max_hp
	extra_charge = 0.0
	invulnerability_timer = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = coyote_time
	jumps_remaining = double_jump_count
	fire_timer = 0.0
	fov_kick = 0.0
	shake_timer = 0.0
	shake_strength = 0.0
	current_platform_enemy = null
	ready_cue_played = false
	camera.position = camera_base_position
	camera.fov = base_fov


func _unhandled_input(event: InputEvent) -> void:
	if not manager or not manager.is_playing():
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -deg_to_rad(max_pitch_degrees), deg_to_rad(max_pitch_degrees))
		head.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			jump_buffer_timer = jump_buffer_time
		elif event.keycode == KEY_SHIFT:
			try_fire_extra()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		try_fire_extra()


func _physics_process(delta: float) -> void:
	if not manager or not manager.is_playing():
		return
	# Movement and platform detection are intentionally permissive for a floaty feel.
	_update_timers(delta)
	_apply_arcade_movement(delta)
	_handle_jump_buffer()
	move_and_slide()
	_update_enemy_platform()
	_update_auto_fire(delta)
	add_extra_charge(passive_charge_rate * delta)
	_update_camera_feedback(delta)


func _update_timers(delta: float) -> void:
	invulnerability_timer = max(0.0, invulnerability_timer - delta)
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	if is_on_floor() or current_platform_enemy != null:
		coyote_timer = coyote_time
		jumps_remaining = double_jump_count
	else:
		coyote_timer = max(0.0, coyote_timer - delta)


func _apply_arcade_movement(delta: float) -> void:
	var input := _read_move_input()
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var desired := (right * input.x + forward * -input.y).normalized() * move_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var acceleration: float = ground_acceleration if is_on_floor() or current_platform_enemy != null else air_acceleration
	if desired.length_squared() > 0.0:
		horizontal = horizontal.lerp(desired, clamp(acceleration * delta, 0.0, 1.0))
	else:
		horizontal = horizontal.lerp(Vector3.ZERO, clamp(ground_friction * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor() and current_platform_enemy == null:
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _read_move_input() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.y += 1.0
	return input.normalized()


func _handle_jump_buffer() -> void:
	if jump_buffer_timer <= 0.0:
		return
	if coyote_timer > 0.0:
		_do_jump(false)
	elif jumps_remaining > 0:
		_do_jump(true)


func _do_jump(air_jump: bool) -> void:
	velocity.y = jump_force
	jump_buffer_timer = 0.0
	if air_jump:
		jumps_remaining -= 1
	coyote_timer = 0.0
	current_platform_enemy = null
	fov_kick = max(fov_kick, 4.0)


func _update_enemy_platform() -> void:
	# Enemy platforms are simulated with a top-surface distance check instead of
	# heavy physics bodies, keeping large swarms practical for a prototype.
	current_platform_enemy = null
	if not enemy_jump_resets or velocity.y > 1.5:
		return
	var feet_y: float = global_position.y - body_half_height
	var enemy: EnemyBase = manager.find_enemy_platform(global_position, feet_y, enemy_platform_radius)
	if not enemy:
		return
	var top_y: float = enemy.global_position.y + enemy.platform_height
	global_position.y = top_y + body_half_height
	if velocity.y < 0.0:
		velocity.y = 0.0
	current_platform_enemy = enemy
	coyote_timer = coyote_time
	jumps_remaining = double_jump_count


func _update_auto_fire(delta: float) -> void:
	fire_timer += delta
	var interval := 1.0 / primary_fire_rate
	var shots := 0
	while fire_timer >= interval and shots < 3:
		fire_timer -= interval
		shots += 1
		_fire_primary()


func _fire_primary() -> void:
	var direction := -camera.global_transform.basis.z.normalized()
	manager.request_projectile(muzzle.global_position, direction, projectile_speed)


func try_fire_extra() -> void:
	if extra_charge < extra_shot_charge_max:
		return
	var direction := -camera.global_transform.basis.z.normalized()
	manager.perform_extra_shot(camera.global_position, direction, extra_shot_radius, extra_shot_range)
	extra_charge = 0.0
	ready_cue_played = false
	fov_kick = max(fov_kick, 12.0)
	add_camera_shake(0.3, 0.18)


func add_extra_charge(amount: float) -> void:
	if amount <= 0.0 or extra_charge >= extra_shot_charge_max:
		return
	extra_charge = min(extra_shot_charge_max, extra_charge + amount)
	if extra_charge >= extra_shot_charge_max and not ready_cue_played:
		ready_cue_played = true
		if manager and manager.ui:
			manager.ui.extra_ready_feedback()


func add_kill_charge(source: String, current_combo: float) -> void:
	var gain: float = kill_charge_bonus
	if source == "bomb":
		gain = bomb_kill_charge_bonus
	var combo_bonus: float = 1.0 + max(0.0, current_combo - 1.0) * combo_charge_bonus_scale
	add_extra_charge(gain * combo_bonus)


func apply_damage(amount: float, hit_position: Vector3) -> bool:
	if invulnerability_timer > 0.0 or hp <= 0.0:
		return false
	hp = max(0.0, hp - amount)
	invulnerability_timer = invulnerability_time
	var away: Vector3 = global_position - hit_position
	away.y = 0.0
	if away.length_squared() > 0.01:
		velocity += away.normalized() * 4.0
	add_camera_shake(0.28 if amount >= 1.0 else 0.16, 0.22)
	if manager and manager.ui:
		manager.ui.damage_feedback(amount)
	if hp <= 0.0 and manager:
		manager.end_run()
	return true


func is_invulnerable() -> bool:
	return invulnerability_timer > 0.0


func is_dead() -> bool:
	return hp <= 0.0


func is_enemy_platform_contact(enemy: EnemyBase) -> bool:
	return current_platform_enemy == enemy


func add_camera_shake(strength: float, duration: float) -> void:
	shake_strength = max(shake_strength, strength)
	shake_timer = max(shake_timer, duration)


func _update_camera_feedback(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var speed_fov: float = clamp(horizontal_speed / move_speed, 0.0, 1.35) * movement_fov_kick
	fov_kick = move_toward(fov_kick, 0.0, action_fov_recovery * delta)
	camera.fov = lerp(camera.fov, base_fov + speed_fov + fov_kick, clamp(9.0 * delta, 0.0, 1.0))
	if shake_timer > 0.0:
		shake_timer -= delta
		var fade: float = shake_timer / max(0.001, shake_timer + delta)
		var amount := shake_strength * fade
		camera.position = camera_base_position + Vector3(
			randf_range(-amount, amount),
			randf_range(-amount, amount),
			0.0
		)
	else:
		shake_strength = 0.0
		camera.position = camera.position.lerp(camera_base_position, clamp(16.0 * delta, 0.0, 1.0))


func get_view_basis() -> Basis:
	return camera.global_transform.basis


func get_horizontal_velocity_direction() -> Vector3:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length_squared() <= 0.01:
		return Vector3.ZERO
	return horizontal.normalized()

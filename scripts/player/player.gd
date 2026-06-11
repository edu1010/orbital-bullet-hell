class_name PlayerController
extends CharacterBody3D

# Arcade first-person controller with coyote time, buffered jumps, double jump,
# enemy-body platform resets, automatic primary fire, and charged extra shot.
@export_group("Movement")
@export var move_speed := 19.0
@export var ground_acceleration := 20.0
@export var air_acceleration := 11.0
@export var ground_friction := 12.0
@export var gravity := 22.0
@export var jump_force := 12.4
@export var double_jump_count := 1
@export var enemy_jump_resets := true
@export var coyote_time := 0.14
@export var jump_buffer_time := 0.16
@export var enemy_platform_radius := 0.55
@export var enemy_jump_probe_distance := 2.25
@export var enemy_platform_snap_distance := 0.85
@export var body_half_height := 0.9

@export_group("Spherical Gravity")
@export var sphere_center := Vector3.ZERO
@export var sphere_radius := 52.0
@export var gravity_lerp_speed := 8.5
@export var center_flip_lerp_speed := 16.0
@export var center_flip_dot_threshold := -0.2
@export var surface_snap_margin := 0.75

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

@export_group("Boost")
@export var boost_charge_max := 100.0
@export var boost_kill_charge_bonus := 3.2
@export var boost_bomb_kill_charge_bonus := 0.9
@export var boost_combo_charge_bonus_scale := 0.05
@export var boost_duration := 0.58
@export var boost_speed_multiplier := 2.25
@export var boost_acceleration := 38.0
@export var boost_impulse := 18.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var muzzle: Marker3D = $Head/Muzzle

var manager: GameManager
var hp := 3.0
var extra_charge := 0.0
var boost_charge := 0.0
var boost_timer := 0.0
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
var boost_ready_cue_played := false
var gravity_down := Vector3.DOWN
var on_gravity_floor := false


func configure(_manager: GameManager) -> void:
	manager = _manager


func set_spherical_world(center: Vector3, radius: float) -> void:
	sphere_center = center
	sphere_radius = radius


func _ready() -> void:
	camera_base_position = camera.position
	camera.fov = base_fov
	hp = max_hp
	up_direction = -gravity_down
	set_physics_process(true)


func reset_for_run(start_position: Vector3) -> void:
	global_position = start_position
	rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	pitch = 0.0
	velocity = Vector3.ZERO
	hp = max_hp
	extra_charge = 0.0
	boost_charge = 0.0
	boost_timer = 0.0
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
	boost_ready_cue_played = false
	on_gravity_floor = true
	gravity_down = _target_gravity_down()
	up_direction = -gravity_down
	_align_body_to_gravity(1.0)
	camera.position = camera_base_position
	camera.fov = base_fov


func _unhandled_input(event: InputEvent) -> void:
	if not manager or not manager.is_playing():
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -deg_to_rad(max_pitch_degrees), deg_to_rad(max_pitch_degrees))
		head.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			jump_buffer_timer = jump_buffer_time
		elif event.keycode == KEY_SHIFT:
			try_boost()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		try_fire_extra()


func _physics_process(delta: float) -> void:
	if not manager or not manager.is_playing():
		return
	# Movement and platform detection are intentionally permissive for a floaty feel.
	boost_timer = max(0.0, boost_timer - delta)
	_update_gravity(delta)
	_update_timers(delta)
	_apply_arcade_movement(delta)
	_handle_jump_buffer()
	move_and_slide()
	_constrain_to_sphere()
	_update_enemy_platform()
	_update_auto_fire(delta)
	add_extra_charge(passive_charge_rate * delta)
	_update_camera_feedback(delta)


func _update_timers(delta: float) -> void:
	invulnerability_timer = max(0.0, invulnerability_timer - delta)
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	if _is_grounded():
		coyote_timer = coyote_time
		jumps_remaining = double_jump_count
	else:
		coyote_timer = max(0.0, coyote_timer - delta)


func _apply_arcade_movement(delta: float) -> void:
	var input: Vector2 = _read_move_input()
	var forward: Vector3 = get_tangent_forward()
	var right: Vector3 = get_tangent_right()
	var move_direction: Vector3 = right * input.x + forward * -input.y
	if boost_timer > 0.0 and move_direction.length_squared() <= 0.001:
		move_direction = forward
	var target_speed: float = move_speed * (boost_speed_multiplier if boost_timer > 0.0 else 1.0)
	var desired: Vector3 = move_direction.normalized() * target_speed
	var tangent_velocity: Vector3 = velocity.slide(gravity_down)
	var down_speed: float = velocity.dot(gravity_down)
	var acceleration: float = boost_acceleration if boost_timer > 0.0 else (ground_acceleration if _is_grounded() else air_acceleration)
	if desired.length_squared() > 0.0:
		tangent_velocity = tangent_velocity.lerp(desired, clamp(acceleration * delta, 0.0, 1.0))
	else:
		tangent_velocity = tangent_velocity.lerp(Vector3.ZERO, clamp(ground_friction * delta, 0.0, 1.0))
	if not _is_grounded():
		down_speed += gravity * delta
	elif down_speed > 0.0:
		down_speed = 0.0
	velocity = tangent_velocity + gravity_down * down_speed


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
	var tangent_velocity: Vector3 = velocity.slide(gravity_down)
	velocity = tangent_velocity - gravity_down * jump_force
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
	if not enemy_jump_resets or velocity.dot(gravity_down) < -1.5:
		return
	var feet_position: Vector3 = global_position + gravity_down * body_half_height
	var enemy: EnemyBase = manager.find_enemy_platform(feet_position, gravity_down, enemy_platform_radius, enemy_jump_probe_distance)
	if not enemy:
		return
	var top_point: Vector3 = enemy.global_position - gravity_down * enemy.platform_height
	var delta_to_top: Vector3 = feet_position - top_point
	var vertical_delta: float = delta_to_top.dot(gravity_down)
	if vertical_delta >= -enemy_platform_snap_distance and vertical_delta <= 0.45:
		global_position = top_point - gravity_down * body_half_height
		var down_speed: float = velocity.dot(gravity_down)
		if down_speed > 0.0:
			velocity -= gravity_down * down_speed
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
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	manager.request_projectile(muzzle.global_position, direction, projectile_speed)


func try_fire_extra() -> void:
	if extra_charge < extra_shot_charge_max:
		return
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	manager.perform_extra_shot(camera.global_position, direction, extra_shot_radius, extra_shot_range)
	extra_charge = 0.0
	ready_cue_played = false
	fov_kick = max(fov_kick, 12.0)
	add_camera_shake(0.3, 0.18)


func try_boost() -> void:
	if boost_charge < boost_charge_max:
		return
	boost_charge = 0.0
	boost_ready_cue_played = false
	boost_timer = boost_duration
	var boost_direction: Vector3 = _current_intended_boost_direction()
	velocity += boost_direction * boost_impulse
	fov_kick = max(fov_kick, 15.0)
	add_camera_shake(0.16, 0.12)
	if manager and manager.ui:
		manager.ui.boost_feedback()


func add_extra_charge(amount: float) -> void:
	if amount <= 0.0 or extra_charge >= extra_shot_charge_max:
		return
	extra_charge = min(extra_shot_charge_max, extra_charge + amount)
	if extra_charge >= extra_shot_charge_max and not ready_cue_played:
		ready_cue_played = true
		if manager and manager.ui:
			manager.ui.extra_ready_feedback()


func add_boost_charge(amount: float) -> void:
	if amount <= 0.0 or boost_charge >= boost_charge_max:
		return
	boost_charge = min(boost_charge_max, boost_charge + amount)
	if boost_charge >= boost_charge_max and not boost_ready_cue_played:
		boost_ready_cue_played = true
		if manager and manager.ui:
			manager.ui.boost_ready_feedback()


func add_kill_charge(source: String, current_combo: float) -> void:
	var gain: float = kill_charge_bonus
	var boost_gain: float = boost_kill_charge_bonus
	if source == "bomb":
		gain = bomb_kill_charge_bonus
		boost_gain = boost_bomb_kill_charge_bonus
	var combo_bonus: float = 1.0 + max(0.0, current_combo - 1.0) * combo_charge_bonus_scale
	var boost_combo_bonus: float = 1.0 + max(0.0, current_combo - 1.0) * boost_combo_charge_bonus_scale
	add_extra_charge(gain * combo_bonus)
	add_boost_charge(boost_gain * boost_combo_bonus)


func apply_damage(amount: float, hit_position: Vector3) -> bool:
	if invulnerability_timer > 0.0 or hp <= 0.0:
		return false
	hp = max(0.0, hp - amount)
	invulnerability_timer = invulnerability_time
	var away: Vector3 = global_position - hit_position
	away = away.slide(gravity_down)
	if away.length_squared() > 0.01:
		velocity += away.normalized() * 4.0
	add_camera_shake(0.28 if amount >= 1.0 else 0.16, 0.22)
	if manager and manager.ui:
		manager.ui.damage_feedback(amount)
	if hp <= 0.0 and manager:
		manager.end_run()
	return true


func heal(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	var old_hp: float = hp
	hp = min(max_hp, hp + amount)
	if hp > old_hp:
		fov_kick = max(fov_kick, 4.0)
		add_camera_shake(0.08, 0.1)
		if manager and manager.ui:
			manager.ui.heal_feedback(hp - old_hp)


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
	var horizontal_speed: float = velocity.slide(gravity_down).length()
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
	var horizontal: Vector3 = velocity.slide(gravity_down)
	if horizontal.length_squared() <= 0.01:
		return Vector3.ZERO
	return horizontal.normalized()


func get_gravity_down() -> Vector3:
	return gravity_down


func get_tangent_forward() -> Vector3:
	var forward: Vector3 = -global_transform.basis.z
	forward = forward.slide(gravity_down)
	if forward.length_squared() <= 0.001:
		forward = (-gravity_down).cross(get_tangent_right())
	return forward.normalized()


func get_tangent_right() -> Vector3:
	var right: Vector3 = global_transform.basis.x
	right = right.slide(gravity_down)
	if right.length_squared() <= 0.001:
		right = gravity_down.cross(Vector3.UP)
		if right.length_squared() <= 0.001:
			right = gravity_down.cross(Vector3.RIGHT)
	return right.normalized()


func get_random_tangent_direction() -> Vector3:
	var angle: float = randf_range(0.0, TAU)
	return (get_tangent_right() * cos(angle) + get_tangent_forward() * sin(angle)).normalized()


func get_default_spawn_position() -> Vector3:
	return sphere_center + Vector3.BACK * max(1.0, sphere_radius - body_half_height)


func project_inside_sphere(approx_position: Vector3, altitude_from_wall: float) -> Vector3:
	var radial: Vector3 = approx_position - sphere_center
	if radial.length_squared() <= 0.001:
		radial = gravity_down
	var down_at_position: Vector3 = radial.normalized()
	var distance_from_center: float = max(1.0, sphere_radius - altitude_from_wall)
	return sphere_center + down_at_position * distance_from_center


func project_outside_sphere(approx_position: Vector3, outside_distance: float) -> Vector3:
	var radial: Vector3 = approx_position - sphere_center
	if radial.length_squared() <= 0.001:
		radial = gravity_down
	return sphere_center + radial.normalized() * (sphere_radius + outside_distance)


func _current_intended_boost_direction() -> Vector3:
	var input: Vector2 = _read_move_input()
	var direction: Vector3 = get_tangent_right() * input.x + get_tangent_forward() * -input.y
	if direction.length_squared() <= 0.001:
		direction = get_tangent_forward()
	return direction.normalized()


func _update_gravity(delta: float) -> void:
	var target_down: Vector3 = _target_gravity_down()
	var lerp_speed: float = gravity_lerp_speed
	var radial: Vector3 = global_position - sphere_center
	if radial.length_squared() > 0.001 and radial.normalized().dot(gravity_down) < center_flip_dot_threshold:
		lerp_speed = center_flip_lerp_speed
	var blend: float = clamp(lerp_speed * delta, 0.0, 1.0)
	if gravity_down.dot(target_down) < -0.98:
		gravity_down = gravity_down.lerp(target_down, blend).normalized()
	else:
		gravity_down = gravity_down.slerp(target_down, blend).normalized()
	up_direction = -gravity_down
	_align_body_to_gravity(blend)


func _target_gravity_down() -> Vector3:
	var radial: Vector3 = global_position - sphere_center
	if radial.length_squared() <= 0.001:
		return gravity_down
	return radial.normalized()


func _align_body_to_gravity(blend: float) -> void:
	var target_up: Vector3 = -gravity_down
	var forward: Vector3 = -global_transform.basis.z
	forward = forward.slide(gravity_down)
	if forward.length_squared() <= 0.001:
		forward = target_up.cross(get_tangent_right())
	forward = forward.normalized()
	var target_basis: Basis = Basis.looking_at(forward, target_up).orthonormalized()
	if blend >= 1.0:
		global_transform.basis = target_basis
	else:
		var current_quat: Quaternion = global_transform.basis.get_rotation_quaternion()
		var target_quat: Quaternion = target_basis.get_rotation_quaternion()
		global_transform.basis = Basis(current_quat.slerp(target_quat, blend)).orthonormalized()


func _constrain_to_sphere() -> void:
	on_gravity_floor = false
	var radial: Vector3 = global_position - sphere_center
	if radial.length_squared() <= 0.001:
		return
	var distance: float = radial.length()
	var max_distance: float = max(1.0, sphere_radius - body_half_height)
	var wall_down: Vector3 = radial / distance
	if distance >= max_distance:
		global_position = sphere_center + wall_down * max_distance
		gravity_down = wall_down
		up_direction = -gravity_down
		var down_speed: float = velocity.dot(gravity_down)
		if down_speed > 0.0:
			velocity -= gravity_down * down_speed
		on_gravity_floor = true
	elif max_distance - distance <= surface_snap_margin and velocity.dot(gravity_down) >= 0.0:
		on_gravity_floor = true


func _is_grounded() -> bool:
	return on_gravity_floor or current_platform_enemy != null or is_on_floor()

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
@export var jump_force := 16.5
@export var double_jump_count := 1
@export var enemy_jump_resets := true
@export var coyote_time := 0.14
@export var jump_buffer_time := 0.16
@export var enemy_platform_radius := 1.15
@export var enemy_jump_probe_distance := 4.0
@export var enemy_platform_snap_distance := 1.35
@export var body_half_height := 0.9

@export_group("Spherical Gravity")
@export var sphere_center := Vector3.ZERO
@export var sphere_radius := 38.0
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
@export var invulnerability_time := 1.5

@export_group("Primary Fire")
@export var primary_fire_rate := 12.5
@export var projectile_speed := 62.0
@export var downward_fire_lift_threshold := 0.42
@export var downward_fire_lift_impulse := 2.0
@export var downward_fire_lift_max_speed := 30.0

@export_group("Extra Shot")
@export var extra_shot_charge_max := 100.0
@export var passive_charge_rate := 9.0
@export var kill_charge_bonus := 2.4
@export var bomb_kill_charge_bonus := 0.8
@export var combo_charge_bonus_scale := 0.12
@export var extra_shot_radius := 5.0
@export var extra_shot_range := 88.0
@export var extra_shot_lift_impulse := 8.0

@export_group("Orbital Shield")
@export var orbital_shield_charge_max := 100.0
@export var orbital_shield_enemy_jump_charge := 16.0
@export var orbital_shield_shard_charge_per_point := 0.08
@export var orbital_shield_radius := 7.4
@export var orbital_shield_duration := 0.72
@export var orbital_shield_launch_speed := 92.0
@export var orbital_shield_gravity_lerp_speed := 44.0

@export_group("Boost")
@export var boost_charge_max := 100.0
@export var boost_kill_charge_bonus := 5.4
@export var boost_bomb_kill_charge_bonus := 1.6
@export var boost_combo_charge_bonus_scale := 0.08
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
var orbital_shield_charge := 0.0
var boost_charge := 0.0
var orbital_shield_timer := 0.0
var boost_timer := 0.0
var invulnerability_timer := 0.0
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var jumps_remaining := 1
var fire_timer := 0.0
var overdrive_timer := 0.0
var pitch := 0.0
var fov_kick := 0.0
var shake_timer := 0.0
var shake_strength := 0.0
var camera_base_position := Vector3.ZERO
var current_platform_enemy: EnemyBase
var ready_cue_played := false
var orbital_shield_ready_cue_played := false
var boost_ready_cue_played := false
var gravity_down := Vector3.DOWN
var on_gravity_floor := false
var orbital_shield_visual: MeshInstance3D
var orbital_shield_material: StandardMaterial3D
var weapon_root: Node3D
var weapon_spin: Node3D
var weapon_muzzle: Marker3D
var weapon_muzzle_flash: MeshInstance3D
var muzzle_flash_timer := 0.0
var weapon_root_base_position := Vector3(0.3, -0.34, -0.48)
var weapon_bob_time := 0.0

@export_group("Weapon Viewmodel")
@export var weapon_spin_speed := 15.0
# Bullets leave the gun muzzle and aim at this distance along the crosshair, so
# they appear to fire from the barrels yet still converge on where you are looking.
@export var aim_convergence_distance := 90.0

# Lightweight action counters consumed by the tutorial to detect mechanics.
var stat_jumps := 0
var stat_air_jumps := 0
var stat_enemy_jumps := 0
var stat_extra_shots := 0
var stat_shield_shots := 0
var stat_boosts := 0


func configure(_manager: GameManager) -> void:
	manager = _manager


func set_spherical_world(center: Vector3, radius: float) -> void:
	sphere_center = center
	sphere_radius = radius


func make_camera_current() -> void:
	# Hands the viewport back to the player camera when the menu showcase releases it.
	if camera:
		camera.current = true


func _ready() -> void:
	camera_base_position = camera.position
	camera.fov = base_fov
	_create_orbital_shield_visual()
	_create_weapon_viewmodel()
	hp = max_hp
	up_direction = -gravity_down
	set_physics_process(true)
	set_process(true)


func reset_for_run(start_position: Vector3) -> void:
	global_position = start_position
	rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	pitch = 0.0
	velocity = Vector3.ZERO
	hp = max_hp
	extra_charge = 0.0
	orbital_shield_charge = 0.0
	boost_charge = 0.0
	orbital_shield_timer = 0.0
	boost_timer = 0.0
	invulnerability_timer = 0.0
	overdrive_timer = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = coyote_time
	jumps_remaining = double_jump_count
	fire_timer = 0.0
	fov_kick = 0.0
	shake_timer = 0.0
	shake_strength = 0.0
	current_platform_enemy = null
	ready_cue_played = false
	orbital_shield_ready_cue_played = false
	boost_ready_cue_played = false
	stat_jumps = 0
	stat_air_jumps = 0
	stat_enemy_jumps = 0
	stat_extra_shots = 0
	stat_shield_shots = 0
	stat_boosts = 0
	if orbital_shield_visual:
		orbital_shield_visual.visible = false
	on_gravity_floor = true
	gravity_down = _target_gravity_down()
	up_direction = -gravity_down
	_align_body_to_gravity(1.0)
	camera.position = camera_base_position
	camera.fov = base_fov


func _unhandled_input(event: InputEvent) -> void:
	if not manager or not manager.is_playing():
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and not vr_active:
		rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -deg_to_rad(max_pitch_degrees), deg_to_rad(max_pitch_degrees))
		head.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == manager.get_bound_key("jump", KEY_SPACE):
			manager.dismiss_start_controls_hint()
			jump_buffer_timer = jump_buffer_time
		elif event.keycode == manager.get_bound_key("boost", KEY_SHIFT):
			try_boost()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		try_fire_orbital_shield()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_fire_extra()


func _physics_process(delta: float) -> void:
	if not manager or not manager.is_playing():
		return
	# Movement and platform detection are intentionally permissive for a floaty feel.
	boost_timer = max(0.0, boost_timer - delta)
	_update_orbital_shield(delta)
	_update_gravity(delta)
	_update_timers(delta)
	_apply_arcade_movement(delta)
	_handle_jump_buffer()
	move_and_slide()
	_constrain_to_sphere()
	_update_enemy_platform()
	if not vr_active:
		_update_auto_fire(delta)  # en VR disparan las dos manos (vr_hand.gd)
	add_extra_charge(passive_charge_rate * delta)
	_update_camera_feedback(delta)


func _process(delta: float) -> void:
	if not weapon_root:
		return
	var showing: bool = manager != null and manager.is_playing()
	weapon_root.visible = showing and not vr_active  # en VR las manos son las armas
	if not showing:
		return
	if weapon_spin:
		weapon_spin.rotate_object_local(Vector3(0.0, 0.0, 1.0), weapon_spin_speed * delta)
	if muzzle_flash_timer > 0.0 and weapon_muzzle_flash:
		muzzle_flash_timer = max(0.0, muzzle_flash_timer - delta)
		weapon_muzzle_flash.visible = true
		var flash: float = muzzle_flash_timer / 0.05
		weapon_muzzle_flash.scale = Vector3.ONE * (0.55 + flash * 0.95)
	elif weapon_muzzle_flash and weapon_muzzle_flash.visible:
		weapon_muzzle_flash.visible = false
	# Subtle idle sway and walk bob so the viewmodel feels alive.
	weapon_bob_time += delta
	var speed_factor: float = clamp(velocity.slide(gravity_down).length() / max(0.1, move_speed), 0.0, 1.0)
	var bob: float = sin(weapon_bob_time * 9.0) * (0.004 + speed_factor * 0.012)
	var sway: float = sin(weapon_bob_time * 1.7) * 0.004
	weapon_root.position = weapon_root_base_position + Vector3(sway, bob, 0.0)


func _update_timers(delta: float) -> void:
	invulnerability_timer = max(0.0, invulnerability_timer - delta)
	overdrive_timer = max(0.0, overdrive_timer - delta)
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	if _is_grounded():
		coyote_timer = coyote_time
		jumps_remaining = double_jump_count
	else:
		coyote_timer = max(0.0, coyote_timer - delta)


func _apply_arcade_movement(delta: float) -> void:
	var input: Vector2 = _read_move_input()
	if input.length_squared() > 0.0:
		manager.dismiss_start_controls_hint()
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


# --- Integración VR (la conduce el rig VR; en plano queda inerte) ---
var vr_active := false
var vr_move_input := Vector2.ZERO


func apply_vr_turn(yaw_delta: float) -> void:
	# Giro suave con el joystick derecho, igual que el yaw del mouse-look.
	rotate_object_local(Vector3.UP, yaw_delta)


func vr_jump() -> void:
	if manager:
		manager.dismiss_start_controls_hint()
	jump_buffer_timer = jump_buffer_time


func _read_move_input() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_key_pressed(manager.get_bound_key("left", KEY_A)):
		input.x -= 1.0
	if Input.is_key_pressed(manager.get_bound_key("right", KEY_D)):
		input.x += 1.0
	if Input.is_key_pressed(manager.get_bound_key("forward", KEY_W)):
		input.y -= 1.0
	if Input.is_key_pressed(manager.get_bound_key("backward", KEY_S)):
		input.y += 1.0
	input = input.normalized()
	input += vr_move_input  # joystick VR analógico (lo fija el rig cada frame)
	if input.length() > 1.0:
		input = input.normalized()
	return input


func _handle_jump_buffer() -> void:
	if jump_buffer_timer <= 0.0:
		return
	if coyote_timer > 0.0:
		var was_enemy_jump: bool = current_platform_enemy != null
		_do_jump(false)
		if was_enemy_jump:
			_on_enemy_platform_jump()
	elif _try_enemy_platform_jump():
		_do_jump(false)
		_on_enemy_platform_jump()
	elif jumps_remaining > 0:
		_do_jump(true)


func _do_jump(air_jump: bool) -> void:
	var tangent_velocity: Vector3 = velocity.slide(gravity_down)
	velocity = tangent_velocity - gravity_down * jump_force
	jump_buffer_timer = 0.0
	stat_jumps += 1
	if air_jump:
		jumps_remaining -= 1
		stat_air_jumps += 1
	coyote_timer = 0.0
	current_platform_enemy = null
	fov_kick = max(fov_kick, 4.0)


func _try_enemy_platform_jump() -> bool:
	if not enemy_jump_resets or not manager:
		return false
	var feet_position: Vector3 = global_position + gravity_down * body_half_height
	var enemy: EnemyBase = manager.find_enemy_platform(
		feet_position,
		gravity_down,
		enemy_platform_radius * 1.65,
		enemy_jump_probe_distance * 1.15
	)
	if not enemy:
		return false
	current_platform_enemy = enemy
	coyote_timer = coyote_time
	jumps_remaining = double_jump_count
	return true


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
	var rate: float = primary_fire_rate * (2.0 if overdrive_timer > 0.0 else 1.0)
	var interval := 1.0 / rate
	var shots := 0
	while fire_timer >= interval and shots < 6:
		fire_timer -= interval
		shots += 1
		_fire_primary()


func _fire_primary() -> void:
	# Spawn at the gun muzzle but aim at the crosshair convergence point so the
	# tracers visibly leave the barrels yet still land where the player is looking.
	var view_forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var origin: Vector3 = weapon_muzzle.global_position if weapon_muzzle else muzzle.global_position
	var aim_point: Vector3 = camera.global_position + view_forward * aim_convergence_distance
	var direction: Vector3 = (aim_point - origin).normalized()
	manager.request_projectile(origin, direction, projectile_speed)
	muzzle_flash_timer = 0.05
	_apply_downward_fire_lift(view_forward, downward_fire_lift_impulse)


func try_fire_extra() -> void:
	if extra_charge < extra_shot_charge_max:
		return
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	manager.perform_extra_shot(camera.global_position, direction, extra_shot_radius, extra_shot_range)
	_apply_downward_fire_lift(direction, extra_shot_lift_impulse)
	stat_extra_shots += 1
	extra_charge = 0.0
	ready_cue_played = false
	fov_kick = max(fov_kick, 12.0)
	add_camera_shake(0.3, 0.18)


func try_fire_orbital_shield() -> void:
	if orbital_shield_charge < orbital_shield_charge_max:
		return
	orbital_shield_charge = 0.0
	orbital_shield_ready_cue_played = false
	stat_shield_shots += 1
	orbital_shield_timer = orbital_shield_duration
	var tangent_velocity: Vector3 = velocity.slide(gravity_down) * 0.2
	velocity = tangent_velocity - gravity_down * orbital_shield_launch_speed
	fov_kick = max(fov_kick, 22.0)
	add_camera_shake(0.5, 0.28)
	if manager:
		manager.spawn_orbital_shield_visual(global_position, -gravity_down, orbital_shield_radius)
		manager.perform_orbital_shield(global_position, orbital_shield_radius)
		if manager.ui:
			manager.ui.orbital_shield_feedback()


func _apply_downward_fire_lift(direction: Vector3, impulse: float) -> void:
	var downward_alignment: float = direction.normalized().dot(gravity_down)
	if downward_alignment <= downward_fire_lift_threshold:
		return
	var lift_scale: float = inverse_lerp(downward_fire_lift_threshold, 1.0, downward_alignment)
	var current_up_speed: float = velocity.dot(-gravity_down)
	var capped_impulse: float = min(impulse * lift_scale, max(0.0, downward_fire_lift_max_speed - current_up_speed))
	if capped_impulse <= 0.0:
		return
	velocity += -gravity_down * capped_impulse
	fov_kick = max(fov_kick, 3.0)


func try_boost() -> void:
	if boost_charge < boost_charge_max:
		return
	manager.dismiss_start_controls_hint()
	boost_charge = 0.0
	boost_ready_cue_played = false
	stat_boosts += 1
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


func add_orbital_shield_charge(amount: float) -> void:
	if amount <= 0.0 or orbital_shield_charge >= orbital_shield_charge_max:
		return
	orbital_shield_charge = min(orbital_shield_charge_max, orbital_shield_charge + amount)
	if orbital_shield_charge >= orbital_shield_charge_max and not orbital_shield_ready_cue_played:
		orbital_shield_ready_cue_played = true
		if manager and manager.ui:
			manager.ui.orbital_shield_ready_feedback()


func add_boost_charge(amount: float) -> void:
	if amount <= 0.0 or boost_charge >= boost_charge_max:
		return
	boost_charge = min(boost_charge_max, boost_charge + amount)
	if boost_charge >= boost_charge_max and not boost_ready_cue_played:
		boost_ready_cue_played = true
		if manager and manager.ui:
			manager.ui.boost_ready_feedback()


func refill_all_charges() -> void:
	extra_charge = extra_shot_charge_max
	orbital_shield_charge = orbital_shield_charge_max
	boost_charge = boost_charge_max
	ready_cue_played = true
	orbital_shield_ready_cue_played = true
	boost_ready_cue_played = true


func apply_overdrive(duration: float) -> void:
	# Doubles the primary fire rate for a while (see _update_auto_fire).
	overdrive_timer = max(overdrive_timer, duration)
	fov_kick = max(fov_kick, 14.0)
	add_camera_shake(0.22, 0.16)


func is_overdrive_active() -> bool:
	return overdrive_timer > 0.0


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


func _on_enemy_platform_jump() -> void:
	stat_enemy_jumps += 1
	add_orbital_shield_charge(orbital_shield_enemy_jump_charge)
	if manager:
		manager.spawn_burst(global_position, Color(0.62, 0.96, 1.0), 1.4, 0.16)


func apply_damage(amount: float, hit_position: Vector3) -> bool:
	if orbital_shield_timer > 0.0 or invulnerability_timer > 0.0 or hp <= 0.0:
		return false
	hp = max(0.0, hp - amount)
	invulnerability_timer = invulnerability_time
	add_camera_shake(0.28 if amount >= 1.0 else 0.16, 0.22)
	if manager and manager.ui:
		manager.ui.damage_feedback(amount)
		manager.ui.register_damage_direction(hit_position)
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


func _create_orbital_shield_visual() -> void:
	orbital_shield_visual = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	orbital_shield_visual.mesh = mesh
	orbital_shield_material = StandardMaterial3D.new()
	orbital_shield_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orbital_shield_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orbital_shield_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	orbital_shield_material.albedo_color = Color(0.35, 0.95, 1.0, 0.0)
	orbital_shield_material.emission_enabled = true
	orbital_shield_material.emission = Color(0.35, 0.95, 1.0, 0.0)
	orbital_shield_material.emission_energy_multiplier = 2.4
	orbital_shield_visual.material_override = orbital_shield_material
	orbital_shield_visual.visible = false
	add_child(orbital_shield_visual)


func _create_weapon_viewmodel() -> void:
	# A low-poly rotary gatling cannon built from primitives, parented to the camera
	# so it tracks the view. The whole barrel cluster spins around the bore, and it
	# is drawn over the world so it reads as a true first-person viewmodel. Parts are
	# added back-to-front so the on-top draw keeps a believable painter ordering.
	weapon_root = Node3D.new()
	weapon_root.position = weapon_root_base_position
	weapon_root.rotation_degrees = Vector3(3.0, 8.0, 0.0)
	camera.add_child(weapon_root)
	var parts := build_gatling_viewmodel(weapon_root)
	weapon_spin = parts["spin"]
	weapon_muzzle = parts["muzzle"]
	weapon_muzzle_flash = parts["flash"]
	weapon_root.visible = false


## Construye la gatling low-poly bajo `parent`, apuntando a -Z, y devuelve
## {spin, muzzle, flash}. La usa el viewmodel en plano y las MANOS en VR (vr_hand).
func build_gatling_viewmodel(parent: Node3D) -> Dictionary:
	var tan_mat: StandardMaterial3D = _make_weapon_material(Color(0.62, 0.55, 0.42), Color(0.3, 0.25, 0.16), 0.28)
	var tan_dark: StandardMaterial3D = _make_weapon_material(Color(0.42, 0.37, 0.28), Color(0.18, 0.15, 0.1), 0.2)
	var dark_metal: StandardMaterial3D = _make_weapon_material(Color(0.12, 0.11, 0.1), Color(0.06, 0.05, 0.04), 0.12)
	var brass: StandardMaterial3D = _make_weapon_material(Color(0.66, 0.5, 0.2), Color(0.6, 0.42, 0.12), 0.8)
	var muzzle_glow: StandardMaterial3D = _make_weapon_material(Color(1.0, 0.66, 0.3), Color(1.0, 0.55, 0.2), 2.6)

	# Rear housing / receiver and the motor block, plus grip and ammo drum.
	_add_weapon_box(parent, tan_mat, Vector3(0.2, 0.19, 0.26), Vector3(0.0, 0.0, 0.12))
	_add_weapon_box(parent, dark_metal, Vector3(0.07, 0.18, 0.12), Vector3(0.0, -0.16, 0.16), Vector3(16.0, 0.0, 0.0))
	_add_weapon_box(parent, tan_dark, Vector3(0.17, 0.17, 0.14), Vector3(-0.16, -0.04, 0.14))
	_add_weapon_box(parent, brass, Vector3(0.03, 0.03, 0.16), Vector3(-0.05, 0.02, 0.1), Vector3(0.0, 0.0, 26.0))
	_add_weapon_cylinder(parent, tan_mat, 0.11, 0.16, 6, Vector3(0.0, 0.0, -0.02))

	# Spinning barrel assembly mounted on the bore axis.
	var spin := Node3D.new()
	spin.position = Vector3(0.0, 0.0, -0.12)
	parent.add_child(spin)
	_add_weapon_cylinder(spin, tan_dark, 0.09, 0.05, 6, Vector3(0.0, 0.0, 0.0))
	_add_weapon_cylinder(spin, dark_metal, 0.02, 0.62, 6, Vector3(0.0, 0.0, -0.32))
	for i in range(6):
		var barrel_angle: float = TAU * float(i) / 6.0
		var ring_offset: Vector3 = Vector3(cos(barrel_angle), sin(barrel_angle), 0.0) * 0.066
		var barrel_material: StandardMaterial3D = tan_mat if i % 2 == 0 else tan_dark
		_add_weapon_cylinder(spin, barrel_material, 0.024, 0.62, 6, ring_offset + Vector3(0.0, 0.0, -0.32))
	_add_weapon_cylinder(spin, tan_mat, 0.092, 0.05, 6, Vector3(0.0, 0.0, -0.62))

	# Muzzle marker (bullet origin) and a flash that pulses on every shot.
	var muzzle_marker := Marker3D.new()
	muzzle_marker.position = Vector3(0.0, 0.0, -0.74)
	parent.add_child(muzzle_marker)
	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.1
	flash_mesh.height = 0.2
	flash_mesh.radial_segments = 6
	flash_mesh.rings = 3
	flash.mesh = flash_mesh
	flash.material_override = muzzle_glow
	flash.position = Vector3(0.0, 0.0, -0.76)
	flash.visible = false
	parent.add_child(flash)

	return {"spin": spin, "muzzle": muzzle_marker, "flash": flash}


func _make_weapon_material(albedo: Color, emission: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.55
	material.metallic = 0.45
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = emission_energy
	# Draw over the world so swarmers passing the corner never clip through the gun.
	material.no_depth_test = true
	material.render_priority = 2
	return material


func _add_weapon_box(parent: Node3D, material: Material, box_size: Vector3, local_position: Vector3, local_rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = local_position
	part.rotation_degrees = local_rotation_degrees
	parent.add_child(part)


func _add_weapon_cylinder(parent: Node3D, material: Material, radius: float, length: float, sides: int, local_position: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = sides
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = local_position
	# Cylinders are built along Y; tip them to lie along the camera's -Z bore axis.
	part.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	parent.add_child(part)


func _update_orbital_shield(delta: float) -> void:
	if orbital_shield_timer <= 0.0:
		if orbital_shield_visual:
			orbital_shield_visual.visible = false
		return
	orbital_shield_timer = max(0.0, orbital_shield_timer - delta)
	if manager:
		manager.perform_orbital_shield(global_position, orbital_shield_radius)
	if orbital_shield_visual and orbital_shield_material:
		var progress: float = 1.0 - orbital_shield_timer / max(0.001, orbital_shield_duration)
		var pulse: float = 1.0 + sin(progress * TAU * 3.0) * 0.06
		var alpha: float = lerp(0.26, 0.08, progress)
		orbital_shield_visual.visible = true
		orbital_shield_visual.scale = Vector3.ONE * orbital_shield_radius * pulse
		var color := Color(0.35, 0.95, 1.0, alpha)
		orbital_shield_material.albedo_color = color
		orbital_shield_material.emission = color
	if orbital_shield_timer <= 0.0 and orbital_shield_visual:
		orbital_shield_visual.visible = false


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
	if orbital_shield_timer > 0.0:
		lerp_speed = max(lerp_speed, orbital_shield_gravity_lerp_speed)
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

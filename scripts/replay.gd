class_name ReplayController
extends Node3D

# Records a rolling window of the run (player camera + nearby enemies + projectiles
# + boss) into a ring buffer, then plays it back with lightweight "ghost" primitives.
# Playback supports first/third-person cameras, variable speed and scrubbing.

const RECORD_HZ := 20.0
const MAX_SECONDS := 45.0
const MAX_ENEMIES := 220
const MAX_PROJECTILES := 80
const SPEEDS := [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0]

var manager: GameManager
var player: PlayerController

var recording := false
var record_accum := 0.0
var record_time := 0.0
var frames: Array = []

var playing := false
var paused := false
var third_person := false
var playback_time := 0.0
var playback_speed := 1.0

var camera: Camera3D
var enemy_container: Node3D
var projectile_container: Node3D
var enemy_ghosts: Array[MeshInstance3D] = []
var projectile_ghosts: Array[MeshInstance3D] = []
var player_ghost: Node3D
var boss_root: Node3D
var boss_head_ghost: MeshInstance3D
var boss_weak_ghosts: Array[MeshInstance3D] = []
var boss_laser_ghost: MeshInstance3D

var enemy_materials: Array[StandardMaterial3D] = []
var enemy_scales: Array[float] = [0.82, 1.38, 1.03, 2.15]
var shared_sphere: SphereMesh
var built := false


func configure(_manager: GameManager, _player: PlayerController) -> void:
	manager = _manager
	player = _player
	if not built:
		_build()
	visible = false
	set_process(true)


func begin_recording() -> void:
	recording = true
	frames.clear()
	record_accum = 0.0
	record_time = 0.0


func stop_recording() -> void:
	recording = false


func has_replay() -> bool:
	return frames.size() > 3


func get_speeds() -> Array:
	return SPEEDS


func record(delta: float) -> void:
	if not recording:
		return
	record_accum += delta
	var step: float = 1.0 / RECORD_HZ
	if record_accum < step:
		return
	record_accum -= step
	record_time += step
	_capture_frame()
	var max_frames: int = int(MAX_SECONDS * RECORD_HZ)
	while frames.size() > max_frames:
		frames.pop_front()


func _capture_frame() -> void:
	var cam: Camera3D = player.camera
	var snapshot := {
		"t": record_time,
		"ppos": player.global_position,
		"pfwd": -player.global_transform.basis.z,
		"pup": player.global_transform.basis.y,
		"campos": cam.global_position,
		"camquat": cam.global_transform.basis.get_rotation_quaternion(),
		"alive": not player.is_dead(),
	}
	# Nearest enemies only, so memory stays bounded in dense swarms.
	var ranked: Array = []
	for enemy in manager.active_enemies:
		if not enemy.active:
			continue
		ranked.append([enemy.global_position.distance_squared_to(player.global_position), enemy])
	ranked.sort_custom(func(a, b): return a[0] < b[0])
	var positions := PackedVector3Array()
	var types := PackedByteArray()
	var count: int = mini(ranked.size(), MAX_ENEMIES)
	for i in range(count):
		var enemy: EnemyBase = ranked[i][1]
		positions.append(enemy.global_position)
		types.append(_enemy_type_code(enemy))
	snapshot["enemies"] = positions
	snapshot["etypes"] = types
	var projectiles := PackedVector3Array()
	for projectile in manager.active_projectiles:
		if projectile.active:
			projectiles.append(projectile.global_position)
			if projectiles.size() >= MAX_PROJECTILES:
				break
	snapshot["projectiles"] = projectiles
	snapshot["boss"] = _capture_boss()
	frames.append(snapshot)


func _capture_boss() -> Variant:
	var boss: DragonBoss = manager.boss.get_active_dragon() if manager.boss else null
	if not boss or not boss.is_active():
		return null
	var weak: Array = []
	for weak_point in boss.weak_points:
		var root: Node3D = weak_point["root"]
		weak.append({"pos": root.global_position, "alive": bool(weak_point["alive"])})
	var data := {
		"head": boss.head_position,
		"dir": boss.head_dir,
		"weak": weak,
		"laser": boss.laser_mesh.visible,
	}
	if boss.laser_mesh.visible:
		data["lstart"] = boss._mouth_origin()
		data["laim"] = boss.aim_dir
		data["lrange"] = boss.laser_range
	return data


func _enemy_type_code(enemy: EnemyBase) -> int:
	if enemy is BombEnemy:
		return 3
	if enemy is ChargerEnemy:
		return 1
	if enemy is AvoiderEnemy:
		return 2
	return 0


# --- Playback --------------------------------------------------------------

func start_playback() -> void:
	if not has_replay():
		return
	playing = true
	paused = false
	playback_speed = 1.0
	playback_time = 0.0
	third_person = false
	visible = true
	camera.current = true
	if manager and manager.ui:
		manager.ui.show_replay_controls(true)
		manager.ui.update_replay_controls(playback_speed, paused, third_person, 0.0)


func stop_playback() -> void:
	playing = false
	visible = false
	_hide_all_ghosts()
	if player and player.camera:
		player.camera.current = true
	if manager and manager.ui:
		manager.ui.show_replay_controls(false)


func set_playback_speed(speed: float) -> void:
	playback_speed = speed
	paused = false
	_refresh_controls()


func toggle_pause() -> void:
	paused = not paused
	_refresh_controls()


func toggle_camera() -> void:
	third_person = not third_person
	_refresh_controls()


func scrub_to(fraction: float) -> void:
	playback_time = clamp(fraction, 0.0, 1.0) * _duration()
	_refresh_controls()


func _refresh_controls() -> void:
	if manager and manager.ui:
		manager.ui.update_replay_controls(playback_speed, paused, third_person, _progress())


func _duration() -> float:
	if frames.size() < 2:
		return 0.0
	return float(frames[frames.size() - 1]["t"]) - float(frames[0]["t"])


func _progress() -> float:
	var duration: float = _duration()
	if duration <= 0.0:
		return 0.0
	return clamp(playback_time / duration, 0.0, 1.0)


func _process(delta: float) -> void:
	if not playing or frames.size() < 2:
		return
	if not paused:
		playback_time += delta * playback_speed
		var duration: float = _duration()
		if playback_time >= duration:
			playback_time = duration
			paused = true
			_refresh_controls()
	_render_playback()
	if not paused and manager and manager.ui:
		manager.ui.update_replay_progress(_progress())


func _render_playback() -> void:
	var base_t: float = float(frames[0]["t"])
	var target: float = base_t + playback_time
	var index: int = _frame_index(target)
	var snap: Dictionary = frames[index]
	var next: Dictionary = frames[mini(index + 1, frames.size() - 1)]
	var span: float = float(next["t"]) - float(snap["t"])
	var factor: float = 0.0 if span <= 0.0 else clamp((target - float(snap["t"])) / span, 0.0, 1.0)
	_update_camera(snap, next, factor)
	_update_player_ghost(snap, next, factor)
	_update_enemy_ghosts(snap)
	_update_projectile_ghosts(snap)
	_update_boss_ghost(snap)


func _frame_index(target_t: float) -> int:
	for i in range(frames.size() - 1):
		if float(frames[i + 1]["t"]) > target_t:
			return i
	return frames.size() - 2


func _update_camera(snap: Dictionary, next: Dictionary, factor: float) -> void:
	if third_person:
		var ppos: Vector3 = lerp(snap["ppos"], next["ppos"], factor)
		var pfwd: Vector3 = (snap["pfwd"] as Vector3).slerp(next["pfwd"], factor).normalized()
		var pup: Vector3 = (snap["pup"] as Vector3).slerp(next["pup"], factor).normalized()
		var eye: Vector3 = ppos - pfwd * 9.0 + pup * 4.0
		camera.global_position = eye
		camera.look_at(ppos + pup * 1.5, pup)
	else:
		var campos: Vector3 = lerp(snap["campos"], next["campos"], factor)
		var camquat: Quaternion = (snap["camquat"] as Quaternion).slerp(next["camquat"], factor)
		camera.global_transform = Transform3D(Basis(camquat), campos)


func _update_player_ghost(snap: Dictionary, next: Dictionary, factor: float) -> void:
	if not player_ghost:
		return
	player_ghost.visible = third_person
	if not third_person:
		return
	var ppos: Vector3 = lerp(snap["ppos"], next["ppos"], factor)
	var pfwd: Vector3 = (snap["pfwd"] as Vector3).slerp(next["pfwd"], factor).normalized()
	var pup: Vector3 = (snap["pup"] as Vector3).slerp(next["pup"], factor).normalized()
	player_ghost.global_position = ppos
	if pfwd.length_squared() > 0.001:
		player_ghost.look_at(ppos + pfwd, pup)


func _update_enemy_ghosts(snap: Dictionary) -> void:
	var positions: PackedVector3Array = snap["enemies"]
	var types: PackedByteArray = snap["etypes"]
	for i in range(positions.size()):
		var ghost: MeshInstance3D = _enemy_ghost(i)
		var type_code: int = types[i]
		ghost.visible = true
		ghost.global_position = positions[i]
		ghost.material_override = enemy_materials[type_code]
		ghost.scale = Vector3.ONE * enemy_scales[type_code]
	for i in range(positions.size(), enemy_ghosts.size()):
		enemy_ghosts[i].visible = false


func _update_projectile_ghosts(snap: Dictionary) -> void:
	var positions: PackedVector3Array = snap["projectiles"]
	for i in range(positions.size()):
		var ghost: MeshInstance3D = _projectile_ghost(i)
		# In first person, skip bullets right at the lens so they don't fill the view.
		if not third_person and positions[i].distance_to(camera.global_position) < 3.0:
			ghost.visible = false
			continue
		ghost.visible = true
		ghost.global_position = positions[i]
	for i in range(positions.size(), projectile_ghosts.size()):
		projectile_ghosts[i].visible = false


func _update_boss_ghost(snap: Dictionary) -> void:
	var data: Variant = snap["boss"]
	if data == null:
		boss_root.visible = false
		return
	boss_root.visible = true
	var boss_data: Dictionary = data
	boss_head_ghost.global_position = boss_data["head"]
	var dir: Vector3 = boss_data["dir"]
	if dir.length_squared() > 0.001:
		boss_head_ghost.look_at(boss_data["head"] + dir, Vector3.UP)
	var weak: Array = boss_data["weak"]
	for i in range(boss_weak_ghosts.size()):
		var ghost: MeshInstance3D = boss_weak_ghosts[i]
		if i < weak.size():
			ghost.visible = true
			ghost.global_position = weak[i]["pos"]
			ghost.material_override.albedo_color = Color(1.0, 0.15, 0.12) if weak[i]["alive"] else Color(0.25, 0.26, 0.3)
		else:
			ghost.visible = false
	if bool(boss_data["laser"]):
		boss_laser_ghost.visible = true
		var lstart: Vector3 = boss_data["lstart"]
		var laim: Vector3 = boss_data["laim"]
		var lrange: float = boss_data["lrange"]
		var y_axis: Vector3 = laim
		var x_axis: Vector3 = y_axis.cross(Vector3.UP)
		if x_axis.length_squared() <= 0.001:
			x_axis = y_axis.cross(Vector3.RIGHT)
		x_axis = x_axis.normalized()
		var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
		# Scale local axes directly (see dragon_boss._update_laser_visual): Basis.scaled()
		# premultiplies in WORLD axes and shears an off-vertical beam into a vertical streak.
		var beam_basis := Basis(x_axis * 0.7, y_axis * lrange, z_axis * 0.7)
		boss_laser_ghost.global_transform = Transform3D(beam_basis, lstart + laim * lrange * 0.5)
	else:
		boss_laser_ghost.visible = false


func _enemy_ghost(index: int) -> MeshInstance3D:
	while index >= enemy_ghosts.size():
		var ghost := MeshInstance3D.new()
		ghost.mesh = shared_sphere
		ghost.visible = false
		enemy_container.add_child(ghost)
		enemy_ghosts.append(ghost)
	return enemy_ghosts[index]


func _projectile_ghost(index: int) -> MeshInstance3D:
	while index >= projectile_ghosts.size():
		var ghost := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.16
		mesh.height = 0.32
		mesh.radial_segments = 6
		mesh.rings = 3
		ghost.mesh = mesh
		ghost.material_override = _emissive(Color(0.6, 0.95, 1.0), 1.8)
		ghost.visible = false
		projectile_container.add_child(ghost)
		projectile_ghosts.append(ghost)
	return projectile_ghosts[index]


func _hide_all_ghosts() -> void:
	for ghost in enemy_ghosts:
		ghost.visible = false
	for ghost in projectile_ghosts:
		ghost.visible = false
	if player_ghost:
		player_ghost.visible = false
	if boss_root:
		boss_root.visible = false


# --- Construction ----------------------------------------------------------

func _build() -> void:
	built = true
	camera = Camera3D.new()
	camera.fov = 86.0
	camera.current = false
	add_child(camera)

	enemy_container = Node3D.new()
	add_child(enemy_container)
	projectile_container = Node3D.new()
	add_child(projectile_container)

	shared_sphere = SphereMesh.new()
	shared_sphere.radius = 1.0
	shared_sphere.height = 2.0
	shared_sphere.radial_segments = 7
	shared_sphere.rings = 4
	enemy_materials = [
		_emissive(Color(0.86, 0.68, 0.48), 0.8),
		_emissive(Color(1.0, 0.55, 0.18), 0.9),
		_emissive(Color(0.72, 0.86, 0.32), 0.9),
		_emissive(Color(0.92, 0.44, 0.2), 1.0),
	]

	player_ghost = Node3D.new()
	add_child(player_ghost)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.6
	capsule.height = 1.9
	body.mesh = capsule
	body.material_override = _emissive(Color(0.4, 0.8, 1.0), 0.9)
	player_ghost.add_child(body)
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.35
	cone.height = 0.9
	cone.radial_segments = 6
	nose.mesh = cone
	nose.material_override = _emissive(Color(0.7, 0.95, 1.0), 1.4)
	nose.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	nose.position = Vector3(0.0, 0.3, -0.8)
	player_ghost.add_child(nose)
	player_ghost.visible = false

	boss_root = Node3D.new()
	add_child(boss_root)
	boss_head_ghost = MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = Vector3(2.4, 1.8, 2.8)
	boss_head_ghost.mesh = head_box
	boss_head_ghost.material_override = _emissive(Color(0.85, 0.62, 0.18), 0.7)
	boss_root.add_child(boss_head_ghost)
	for i in range(3):
		var weak := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 2.0
		sphere.height = 4.0
		sphere.radial_segments = 8
		sphere.rings = 4
		weak.mesh = sphere
		weak.material_override = _emissive(Color(1.0, 0.15, 0.12), 3.0)
		boss_root.add_child(weak)
		boss_weak_ghosts.append(weak)
	boss_laser_ghost = MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 1.0
	beam.bottom_radius = 1.0
	beam.height = 1.0
	beam.radial_segments = 8
	boss_laser_ghost.mesh = beam
	var laser_mat := _emissive(Color(1.0, 0.18, 0.12), 3.0)
	laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_mat.albedo_color = Color(1.0, 0.14, 0.1, 0.9)
	laser_mat.no_depth_test = true
	boss_laser_ghost.material_override = laser_mat
	boss_root.add_child(boss_laser_ghost)
	boss_root.visible = false


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

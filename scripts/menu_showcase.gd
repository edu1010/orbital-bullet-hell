class_name MenuShowcase
extends Node3D

# Attract-mode background for the main menu. While the game is in the MENU state a
# dedicated camera slowly orbits the arena (and the grid sphere spins) while a swarm
# of enemy-like particles swirls in the centre, gathers and morphs into one of the
# bosses (dragon -> cube -> butterfly), idles for a few seconds, then disperses back
# into a swarm and forms the next boss, looping forever.
#
# It is completely decoupled from gameplay: it owns its own Camera3D and meshes, runs
# only in MENU, and never touches the live enemies, bosses or the is_playing() gate,
# so it cannot affect a real run. When a run starts it hands the viewport back to the
# player camera.

enum Phase { SWIRL, FORM, HOLD, DISPERSE }

const BOSS_TYPES := ["dragon", "cube", "butterfly"]
const NEUTRAL_COLOR := Color(0.85, 0.3, 0.35)

@export var particle_count := 100
@export var swirl_radius := 9.0
@export var view_distance := 30.0
@export var camera_height := 7.0
@export var camera_fov := 60.0
@export var camera_orbit_speed := 0.16
@export var arena_spin_speed := 0.05

@export var cube_half := 6.0
@export var cube_grid_n := 5
@export var cube_spin := 0.5

@export var wing_span := 11.0
@export var wing_height := 8.0
@export var wing_steps := 11
@export var flap_speed := 4.0
@export var flap_reach := 0.6

@export var dragon_len := 22.0
@export var dragon_amp := 3.2
@export var dragon_freq := 2.2
@export var dragon_segments := 100
@export var dragon_scroll := 2.4
@export var dragon_spin := 0.35

@export var swirl_time := 2.6
@export var form_time := 2.2
@export var hold_time := 5.0
@export var disperse_time := 1.8

var manager: GameManager
var player: PlayerController
var arena: Node3D

var active := false
var camera: Camera3D
var formation_center := Vector3.ZERO
var orbit_angle := 0.0
var anim_time := 0.0

var particles: Array = []
var particle_material: StandardMaterial3D

var phase: int = Phase.SWIRL
var phase_elapsed := 0.0
var boss_index := 0

var cube_cache: Array = []

# Current boss feature meshes (rebuilt each time a boss forms).
var feature_root: Node3D
var anim_core: MeshInstance3D
var anim_rings: Node3D
var anim_gems: Array = []
var anim_head: Node3D


func _ready() -> void:
	_build_camera()
	_build_particles()
	set_process(true)


func configure(_manager: GameManager, _player: PlayerController, _arena: Node3D) -> void:
	manager = _manager
	player = _player
	arena = _arena
	if manager and not manager.run_state_changed.is_connected(_on_run_state_changed):
		manager.run_state_changed.connect(_on_run_state_changed)


func _on_run_state_changed(state: int) -> void:
	var want_active: bool = state == GameManager.RunState.MENU
	if want_active == active:
		return
	if want_active:
		_enter()
	else:
		_exit()


func _enter() -> void:
	active = true
	visible = true
	_reset_cycle()
	if camera:
		camera.current = true


func _exit() -> void:
	active = false
	# Hide every particle / boss mesh so nothing from the menu lingers in the arena
	# once a run starts; the camera is also handed back to the player.
	visible = false
	_clear_features()
	if camera:
		camera.current = false
	if player:
		player.make_camera_current()
	if arena:
		arena.rotation = Vector3.ZERO


func _reset_cycle() -> void:
	boss_index = 0
	phase = Phase.SWIRL
	phase_elapsed = 0.0
	_clear_features()
	_update_particle_color()


func _process(delta: float) -> void:
	if not active:
		return
	anim_time += delta
	_update_camera(delta)
	if arena:
		arena.rotate_y(arena_spin_speed * delta)
	_advance_phase(delta)
	_update_particle_color()
	_update_particles(delta)
	_update_features()


# --- Camera ----------------------------------------------------------------

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = camera_fov
	camera.near = 0.05
	camera.far = 500.0
	add_child(camera)


func _update_camera(delta: float) -> void:
	orbit_angle += camera_orbit_speed * delta
	var orbit := Vector3(cos(orbit_angle), 0.0, sin(orbit_angle)) * view_distance
	camera.global_position = formation_center + orbit + Vector3.UP * camera_height
	camera.look_at(formation_center, Vector3.UP)


# --- Phase machine ---------------------------------------------------------

func _advance_phase(delta: float) -> void:
	phase_elapsed += delta
	match phase:
		Phase.SWIRL:
			if phase_elapsed >= swirl_time:
				_set_phase(Phase.FORM)
				_build_features_for_current()
		Phase.FORM:
			if phase_elapsed >= form_time:
				_set_phase(Phase.HOLD)
		Phase.HOLD:
			if phase_elapsed >= hold_time:
				_set_phase(Phase.DISPERSE)
		Phase.DISPERSE:
			if phase_elapsed >= disperse_time:
				boss_index = (boss_index + 1) % BOSS_TYPES.size()
				_clear_features()
				_set_phase(Phase.SWIRL)


func _set_phase(new_phase: int) -> void:
	phase = new_phase
	phase_elapsed = 0.0


func _reveal() -> float:
	match phase:
		Phase.FORM:
			return _smoothstep(clamp(phase_elapsed / max(0.01, form_time), 0.0, 1.0))
		Phase.HOLD:
			return 1.0
		Phase.DISPERSE:
			return 1.0 - _smoothstep(clamp(phase_elapsed / max(0.01, disperse_time), 0.0, 1.0))
		_:
			return 0.0


# --- Particles -------------------------------------------------------------

func _build_particles() -> void:
	particle_material = _unshaded(NEUTRAL_COLOR, NEUTRAL_COLOR, 2.4, false)
	var mesh := _sphere_mesh(0.32, 4, 2)
	for i in range(particle_count):
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = particle_material
		add_child(node)
		var dir: Vector3 = _fib_dir(i)
		var seed: float = randf_range(0.0, TAU)
		var start: Vector3 = formation_center + dir * swirl_radius
		node.global_position = start
		particles.append({
			"node": node,
			"pos": start,
			"dir": dir,
			"seed": seed,
			"spin": randf_range(-2.2, 2.2),
		})


func _update_particles(delta: float) -> void:
	var blend: float = clamp(_phase_lerp_rate() * delta, 0.0, 1.0)
	var in_boss: bool = phase == Phase.FORM or phase == Phase.HOLD
	var locals: Array = []
	var orient := Basis()
	if in_boss:
		locals = _boss_local_targets()
		orient = _boss_orient_basis()
	for i in range(particles.size()):
		var p: Dictionary = particles[i]
		var target: Vector3
		if in_boss and i < locals.size():
			target = formation_center + orient * (locals[i] as Vector3)
		elif in_boss:
			target = formation_center + _ambient_target(p)
		else:
			target = formation_center + _swirl_target(p)
		var pos: Vector3 = (p["pos"] as Vector3).lerp(target, blend)
		p["pos"] = pos
		var node: Node3D = p["node"]
		node.global_position = pos
		node.rotate_y((p["spin"] as float) * delta)


func _phase_lerp_rate() -> float:
	match phase:
		Phase.FORM:
			return 3.2
		Phase.HOLD:
			return 4.0
		Phase.DISPERSE:
			return 2.6
		_:
			return 1.6


func _swirl_target(p: Dictionary) -> Vector3:
	var dir: Vector3 = p["dir"]
	var seed: float = p["seed"]
	var r: float = swirl_radius + sin(anim_time * 0.8 + seed) * 1.8
	return (Basis(Vector3.UP, anim_time * 0.5) * dir) * r


func _ambient_target(p: Dictionary) -> Vector3:
	var seed: float = p["seed"]
	var angle: float = anim_time * 0.4 + seed
	var r: float = swirl_radius + 5.0
	return Vector3(cos(angle) * r, sin(seed) * 3.0, sin(angle) * r)


func _update_particle_color() -> void:
	if not particle_material:
		return
	var boss_color: Color = _boss_color()
	var c: Color
	match phase:
		Phase.FORM:
			c = NEUTRAL_COLOR.lerp(boss_color, _smoothstep(clamp(phase_elapsed / max(0.01, form_time), 0.0, 1.0)))
		Phase.HOLD:
			c = boss_color
		Phase.DISPERSE:
			c = boss_color.lerp(NEUTRAL_COLOR, _smoothstep(clamp(phase_elapsed / max(0.01, disperse_time), 0.0, 1.0)))
		_:
			c = NEUTRAL_COLOR
	particle_material.albedo_color = c
	particle_material.emission = c


func _boss_color() -> Color:
	match BOSS_TYPES[boss_index]:
		"dragon":
			return Color(1.0, 0.7, 0.2)
		"cube":
			return Color(1.0, 0.35, 0.25)
		_:
			return Color(1.0, 0.4, 0.65)


# --- Boss shapes (local space, full size) ----------------------------------

func _boss_local_targets() -> Array:
	match BOSS_TYPES[boss_index]:
		"cube":
			return _cube_locals()
		"butterfly":
			return _butterfly_locals()
		_:
			return _dragon_locals()


func _boss_orient_basis() -> Basis:
	match BOSS_TYPES[boss_index]:
		"butterfly":
			var facing: Vector3 = camera.global_position - formation_center
			if facing.length_squared() <= 0.001:
				facing = Vector3.BACK
			facing = facing.normalized()
			var up: Vector3 = Vector3.UP - facing * Vector3.UP.dot(facing)
			if up.length_squared() <= 0.001:
				up = facing.cross(Vector3.RIGHT)
			up = up.normalized()
			var right: Vector3 = up.cross(facing).normalized()
			return Basis(right, up, facing)
		"dragon":
			return Basis(Vector3.UP, anim_time * dragon_spin) * Basis(Vector3.RIGHT, 0.22)
		_:
			return Basis(Vector3.UP, anim_time * cube_spin) * Basis(Vector3.RIGHT, 0.4)


func _cube_locals() -> Array:
	if not cube_cache.is_empty():
		return cube_cache
	var n: int = max(2, cube_grid_n)
	for i in range(n):
		for j in range(n):
			for k in range(n):
				var on_surface: bool = i == 0 or i == n - 1 or j == 0 or j == n - 1 or k == 0 or k == n - 1
				if not on_surface:
					continue
				cube_cache.append(Vector3(
					lerp(-cube_half, cube_half, float(i) / float(n - 1)),
					lerp(-cube_half, cube_half, float(j) / float(n - 1)),
					lerp(-cube_half, cube_half, float(k) / float(n - 1))
				))
	return cube_cache


func _butterfly_locals() -> Array:
	var pts: Array = []
	var flap: float = sin(anim_time * flap_speed)
	var body_points := 6
	for i in range(body_points):
		var y: float = lerp(-wing_height * 0.55, wing_height * 0.6, float(i) / float(body_points - 1))
		pts.append(Vector3(0.0, y, 0.0))
	for side in [-1.0, 1.0]:
		for ix in range(1, wing_steps + 1):
			for iy in range(wing_steps):
				var wx: float = side * wing_span * float(ix) / float(wing_steps)
				var wy: float = lerp(-wing_height, wing_height, float(iy) / float(wing_steps - 1))
				if _inside_wing(abs(wx), wy):
					pts.append(Vector3(wx, wy, flap * flap_reach * abs(wx)))
	return pts


func _inside_wing(ax: float, wy: float) -> bool:
	var upper: bool = _inside_lobe(ax, wy, wing_span * 0.5, wing_height * 0.42, wing_span * 0.55, wing_height * 0.5)
	var lower: bool = _inside_lobe(ax, wy, wing_span * 0.42, -wing_height * 0.42, wing_span * 0.46, wing_height * 0.42)
	return upper or lower


func _inside_lobe(ax: float, wy: float, cx: float, cy: float, rx: float, ry: float) -> bool:
	var dx: float = (ax - cx) / rx
	var dy: float = (wy - cy) / ry
	return dx * dx + dy * dy <= 1.0


func _dragon_locals() -> Array:
	var pts: Array = []
	var scroll: float = anim_time * dragon_scroll
	var n: int = max(2, dragon_segments)
	for i in range(n):
		var u: float = float(i) / float(n - 1)
		pts.append(_dragon_point(u, scroll))
	return pts


func _dragon_point(u: float, scroll: float) -> Vector3:
	var x: float = lerp(dragon_len * 0.5, -dragon_len * 0.5, u)
	var y: float = sin(u * dragon_freq * TAU + scroll) * dragon_amp
	var z: float = cos(u * dragon_freq * TAU * 0.5 + scroll * 0.6) * dragon_amp * 0.5
	return Vector3(x, y, z)


# --- Boss feature meshes ----------------------------------------------------

func _build_features_for_current() -> void:
	_clear_features()
	feature_root = Node3D.new()
	add_child(feature_root)
	match BOSS_TYPES[boss_index]:
		"cube":
			_build_cube_features()
		"butterfly":
			_build_butterfly_features()
		_:
			_build_dragon_features()


func _clear_features() -> void:
	if feature_root and is_instance_valid(feature_root):
		feature_root.queue_free()
	feature_root = null
	anim_core = null
	anim_rings = null
	anim_gems = []
	anim_head = null


func _update_features() -> void:
	if not feature_root or not is_instance_valid(feature_root):
		return
	var reveal: float = _reveal()
	feature_root.visible = reveal > 0.02
	feature_root.transform = Transform3D(_boss_orient_basis().scaled(Vector3.ONE * reveal), formation_center)
	match BOSS_TYPES[boss_index]:
		"cube":
			_update_cube_features()
		"butterfly":
			_update_butterfly_features()
		_:
			_update_dragon_features()


func _build_cube_features() -> void:
	var edge_mat := _unshaded(Color(0.95, 0.28, 0.22, 0.95), Color(1.0, 0.22, 0.16), 2.6, false)
	var thickness := 0.32
	for axis in range(3):
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				var size := Vector3(thickness, thickness, thickness)
				var pos := Vector3.ZERO
				match axis:
					0:
						size.x = cube_half * 2.0
						pos = Vector3(0.0, sa * cube_half, sb * cube_half)
					1:
						size.y = cube_half * 2.0
						pos = Vector3(sa * cube_half, 0.0, sb * cube_half)
					_:
						size.z = cube_half * 2.0
						pos = Vector3(sa * cube_half, sb * cube_half, 0.0)
				_part(feature_root, _box_mesh(size), edge_mat, pos)
	var core_mat := _unshaded(Color(1.0, 0.14, 0.12), Color(1.0, 0.2, 0.12), 3.6, false)
	anim_core = _part(feature_root, _sphere_mesh(2.2, 12, 7), core_mat, Vector3.ZERO)
	anim_rings = Node3D.new()
	feature_root.add_child(anim_rings)
	var ring_mat := _unshaded(Color(1.0, 0.5, 0.3, 0.85), Color(1.0, 0.4, 0.2), 3.0, true)
	_add_ring(anim_rings, 3.4, 0.16, ring_mat, Vector3.ZERO)
	_add_ring(anim_rings, 4.0, 0.12, ring_mat, Vector3(PI * 0.5, 0.0, 0.0))


func _update_cube_features() -> void:
	if anim_rings:
		anim_rings.rotation = Vector3(anim_time * 1.1, anim_time * 1.8, 0.0)
	if anim_core:
		anim_core.scale = Vector3.ONE * (1.0 + sin(anim_time * 5.0) * 0.12)


func _build_butterfly_features() -> void:
	var body_mat := _shaded(Color(0.5, 0.18, 0.3), Color(0.6, 0.2, 0.35), 1.4)
	_part(feature_root, _cylinder_mesh(0.45, wing_height * 1.2, 6), body_mat, Vector3.ZERO)
	var gem_specs := [
		Vector2(wing_span * 0.55, wing_height * 0.45),
		Vector2(wing_span * 0.5, -wing_height * 0.4),
		Vector2(-wing_span * 0.55, wing_height * 0.45),
		Vector2(-wing_span * 0.5, -wing_height * 0.4),
	]
	anim_gems = []
	for spec in gem_specs:
		var gem_mat := _unshaded(Color(1.0, 0.14, 0.18), Color(1.0, 0.2, 0.16), 3.6, false)
		var gem := _part(feature_root, _sphere_mesh(1.4, 10, 6), gem_mat, Vector3.ZERO)
		anim_gems.append({"node": gem, "base": spec})


func _update_butterfly_features() -> void:
	var flap: float = sin(anim_time * flap_speed)
	var pulse: float = 1.0 + sin(anim_time * 6.0) * 0.14
	for g in anim_gems:
		var base: Vector2 = g["base"]
		var node: Node3D = g["node"]
		node.position = Vector3(base.x, base.y, flap * flap_reach * abs(base.x))
		node.scale = Vector3.ONE * pulse


func _build_dragon_features() -> void:
	var gold := _shaded(Color(0.85, 0.62, 0.18), Color(0.5, 0.32, 0.06), 0.8)
	var red := _shaded(Color(0.7, 0.14, 0.12), Color(0.45, 0.06, 0.05), 0.8)
	var mane := _shaded(Color(0.95, 0.85, 0.3), Color(0.8, 0.6, 0.15), 1.4)
	var eye := _unshaded(Color(1.0, 0.9, 0.2), Color(1.0, 0.85, 0.1), 2.6, false)
	var crown := _unshaded(Color(1.0, 0.14, 0.12), Color(1.0, 0.2, 0.12), 3.4, false)
	anim_head = Node3D.new()
	feature_root.add_child(anim_head)
	# Skull faces local -Z; _update_dragon_features yaws it toward +X (the head end of
	# the serpentine), so it points away from the body that trails off toward -X.
	_part(anim_head, _box_mesh(Vector3(2.4, 1.7, 2.6)), gold, Vector3(0.0, 0.4, -0.6))
	_part(anim_head, _box_mesh(Vector3(1.9, 0.7, 1.6)), red, Vector3(0.0, 0.2, -2.0))
	for side in [-1.0, 1.0]:
		_part(anim_head, _cone_mesh(0.4, 2.0, 4), mane, Vector3(side * 0.9, 1.5, 0.4), Vector3(-22.0, 0.0, side * 12.0))
		_part(anim_head, _sphere_mesh(0.35, 8, 4), eye, Vector3(side * 0.85, 0.6, -1.4))
	_part(anim_head, _sphere_mesh(0.9, 10, 6), crown, Vector3(0.0, 2.0, -0.3))


func _update_dragon_features() -> void:
	if not anim_head:
		return
	var scroll: float = anim_time * dragon_scroll
	anim_head.position = _dragon_point(0.0, scroll) + Vector3(2.0, 0.0, 0.0)
	anim_head.rotation = Vector3(sin(anim_time * 1.3) * 0.1, -PI * 0.5 + sin(anim_time * 0.9) * 0.12, 0.0)


# --- Helpers ---------------------------------------------------------------

func _fib_dir(i: int) -> Vector3:
	var n: float = float(max(1, particle_count))
	var k: float = float(i) + 0.5
	var phi: float = acos(clamp(1.0 - 2.0 * k / n, -1.0, 1.0))
	var theta: float = PI * (1.0 + sqrt(5.0)) * k
	return Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))


func _smoothstep(x: float) -> float:
	var t: float = clamp(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _unshaded(albedo: Color, emission: Color, energy: float, transparent: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	return m


func _shaded(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = 0.6
	m.metallic = 0.35
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, local_position: Vector3, local_rotation_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = local_position
	part.rotation_degrees = local_rotation_degrees
	parent.add_child(part)
	return part


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _sphere_mesh(radius: float, segments: int = 8, rings: int = 4) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


func _cone_mesh(radius: float, height: float, sides: int = 4) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return mesh


func _cylinder_mesh(radius: float, height: float, sides: int = 6) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return mesh


func _add_ring(parent: Node3D, radius: float, half_width: float, material: Material, local_rotation: Vector3) -> void:
	var mesh := ImmediateMesh.new()
	var segments := 48
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var inner: float = radius - half_width
		var outer: float = radius + half_width
		var inner0 := Vector3(cos(a0) * inner, sin(a0) * inner, 0.0)
		var outer0 := Vector3(cos(a0) * outer, sin(a0) * outer, 0.0)
		var inner1 := Vector3(cos(a1) * inner, sin(a1) * inner, 0.0)
		var outer1 := Vector3(cos(a1) * outer, sin(a1) * outer, 0.0)
		mesh.surface_add_vertex(inner0)
		mesh.surface_add_vertex(outer0)
		mesh.surface_add_vertex(outer1)
		mesh.surface_add_vertex(inner0)
		mesh.surface_add_vertex(outer1)
		mesh.surface_add_vertex(inner1)
	mesh.surface_end()
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = material
	ring.rotation = local_rotation
	parent.add_child(ring)

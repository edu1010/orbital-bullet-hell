extends Node3D

@export var arena_radius := 38.0
@export var sphere_segments := 96
@export var sphere_rings := 48
@export var grid_latitude_lines := 15
@export var grid_longitude_lines := 32
@export var grid_line_segments := 96
@export var grid_surface_offset := 0.18
@export_range(0.0, 0.35, 0.01) var grid_pole_gap_radians := 0.08

@onready var arena: Node3D = $Arena
@onready var game_manager: GameManager = $GameManager
@onready var spawn_manager: SpawnManager = $SpawnManager
@onready var tutorial: TutorialController = $Tutorial
@onready var player: PlayerController = $Player
@onready var ui: GameUI = $UI
@onready var enemies_container: Node3D = $Pools/Enemies
@onready var projectiles_container: Node3D = $Pools/Projectiles
@onready var shards_container: Node3D = $Pools/Shards
@onready var effects_container: Node3D = $Pools/Effects
@onready var reflectors_container: Node3D = $Pools/Reflectors


func _ready() -> void:
	randomize()
	# The arena is generated at runtime so the scene stays small and easy to modify.
	_build_arena()
	player.set_spherical_world(Vector3.ZERO, arena_radius)
	game_manager.configure(
		player,
		spawn_manager,
		ui,
		enemies_container,
		projectiles_container,
		shards_container,
		effects_container,
		reflectors_container
	)
	spawn_manager.configure(game_manager, player)
	tutorial.configure(game_manager, player, ui)
	game_manager.tutorial = tutorial
	player.configure(game_manager)
	ui.configure(game_manager)
	game_manager.show_main_menu()


func _build_arena() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.018, 0.026)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.62)
	env.ambient_light_energy = 0.55
	environment.environment = env
	arena.add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	light.light_energy = 1.4
	light.light_color = Color(0.72, 0.85, 1.0)
	arena.add_child(light)

	_build_sphere_shell()
	_build_sphere_grid()


func _build_sphere_shell() -> void:
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = arena_radius
	sphere.height = arena_radius * 2.0
	sphere.radial_segments = sphere_segments
	sphere.rings = sphere_rings
	shell.mesh = sphere
	var shell_material := StandardMaterial3D.new()
	shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_material.cull_mode = BaseMaterial3D.CULL_FRONT
	shell_material.albedo_color = Color(0.025, 0.028, 0.045, 0.82)
	shell_material.emission_enabled = true
	shell_material.emission = Color(0.02, 0.04, 0.08)
	shell_material.emission_energy_multiplier = 0.45
	shell.material_override = shell_material
	arena.add_child(shell)


func _build_sphere_grid() -> void:
	var grid := MeshInstance3D.new()
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	var grid_radius: float = arena_radius - grid_surface_offset
	var pole_limit: float = PI * 0.5 - grid_pole_gap_radians
	for lat_index in range(1, grid_latitude_lines):
		var latitude: float = lerp(-PI * 0.5, PI * 0.5, float(lat_index) / float(grid_latitude_lines))
		for segment in range(grid_line_segments):
			var a0: float = TAU * float(segment) / float(grid_line_segments)
			var a1: float = TAU * float(segment + 1) / float(grid_line_segments)
			immediate.surface_add_vertex(_sphere_point(grid_radius, latitude, a0))
			immediate.surface_add_vertex(_sphere_point(grid_radius, latitude, a1))
	for lon_index in range(grid_longitude_lines):
		var longitude: float = TAU * float(lon_index) / float(grid_longitude_lines)
		for segment in range(grid_line_segments):
			var t0: float = lerp(-pole_limit, pole_limit, float(segment) / float(grid_line_segments))
			var t1: float = lerp(-pole_limit, pole_limit, float(segment + 1) / float(grid_line_segments))
			immediate.surface_add_vertex(_sphere_point(grid_radius, t0, longitude))
			immediate.surface_add_vertex(_sphere_point(grid_radius, t1, longitude))
	immediate.surface_end()
	grid.mesh = immediate
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.albedo_color = Color(0.18, 0.7, 0.95, 0.28)
	grid_material.emission_enabled = true
	grid_material.emission = Color(0.1, 0.55, 0.9)
	grid_material.emission_energy_multiplier = 0.45
	grid.material_override = grid_material
	arena.add_child(grid)


func _sphere_point(radius: float, latitude: float, longitude: float) -> Vector3:
	var ring_radius: float = cos(latitude) * radius
	return Vector3(
		ring_radius * cos(longitude),
		sin(latitude) * radius,
		ring_radius * sin(longitude)
	)

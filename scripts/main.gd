extends Node3D

@export var arena_size := 2000.0
@export var grid_spacing := 12.0
@export var grid_line_count := 140

@onready var arena: Node3D = $Arena
@onready var game_manager: GameManager = $GameManager
@onready var spawn_manager: SpawnManager = $SpawnManager
@onready var player: PlayerController = $Player
@onready var ui: GameUI = $UI
@onready var enemies_container: Node3D = $Pools/Enemies
@onready var projectiles_container: Node3D = $Pools/Projectiles
@onready var shards_container: Node3D = $Pools/Shards
@onready var effects_container: Node3D = $Pools/Effects


func _ready() -> void:
	randomize()
	# The arena is generated at runtime so the scene stays small and easy to modify.
	_build_arena()
	game_manager.configure(
		player,
		spawn_manager,
		ui,
		enemies_container,
		projectiles_container,
		shards_container,
		effects_container
	)
	spawn_manager.configure(game_manager, player)
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

	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(arena_size, arena_size)
	ground_mesh.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.025, 0.028, 0.04)
	ground_material.roughness = 0.8
	ground_mesh.material_override = ground_material
	arena.add_child(ground_mesh)

	var ground_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(arena_size, 0.2, arena_size)
	collision.shape = box
	collision.position.y = -0.12
	ground_body.add_child(collision)
	arena.add_child(ground_body)

	var grid := MeshInstance3D.new()
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	var half := grid_line_count * grid_spacing * 0.5
	var half_lines := int(grid_line_count / 2)
	for i in range(-half_lines, half_lines + 1):
		var p := float(i) * grid_spacing
		immediate.surface_add_vertex(Vector3(p, 0.035, -half))
		immediate.surface_add_vertex(Vector3(p, 0.035, half))
		immediate.surface_add_vertex(Vector3(-half, 0.035, p))
		immediate.surface_add_vertex(Vector3(half, 0.035, p))
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

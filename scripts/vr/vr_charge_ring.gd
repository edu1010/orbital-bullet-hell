extends Node3D
## HUD radial en WORLD-SPACE en la punta del arma: muestra HP y las cargas
## (disparo extra / escudo / impulso) igual que el HUD curvo de PC, pero como un
## disco 3D que mira siempre a la cámara. Reutiliza el mismo RadialHud del juego
## metido en un SubViewport pequeño.

const RADIAL_HUD := preload("res://scripts/ui/radial_hud.gd")

@export var size_meters := 0.16    # diámetro del disco
@export var resolution := 180      # px del SubViewport

var manager = null
var viewport: SubViewport
var hud   # RadialHud (sin tipo para evitar el cache de class_name en --check-only)
var quad: MeshInstance3D


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(resolution, resolution)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	hud = RADIAL_HUD.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.size = Vector2(resolution, resolution)
	viewport.add_child(hud)

	quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(size_meters, size_meters)
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport.get_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED  # mira siempre a la cámara
	mat.billboard_keep_scale = true
	quad.material_override = mat
	add_child(quad)

	if manager and manager.player and hud.has_method("configure"):
		hud.configure(manager.player)


func _process(_delta: float) -> void:
	if manager == null or manager.player == null or hud == null:
		return
	var playing: bool = manager.has_method("is_playing") and manager.is_playing()
	visible = playing
	if not playing:
		return
	var p = manager.player
	hud.set_state({
		"hp": p.hp,
		"max_hp": p.max_hp,
		"charge": p.extra_charge,
		"charge_max": p.extra_shot_charge_max,
		"shield": p.orbital_shield_charge,
		"shield_max": p.orbital_shield_charge_max,
		"shield_active": p.orbital_shield_timer > 0.0,
		"boost": p.boost_charge,
		"boost_max": p.boost_charge_max,
		"boost_active": p.boost_timer > 0.0,
		"invulnerable": p.is_invulnerable() if p.has_method("is_invulnerable") else false,
		"warn_active": false,  # las cuñas direccionales usan la cámara plana; las omitimos en VR
	})

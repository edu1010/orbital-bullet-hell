class_name GameUI
extends CanvasLayer

var manager: GameManager
var root: Control
var hud: VBoxContainer
var score_label: Label
var high_score_label: Label
var combo_label: Label
var time_label: Label
var enemy_label: Label
var overlay: ColorRect
var overlay_label: Label
var menu_root: Control
var menu_title: Label
var main_menu_panel: Control
var pause_panel: Control
var leaderboard_panel: Control
var leaderboard_rows: VBoxContainer
var settings_panel: Control
var settings_rows: VBoxContainer
var reticle_dot: ColorRect
var radial_hud: RadialHud
var tutorial_button_icon: Control
var tutorial_button_label: Label
var tutorial_panel: Control
var tutorial_step_label: Label
var tutorial_title_label: Label
var tutorial_objective_label: Label
var tutorial_status_label: Label
var start_hint_panel: Control
var start_hint_stack: VBoxContainer
var low_health_rect: ColorRect
var flash_rect: ColorRect
var damage_vignette: ColorRect
var vignette_material: ShaderMaterial
var ready_label: Label
var boss_bar_root: Control
var boss_bar_fill: ColorRect
var boss_bar_label: Label
var gameover_buttons: HBoxContainer
var gameover_replay_button: Button
var replay_panel: Control
var replay_progress_holder: Control
var replay_progress_fill: ColorRect
var replay_pause_button: Button
var replay_camera_button: Button
var replay_speed_buttons: Array = []
var audio_player: AudioStreamPlayer
var flash_timer := 0.0
var vignette_timer := 0.0
var vignette_duration := 1.5
var ready_timer := 0.0
var start_hint_requested := false
var start_hint_playing := false
var start_hint_timer := 0.0
var start_hint_enabled := true
var reticle_enabled := true
var low_health_filter_enabled := true
var damage_flash_enabled := true
var current_ui_state := -1
var active_menu_screen := "main"
var settings_tab := "video"
var setting_value_labels: Dictionary = {}
var key_value_labels: Dictionary = {}
var key_bindings: Dictionary = {
	"forward": KEY_W,
	"backward": KEY_S,
	"left": KEY_A,
	"right": KEY_D,
	"jump": KEY_SPACE,
	"boost": KEY_SHIFT,
	"menu": KEY_ESCAPE,
}
var rebinding_action := ""
var resolution_options: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
var fps_options: Array[int] = [0, 60, 100, 144]
var setting_resolution_index := 0
var setting_fps_index := 2
var setting_fullscreen := false
var setting_fov := 86.0
var setting_sensitivity := 0.0022
var setting_effects_volume := 1.0
var flash_color: Color = Color(1.0, 0.08, 0.06, 0.0)
var language := "en"
var languages: Array[String] = ["en", "es"]
var localized_controls: Array = []

const STRINGS := {
	"play": {"en": "PLAY", "es": "JUGAR"},
	"tutorial": {"en": "TUTORIAL", "es": "TUTORIAL"},
	"ranking": {"en": "RANKING", "es": "CLASIFICACIÓN"},
	"settings": {"en": "SETTINGS", "es": "AJUSTES"},
	"quit": {"en": "QUIT", "es": "SALIR"},
	"resume": {"en": "RESUME", "es": "REANUDAR"},
	"main_menu": {"en": "MAIN MENU", "es": "MENÚ PRINCIPAL"},
	"paused": {"en": "PAUSED", "es": "PAUSA"},
	"back": {"en": "BACK", "es": "ATRÁS"},
	"reset": {"en": "RESET", "es": "REINICIAR"},
	"refresh": {"en": "REFRESH", "es": "ACTUALIZAR"},
	"local_board": {"en": "LOCAL BOARD", "es": "TABLA LOCAL"},
	"col_rank": {"en": "RANK", "es": "PUESTO"},
	"col_pilot": {"en": "PILOT", "es": "PILOTO"},
	"col_score": {"en": "SCORE", "es": "PUNTOS"},
	"tab_video": {"en": "VIDEO", "es": "VÍDEO"},
	"tab_hud": {"en": "HUD", "es": "HUD"},
	"tab_keys": {"en": "KEYS", "es": "TECLAS"},
	"tab_pad": {"en": "PAD", "es": "MANDO"},
	"set_resolution": {"en": "RESOLUTION", "es": "RESOLUCIÓN"},
	"set_fullscreen": {"en": "FULLSCREEN", "es": "PANTALLA COMPLETA"},
	"set_fps": {"en": "FPS LIMIT", "es": "LÍMITE FPS"},
	"set_fov": {"en": "FIELD OF VIEW", "es": "CAMPO DE VISIÓN"},
	"set_sensitivity": {"en": "SENSITIVITY", "es": "SENSIBILIDAD"},
	"set_volume": {"en": "EFFECTS VOLUME", "es": "VOLUMEN EFECTOS"},
	"set_reticle": {"en": "RETICLE", "es": "RETÍCULA"},
	"set_start_hint": {"en": "START HINT", "es": "AYUDA INICIAL"},
	"set_low_health": {"en": "LOW HEALTH FILTER", "es": "FILTRO VIDA BAJA"},
	"set_flashes": {"en": "FLASHES", "es": "DESTELLOS"},
	"set_language": {"en": "LANGUAGE", "es": "IDIOMA"},
	"key_forward": {"en": "FORWARD", "es": "ADELANTE"},
	"key_backward": {"en": "BACKWARD", "es": "ATRÁS"},
	"key_left": {"en": "LEFT", "es": "IZQUIERDA"},
	"key_right": {"en": "RIGHT", "es": "DERECHA"},
	"key_extra": {"en": "EXTRA SHOT", "es": "DISPARO EXTRA"},
	"key_shield": {"en": "SHIELD", "es": "ESCUDO"},
	"key_jump": {"en": "JUMP / ENEMY JUMP", "es": "SALTO / SALTO ENEMIGO"},
	"key_boost": {"en": "BOOST", "es": "IMPULSO"},
	"key_menu": {"en": "MENU", "es": "MENÚ"},
	"pad_move": {"en": "MOVE", "es": "MOVER"},
	"pad_look": {"en": "LOOK", "es": "MIRAR"},
	"pad_shoot": {"en": "SHOOT", "es": "DISPARAR"},
	"pad_jump": {"en": "JUMP", "es": "SALTAR"},
	"pad_boost": {"en": "BOOST", "es": "IMPULSO"},
	"pad_menu": {"en": "MENU", "es": "MENÚ"},
	"press_key": {"en": "PRESS KEY...", "es": "PULSA TECLA..."},
	"lang_value": {"en": "ENGLISH", "es": "ESPAÑOL"},
	"hud_score": {"en": "Score", "es": "Puntos"},
	"hud_high": {"en": "High", "es": "Récord"},
	"hud_combo": {"en": "Combo", "es": "Combo"},
	"hud_time": {"en": "Time", "es": "Tiempo"},
	"hud_enemies": {"en": "Enemies", "es": "Enemigos"},
	"ready_extra": {"en": "EXTRA READY", "es": "EXTRA LISTO"},
	"ready_boost": {"en": "BOOST READY", "es": "IMPULSO LISTO"},
	"ready_shield": {"en": "SHIELD READY", "es": "ESCUDO LISTO"},
	"cue_shield": {"en": "SHIELD", "es": "ESCUDO"},
	"cue_boost": {"en": "BOOST", "es": "IMPULSO"},
	"cue_heal": {"en": "HEAL", "es": "CURA"},
	"cue_power_surge": {"en": "POWER SURGE", "es": "SOBRECARGA"},
	"hint_look": {"en": "LOOK", "es": "MIRAR"},
	"hint_move": {"en": "MOVE", "es": "MOVER"},
	"hint_boost": {"en": "BOOST", "es": "IMPULSO"},
	"hint_extra": {"en": "EXTRA SHOT", "es": "DISPARO EXTRA"},
	"hint_shield": {"en": "SHIELD", "es": "ESCUDO"},
	"hint_jump": {"en": "JUMP", "es": "SALTAR"},
	"hint_enemy_jump": {"en": "ENEMY JUMP", "es": "SALTO ENEMIGO"},
	"gameover_title": {"en": "RUN ENDED", "es": "FIN DE PARTIDA"},
	"gameover_restart": {"en": "R to restart", "es": "R para reiniciar"},
	"tut_step": {"en": "STEP", "es": "PASO"},
	"tut_objective": {"en": "> OBJECTIVE <", "es": "> OBJETIVO <"},
	"tut_complete": {"en": "DONE!", "es": "¡COMPLETADO!"},
	"tut_finished_title": {"en": "TUTORIAL COMPLETE!", "es": "¡TUTORIAL COMPLETADO!"},
	"tut_finished_body": {"en": "You've mastered every element. Good hunting, pilot!", "es": "Ya dominas todos los elementos. ¡Buena caza, piloto!"},
	"tut_hint": {"en": "[ESC] exit     ·     [N] skip step", "es": "[ESC] salir     ·     [N] saltar paso"},
	"boss_incoming": {"en": "DRAGON INCOMING", "es": "¡DRAGÓN A LA VISTA!"},
	"boss_defeated": {"en": "DRAGON DEFEATED", "es": "¡DRAGÓN DERROTADO!"},
	"replay": {"en": "REPLAY", "es": "REPETICIÓN"},
	"restart": {"en": "RESTART", "es": "REINTENTAR"},
	"to_menu": {"en": "MENU", "es": "MENÚ"},
	"replay_play": {"en": "PLAY", "es": "PLAY"},
	"replay_pause": {"en": "PAUSE", "es": "PAUSA"},
	"replay_first": {"en": "1ST PERSON", "es": "1ª PERSONA"},
	"replay_third": {"en": "3RD PERSON", "es": "3ª PERSONA"},
	"replay_exit": {"en": "EXIT", "es": "SALIR"},
	"tut_move_title": {"en": "MOVEMENT", "es": "MOVIMIENTO"},
	"tut_move_obj": {"en": "Move with [W][A][S][D] and look with the [MOUSE].", "es": "Muévete con [W][A][S][D] y mira con el [RATÓN]."},
	"tut_jump_title": {"en": "JUMP", "es": "SALTO"},
	"tut_jump_obj": {"en": "Press [SPACE] to jump. Press again in the air for a double jump.", "es": "Pulsa [ESPACIO] para saltar. Púlsalo de nuevo en el aire para el doble salto."},
	"tut_shoot_title": {"en": "PRIMARY FIRE", "es": "DISPARO PRIMARIO"},
	"tut_shoot_obj": {"en": "Your weapon fires on its own. Aim at the enemy and destroy it.", "es": "Tu arma dispara sola. Apunta al enemigo y destrúyelo."},
	"tut_enemy_jump_title": {"en": "ENEMY-PLATFORM JUMP", "es": "SALTO SOBRE ENEMIGO"},
	"tut_enemy_jump_obj": {"en": "Land on top of the enemy and bounce with [SPACE] to recharge the shield.", "es": "Sube encima del enemigo y rebota con [ESPACIO] para recargar el escudo."},
	"tut_extra_title": {"en": "EXTRA SHOT", "es": "DISPARO EXTRA"},
	"tut_extra_obj": {"en": "Charge ready. Press [LMB] to launch the beam and sweep the enemies.", "es": "Carga lista. Pulsa [CLIC IZQ] para lanzar el rayo y barrer a los enemigos."},
	"tut_shield_title": {"en": "ORBITAL SHIELD", "es": "ESCUDO ORBITAL"},
	"tut_shield_obj": {"en": "Charge ready. Press [RMB] to launch the shield and lift off.", "es": "Carga lista. Pulsa [CLIC DER] para lanzar el escudo y elevarte."},
	"tut_boost_title": {"en": "BOOST", "es": "IMPULSO"},
	"tut_boost_obj": {"en": "Charge ready. Press [SHIFT] to dash at high speed.", "es": "Carga lista. Pulsa [SHIFT] para impulsarte a gran velocidad."},
	"tut_charger_title": {"en": "ENEMY: CHARGER", "es": "ENEMIGO: CARGADOR"},
	"tut_charger_obj": {"en": "Destroy the Charger. It weaves to reach you: track it with your aim.", "es": "Destruye al Cargador. Zigzaguea para alcanzarte: síguelo con la mira."},
	"tut_avoider_title": {"en": "ENEMY: AVOIDER", "es": "ENEMIGO: ESQUIVADOR"},
	"tut_avoider_obj": {"en": "Destroy the Avoider. It dodges your bullets, close in and corner it!", "es": "Destruye al Esquivador. Esquiva tus balas, ¡acércate y acorrálalo!"},
	"tut_bomb_title": {"en": "BOMB", "es": "BOMBA"},
	"tut_bomb_obj": {"en": "Detonate the Bomb by shooting it from afar. Never touch it in a real run!", "es": "Detona la Bomba disparándole desde lejos. ¡Jamás la toques en una partida real!"},
	"tut_reflector_title": {"en": "HEAL REFLECTOR", "es": "REFLECTOR DE CURA"},
	"tut_reflector_obj": {"en": "Shoot the Reflector to draw it in: it heals you and fires healing rays.", "es": "Dispárale al Reflector para atraerlo: te curará y lanzará rayos sanadores."},
	"tut_magnet_title": {"en": "SCORE MAGNET", "es": "IMÁN DE PUNTOS"},
	"tut_magnet_obj": {"en": "Collect the Magnet to pull every score shard toward you.", "es": "Recoge el Imán para atraer hacia ti todos los fragmentos de puntos."},
}


func t(key: String) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	if entry.is_empty():
		return key
	return str(entry.get(language, entry.get("en", key)))


func _loc(control: Control, key: String) -> void:
	# Register a control so its text refreshes when the language changes.
	localized_controls.append({"control": control, "key": key})
	if control is Button:
		(control as Button).text = t(key)
	elif control is Label:
		(control as Label).text = t(key)


func set_language(new_language: String) -> void:
	if not languages.has(new_language) or new_language == language:
		return
	language = new_language
	_apply_language()
	_save_settings()


func _apply_language() -> void:
	for entry in localized_controls:
		var control: Control = entry["control"]
		if not is_instance_valid(control):
			continue
		if control is Button:
			(control as Button).text = t(entry["key"])
		elif control is Label:
			(control as Label).text = t(entry["key"])
	_refresh_menu_title()
	_rebuild_start_controls_hint()
	if settings_panel and settings_panel.visible:
		_show_settings_tab(settings_tab)
	if leaderboard_panel and leaderboard_panel.visible:
		_populate_leaderboard()


func _refresh_menu_title() -> void:
	if not menu_title:
		return
	match active_menu_screen:
		"pause":
			menu_title.text = t("paused")
		"leaderboard":
			menu_title.text = t("ranking")
		"settings":
			menu_title.text = t("settings")
		_:
			menu_title.text = "ORBITAL SWARM"


func configure(_manager: GameManager) -> void:
	manager = _manager
	if radial_hud and manager and manager.player:
		radial_hud.configure(manager.player)
	_sync_settings_from_manager()
	_load_settings()
	_apply_settings()
	_update_settings_labels()


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer -= delta
		var alpha: float = clamp(flash_timer / 0.24, 0.0, 1.0) * 0.42
		flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, alpha)
	else:
		flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	if vignette_material:
		var vignette_intensity := 0.0
		if vignette_timer > 0.0:
			vignette_timer -= delta
			# Ease-out so the edges punch in instantly then linger and fade.
			var t: float = clamp(vignette_timer / vignette_duration, 0.0, 1.0)
			vignette_intensity = (1.0 - pow(1.0 - t, 2.0)) * 0.85 + t * 0.15
			var pulse: float = 0.85 + sin(float(Time.get_ticks_msec()) / 90.0) * 0.15
			vignette_intensity *= pulse
		vignette_material.set_shader_parameter("intensity", vignette_intensity)
	if ready_timer > 0.0:
		ready_timer -= delta
		ready_label.modulate.a = clamp(ready_timer / 0.35, 0.0, 1.0)
	else:
		ready_label.modulate.a = 0.0
	if start_hint_panel and start_hint_panel.visible:
		start_hint_timer += delta
		start_hint_panel.modulate.a = 0.84 + sin(start_hint_timer * 3.4) * 0.08


func _input(event: InputEvent) -> void:
	if rebinding_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		key_bindings[rebinding_action] = key_event.keycode
		rebinding_action = ""
		_save_settings()
		_show_settings_tab("keys")
		get_viewport().set_input_as_handled()


func update_hud(data: Dictionary) -> void:
	score_label.text = "%s: %d" % [t("hud_score"), data.get("score", 0)]
	high_score_label.text = "%s: %d" % [t("hud_high"), data.get("high_score", 0)]
	combo_label.text = "%s: x%.2f" % [t("hud_combo"), float(data.get("combo", 1.0))]
	time_label.text = "%s: %s" % [t("hud_time"), _format_time(float(data.get("time", 0.0)))]
	enemy_label.text = "%s: %d" % [t("hud_enemies"), data.get("enemies", 0)]
	var hp_value: float = float(data.get("hp", 3.0))
	var hp_max: float = float(data.get("max_hp", 3.0))
	var low_health: bool = low_health_filter_enabled and hp_value > 0.0 and hp_value <= hp_max * 0.34
	if low_health:
		var pulse: float = (sin(float(Time.get_ticks_msec()) / 145.0) + 1.0) * 0.5
		low_health_rect.color = Color(1.0, 0.03, 0.015, 0.12 + pulse * 0.12)
	else:
		low_health_rect.color = Color(1.0, 0.0, 0.0, 0.0)
	if radial_hud:
		radial_hud.set_state(data)
	set_boss_health(bool(data.get("boss_active", false)), float(data.get("boss_health", 0.0)))


func show_state(state: int) -> void:
	current_ui_state = state
	match state:
		GameManager.RunState.MENU:
			overlay.visible = true
			overlay.color = Color(0.02, 0.025, 0.04, 0.26)
			overlay_label.visible = false
			_show_menu_screen("main")
		GameManager.RunState.PAUSED:
			overlay.visible = true
			overlay.color = Color(0.0, 0.0, 0.0, 0.62)
			overlay_label.visible = false
			_show_pause_screen()
		GameManager.RunState.GAME_OVER:
			overlay.visible = true
			overlay.color = Color(0.0, 0.0, 0.0, 0.62)
			overlay_label.visible = true
			_hide_menu()
			var score: int = manager.score if manager else 0
			var high: int = manager.high_score if manager else 0
			overlay_label.text = "%s\n\n%s %d\n%s %d\n\n%s" % [t("gameover_title"), t("hud_score"), score, t("hud_high"), high, t("gameover_restart")]
		_:
			overlay.visible = false
			overlay_label.visible = false
			_hide_menu()
			overlay_label.text = ""
	if state != GameManager.RunState.TUTORIAL and tutorial_panel:
		tutorial_panel.visible = false
	if gameover_buttons:
		gameover_buttons.visible = state == GameManager.RunState.GAME_OVER
		if state == GameManager.RunState.GAME_OVER and gameover_replay_button:
			gameover_replay_button.visible = manager != null and manager.can_replay()
	if replay_panel and state != GameManager.RunState.REPLAY:
		replay_panel.visible = false
	start_hint_playing = state == GameManager.RunState.PLAYING or state == GameManager.RunState.TUTORIAL
	_refresh_start_controls_hint()
	_refresh_reticle()


func show_start_controls_hint(visible: bool) -> void:
	start_hint_requested = visible and start_hint_enabled
	if visible:
		start_hint_timer = 0.0
	_refresh_start_controls_hint()


func is_main_menu_screen() -> bool:
	return active_menu_screen == "main"


func is_base_menu_screen() -> bool:
	return active_menu_screen == "main" or active_menu_screen == "pause"


func is_rebinding_key() -> bool:
	return not rebinding_action.is_empty()


func return_to_main_menu_screen() -> void:
	if current_ui_state == GameManager.RunState.PAUSED:
		_show_pause_screen()
	else:
		_show_menu_screen("main")


func get_bound_key(action_name: String, fallback: int) -> int:
	return int(key_bindings.get(action_name, fallback))


func damage_feedback(_amount: float) -> void:
	if not damage_flash_enabled:
		return
	flash_color = Color(1.0, 0.08, 0.06, 1.0)
	flash_timer = 0.24
	vignette_timer = vignette_duration


func register_damage_direction(world_position: Vector3) -> void:
	if radial_hud:
		radial_hud.register_damage(world_position)


func heal_feedback(_amount: float) -> void:
	if not damage_flash_enabled:
		return
	flash_color = Color(0.25, 1.0, 0.18, 1.0)
	flash_timer = 0.22
	ready_timer = 0.35
	ready_label.modulate.a = 1.0
	ready_label.text = t("cue_heal")


func extra_ready_feedback() -> void:
	ready_timer = 1.1
	ready_label.modulate.a = 1.0
	ready_label.text = t("ready_extra")
	_play_tone(880.0, 0.12)


func boost_ready_feedback() -> void:
	ready_timer = 0.9
	ready_label.modulate.a = 1.0
	ready_label.text = t("ready_boost")
	_play_tone(660.0, 0.1)


func orbital_shield_ready_feedback() -> void:
	ready_timer = 1.1
	ready_label.modulate.a = 1.0
	ready_label.text = t("ready_shield")
	_play_tone(1040.0, 0.12)


func orbital_shield_feedback() -> void:
	ready_timer = 0.5
	ready_label.modulate.a = 1.0
	ready_label.text = t("cue_shield")
	_play_tone(440.0, 0.08)


func boost_feedback() -> void:
	ready_timer = 0.35
	ready_label.modulate.a = 1.0
	ready_label.text = t("cue_boost")


func boss_alert(key: String) -> void:
	ready_timer = 1.6
	ready_label.modulate = Color(1.0, 0.45, 0.3, 1.0)
	ready_label.text = t(key)
	if damage_flash_enabled:
		flash_color = Color(1.0, 0.3, 0.1, 1.0)
		flash_timer = 0.5
	_play_tone(196.0, 0.3)


func power_surge_feedback() -> void:
	if damage_flash_enabled:
		flash_color = Color(0.35, 0.95, 1.0, 1.0)
		flash_timer = 0.82
	ready_timer = 1.35
	ready_label.modulate = Color(0.65, 1.0, 0.95, 1.0)
	ready_label.text = t("cue_power_surge")
	_play_tone(1320.0, 0.16)


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	hud = VBoxContainer.new()
	hud.position = Vector2(18.0, 14.0)
	hud.z_index = 20
	hud.add_theme_constant_override("separation", 4)
	root.add_child(hud)

	# Top-left now carries only compact run text; HP and charge readouts moved to
	# the curved gauges drawn around the crosshair (see RadialHud).
	score_label = _make_label(30)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.28))
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	high_score_label = _make_label(15)
	combo_label = _make_label(16)
	time_label = _make_label(15)
	enemy_label = _make_label(14)
	hud.add_child(score_label)
	hud.add_child(high_score_label)
	hud.add_child(combo_label)
	hud.add_child(time_label)
	hud.add_child(enemy_label)

	ready_label = _make_label(24)
	ready_label.text = "EXTRA READY"
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ready_label.position.y = 42.0
	ready_label.z_index = 21
	ready_label.modulate = Color(0.55, 0.95, 1.0, 0.0)
	root.add_child(ready_label)

	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 5
	overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	overlay_label = _make_label(28)
	overlay_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(overlay_label)

	_build_menu()
	_build_start_controls_hint()
	_build_tutorial_panel()
	_build_boss_bar()
	_build_gameover_buttons()
	_build_replay_ui()

	radial_hud = RadialHud.new()
	radial_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	radial_hud.z_index = 16
	radial_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radial_hud.visible = false
	root.add_child(radial_hud)

	reticle_dot = ColorRect.new()
	reticle_dot.anchor_left = 0.5
	reticle_dot.anchor_top = 0.5
	reticle_dot.anchor_right = 0.5
	reticle_dot.anchor_bottom = 0.5
	reticle_dot.offset_left = -2.0
	reticle_dot.offset_top = -2.0
	reticle_dot.offset_right = 2.0
	reticle_dot.offset_bottom = 2.0
	reticle_dot.z_index = 17
	reticle_dot.color = Color(0.86, 0.96, 1.0, 0.94)
	reticle_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle_dot.visible = false
	root.add_child(reticle_dot)

	low_health_rect = ColorRect.new()
	low_health_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	low_health_rect.z_index = 12
	low_health_rect.color = Color(1.0, 0.0, 0.0, 0.0)
	low_health_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(low_health_rect)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.z_index = 15
	flash_rect.color = Color(1.0, 0.0, 0.0, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)

	# Red edge vignette pulsed on hit: transparent at the centre, glowing red toward
	# the borders so taking damage reads at a glance without blocking the view.
	damage_vignette = ColorRect.new()
	damage_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_vignette.z_index = 14
	damage_vignette.color = Color(1.0, 1.0, 1.0, 1.0)
	damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_shader := Shader.new()
	vignette_shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.05, 0.04, 1.0);
void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 1.41421356;
	float vignette = smoothstep(0.42, 0.95, dist);
	COLOR = vec4(edge_color.rgb, edge_color.a * vignette * intensity);
}
"""
	vignette_material = ShaderMaterial.new()
	vignette_material.shader = vignette_shader
	vignette_material.set_shader_parameter("intensity", 0.0)
	damage_vignette.material = vignette_material
	root.add_child(damage_vignette)

	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)


func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.z_index = 30
	menu_root.visible = false
	menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(menu_root)

	menu_title = _make_label(78)
	menu_title.text = "ORBITAL SWARM"
	menu_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	menu_title.position.y = 96.0
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0, 0.98))
	menu_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.08, 0.16, 0.92))
	menu_title.add_theme_constant_override("shadow_offset_x", 4)
	menu_title.add_theme_constant_override("shadow_offset_y", 4)
	menu_root.add_child(menu_title)

	_build_main_menu()
	_build_pause_menu()
	_build_leaderboard_menu()
	_build_settings_menu()


func _build_main_menu() -> void:
	main_menu_panel = HBoxContainer.new()
	main_menu_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	main_menu_panel.offset_left = 130.0
	main_menu_panel.offset_right = -130.0
	main_menu_panel.offset_top = -158.0
	main_menu_panel.offset_bottom = -64.0
	main_menu_panel.add_theme_constant_override("separation", 0)
	menu_root.add_child(main_menu_panel)

	_add_main_menu_button("play", "_on_play_pressed")
	_add_main_menu_tutorial_button()
	_add_main_menu_button("ranking", "_on_ranking_pressed")
	_add_main_menu_button("settings", "_on_settings_pressed")
	_add_main_menu_button("quit", "_on_quit_pressed")


func _build_pause_menu() -> void:
	pause_panel = VBoxContainer.new()
	pause_panel.position = Vector2(392.0, 196.0)
	pause_panel.size = Vector2(420.0, 390.0)
	pause_panel.add_theme_constant_override("separation", 0)
	pause_panel.visible = false
	menu_root.add_child(pause_panel)

	_add_pause_menu_button("resume", "_on_resume_pressed")
	_add_pause_menu_button("ranking", "_on_ranking_pressed")
	_add_pause_menu_button("settings", "_on_settings_pressed")
	_add_pause_menu_button("main_menu", "_on_main_menu_pressed")
	_add_pause_menu_button("quit", "_on_quit_pressed")


func _build_leaderboard_menu() -> void:
	leaderboard_panel = Control.new()
	leaderboard_panel.position = Vector2(74.0, 126.0)
	leaderboard_panel.size = Vector2(1060.0, 560.0)
	leaderboard_panel.visible = false
	menu_root.add_child(leaderboard_panel)

	var backdrop := PanelContainer.new()
	backdrop.size = Vector2(1060.0, 506.0)
	backdrop.add_theme_stylebox_override("panel", _make_flat_style(Color(0.06, 0.075, 0.13, 0.84), Color(0.52, 0.9, 1.0, 0.26), 1))
	leaderboard_panel.add_child(backdrop)

	var layout := VBoxContainer.new()
	layout.size = Vector2(1060.0, 506.0)
	layout.add_theme_constant_override("separation", 0)
	backdrop.add_child(layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(1040.0, 54.0)
	header.add_theme_constant_override("separation", 14)
	layout.add_child(header)
	var rank_head := _make_table_header("RANK", 120.0)
	var name_head := _make_table_header("PILOT", 520.0)
	var score_head := _make_table_header("SCORE", 280.0)
	header.add_child(rank_head)
	header.add_child(name_head)
	header.add_child(score_head)
	_loc(rank_head, "col_rank")
	_loc(name_head, "col_pilot")
	_loc(score_head, "col_score")

	leaderboard_rows = VBoxContainer.new()
	leaderboard_rows.add_theme_constant_override("separation", 0)
	layout.add_child(leaderboard_rows)

	var footer := HBoxContainer.new()
	footer.position = Vector2(0.0, 508.0)
	footer.size = Vector2(1060.0, 54.0)
	footer.add_theme_constant_override("separation", 0)
	leaderboard_panel.add_child(footer)
	var back := _make_menu_button("", 30)
	back.custom_minimum_size = Vector2(260.0, 54.0)
	back.pressed.connect(Callable(self, "_on_back_pressed"))
	footer.add_child(back)
	_loc(back, "back")
	var label := _make_label(30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(540.0, 54.0)
	footer.add_child(label)
	_loc(label, "local_board")
	var refresh := _make_menu_button("", 30)
	refresh.custom_minimum_size = Vector2(260.0, 54.0)
	refresh.pressed.connect(Callable(self, "_populate_leaderboard"))
	footer.add_child(refresh)
	_loc(refresh, "refresh")


func _build_settings_menu() -> void:
	settings_panel = Control.new()
	settings_panel.position = Vector2(72.0, 86.0)
	settings_panel.size = Vector2(1068.0, 612.0)
	settings_panel.visible = false
	menu_root.add_child(settings_panel)

	var top_tabs := HBoxContainer.new()
	top_tabs.size = Vector2(1068.0, 70.0)
	top_tabs.add_theme_constant_override("separation", 0)
	settings_panel.add_child(top_tabs)
	var tabs: Array = [["video", "tab_video"], ["hud", "tab_hud"], ["keys", "tab_keys"], ["pad", "tab_pad"]]
	for tab_index in range(tabs.size()):
		var tab_id: String = tabs[tab_index][0]
		var tab_key: String = tabs[tab_index][1]
		var button := _make_menu_button("", 29)
		button.custom_minimum_size = Vector2(267.0, 70.0)
		button.pressed.connect(Callable(self, "_show_settings_tab").bind(tab_id))
		top_tabs.add_child(button)
		_loc(button, tab_key)

	var body := PanelContainer.new()
	body.position = Vector2(0.0, 70.0)
	body.size = Vector2(1068.0, 470.0)
	body.add_theme_stylebox_override("panel", _make_flat_style(Color(0.06, 0.075, 0.13, 0.82), Color(0.52, 0.9, 1.0, 0.25), 1))
	settings_panel.add_child(body)

	settings_rows = VBoxContainer.new()
	settings_rows.size = Vector2(1068.0, 470.0)
	settings_rows.add_theme_constant_override("separation", 0)
	body.add_child(settings_rows)

	var bottom := HBoxContainer.new()
	bottom.position = Vector2(0.0, 542.0)
	bottom.size = Vector2(520.0, 62.0)
	bottom.add_theme_constant_override("separation", 0)
	settings_panel.add_child(bottom)
	var back := _make_menu_button("", 30)
	back.custom_minimum_size = Vector2(260.0, 62.0)
	back.pressed.connect(Callable(self, "_on_back_pressed"))
	bottom.add_child(back)
	_loc(back, "back")
	var reset := _make_menu_button("", 30)
	reset.custom_minimum_size = Vector2(260.0, 62.0)
	reset.pressed.connect(Callable(self, "_reset_settings"))
	bottom.add_child(reset)
	_loc(reset, "reset")


func _add_main_menu_button(key: String, callback: String) -> void:
	var button := _make_menu_button("", 34)
	button.custom_minimum_size = Vector2(180.0, 92.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(Callable(self, callback))
	main_menu_panel.add_child(button)
	_loc(button, key)


func _add_main_menu_tutorial_button() -> void:
	# A distinct main-menu entry marked with a generated graduation-cap symbol.
	var button := _make_menu_button("", 26)
	button.custom_minimum_size = Vector2(180.0, 92.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(Callable(self, "_on_tutorial_pressed"))
	main_menu_panel.add_child(button)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 3)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	tutorial_button_icon = _make_grad_cap_icon()
	tutorial_button_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(tutorial_button_icon)

	tutorial_button_label = _make_label(24)
	tutorial_button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_button_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_button_label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	tutorial_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(tutorial_button_label)
	_loc(tutorial_button_label, "tutorial")

	# Keep the icon and label readable against the light hover background.
	button.mouse_entered.connect(Callable(self, "_on_tutorial_button_hover").bind(true))
	button.mouse_exited.connect(Callable(self, "_on_tutorial_button_hover").bind(false))


func _on_tutorial_button_hover(hovered: bool) -> void:
	var color: Color = Color(0.12, 0.22, 0.3) if hovered else Color(0.98, 0.99, 1.0)
	if tutorial_button_label:
		tutorial_button_label.add_theme_color_override("font_color", color)
	if tutorial_button_icon:
		tutorial_button_icon.modulate = color if hovered else Color(1.0, 1.0, 1.0)


func _make_grad_cap_icon() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(44.0, 30.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap_color := Color(0.45, 0.95, 1.0)
	var base_color := Color(0.26, 0.68, 0.94)
	var tassel_color := Color(0.94, 1.0, 0.72)
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([Vector2(13.0, 13.0), Vector2(31.0, 13.0), Vector2(28.0, 25.0), Vector2(16.0, 25.0)])
	base.color = base_color
	holder.add_child(base)
	var board := Polygon2D.new()
	board.polygon = PackedVector2Array([Vector2(22.0, 3.0), Vector2(40.0, 12.0), Vector2(22.0, 21.0), Vector2(4.0, 12.0)])
	board.color = cap_color
	holder.add_child(board)
	var tassel_string := Polygon2D.new()
	tassel_string.polygon = PackedVector2Array([Vector2(33.0, 12.0), Vector2(35.0, 12.0), Vector2(35.0, 25.0), Vector2(33.0, 25.0)])
	tassel_string.color = tassel_color
	holder.add_child(tassel_string)
	var knob := Polygon2D.new()
	knob.polygon = PackedVector2Array([Vector2(31.0, 24.0), Vector2(37.0, 24.0), Vector2(37.0, 29.0), Vector2(31.0, 29.0)])
	knob.color = tassel_color
	holder.add_child(knob)
	return holder


func _add_pause_menu_button(key: String, callback: String) -> void:
	var button := _make_menu_button("", 34)
	button.custom_minimum_size = Vector2(420.0, 74.0)
	button.pressed.connect(Callable(self, callback))
	pause_panel.add_child(button)
	_loc(button, key)


func _show_pause_screen() -> void:
	if not menu_root:
		return
	active_menu_screen = "pause"
	menu_root.visible = true
	menu_title.text = t("paused")
	main_menu_panel.visible = false
	pause_panel.visible = true
	leaderboard_panel.visible = false
	settings_panel.visible = false


func _show_menu_screen(screen: String) -> void:
	if not menu_root:
		return
	active_menu_screen = screen
	menu_root.visible = true
	main_menu_panel.visible = screen == "main"
	pause_panel.visible = false
	leaderboard_panel.visible = screen == "leaderboard"
	settings_panel.visible = screen == "settings"
	if screen == "main":
		menu_title.text = "ORBITAL SWARM"
	elif screen == "leaderboard":
		menu_title.text = t("ranking")
		_populate_leaderboard()
	else:
		menu_title.text = t("settings")
		_show_settings_tab(settings_tab)


func _hide_menu() -> void:
	if menu_root:
		menu_root.visible = false


func _on_play_pressed() -> void:
	if manager:
		manager.start_run()


func _on_tutorial_pressed() -> void:
	if manager:
		manager.start_tutorial()


func _on_resume_pressed() -> void:
	if manager:
		manager.resume_from_pause()


func _on_main_menu_pressed() -> void:
	if manager:
		manager.return_to_main_menu()


func _on_ranking_pressed() -> void:
	_show_menu_screen("leaderboard")


func _on_settings_pressed() -> void:
	_show_menu_screen("settings")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_back_pressed() -> void:
	rebinding_action = ""
	return_to_main_menu_screen()


func _populate_leaderboard() -> void:
	if not leaderboard_rows:
		return
	var old_leaderboard_rows: Array = leaderboard_rows.get_children()
	for child_index in range(old_leaderboard_rows.size()):
		var old_leaderboard_row: Node = old_leaderboard_rows[child_index] as Node
		if old_leaderboard_row:
			old_leaderboard_row.queue_free()
	var local_score: int = manager.high_score if manager else 0
	var entries: Array[Dictionary] = [
		{"name": "ENRI", "score": 32012, "local": false},
		{"name": "CRUNCHY YOGURT", "score": 31837, "local": false},
		{"name": "JO", "score": 31317, "local": false},
		{"name": "CYTHIEL", "score": 31277, "local": false},
		{"name": "EDU1010", "score": max(local_score, 0), "local": true},
		{"name": "DEBANNER", "score": 31043, "local": false},
		{"name": "SALLY", "score": 30791, "local": false},
		{"name": "CHOGAN", "score": 30590, "local": false},
		{"name": "SPICA", "score": 30248, "local": false},
		{"name": "[___]", "score": 30240, "local": false},
	]
	entries.sort_custom(Callable(self, "_sort_score_desc"))
	for i in range(entries.size()):
		_add_leaderboard_row(i + 1, entries[i])


func _sort_score_desc(a: Dictionary, b: Dictionary) -> bool:
	return int(a["score"]) > int(b["score"])


func _add_leaderboard_row(rank: int, entry: Dictionary) -> void:
	var is_local: bool = bool(entry.get("local", false))
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(1060.0, 44.0)
	var row_color := Color(0.07, 0.1, 0.18, 0.82) if rank % 2 == 0 else Color(0.09, 0.08, 0.12, 0.78)
	if is_local:
		row_color = Color(0.86, 0.94, 1.0, 0.9)
	row_panel.add_theme_stylebox_override("panel", _make_flat_style(row_color))
	leaderboard_rows.add_child(row_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row_panel.add_child(row)
	var font_color := Color(0.02, 0.025, 0.04) if is_local else Color(0.95, 0.98, 1.0)
	row.add_child(_make_table_cell("#%02d" % rank, 120.0, font_color))
	row.add_child(_make_table_cell(str(entry["name"]), 520.0, font_color))
	row.add_child(_make_table_cell("%s <>" % _format_score(int(entry["score"])), 280.0, font_color))


func _show_settings_tab(tab: String) -> void:
	settings_tab = tab
	if settings_tab != "keys":
		rebinding_action = ""
	if not settings_rows:
		return
	var old_setting_rows: Array = settings_rows.get_children()
	for child_index in range(old_setting_rows.size()):
		var old_setting_row: Node = old_setting_rows[child_index] as Node
		if old_setting_row:
			old_setting_row.queue_free()
	setting_value_labels.clear()
	key_value_labels.clear()
	match settings_tab:
		"hud":
			_add_setting_row(t("set_language"), "language")
			_add_setting_row(t("set_reticle"), "reticle")
			_add_setting_row(t("set_start_hint"), "start_hint")
			_add_setting_row(t("set_low_health"), "low_health")
			_add_setting_row(t("set_flashes"), "damage_flash")
		"keys":
			_add_keybind_row(t("key_forward"), "forward")
			_add_keybind_row(t("key_backward"), "backward")
			_add_keybind_row(t("key_left"), "left")
			_add_keybind_row(t("key_right"), "right")
			_add_readonly_row(t("key_extra"), "[LMB]")
			_add_readonly_row(t("key_shield"), "[RMB]")
			_add_keybind_row(t("key_jump"), "jump")
			_add_keybind_row(t("key_boost"), "boost")
			_add_keybind_row(t("key_menu"), "menu")
		"pad":
			_add_readonly_row(t("pad_move"), "[LS]")
			_add_readonly_row(t("pad_look"), "[RS]")
			_add_readonly_row(t("pad_shoot"), "[RB]")
			_add_readonly_row(t("pad_jump"), "[LB]")
			_add_readonly_row(t("pad_boost"), "[LT]")
			_add_readonly_row(t("pad_menu"), "[START]")
		_:
			_add_setting_row(t("set_resolution"), "resolution")
			_add_setting_row(t("set_fullscreen"), "fullscreen")
			_add_setting_row(t("set_fps"), "fps")
			_add_setting_row(t("set_fov"), "fov")
			_add_setting_row(t("set_sensitivity"), "sensitivity")
			_add_setting_row(t("set_volume"), "effects_volume")
	_update_settings_labels()
	_update_keybind_labels()


func _add_setting_row(label_text: String, setting_name: String) -> void:
	var row_panel := _make_row_panel(settings_rows.get_child_count())
	settings_rows.add_child(row_panel)
	var row := _make_row_container()
	row_panel.add_child(row)
	row.add_child(_make_table_cell(label_text, 540.0, Color(0.95, 0.98, 1.0)))
	var minus := _make_menu_button("<", 26)
	minus.custom_minimum_size = Vector2(64.0, 42.0)
	minus.pressed.connect(Callable(self, "_adjust_setting").bind(setting_name, -1))
	row.add_child(minus)
	var value := _make_table_cell("", 260.0, Color(0.95, 0.98, 1.0))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setting_value_labels[setting_name] = value
	row.add_child(value)
	var plus := _make_menu_button(">", 26)
	plus.custom_minimum_size = Vector2(64.0, 42.0)
	plus.pressed.connect(Callable(self, "_adjust_setting").bind(setting_name, 1))
	row.add_child(plus)


func _add_readonly_row(label_text: String, value_text: String) -> void:
	var row_panel := _make_row_panel(settings_rows.get_child_count())
	settings_rows.add_child(row_panel)
	var row := _make_row_container()
	row_panel.add_child(row)
	row.add_child(_make_table_cell(label_text, 700.0, Color(0.95, 0.98, 1.0)))
	var value := _make_table_cell(value_text, 300.0, Color(0.95, 0.98, 1.0))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)


func _add_keybind_row(label_text: String, action_name: String) -> void:
	var row_panel := _make_row_panel(settings_rows.get_child_count())
	settings_rows.add_child(row_panel)
	var row := _make_row_container()
	row_panel.add_child(row)
	row.add_child(_make_table_cell(label_text, 650.0, Color(0.95, 0.98, 1.0)))
	var button := _make_menu_button("", 25)
	button.custom_minimum_size = Vector2(340.0, 42.0)
	button.pressed.connect(Callable(self, "_begin_key_rebind").bind(action_name))
	key_value_labels[action_name] = button
	row.add_child(button)


func _adjust_setting(setting_name: String, direction: int) -> void:
	match setting_name:
		"resolution":
			setting_resolution_index = wrapi(setting_resolution_index + direction, 0, resolution_options.size())
			if not setting_fullscreen:
				var selected_resolution: Vector2i = resolution_options[setting_resolution_index]
				DisplayServer.window_set_size(selected_resolution)
		"fullscreen":
			setting_fullscreen = not setting_fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if setting_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		"fps":
			setting_fps_index = wrapi(setting_fps_index + direction, 0, fps_options.size())
			Engine.max_fps = int(fps_options[setting_fps_index])
		"fov":
			setting_fov = clamp(setting_fov + float(direction) * 5.0, 70.0, 120.0)
		"sensitivity":
			setting_sensitivity = clamp(setting_sensitivity + float(direction) * 0.0002, 0.0008, 0.006)
		"effects_volume":
			setting_effects_volume = clamp(setting_effects_volume + float(direction) * 0.1, 0.0, 1.0)
		"reticle":
			reticle_enabled = not reticle_enabled
		"start_hint":
			start_hint_enabled = not start_hint_enabled
		"low_health":
			low_health_filter_enabled = not low_health_filter_enabled
		"damage_flash":
			damage_flash_enabled = not damage_flash_enabled
		"language":
			var index: int = maxi(0, languages.find(language))
			set_language(languages[wrapi(index + direction, 0, languages.size())])
			return
	_apply_settings()
	_update_settings_labels()
	_save_settings()


func _begin_key_rebind(action_name: String) -> void:
	rebinding_action = action_name
	_update_keybind_labels()


func _update_keybind_labels() -> void:
	var action_names: Array = key_value_labels.keys()
	for action_index in range(action_names.size()):
		var action_name: String = str(action_names[action_index])
		var button: Button = key_value_labels.get(action_name) as Button
		if not button:
			continue
		if action_name == rebinding_action:
			button.text = t("press_key")
		else:
			button.text = "[%s]" % _format_key_name(get_bound_key(action_name, 0))


func _format_key_name(keycode: int) -> String:
	var key_text: String = OS.get_keycode_string(keycode)
	if key_text.is_empty():
		return "NONE"
	return key_text.to_upper()


func _reset_settings() -> void:
	setting_resolution_index = 0
	setting_fps_index = 2
	setting_fullscreen = false
	setting_fov = 86.0
	setting_sensitivity = 0.0022
	setting_effects_volume = 1.0
	reticle_enabled = true
	start_hint_enabled = true
	low_health_filter_enabled = true
	damage_flash_enabled = true
	_apply_settings()
	_save_settings()
	_show_settings_tab(settings_tab)


const SETTINGS_PATH := "user://bullet_hell_settings.cfg"


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "resolution_index", setting_resolution_index)
	config.set_value("settings", "fps_index", setting_fps_index)
	config.set_value("settings", "fullscreen", setting_fullscreen)
	config.set_value("settings", "fov", setting_fov)
	config.set_value("settings", "sensitivity", setting_sensitivity)
	config.set_value("settings", "effects_volume", setting_effects_volume)
	config.set_value("settings", "reticle", reticle_enabled)
	config.set_value("settings", "start_hint", start_hint_enabled)
	config.set_value("settings", "low_health", low_health_filter_enabled)
	config.set_value("settings", "damage_flash", damage_flash_enabled)
	config.set_value("settings", "language", language)
	for action_name in key_bindings.keys():
		config.set_value("keys", str(action_name), int(key_bindings[action_name]))
	config.save(SETTINGS_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	setting_resolution_index = clampi(int(config.get_value("settings", "resolution_index", setting_resolution_index)), 0, resolution_options.size() - 1)
	setting_fps_index = clampi(int(config.get_value("settings", "fps_index", setting_fps_index)), 0, fps_options.size() - 1)
	setting_fullscreen = bool(config.get_value("settings", "fullscreen", setting_fullscreen))
	setting_fov = clamp(float(config.get_value("settings", "fov", setting_fov)), 70.0, 120.0)
	setting_sensitivity = clamp(float(config.get_value("settings", "sensitivity", setting_sensitivity)), 0.0008, 0.006)
	setting_effects_volume = clamp(float(config.get_value("settings", "effects_volume", setting_effects_volume)), 0.0, 1.0)
	reticle_enabled = bool(config.get_value("settings", "reticle", reticle_enabled))
	start_hint_enabled = bool(config.get_value("settings", "start_hint", start_hint_enabled))
	low_health_filter_enabled = bool(config.get_value("settings", "low_health", low_health_filter_enabled))
	damage_flash_enabled = bool(config.get_value("settings", "damage_flash", damage_flash_enabled))
	for action_name in key_bindings.keys():
		key_bindings[action_name] = int(config.get_value("keys", str(action_name), key_bindings[action_name]))
	# Apply the persisted window mode/size immediately on startup.
	if setting_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution_options[setting_resolution_index])
	# The UI was built in the default language; refresh it if a language was saved.
	var saved_language: String = str(config.get_value("settings", "language", language))
	if languages.has(saved_language) and saved_language != language:
		language = saved_language
		_apply_language()


func _sync_settings_from_manager() -> void:
	if not manager or not manager.player:
		return
	setting_fov = manager.player.base_fov
	setting_sensitivity = manager.player.mouse_sensitivity
	setting_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func _apply_settings() -> void:
	Engine.max_fps = int(fps_options[setting_fps_index])
	if manager and manager.player:
		manager.player.base_fov = setting_fov
		manager.player.mouse_sensitivity = setting_sensitivity
		if manager.player.camera:
			manager.player.camera.fov = setting_fov
	var volume: float = max(0.001, setting_effects_volume)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))
	AudioServer.set_bus_mute(0, setting_effects_volume <= 0.0)
	_refresh_reticle()
	if not start_hint_enabled:
		start_hint_requested = false
		_refresh_start_controls_hint()


func _update_settings_labels() -> void:
	if setting_value_labels.is_empty():
		return
	if setting_value_labels.has("resolution"):
		var resolution: Vector2i = resolution_options[setting_resolution_index]
		_set_setting_value("resolution", "%d x %d" % [resolution.x, resolution.y])
	if setting_value_labels.has("fullscreen"):
		_set_setting_value("fullscreen", "ON" if setting_fullscreen else "OFF")
	if setting_value_labels.has("fps"):
		var fps: int = int(fps_options[setting_fps_index])
		_set_setting_value("fps", "OFF" if fps <= 0 else str(fps))
	if setting_value_labels.has("fov"):
		_set_setting_value("fov", "%d" % int(setting_fov))
	if setting_value_labels.has("sensitivity"):
		_set_setting_value("sensitivity", "%.2f" % (setting_sensitivity * 10000.0))
	if setting_value_labels.has("effects_volume"):
		_set_setting_value("effects_volume", "%d%%" % int(round(setting_effects_volume * 100.0)))
	if setting_value_labels.has("reticle"):
		_set_setting_value("reticle", "ON" if reticle_enabled else "OFF")
	if setting_value_labels.has("start_hint"):
		_set_setting_value("start_hint", "ON" if start_hint_enabled else "OFF")
	if setting_value_labels.has("low_health"):
		_set_setting_value("low_health", "ON" if low_health_filter_enabled else "OFF")
	if setting_value_labels.has("damage_flash"):
		_set_setting_value("damage_flash", "ON" if damage_flash_enabled else "OFF")
	if setting_value_labels.has("language"):
		_set_setting_value("language", t("lang_value"))


func _set_setting_value(setting_name: String, text: String) -> void:
	var label: Label = setting_value_labels.get(setting_name) as Label
	if label:
		label.text = text


func _refresh_reticle() -> void:
	var in_action: bool = current_ui_state == GameManager.RunState.PLAYING or current_ui_state == GameManager.RunState.TUTORIAL
	if reticle_dot:
		reticle_dot.visible = reticle_enabled and in_action
	if radial_hud:
		radial_hud.visible = in_action


func _make_menu_button(text: String, font_size := 28) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.12, 0.22, 0.3))
	button.add_theme_stylebox_override("normal", _make_flat_style(Color(0.045, 0.06, 0.11, 0.9)))
	button.add_theme_stylebox_override("hover", _make_flat_style(Color(0.88, 0.95, 1.0, 0.95)))
	button.add_theme_stylebox_override("pressed", _make_flat_style(Color(0.45, 0.95, 1.0, 0.78)))
	return button


func _make_flat_style(color: Color, border_color: Color = Color(0.0, 0.0, 0.0, 0.0), border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	return style


func _make_table_header(text: String, width: float) -> Label:
	var label := _make_table_cell(text, width, Color(0.35, 0.95, 1.0))
	label.add_theme_font_size_override("font_size", 24)
	return label


func _make_table_cell(text: String, width: float, color: Color) -> Label:
	var label := _make_label(27)
	label.text = text
	label.custom_minimum_size = Vector2(width, 42.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	return label


func _make_row_panel(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1068.0, 49.0)
	var color := Color(0.07, 0.1, 0.18, 0.78) if index % 2 == 0 else Color(0.09, 0.075, 0.11, 0.76)
	if index == 4:
		color = Color(0.0, 0.42, 0.58, 0.84)
	panel.add_theme_stylebox_override("panel", _make_flat_style(color))
	return panel


func _make_row_container() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(1068.0, 48.0)
	row.add_theme_constant_override("separation", 14)
	return row


func _format_score(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3, 3) + result
		text = text.substr(0, text.length() - 3)
	return text + result


func _build_start_controls_hint() -> void:
	start_hint_panel = Control.new()
	start_hint_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_hint_panel.z_index = 18
	start_hint_panel.visible = false
	start_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_hint_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	root.add_child(start_hint_panel)

	start_hint_stack = VBoxContainer.new()
	start_hint_stack.position = Vector2(104.0, 158.0)
	start_hint_stack.size = Vector2(560.0, 340.0)
	start_hint_stack.custom_minimum_size = Vector2(560.0, 340.0)
	start_hint_stack.add_theme_constant_override("separation", 5)
	start_hint_panel.add_child(start_hint_stack)
	_populate_start_hint_rows()


func _populate_start_hint_rows() -> void:
	if not start_hint_stack:
		return
	for child in start_hint_stack.get_children():
		child.queue_free()
	_add_start_hint_row(start_hint_stack, "[MOUSE]", t("hint_look"))
	_add_start_hint_separator(start_hint_stack)
	_add_start_hint_row(start_hint_stack, "[W] [A] [S] [D]", t("hint_move"))
	_add_start_hint_separator(start_hint_stack)
	_add_start_hint_row(start_hint_stack, "[SHIFT]", t("hint_boost"))
	_add_start_hint_separator(start_hint_stack)
	_add_start_hint_row(start_hint_stack, "[LMB]", t("hint_extra"))
	_add_start_hint_separator(start_hint_stack)
	_add_start_hint_row(start_hint_stack, "[RMB]", t("hint_shield"))
	_add_start_hint_separator(start_hint_stack)
	_add_start_hint_row(start_hint_stack, "[SPACE]", t("hint_jump"))
	_add_start_hint_row(start_hint_stack, "[SPACE] %s" % ("ON ENEMY" if language == "en" else "EN ENEMIGO"), t("hint_enemy_jump"))


func _rebuild_start_controls_hint() -> void:
	_populate_start_hint_rows()


func _add_start_hint_row(parent: VBoxContainer, control_text: String, action_text: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(540.0, 38.0)
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)

	var control := _make_label(28)
	control.text = control_text
	control.custom_minimum_size = Vector2(265.0, 34.0)
	control.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0, 0.96))
	control.add_theme_color_override("font_shadow_color", Color(0.0, 0.13, 0.22, 0.9))
	row.add_child(control)

	var marker := _make_label(27)
	marker.text = ">"
	marker.custom_minimum_size = Vector2(38.0, 34.0)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_color_override("font_color", Color(0.42, 0.98, 1.0, 0.9))
	row.add_child(marker)

	var action := _make_label(29)
	action.text = action_text
	action.custom_minimum_size = Vector2(220.0, 34.0)
	action.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 0.98))
	action.add_theme_color_override("font_shadow_color", Color(0.0, 0.1, 0.18, 0.95))
	row.add_child(action)


func _add_start_hint_separator(parent: VBoxContainer) -> void:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(520.0, 1.0)
	line.color = Color(0.45, 0.95, 1.0, 0.34)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _refresh_start_controls_hint() -> void:
	if not start_hint_panel:
		return
	var show_hint := start_hint_requested and start_hint_playing
	start_hint_panel.visible = show_hint
	if hud:
		hud.visible = start_hint_playing and not show_hint
	if not start_hint_panel.visible:
		start_hint_panel.modulate.a = 0.0


func _build_tutorial_panel() -> void:
	tutorial_panel = Control.new()
	tutorial_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_panel.z_index = 19
	tutorial_panel.visible = false
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tutorial_panel)

	var backdrop := PanelContainer.new()
	backdrop.anchor_left = 0.5
	backdrop.anchor_right = 0.5
	backdrop.offset_left = -440.0
	backdrop.offset_right = 440.0
	backdrop.offset_top = 80.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_theme_stylebox_override("panel", _make_flat_style(Color(0.05, 0.07, 0.12, 0.86), Color(0.45, 0.92, 1.0, 0.5), 2))
	tutorial_panel.add_child(backdrop)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(stack)

	tutorial_step_label = _make_label(18)
	tutorial_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_step_label.add_theme_color_override("font_color", Color(0.5, 0.92, 1.0))
	stack.add_child(tutorial_step_label)

	tutorial_title_label = _make_label(34)
	tutorial_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_title_label.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0))
	stack.add_child(tutorial_title_label)

	tutorial_objective_label = _make_label(20)
	tutorial_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_objective_label.custom_minimum_size = Vector2(840.0, 48.0)
	stack.add_child(tutorial_objective_label)

	tutorial_status_label = _make_label(24)
	tutorial_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(tutorial_status_label)

	var hint := _make_label(15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.6, 0.78, 0.9, 0.82))
	stack.add_child(hint)
	_loc(hint, "tut_hint")


func _build_boss_bar() -> void:
	boss_bar_root = Control.new()
	boss_bar_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boss_bar_root.z_index = 19
	boss_bar_root.visible = false
	boss_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_bar_root)

	boss_bar_label = _make_label(20)
	boss_bar_label.text = "- - -   DRAGON   - - -"
	boss_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar_label.anchor_left = 0.5
	boss_bar_label.anchor_right = 0.5
	boss_bar_label.offset_left = -320.0
	boss_bar_label.offset_right = 320.0
	boss_bar_label.offset_top = 14.0
	boss_bar_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
	boss_bar_root.add_child(boss_bar_label)

	var frame := ColorRect.new()
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.offset_left = -320.0
	frame.offset_right = 320.0
	frame.offset_top = 44.0
	frame.offset_bottom = 66.0
	frame.color = Color(0.06, 0.02, 0.03, 0.85)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar_root.add_child(frame)

	boss_bar_fill = ColorRect.new()
	boss_bar_fill.anchor_left = 0.0
	boss_bar_fill.anchor_top = 0.0
	boss_bar_fill.anchor_right = 1.0
	boss_bar_fill.anchor_bottom = 1.0
	boss_bar_fill.offset_left = 3.0
	boss_bar_fill.offset_top = 3.0
	boss_bar_fill.offset_bottom = -3.0
	boss_bar_fill.offset_right = -3.0
	boss_bar_fill.color = Color(0.95, 0.18, 0.14, 0.95)
	boss_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(boss_bar_fill)


func _build_gameover_buttons() -> void:
	gameover_buttons = HBoxContainer.new()
	gameover_buttons.set_anchors_preset(Control.PRESET_CENTER)
	gameover_buttons.offset_left = -330.0
	gameover_buttons.offset_right = 330.0
	gameover_buttons.offset_top = 120.0
	gameover_buttons.offset_bottom = 190.0
	gameover_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	gameover_buttons.add_theme_constant_override("separation", 16)
	gameover_buttons.z_index = 8
	gameover_buttons.visible = false
	overlay.add_child(gameover_buttons)

	gameover_replay_button = _make_menu_button("", 28)
	gameover_replay_button.custom_minimum_size = Vector2(220.0, 60.0)
	gameover_replay_button.pressed.connect(Callable(self, "_on_replay_pressed"))
	gameover_buttons.add_child(gameover_replay_button)
	_loc(gameover_replay_button, "replay")

	var restart_button := _make_menu_button("", 28)
	restart_button.custom_minimum_size = Vector2(200.0, 60.0)
	restart_button.pressed.connect(Callable(self, "_on_restart_pressed"))
	gameover_buttons.add_child(restart_button)
	_loc(restart_button, "restart")

	var menu_button := _make_menu_button("", 28)
	menu_button.custom_minimum_size = Vector2(200.0, 60.0)
	menu_button.pressed.connect(Callable(self, "_on_main_menu_pressed"))
	gameover_buttons.add_child(menu_button)
	_loc(menu_button, "to_menu")


func _on_replay_pressed() -> void:
	if manager:
		manager.start_replay()


func _on_restart_pressed() -> void:
	if manager:
		manager.start_run()


func _build_replay_ui() -> void:
	replay_panel = Control.new()
	replay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	replay_panel.z_index = 31
	replay_panel.visible = false
	replay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(replay_panel)

	var title := _make_label(30)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 24.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	replay_panel.add_child(title)
	_loc(title, "replay")

	# Clickable progress / scrub bar.
	replay_progress_holder = Control.new()
	replay_progress_holder.anchor_left = 0.5
	replay_progress_holder.anchor_right = 0.5
	replay_progress_holder.anchor_top = 1.0
	replay_progress_holder.anchor_bottom = 1.0
	replay_progress_holder.offset_left = -490.0
	replay_progress_holder.offset_right = 490.0
	replay_progress_holder.offset_top = -96.0
	replay_progress_holder.offset_bottom = -74.0
	replay_progress_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	replay_progress_holder.gui_input.connect(Callable(self, "_on_replay_scrub"))
	replay_panel.add_child(replay_progress_holder)
	var bar_bg := ColorRect.new()
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_bg.color = Color(0.08, 0.1, 0.16, 0.85)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay_progress_holder.add_child(bar_bg)
	replay_progress_fill = ColorRect.new()
	replay_progress_fill.anchor_top = 0.0
	replay_progress_fill.anchor_bottom = 1.0
	replay_progress_fill.offset_right = 0.0
	replay_progress_fill.color = Color(0.45, 0.9, 1.0, 0.92)
	replay_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay_progress_holder.add_child(replay_progress_fill)

	# Control row.
	var controls := HBoxContainer.new()
	controls.anchor_left = 0.5
	controls.anchor_right = 0.5
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_left = -560.0
	controls.offset_right = 560.0
	controls.offset_top = -64.0
	controls.offset_bottom = -16.0
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	replay_panel.add_child(controls)

	replay_pause_button = _make_menu_button("", 22)
	replay_pause_button.custom_minimum_size = Vector2(118.0, 48.0)
	replay_pause_button.pressed.connect(Callable(self, "_on_replay_pause"))
	controls.add_child(replay_pause_button)

	replay_camera_button = _make_menu_button("", 22)
	replay_camera_button.custom_minimum_size = Vector2(168.0, 48.0)
	replay_camera_button.pressed.connect(Callable(self, "_on_replay_camera"))
	controls.add_child(replay_camera_button)

	replay_speed_buttons.clear()
	var speeds: Array = manager.replay.get_speeds() if (manager and manager.replay) else [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0]
	for speed in speeds:
		var button := _make_menu_button(_format_speed(speed), 22)
		button.custom_minimum_size = Vector2(72.0, 48.0)
		button.pressed.connect(Callable(self, "_on_replay_speed").bind(float(speed)))
		controls.add_child(button)
		replay_speed_buttons.append({"button": button, "speed": float(speed)})

	var exit_button := _make_menu_button("", 22)
	exit_button.custom_minimum_size = Vector2(118.0, 48.0)
	exit_button.pressed.connect(Callable(self, "_on_replay_exit"))
	controls.add_child(exit_button)
	_loc(exit_button, "replay_exit")


func _format_speed(speed: float) -> String:
	if speed == floor(speed):
		return "%dx" % int(speed)
	return "%sx" % str(speed)


func _on_replay_pause() -> void:
	if manager and manager.replay:
		manager.replay.toggle_pause()


func _on_replay_camera() -> void:
	if manager and manager.replay:
		manager.replay.toggle_camera()


func _on_replay_speed(speed: float) -> void:
	if manager and manager.replay:
		manager.replay.set_playback_speed(speed)


func _on_replay_exit() -> void:
	if manager:
		manager.exit_replay()


func _on_replay_scrub(event: InputEvent) -> void:
	if not manager or not manager.replay or not replay_progress_holder:
		return
	var scrubbing := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		scrubbing = true
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		scrubbing = true
	if not scrubbing:
		return
	var width: float = replay_progress_holder.size.x
	if width <= 0.0:
		return
	manager.replay.scrub_to(clamp(event.position.x / width, 0.0, 1.0))


func show_replay_controls(controls_visible: bool) -> void:
	if replay_panel:
		replay_panel.visible = controls_visible


func update_replay_controls(speed: float, paused: bool, third_person: bool, progress: float) -> void:
	if replay_pause_button:
		replay_pause_button.text = t("replay_play") if paused else t("replay_pause")
	if replay_camera_button:
		replay_camera_button.text = t("replay_third") if third_person else t("replay_first")
	for entry in replay_speed_buttons:
		var button: Button = entry["button"]
		var active: bool = abs(float(entry["speed"]) - speed) < 0.001
		button.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if active else Color(0.98, 0.99, 1.0))
	update_replay_progress(progress)


func update_replay_progress(fraction: float) -> void:
	if replay_progress_fill and replay_progress_holder:
		replay_progress_fill.offset_right = clamp(fraction, 0.0, 1.0) * replay_progress_holder.size.x


func set_boss_health(bar_visible: bool, fraction: float) -> void:
	if not boss_bar_root:
		return
	boss_bar_root.visible = bar_visible
	if bar_visible and boss_bar_fill:
		var full_width: float = 634.0
		boss_bar_fill.offset_right = -3.0 - (1.0 - clamp(fraction, 0.0, 1.0)) * full_width


func show_tutorial_panel(panel_visible: bool) -> void:
	if tutorial_panel:
		tutorial_panel.visible = panel_visible


func set_tutorial_stage(index: int, total: int, title: String, objective: String) -> void:
	if not tutorial_panel:
		return
	tutorial_panel.visible = true
	tutorial_step_label.text = "%s %d / %d" % [t("tut_step"), index, total]
	tutorial_title_label.text = title
	tutorial_objective_label.text = objective
	tutorial_status_label.text = t("tut_objective")
	tutorial_status_label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))


func tutorial_stage_complete() -> void:
	if tutorial_status_label:
		tutorial_status_label.text = t("tut_complete")
		tutorial_status_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	ready_timer = 0.95
	ready_label.modulate = Color(0.45, 1.0, 0.55, 1.0)
	ready_label.text = t("tut_complete")
	_play_tone(990.0, 0.12)


func tutorial_finished() -> void:
	if not tutorial_panel:
		return
	tutorial_step_label.text = ""
	tutorial_title_label.text = t("tut_finished_title")
	tutorial_objective_label.text = t("tut_finished_body")
	tutorial_status_label.text = ""
	ready_timer = 1.6
	ready_label.modulate = Color(0.65, 1.0, 0.95, 1.0)
	ready_label.text = t("tut_complete")
	_play_tone(1320.0, 0.18)


func _make_label(size := 18) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [int(total / 60), total % 60]


func _play_tone(frequency: float, duration: float) -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050
	stream.buffer_length = duration
	audio_player.stream = stream
	audio_player.play()
	var playback: AudioStreamPlayback = audio_player.get_stream_playback()
	if not playback:
		return
	var frames := int(stream.mix_rate * duration)
	var phase := 0.0
	for i in range(frames):
		var fade: float = 1.0 - float(i) / float(maxi(1, frames))
		var sample := sin(phase) * 0.22 * fade
		playback.push_frame(Vector2(sample, sample))
		phase += TAU * frequency / stream.mix_rate

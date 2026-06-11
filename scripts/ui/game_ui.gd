class_name GameUI
extends CanvasLayer

var manager: GameManager
var root: Control
var hud: VBoxContainer
var score_label: Label
var high_score_label: Label
var hp_label: Label
var charge_label: Label
var charge_bar: ProgressBar
var boost_label: Label
var boost_bar: ProgressBar
var combo_label: Label
var time_label: Label
var enemy_label: Label
var overlay: ColorRect
var overlay_label: Label
var flash_rect: ColorRect
var ready_label: Label
var audio_player: AudioStreamPlayer
var flash_timer := 0.0
var ready_timer := 0.0


func configure(_manager: GameManager) -> void:
	manager = _manager


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer -= delta
		var alpha: float = clamp(flash_timer / 0.24, 0.0, 1.0) * 0.42
		flash_rect.color = Color(1.0, 0.08, 0.06, alpha)
	else:
		flash_rect.color = Color(1.0, 0.08, 0.06, 0.0)
	if ready_timer > 0.0:
		ready_timer -= delta
		ready_label.modulate.a = clamp(ready_timer / 0.35, 0.0, 1.0)
	else:
		ready_label.modulate.a = 0.0


func update_hud(data: Dictionary) -> void:
	score_label.text = "Score: %d" % data.get("score", 0)
	high_score_label.text = "High: %d" % data.get("high_score", 0)
	var hp_value: float = float(data.get("hp", 3.0))
	var hp_max: float = float(data.get("max_hp", 3.0))
	hp_label.text = "HP: %.1f / %.0f" % [hp_value, hp_max]
	if data.get("invulnerable", false):
		hp_label.modulate = Color(1.0, 0.3, 0.25) if int(Time.get_ticks_msec() / 90) % 2 == 0 else Color(1.0, 1.0, 1.0)
	else:
		hp_label.modulate = Color(1.0, 1.0, 1.0)
	var charge: float = float(data.get("charge", 0.0))
	var charge_max: float = float(data.get("charge_max", 100.0))
	charge_bar.max_value = charge_max
	charge_bar.value = charge
	charge_label.text = "Extra: %03d%%" % int(round(charge / charge_max * 100.0))
	var boost: float = float(data.get("boost", 0.0))
	var boost_max: float = float(data.get("boost_max", 100.0))
	boost_bar.max_value = boost_max
	boost_bar.value = boost
	boost_label.text = "Boost: %03d%%" % int(round(boost / boost_max * 100.0))
	if data.get("boost_active", false):
		boost_label.modulate = Color(0.65, 1.0, 0.35)
	else:
		boost_label.modulate = Color(1.0, 1.0, 1.0)
	combo_label.text = "Combo: x%.2f" % float(data.get("combo", 1.0))
	time_label.text = "Time: %s" % _format_time(float(data.get("time", 0.0)))
	enemy_label.text = "Enemies: %d" % data.get("enemies", 0)


func show_state(state: int) -> void:
	match state:
		GameManager.RunState.MENU:
			overlay.visible = true
			overlay_label.text = "ABSTRACT SWARM\n\nClick or press Space"
		GameManager.RunState.PAUSED:
			overlay.visible = true
			overlay_label.text = "PAUSED\n\nEsc"
		GameManager.RunState.GAME_OVER:
			overlay.visible = true
			var score: int = manager.score if manager else 0
			var high: int = manager.high_score if manager else 0
			overlay_label.text = "RUN ENDED\n\nScore %d\nHigh %d\n\nR to restart" % [score, high]
		_:
			overlay.visible = false
			overlay_label.text = ""


func damage_feedback(_amount: float) -> void:
	flash_timer = 0.24


func extra_ready_feedback() -> void:
	ready_timer = 1.1
	ready_label.modulate.a = 1.0
	ready_label.text = "EXTRA READY"
	_play_tone(880.0, 0.12)


func boost_ready_feedback() -> void:
	ready_timer = 0.9
	ready_label.modulate.a = 1.0
	ready_label.text = "BOOST READY"
	_play_tone(660.0, 0.1)


func boost_feedback() -> void:
	ready_timer = 0.35
	ready_label.modulate.a = 1.0
	ready_label.text = "BOOST"


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

	score_label = _make_label(32)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.28))
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	high_score_label = _make_label(16)
	hp_label = _make_label()
	charge_label = _make_label()
	boost_label = _make_label()
	combo_label = _make_label()
	time_label = _make_label()
	enemy_label = _make_label(14)
	hud.add_child(score_label)
	hud.add_child(high_score_label)
	hud.add_child(hp_label)
	hud.add_child(charge_label)
	charge_bar = ProgressBar.new()
	charge_bar.custom_minimum_size = Vector2(260.0, 14.0)
	charge_bar.show_percentage = false
	charge_bar.min_value = 0.0
	charge_bar.max_value = 100.0
	_style_charge_bar()
	hud.add_child(charge_bar)
	hud.add_child(boost_label)
	boost_bar = ProgressBar.new()
	boost_bar.custom_minimum_size = Vector2(260.0, 14.0)
	boost_bar.show_percentage = false
	boost_bar.min_value = 0.0
	boost_bar.max_value = 100.0
	_style_boost_bar()
	hud.add_child(boost_bar)
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

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.z_index = 15
	flash_rect.color = Color(1.0, 0.0, 0.0, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)

	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)


func _make_label(size := 18) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _style_charge_bar() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.06, 0.08, 0.86)
	background.border_color = Color(0.25, 0.55, 0.7)
	background.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.85, 1.0, 0.94)
	charge_bar.add_theme_stylebox_override("background", background)
	charge_bar.add_theme_stylebox_override("fill", fill)


func _style_boost_bar() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.07, 0.05, 0.86)
	background.border_color = Color(0.45, 0.8, 0.28)
	background.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.45, 1.0, 0.25, 0.94)
	boost_bar.add_theme_stylebox_override("background", background)
	boost_bar.add_theme_stylebox_override("fill", fill)


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [int(total / 60), total % 60]


func _play_tone(frequency: float, duration: float) -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050
	stream.buffer_length = duration
	audio_player.stream = stream
	audio_player.play()
	var playback = audio_player.get_stream_playback()
	if not playback:
		return
	var frames := int(stream.mix_rate * duration)
	var phase := 0.0
	for i in range(frames):
		var fade: float = 1.0 - float(i) / float(maxi(1, frames))
		var sample := sin(phase) * 0.22 * fade
		playback.push_frame(Vector2(sample, sample))
		phase += TAU * frequency / stream.mix_rate

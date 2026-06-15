class_name RadialHud
extends Control

# Curved HUD drawn around the crosshair: small arc gauges for HP and the three
# charges, a directional red wedge when the player is hit, and amber/red ticks
# pointing toward the nearest threatening enemy. All angles are computed in
# screen space from the camera basis so the cues map to where things actually are.

const GAUGE_RADIUS := 58.0
const GAUGE_WIDTH := 6.0
const GAUGE_SPAN := 0.9
const GAUGE_SEGMENTS := 20

var player: PlayerController
var state: Dictionary = {}
var damage_marks: Array = []
var warn_active := false
var warn_angle := 0.0
var warn_strength := 0.0
var warn_is_bomb := false


func configure(_player: PlayerController) -> void:
	player = _player
	set_process(true)


func set_state(data: Dictionary) -> void:
	state = data
	warn_active = bool(data.get("warn_active", false))
	warn_is_bomb = bool(data.get("warn_is_bomb", false))
	if warn_active and player:
		var warn_position: Vector3 = data.get("warn_position", Vector3.ZERO)
		var warn_distance: float = float(data.get("warn_distance", 999.0))
		var warn_radius: float = float(data.get("warn_radius", 26.0))
		warn_angle = _screen_angle_to(warn_position)
		warn_strength = clamp(1.0 - warn_distance / max(1.0, warn_radius), 0.0, 1.0)
	else:
		warn_strength = 0.0
	queue_redraw()


func register_damage(world_position: Vector3) -> void:
	if not player:
		return
	damage_marks.append({"angle": _screen_angle_to(world_position), "time": 0.0, "max": 0.75})
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	for i in range(damage_marks.size() - 1, -1, -1):
		damage_marks[i]["time"] += delta
		if damage_marks[i]["time"] >= damage_marks[i]["max"]:
			damage_marks.remove_at(i)
	queue_redraw()


func _screen_angle_to(world_position: Vector3) -> float:
	if not player or not player.camera:
		return 0.0
	var camera: Camera3D = player.camera
	var to_target: Vector3 = world_position - camera.global_position
	var camera_basis: Basis = camera.global_transform.basis
	var right_component: float = to_target.dot(camera_basis.x)
	var up_component: float = to_target.dot(camera_basis.y)
	if abs(right_component) < 0.0001 and abs(up_component) < 0.0001:
		return PI * 0.5
	# Screen Y grows downward, so negate the up component.
	return atan2(-up_component, right_component)


func _draw() -> void:
	if state.is_empty():
		return
	var center: Vector2 = size * 0.5
	var pulse: float = (sin(float(Time.get_ticks_msec()) / 130.0) + 1.0) * 0.5

	var hp: float = float(state.get("hp", 0.0))
	var hp_max: float = max(0.001, float(state.get("max_hp", 3.0)))
	var hp_fraction: float = clamp(hp / hp_max, 0.0, 1.0)
	var hp_color: Color = Color(0.35, 1.0, 0.45).lerp(Color(1.0, 0.22, 0.16), 1.0 - hp_fraction)
	if bool(state.get("invulnerable", false)) and int(Time.get_ticks_msec() / 90) % 2 == 0:
		hp_color = Color(1.0, 0.9, 0.9)
	_draw_gauge(center, -PI * 0.5, hp_fraction, hp_color, hp_fraction <= 0.34, false)

	var extra: float = float(state.get("charge", 0.0))
	var extra_max: float = max(0.001, float(state.get("charge_max", 100.0)))
	_draw_gauge(center, PI, clamp(extra / extra_max, 0.0, 1.0), Color(0.3, 0.85, 1.0), extra >= extra_max, false, pulse)

	var shield: float = float(state.get("shield", 0.0))
	var shield_max: float = max(0.001, float(state.get("shield_max", 100.0)))
	_draw_gauge(center, 0.0, clamp(shield / shield_max, 0.0, 1.0), Color(0.4, 0.95, 1.0), shield >= shield_max, bool(state.get("shield_active", false)), pulse)

	var boost: float = float(state.get("boost", 0.0))
	var boost_max: float = max(0.001, float(state.get("boost_max", 100.0)))
	_draw_gauge(center, PI * 0.5, clamp(boost / boost_max, 0.0, 1.0), Color(0.5, 1.0, 0.32), boost >= boost_max, bool(state.get("boost_active", false)), pulse)

	if warn_strength > 0.02:
		_draw_warn(center, warn_angle, warn_strength, warn_is_bomb, pulse)

	for mark in damage_marks:
		_draw_damage(center, float(mark["angle"]), 1.0 - float(mark["time"]) / float(mark["max"]))


func _draw_gauge(center: Vector2, center_angle: float, fraction: float, color: Color, ready: bool, active: bool, pulse: float = 0.0) -> void:
	var start_angle: float = center_angle - GAUGE_SPAN * 0.5
	var end_angle: float = center_angle + GAUGE_SPAN * 0.5
	draw_arc(center, GAUGE_RADIUS, start_angle, end_angle, GAUGE_SEGMENTS, Color(0.08, 0.11, 0.16, 0.66), GAUGE_WIDTH, true)
	if fraction <= 0.0:
		return
	var fill_color: Color = color
	var width: float = GAUGE_WIDTH
	if active:
		fill_color = color.lerp(Color(1.0, 1.0, 1.0), 0.45)
		width = GAUGE_WIDTH + 2.0
	elif ready:
		fill_color = color.lerp(Color(1.0, 1.0, 1.0), 0.25 + pulse * 0.45)
		width = GAUGE_WIDTH + pulse * 1.6
	var fill_end: float = start_angle + fraction * (end_angle - start_angle)
	draw_arc(center, GAUGE_RADIUS, start_angle, fill_end, GAUGE_SEGMENTS, fill_color, width, true)


func _draw_warn(center: Vector2, angle: float, strength: float, is_bomb: bool, pulse: float) -> void:
	var outward: Vector2 = Vector2(cos(angle), sin(angle))
	var perpendicular: Vector2 = Vector2(-sin(angle), cos(angle))
	var inner_radius: float = GAUGE_RADIUS + 13.0
	var length: float = 11.0 + strength * 10.0
	var half_width: float = 5.0 + strength * 4.0
	# Red threat marker — visible early (faint when far) and intensifying as it nears.
	var base_color: Color = Color(1.0, 0.12, 0.06) if is_bomb else Color(1.0, 0.22, 0.14)
	var alpha: float = clamp(0.5 + strength * 0.5, 0.0, 1.0) * (0.78 + pulse * 0.22)
	base_color.a = alpha
	var tip: Vector2 = center + outward * (inner_radius + length)
	var base_a: Vector2 = center + outward * inner_radius + perpendicular * half_width
	var base_b: Vector2 = center + outward * inner_radius - perpendicular * half_width
	draw_colored_polygon(PackedVector2Array([tip, base_a, base_b]), base_color)
	# A faint red arc glow on that side so it reads even at the edge of awareness.
	draw_arc(center, GAUGE_RADIUS + 5.0, angle - 0.5, angle + 0.5, 14, Color(1.0, 0.15, 0.1, alpha * 0.4), 4.0, true)


func _draw_damage(center: Vector2, angle: float, life: float) -> void:
	var alpha: float = clamp(life, 0.0, 1.0)
	var color: Color = Color(1.0, 0.12, 0.06, 0.85 * alpha)
	var span: float = 0.55
	draw_arc(center, GAUGE_RADIUS + 9.0, angle - span, angle + span, 14, color, 11.0, true)
	draw_arc(center, GAUGE_RADIUS + 22.0, angle - span * 0.6, angle + span * 0.6, 10, Color(1.0, 0.2, 0.1, 0.5 * alpha), 5.0, true)

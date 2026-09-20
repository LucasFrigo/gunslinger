class_name PropRadialOverlay
extends Control
## Flat-harness equip wheel, drawn while `prop_radial` (Tab) is held. VR uses the
## world-space `PropRadial` wedges in front of the off hand instead.

const RADIUS := 130.0
const COLOR_IDLE := Color(0.85, 0.82, 0.75, 0.8)
const COLOR_HIGHLIGHT := Color(1.0, 0.78, 0.3)

var _labels := PackedStringArray()
var _highlight := -1


func show_wheel(labels: PackedStringArray) -> void:
	_labels = labels
	_highlight = -1
	visible = true
	queue_redraw()


func set_highlight(index: int) -> void:
	if index == _highlight:
		return
	_highlight = index
	queue_redraw()


func hide_wheel() -> void:
	visible = false
	_labels = PackedStringArray()


func _draw() -> void:
	if _labels.is_empty():
		return
	var font := ThemeDB.fallback_font
	var center := size * 0.5
	draw_circle(center, RADIUS + 40.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_arc(center, RADIUS, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 0.55), 3.0)
	for i in _labels.size():
		var angle := TAU * float(i) / float(_labels.size())
		var active := i == _highlight
		var color := COLOR_HIGHLIGHT if active else COLOR_IDLE
		var radius := 26.0 if active else 20.0
		var at := center + Vector2(sin(angle), -cos(angle)) * RADIUS
		draw_circle(at, radius, Color(color, 0.25))
		draw_arc(at, radius, 0.0, TAU, 32, color, 2.0)
		_draw_centered(font, at + Vector2(0.0, radius + 26.0), _labels[i], 18, color)
	var hint := "release to cancel" if _highlight < 0 else "release to equip"
	_draw_centered(font, center + Vector2(0.0, 6.0), hint, 16, Color(0.9, 0.88, 0.82, 0.8))


func _draw_centered(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at - Vector2(width * 0.5, 0.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

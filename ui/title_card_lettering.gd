class_name TitleCardLettering
extends Control
## A duel card name lettered at runtime, for a human or an archetype with no baked PNG:
## Ultra in capitals at the card's 480x270, letters stepping up to the right, a stepped
## extrusion down-left, a dark outline, and the face in the baked name's bands
## (`ui/title_card_name.gdshader`). Long names shrink to fit.

const SHADER := preload("res://ui/title_card_name.gdshader")
## Palette sampled from `assets/title_card_test/card_name.png`.
const OUTLINE_COLOR := Color("12051f")
const DEEP_COLOR := Color("7a1450")
const NEAR_COLOR := Color("e8283c")
## The face is drawn pure white; the shader swaps in the bands.
const FACE_COLOR := Color.WHITE
## Card pixels: left edge of the name (right edge when mirrored), the widest it may run,
## and the baseline of its first letter.
const NAME_LEFT := 16.0
const NAME_MAX_WIDTH := 400.0
const NAME_BASELINE := 238.0
const FONT_SIZE_MAX := 104
const FONT_SIZE_MIN := 20
const FONT_SIZE_STEP := 4
## Rise of each letter over the one before it, and the most the whole name rises.
const LETTER_RISE := 3.0
const RISE_MAX := 18.0
## Extrusion depth at full size (one step down-left per pixel), and the least a shrunk name
## keeps. The first step is the near colour.
const EXTRUDE := 5
const EXTRUDE_MIN := 2
const OUTLINE_SIZE := 4
## Face height shares where the middle and the low band start.
const BAND_MID := 0.55
const BAND_LOW := 0.78
## Share of the font ascent the capitals fill.
const CAP_SHARE := 0.72

var _text := ""
var _mirrored := false
var _font_size := FONT_SIZE_MAX
var _rise := LETTER_RISE
var _extrude := EXTRUDE
var _origin := Vector2.ZERO
var _advances: PackedFloat32Array = []
var _material: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material


## Lays `text` out in capitals, left on a normal card and right on a mirrored one.
func set_name_text(text: String, mirrored: bool) -> void:
	_text = text.to_upper()
	_mirrored = mirrored
	_layout()
	queue_redraw()


func get_text() -> String:
	return _text


func get_font_size() -> int:
	return _font_size


func _layout() -> void:
	var font := UiFonts.TITLE
	var count := _text.length()
	_rise = minf(LETTER_RISE, RISE_MAX / maxf(count - 1, 1))
	_font_size = FONT_SIZE_MAX
	var width := _measure(font, _font_size)
	while width > NAME_MAX_WIDTH and _font_size > FONT_SIZE_MIN:
		_font_size -= FONT_SIZE_STEP
		width = _measure(font, _font_size)
	_extrude = clampi(roundi(float(EXTRUDE * _font_size) / FONT_SIZE_MAX), EXTRUDE_MIN, EXTRUDE)
	_advances.resize(count)
	for i in count:
		_advances[i] = font.get_char_size(_text.unicode_at(i), _font_size).x
	var left := NAME_LEFT if not _mirrored else TitleCard.SIZE.x - NAME_LEFT - width
	# The face sits up-right of its extrusion, so it starts that far in and up.
	_origin = Vector2(roundf(left + _extrude), NAME_BASELINE - _extrude)
	var cap := font.get_ascent(_font_size) * CAP_SHARE
	var top := _origin.y - cap
	_material.set_shader_parameter("mid_from", top + cap * BAND_MID)
	_material.set_shader_parameter("low_from", top + cap * BAND_LOW)


## Face width plus the extrusion and the outline.
func _measure(font: Font, font_size: int) -> float:
	var width := 0.0
	for i in _text.length():
		width += font.get_char_size(_text.unicode_at(i), font_size).x
	return width + EXTRUDE + OUTLINE_SIZE


func _draw() -> void:
	if _text.is_empty():
		return
	var font := UiFonts.TITLE
	# Pass by pass over the whole name, so no letter's extrusion covers its neighbour's face.
	for step in range(_extrude, -1, -1):
		_draw_copy(font, step, OUTLINE_COLOR, true)
	for step in range(_extrude, 1, -1):
		_draw_copy(font, step, DEEP_COLOR, false)
	_draw_copy(font, 1, NEAR_COLOR, false)
	_draw_copy(font, 0, FACE_COLOR, false)


func _draw_copy(font: Font, step: int, color: Color, outline: bool) -> void:
	var pen := _origin + Vector2(-step, step)
	for i in _text.length():
		var at := Vector2(roundf(pen.x), roundf(pen.y - i * _rise))
		var code := _text.unicode_at(i)
		if outline:
			draw_char_outline(font, at, char(code), _font_size, OUTLINE_SIZE, color)
		else:
			draw_char(font, at, char(code), _font_size, color)
		pen.x += _advances[i]

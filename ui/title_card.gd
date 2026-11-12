class_name TitleCard
extends SubViewport
## One duel title card, drawn at the card's native 480x270 for Nearest scaling: the
## backdrop, the fx, and the name (a baked PNG on the same canvas, else `TitleCardLettering`).
## The layers slide in from the card's side, the backdrop first; the name bobs in whole
## pixels while the card holds, then everything slides back out. A mirrored card flips the
## backdrop and fx, puts the name on the right, and slides from the right.
## `DuelIntro` shows the texture on the flat screen or a head-locked VR quad.

## The name landed (the sting).
signal landed

const SIZE := Vector2i(480, 270)
const BACKDROP_PATH := "res://assets/ui/title_card/card_backdrop.png"
const FX_PATH := "res://assets/ui/title_card/card_fx.png"
## Seconds: each layer's slide in, the fx and name's lag behind the backdrop, the hold
## once the name lands, and the slide out.
const SLIDE_IN := 0.22
const LAYER_LAG := 0.1
const HOLD := 2.0
const SLIDE_OUT := 0.2
const LAND_AT := LAYER_LAG + SLIDE_IN
const OUT_AT := LAND_AT + HOLD
const DURATION := OUT_AT + SLIDE_OUT
## Name bob: card pixels each way, and seconds per cycle.
const BOB_PX := 2.0
const BOB_PERIOD := 1.6

var _backdrop: TextureRect
var _fx: TextureRect
var _baked: TextureRect
var _lettering: TitleCardLettering
var _elapsed := 0.0
var _playing := false
var _mirrored := false
var _landed := false
## Baked name: card pixels it moves right on a mirrored card.
var _baked_shift := 0
## Baked name texture -> its used rect, read once.
var _used_rects := {}


func _init() -> void:
	size = SIZE
	transparent_bg = true
	disable_3d = true
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_backdrop = _layer(load(BACKDROP_PATH))
	_fx = _layer(load(FX_PATH))
	_baked = _layer(null)
	_lettering = TitleCardLettering.new()
	_lettering.size = Vector2(SIZE)
	add_child(_lettering)
	_hide_layers()


func _ready() -> void:
	set_process(false)


func is_playing() -> bool:
	return _playing


func is_mirrored() -> bool:
	return _mirrored


## The name this card letters at runtime ("" while a baked PNG shows).
func lettered_text() -> String:
	return _lettering.get_text() if _lettering.visible else ""


func play(display_name: String, baked_name: Texture2D, mirrored: bool) -> void:
	_mirrored = mirrored
	_elapsed = 0.0
	_landed = false
	_playing = true
	_backdrop.flip_h = mirrored
	_fx.flip_h = mirrored
	_baked.texture = baked_name
	_baked.visible = baked_name != null
	_lettering.visible = baked_name == null
	if baked_name != null:
		var used := _used_rect(baked_name)
		_baked_shift = (SIZE.x - used.end.x) - used.position.x if mirrored else 0
	else:
		_lettering.set_name_text(display_name, mirrored)
	_backdrop.visible = true
	_fx.visible = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)
	_apply(0.0)


func stop() -> void:
	_playing = false
	set_process(false)
	_hide_layers()
	render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	_elapsed += delta / maxf(Engine.time_scale, 0.001)
	if not _landed and _elapsed >= LAND_AT:
		_landed = true
		landed.emit()
	_apply(_elapsed)
	if _elapsed >= DURATION:
		_playing = false
		set_process(false)
		_hide_layers()


func _apply(t: float) -> void:
	var back_x := _slide_x(t, 0.0)
	var front_x := _slide_x(t, LAYER_LAG)
	_backdrop.position = Vector2(back_x, 0.0)
	_fx.position = Vector2(front_x, 0.0)
	var bob := 0.0
	if t >= LAND_AT and t < OUT_AT:
		bob = roundf(BOB_PX * sin(TAU * (t - LAND_AT) / BOB_PERIOD))
	_baked.position = Vector2(front_x + _baked_shift, bob)
	_lettering.position = Vector2(front_x, bob)


## Whole-pixel x of a layer that starts sliding `lag` seconds in: off the card's side, in,
## and back out the same side.
func _slide_x(t: float, lag: float) -> float:
	var off := float(-SIZE.x if not _mirrored else SIZE.x)
	if t >= OUT_AT:
		var u := clampf((t - OUT_AT) / SLIDE_OUT, 0.0, 1.0)
		return roundf(off * u * u)
	var v := clampf((t - lag) / SLIDE_IN, 0.0, 1.0)
	return roundf(off * pow(1.0 - v, 3.0))


func _used_rect(texture: Texture2D) -> Rect2i:
	if not _used_rects.has(texture):
		var image := texture.get_image()
		_used_rects[texture] = image.get_used_rect() if image != null else Rect2i(Vector2i.ZERO, SIZE)
	return _used_rects[texture]


func _layer(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.size = Vector2(SIZE)
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _hide_layers() -> void:
	_backdrop.visible = false
	_fx.visible = false
	_baked.visible = false
	_lettering.visible = false

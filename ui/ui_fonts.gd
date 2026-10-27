class_name UiFonts
extends RefCounted
## Duello type for labels built in code: Ultra for titles and signs, Bitter for copy and readouts.

const TITLE: FontFile = preload("res://assets/fonts/Ultra-Regular.ttf")
const BODY: FontFile = preload("res://assets/fonts/Bitter-Regular.ttf")
const BOLD: FontFile = preload("res://assets/fonts/Bitter-SemiBold.ttf")


## Rasterizes printable ASCII plus every other glyph in `texts` into the font cache at `size`
## and `outline` (the pair a Label3D asks for). Otherwise the first label rebuild that shows
## a new glyph renders it on the spot, mid-frame.
static func warm_glyphs(font: FontFile, size: int, outline: int, texts: PackedStringArray) -> void:
	var extra := {}
	for text in texts:
		for i in text.length():
			var code := text.unicode_at(i)
			if code > 0x7E:
				extra[code] = true
	for edge in [0, outline]:
		var key := Vector2i(size, edge)
		font.render_range(0, key, 0x21, 0x7E)
		for code: int in extra:
			font.render_range(0, key, code, code)

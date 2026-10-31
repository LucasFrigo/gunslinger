class_name MenuDialog
extends Control
## Centered modal chrome shared by Settings / Lobby / mode-config content in
## the HL2-style menus. The host (MainMenu / PauseMenu) owns which child of
## %DialogContent is visible; this component only owns the scrim, the title
## bar, and the one shared Back button.

signal back_pressed

const BACKDROP_SOLID_ALPHA := 0.94
const BACKDROP_FLAT_ALPHA := 0.2

@onready var scrim: ColorRect = %Scrim
@onready var title_label: Label = %DialogTitleLabel
@onready var content_slot: Control = %DialogContent
@onready var back_button: Button = %DialogBackButton


func _ready() -> void:
	visible = false
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	MenuSfx.wire(back_button, self)
	for b: Button in content_slot.find_children("*", "Button", true, false):
		MenuSfx.wire(b, self)


func open(title: String) -> void:
	title_label.text = title
	visible = true


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func set_dim(solid: bool) -> void:
	scrim.color.a = BACKDROP_SOLID_ALPHA if solid else BACKDROP_FLAT_ALPHA

class_name LoadingScreen
extends Control
## Fullscreen boot overlay. Shown until combat AV shaders / audio compile,
## then the main menu takes over.

@onready var _status: Label = %Status
@onready var _bar: ProgressBar = %ProgressBar
@onready var _version: Label = %VersionLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_version.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	set_progress(0.0, "Loading...")


func show_screen() -> void:
	visible = true
	set_progress(0.0, "Loading...")


func hide_screen() -> void:
	visible = false


func set_progress(amount: float, status: String) -> void:
	if _bar != null:
		_bar.value = clampf(amount, 0.0, 1.0)
	if _status != null and not status.is_empty():
		_status.text = status

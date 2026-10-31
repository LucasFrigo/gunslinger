class_name MenuSfx
extends RefCounted
## Wires the HL2-style hover tick / press click onto a menu Button. `host` is a
## long-lived node (the menu root or MenuDialog) that outlives the transient
## AudioStreamPlayer, matching the pattern in autoload/impact_feedback.gd.

static func wire(button: Button, host: Node) -> void:
	button.mouse_entered.connect(_play.bind(&"ui_hover", host))
	button.pressed.connect(_play.bind(&"ui_click", host))


static func _play(cue: StringName, host: Node) -> void:
	var stream := AudioCatalog.get_stream(cue)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.autoplay = true
	host.add_child(player)
	player.finished.connect(player.queue_free)

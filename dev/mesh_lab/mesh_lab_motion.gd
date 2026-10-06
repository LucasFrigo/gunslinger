class_name MeshLabMotion
extends RefCounted
## Shared on/off flags for the mesh lab. The flat puppet and the live VR
## player both read these. The motion menu writes them. All three start on.

static var head := true
static var walk := true
static var hands := true


static func reset() -> void:
	head = true
	walk = true
	hands = true

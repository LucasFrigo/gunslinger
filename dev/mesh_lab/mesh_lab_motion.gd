class_name MeshLabMotion
extends RefCounted
## Shared on/off flags for the mesh lab. The flat puppet and the live VR
## player both read these. The motion menu writes them. Head, walk, and hands start
## on; the drop test starts off. chunk_step counts presses of the chunk key (5).

static var head := true
static var walk := true
static var hands := true
static var drop := false
static var chunk_step := 0


static func reset() -> void:
	head = true
	walk = true
	hands = true
	drop = false
	chunk_step = 0

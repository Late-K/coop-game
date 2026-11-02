class_name Door
extends AnimatableBody3D
## A sliding blast door that sinks into the floor when opened.
## Pure presentation: whoever owns the logic (a puzzle, on the server) calls set_open on every peer.

const OPEN_DROP := 2.6
const MOVE_TIME := 1.2

var is_open := false

@onready var _closed_y := position.y


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:y", _closed_y - (OPEN_DROP if open else 0.0), MOVE_TIME) \
			.set_trans(Tween.TRANS_SINE)

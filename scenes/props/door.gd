class_name Door
extends AnimatableBody3D
## A sliding blast door that sinks into the floor when opened.
## Pure presentation: whoever owns the logic (a puzzle, on the server) calls set_open on
## every peer, or `sync_open.rpc(...)` from the server.

const OPEN_DROP := 2.6
const MOVE_TIME := 1.2

## Placed closed in the editor; starts sunk into the floor when true (e.g. an entrance).
@export var start_open := false
## Saved (SaveGame): reloading after a death puts this back as it was at the last save,
## unless it should stay as it is now.
@export var keep_on_reload := false

var is_open := false

@onready var _closed_y := position.y


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	if start_open:
		is_open = true
		position.y = _closed_y - OPEN_DROP


func save_state() -> Variant:
	return is_open


## Instant: reloads happen behind a black screen.
func load_state(state: Variant) -> void:
	is_open = state
	position.y = _closed_y - (OPEN_DROP if is_open else 0.0)


@rpc("authority", "call_local", "reliable")
func sync_open(open: bool) -> void:
	set_open(open)


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	Sound.play_at("door", global_position, 0.0, 25.0)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:y", _closed_y - (OPEN_DROP if open else 0.0), MOVE_TIME) \
			.set_trans(Tween.TRANS_SINE)

class_name Door
extends AnimatableBody3D
## A sliding blast door that sinks into the floor when opened.
##
## Without a lock it is pure presentation: whoever owns the logic (a puzzle or trigger, on
## the server) calls `sync_open.rpc(...)`. With `manual`, players open it by hand.
## Signalis-style locks make the door part of the sector's structure, and the MAP shows them:
## - KEY: opens with `key_item`, chosen from the inventory (and used up if `consume_key`).
## - BARRED: barred on one side; opens from that side only. A shortcut back, once opened.
## - POWER: dead until a puzzle powers it (`set_powered`), then it opens by hand.
## The server owns whether it is locked and open; both are saved.

enum Lock { NONE, KEY, BARRED, POWER }

const OPEN_DROP := 2.6
const MOVE_TIME := 1.2

## Placed closed in the editor; starts sunk into the floor when true (e.g. an entrance).
@export var start_open := false
@export var lock := Lock.NONE
## KEY: the item that opens it.
@export var key_item := ""
## KEY: the key is used up (Signalis keys go once their last door is open).
@export var consume_key := true
## BARRED: the side it can be unbarred from, along the door's local X (it spans Z).
@export_enum("plus_x", "minus_x") var barred_side := "plus_x"
## Opens by hand (interact) once unlocked, instead of only by a puzzle or trigger. Doors
## opened by hand stay open, as in Signalis (the handle sinks with the door).
@export var manual := false
## Saved (SaveGame): reloading after a death puts this back as it was at the last save,
## unless it should stay as it is now.
@export var keep_on_reload := false

var is_open := false
## Server-owned, synced: still held shut by its lock.
var locked := false

@onready var _closed_y := position.y


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	add_to_group("doors")
	locked = lock != Lock.NONE
	if start_open:
		is_open = true
		locked = false
		position.y = _closed_y - OPEN_DROP
	if lock != Lock.NONE or manual:
		var handle := DoorHandle.new()
		handle.door = self
		add_child(handle)


## Where the door stands in its wall, open or not (an open door has sunk into the floor).
func frame_position() -> Vector3:
	return global_position + Vector3(0, _closed_y - position.y, 0)


## What the map shows: "open", "key", "barred", "power" or "shut" (closed, puzzle-driven).
func map_state() -> String:
	if is_open:
		return "open"
	if locked:
		return ["shut", "key", "barred", "power"][lock]
	return "shut" if not manual else "open"


func save_state() -> Variant:
	return {"open": is_open, "locked": locked}


## Instant: reloads happen behind a black screen.
func load_state(state: Variant) -> void:
	if state is bool: # saves from before doors had locks
		state = {"open": state, "locked": locked}
	is_open = state["open"]
	locked = state["locked"]
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


## Server: a puzzle switches the power on (a POWER door unlocks; it then opens by hand).
func set_powered(powered: bool) -> void:
	if lock == Lock.POWER:
		_sync_lock.rpc(not powered, is_open)


# --- By hand (DoorHandle) -----------------------------------------------------------

func prompt_for(player: Player) -> String:
	if not locked:
		return "" if is_open else "Open door"
	match lock:
		Lock.KEY:
			return "Locked (%s)" % Items.display_name(key_item).to_lower()
		Lock.BARRED:
			return "Unbar door" if _on_barred_side(player) else "Barred from the other side"
		Lock.POWER:
			return "No power"
	return ""


func use(player: Player) -> void:
	if not locked:
		if not is_open:
			_request.rpc_id(1, "open")
		return
	match lock:
		Lock.KEY:
			player.open_inventory(get_node("DoorHandle"))
		Lock.BARRED:
			if _on_barred_side(player):
				Sound.play_ui("keypad_press", -4.0, 0.6)
				_request.rpc_id(1, "unbar")
			else:
				player.notify("It won't move. Something holds it from the other side")
				Sound.play_ui("code_wrong", -10.0)
		Lock.POWER:
			player.notify("The panel is dead")


## Called through the terminal when a KEY door is used: only its key fits.
func try_key(player: Player, index: int) -> bool:
	if player.inventory.slots[index]["id"] != key_item:
		player.notify("That doesn't fit")
		Sound.play_ui("code_wrong", -8.0)
		return false
	if consume_key:
		player.inventory.remove_from(index, 1)
	Sound.play_ui("keypad_press", -2.0, 0.8)
	_request.rpc_id(1, "key")
	return true


func _on_barred_side(player: Player) -> bool:
	var side := to_local(player.global_position).x
	return side > 0.0 if barred_side == "plus_x" else side < 0.0


@rpc("any_peer", "call_local", "reliable")
func _request(action: String) -> void:
	if not multiplayer.is_server():
		return
	match action:
		"key", "unbar":
			if locked:
				_sync_lock.rpc(false, true)
		"open":
			if not locked and (manual or lock != Lock.NONE):
				_sync_lock.rpc(false, true)


@rpc("authority", "call_local", "reliable")
func _sync_lock(now_locked: bool, open: bool) -> void:
	locked = now_locked
	set_open(open)

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
## - ICE: frozen shut under a crust of frost until a heater next to it runs (Heater.doors):
##   the frost melts and the door can be opened.
## - CODE: sealed until a puzzle releases it (`unlock`, e.g. a SymbolCodePuzzle's door).
## Opened by hand, a door lets you through: the player walks through on their own
## (Player.pass_through) and it shuts behind them once the doorway is clear, so there is
## always a door between you and what follows (enemies can't open doors). `stays_open`
## keeps one open. Doors a puzzle opens (not by hand) stay as the puzzle leaves them.
## Opening one shows nothing past it: that room lights once you're in it, and the room you
## left fades out as the door rises behind you. One held open for good joins both sides
## (RoomShroud).
## The server owns whether it is locked and open; both are saved.

enum Lock { NONE, KEY, BARRED, POWER, ICE, CODE }

const OPEN_DROP := 2.6
const MOVE_TIME := 1.2
const SLAM_TIME := 0.12
## Seconds a door opened by hand stays open once whoever went through has cleared the
## doorway; and the longest it waits for someone to go through at all.
const CLOSE_DELAY := 0.6
const UNUSED_CLOSE := 5.0
## Seconds after a door is opened by hand that whoever goes through is spared by enemies
## (Enemy.passing_door): the walk through is out of their hands.
const PASS_GRACE := 3.0

## Placed closed in the editor; starts sunk into the floor when true (e.g. an entrance).
@export var start_open := false
@export var lock := Lock.NONE
## KEY: the item that opens it.
@export var key_item := ""
## KEY: the key is used up (Signalis keys go once their last door is open).
@export var consume_key := true
## BARRED: the side it can be unbarred from, along the door's local X (it spans Z).
@export_enum("plus_x", "minus_x") var barred_side := "plus_x"
## Opens by hand (interact) once unlocked, instead of only by a puzzle or trigger.
@export var manual := false
## Opened by hand, it stays open instead of shutting behind you.
@export var stays_open := false
## Saved (SaveGame): reloading after a death puts this back as it was at the last save,
## unless it should stay as it is now.
@export var keep_on_reload := false

var is_open := false
## Server-owned, synced: still held shut by its lock.
var locked := false
var _frost: MeshInstance3D
var _clear_time := 0.0
## Server: opened by hand, so it shuts again behind whoever went through.
var _by_hand := false
## Server: someone has stood in the doorway since it opened (so "clear" means behind them).
var _used := false
var _open_time := 0.0

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
	if lock == Lock.ICE:
		_add_frost()
	set_physics_process(multiplayer.is_server())


## Server: a door opened by hand shuts once its doorway has been clear for a moment.
func _physics_process(delta: float) -> void:
	if not is_open or locked or not _by_hand or stays_open:
		_clear_time = 0.0
		_open_time = 0.0
		_used = false
		return
	_open_time += delta
	if _doorway_occupied():
		_used = true
		_clear_time = 0.0
	else:
		_clear_time += delta
	if (_used and _clear_time >= CLOSE_DELAY) or (not _used and _open_time >= UNUSED_CLOSE):
		_clear_time = 0.0
		_by_hand = false
		_sync_lock.rpc(false, false)


## A player in the doorway (enemies never step into one, and one waiting beside it mustn't
## hold the door open).
func _doorway_occupied() -> bool:
	for body: Node3D in get_tree().get_nodes_in_group("players"):
		var local := global_transform.affine_inverse() * body.global_position
		if absf(local.x) < 1.1 and absf(local.z) < 1.8:
			return true
	return false


## Where the door stands in its wall, open or not (an open door has sunk into the floor).
func frame_position() -> Vector3:
	return global_position + Vector3(0, _closed_y - position.y, 0)


## Server: opened by hand moments ago, so someone is on their way through.
func letting_through() -> bool:
	return is_open and _by_hand and not stays_open and _open_time < PASS_GRACE


## Open for good, not just while someone goes through: a puzzle's door (no lock, not by
## hand) left open, or one that stays open. The rooms either side then light as one.
func held_open() -> bool:
	return is_open and (stays_open or (lock == Lock.NONE and not manual))


## What the map shows: "open", "key", "barred", "power" or "shut" (closed, puzzle-driven).
func map_state() -> String:
	if is_open:
		return "open"
	if locked:
		return ["shut", "key", "barred", "power", "iced", "shut"][lock]
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
	RoomShroud.doors_changed = true
	if _frost:
		_frost.visible = locked


@rpc("authority", "call_local", "reliable")
func sync_open(open: bool) -> void:
	set_open(open)


func set_open(open: bool) -> void:
	if open and lock == Lock.ICE and locked:
		_thaw() # thawed, not opened: it opens by hand now
		return
	if open == is_open:
		return
	is_open = open
	RoomShroud.doors_changed = true
	Sound.play_at("door", global_position, 0.0, 25.0)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:y", _closed_y - (OPEN_DROP if open else 0.0), MOVE_TIME) \
			.set_trans(Tween.TRANS_SINE)


## Comes down hard, all at once (Chapter 1's entrance), and stays shut: called on every
## machine by whatever brings it down.
func slam() -> void:
	is_open = false
	locked = true
	RoomShroud.doors_changed = true
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:y", _closed_y, SLAM_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Server: a puzzle switches the power on (a POWER door unlocks; it then opens by hand).
func set_powered(powered: bool) -> void:
	if lock == Lock.POWER:
		_sync_lock.rpc(not powered, is_open)


## Server: a puzzle releases a CODE door (it then opens by hand).
func unlock() -> void:
	if locked:
		_sync_lock.rpc(false, is_open)


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
		Lock.ICE:
			return "Frozen shut"
		Lock.CODE:
			return "Sealed"
	return ""


func use(player: Player) -> void:
	if not locked:
		if not is_open:
			_request.rpc_id(1, "open")
			player.pass_through(self)
		return
	match lock:
		Lock.KEY:
			player.open_inventory(get_node("DoorHandle"))
		Lock.BARRED:
			if _on_barred_side(player):
				Sound.play_ui("keypad_press", -4.0, 0.6)
				_request.rpc_id(1, "unbar")
				player.pass_through(self)
			else:
				player.notify("It won't move. Something holds it from the other side")
				Sound.play_ui("code_wrong", -10.0)
		Lock.POWER:
			player.notify("The panel is dead")
		Lock.ICE:
			player.notify("Frozen solid. It won't move until something thaws it")
		Lock.CODE:
			player.notify("Sealed. It won't open without its release code")


## The ICE lock: a crust of frost over both faces, a little proud of the door.
func _add_frost() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.9, 1.0, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.set_meta("retro_skip", true)
	_frost = MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(0.5, Kit.WALL_HEIGHT - 0.1, Kit.DOOR_WIDTH - 0.1)
	_frost.mesh = slab
	_frost.material_override = material
	add_child(_frost)


## The heater's warmth gets to it: the frost runs off and the lock lets go.
func _thaw() -> void:
	locked = false
	if _frost and _frost.visible:
		var material := _frost.material_override as StandardMaterial3D
		var tween := create_tween()
		tween.tween_property(material, "albedo_color:a", 0.0, 1.5)
		tween.tween_callback(func() -> void: _frost.visible = false)


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
	player.pass_through(self)
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
				_by_hand = true
				_sync_lock.rpc(false, true)
		"open":
			if not locked and (manual or lock != Lock.NONE):
				_by_hand = true
				_sync_lock.rpc(false, true)


@rpc("authority", "call_local", "reliable")
func _sync_lock(now_locked: bool, open: bool) -> void:
	locked = now_locked
	set_open(open)

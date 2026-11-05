class_name SymbolCodePuzzle
extends Node
## Cross-player code puzzle: the code is shown somewhere (a monitor in the other room,
## paint on top of walls...) and a keypad accepts it.
##
## The server owns all state (code, entry, solved) and pushes it to both peers;
## clients only ever send keypad presses.

const CODE_LENGTH := 4

@export var keypad: Keypad
## Anything with show_code(code: PackedInt32Array): CodeMonitor, WallCodeDisplay...
@export var display: Node3D
## Opened while solved; a CODE door is released instead (it then opens by hand).
@export var doors: Array[Door] = []
## Switched on while solved: anything with set_active(bool) (PowerLight, TemperatureZone...).
@export var activate: Array[Node] = []
## Story lines played for both players when the code is accepted.
@export var solved_lines: Array[String] = []

## Saved (SaveGame): reloading after a death puts this back as it was at the last save,
## unless it should stay as it is now. A learned code stays solved by default.
@export var keep_on_reload := true

var code := PackedInt32Array()
var entered := PackedInt32Array()
var solved := false


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	keypad.symbol_pressed.connect(_on_keypad_symbol_pressed)
	if not multiplayer.is_server():
		# Ask once our copy of the level exists; pushing from the server could arrive too early.
		_request_state.rpc_id(1)
		return
	for i in CODE_LENGTH:
		code.append(randi() % Symbols.COUNT)
	var names := PackedStringArray()
	for symbol in code:
		names.append(Symbols.NAMES[symbol])
	print("[puzzle] code: %s" % ", ".join(names))
	_apply_state(code, entered, solved)


func _on_keypad_symbol_pressed(symbol: int) -> void:
	submit_symbol.rpc_id(1, symbol)


@rpc("any_peer", "reliable")
func _request_state() -> void:
	if multiplayer.is_server():
		_apply_state.rpc_id(multiplayer.get_remote_sender_id(), code, entered, solved)


@rpc("any_peer", "call_local", "reliable")
func submit_symbol(symbol: int) -> void:
	if not multiplayer.is_server() or solved or symbol < 0 or symbol >= Symbols.COUNT:
		return
	entered.append(symbol)
	if entered.size() == CODE_LENGTH:
		solved = entered == code
		if not solved:
			entered = PackedInt32Array()
		_play_feedback.rpc(solved)
		if solved:
			Story.play(solved_lines)
	_broadcast_state()


func _broadcast_state() -> void:
	_apply_state.rpc(code, entered, solved)


@rpc("authority", "call_local", "reliable")
func _apply_state(new_code: PackedInt32Array, new_entered: PackedInt32Array, new_solved: bool) -> void:
	code = new_code
	entered = new_entered
	solved = new_solved
	display.show_code(code)
	keypad.show_entry(entered)
	for door in doors:
		if door.lock == Door.Lock.CODE:
			if solved and multiplayer.is_server():
				door.unlock()
		else:
			door.set_open(solved)
	for node in activate:
		node.set_active(solved)


func save_state() -> Variant:
	return {"code": code, "solved": solved}


func load_state(state: Variant) -> void:
	_apply_state(state["code"], PackedInt32Array(), state["solved"])


@rpc("authority", "call_local", "reliable")
func _play_feedback(correct: bool) -> void:
	print("[puzzle] %s code entered (peer %d)" % ["correct" if correct else "wrong", multiplayer.get_unique_id()])
	keypad.flash(correct)

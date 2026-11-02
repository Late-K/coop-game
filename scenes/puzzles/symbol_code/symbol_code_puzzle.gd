class_name SymbolCodePuzzle
extends Node
## First cross-player puzzle: the code is shown on a monitor in one room and the
## keypad that accepts it is in the other, so one player reads and the other enters.
##
## The server owns all state (code, entry, solved) and pushes it to both peers;
## clients only ever send keypad presses.

const CODE_LENGTH := 4

@export var keypad: Keypad
@export var monitor: CodeMonitor
@export var door: Door

var code := PackedInt32Array()
var entered := PackedInt32Array()
var solved := false


func _ready() -> void:
	keypad.symbol_pressed.connect(_on_keypad_symbol_pressed)
	if not multiplayer.is_server():
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	for i in CODE_LENGTH:
		code.append(randi() % Symbols.COUNT)
	var names := PackedStringArray()
	for symbol in code:
		names.append(Symbols.NAMES[symbol])
	print("[puzzle] code: %s" % ", ".join(names))
	_broadcast_state()


func _on_keypad_symbol_pressed(symbol: int) -> void:
	submit_symbol.rpc_id(1, symbol)


func _on_peer_connected(id: int) -> void:
	_apply_state.rpc_id(id, code, entered, solved)


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
	_broadcast_state()


func _broadcast_state() -> void:
	_apply_state.rpc(code, entered, solved)


@rpc("authority", "call_local", "reliable")
func _apply_state(new_code: PackedInt32Array, new_entered: PackedInt32Array, new_solved: bool) -> void:
	code = new_code
	entered = new_entered
	solved = new_solved
	monitor.show_code(code)
	keypad.show_entry(entered)
	door.set_open(solved)


@rpc("authority", "call_local", "reliable")
func _play_feedback(correct: bool) -> void:
	print("[puzzle] %s code entered (peer %d)" % ["correct" if correct else "wrong", multiplayer.get_unique_id()])
	keypad.flash(correct)

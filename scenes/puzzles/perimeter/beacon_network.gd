class_name BeaconNetwork
extends Node
## The "Perimeter" puzzle. The Visitor is lost in a whiteout and can only read the
## symbols on nearby posts. The Subject has a map of the posts and a switchboard
## (a Keypad: one button per symbol) but no idea where the Visitor is. From what
## the Visitor describes, the Subject works out where they are and lights a trail
## to the airlock. Only MAX_LIT lamps can burn at once, so guessing is expensive.
##
## The server owns which lamps are lit; clients only send button presses.

signal lamps_changed

const MAX_LIT := 2

@export var keypad: Keypad
@export var lamps: Array[BeaconLamp] = []

## Symbols of the lit lamps, oldest first.
## Saved (SaveGame): reloading after a death puts this back as it was at the last save,
## unless it should stay as it is now.
@export var keep_on_reload := false

var lit := PackedInt32Array()


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	keypad.symbol_pressed.connect(func(symbol: int) -> void: _toggle.rpc_id(1, symbol))
	if not multiplayer.is_server():
		_request_state.rpc_id(1)
		return
	_apply_state(lit)


func lamp_with_symbol(symbol: int) -> BeaconLamp:
	for lamp in lamps:
		if lamp.symbol == symbol:
			return lamp
	return null


@rpc("any_peer", "call_local", "reliable")
func _toggle(symbol: int) -> void:
	if not multiplayer.is_server() or lamp_with_symbol(symbol) == null:
		return
	var index := lit.find(symbol)
	if index >= 0:
		lit.remove_at(index)
	else:
		lit.append(symbol)
		if lit.size() > MAX_LIT:
			lit.remove_at(0) # the oldest lamp goes dark
	_apply_state.rpc(lit)


func save_state() -> Variant:
	return lit


func load_state(state: Variant) -> void:
	_apply_state(state)


@rpc("any_peer", "reliable")
func _request_state() -> void:
	if multiplayer.is_server():
		_apply_state.rpc_id(multiplayer.get_remote_sender_id(), lit)


@rpc("authority", "call_local", "reliable")
func _apply_state(new_lit: PackedInt32Array) -> void:
	lit = new_lit
	for lamp in lamps:
		lamp.set_active(lamp.symbol in lit)
	keypad.show_entry(lit)
	lamps_changed.emit()

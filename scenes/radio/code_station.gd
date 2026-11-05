class_name CodeStation
extends RadioSignal
## A numbers station that reads a code (Chapter 1, puzzle 6: chamber 02). It's a
## SymbolCodePuzzle's display: the code it reads is the one the puzzle's keypad wants. Its
## frequency is picked by the server each playthrough, well away from the partner channel,
## and written up as red paint (`paint`, a WallText: unreadable to the Subject, clear to
## the Visitor, on the wall and on camera). Heard only near it (`audible_range`), so only
## whoever stands in the chamber can tune it in, and tuning to it loses the partner.

## Red writing that gives the frequency away (its {frequency} placeholder is filled in).
@export var paint: WallText
@export_multiline var paint_message := "{frequency}\nTHEY READ\nIT TO YOU"
@export var keep_on_reload := true


func _ready() -> void:
	super()
	add_to_group(SaveGame.SAVED_GROUP)
	sound = "radio_numbers" if sound.is_empty() else sound
	shape = "voice"
	if multiplayer.is_server():
		_set_frequency(_pick())
	else:
		_request_frequency.rpc_id(1)


## Server: somewhere on the band, clear of the partner channel and every other station.
func _pick() -> float:
	var taken: Array[float] = [Radio.channel, Radio.HOME_FREQUENCY]
	for station: RadioSignal in get_tree().get_nodes_in_group("radio_signals"):
		if station != self:
			taken.append(station.frequency)
	var picked := Radio.channel
	while taken.any(func(f: float) -> bool: return absf(picked - f) < 4.0):
		picked = snappedf(randf_range(Radio.MIN_FREQUENCY + 2.0, Radio.MAX_FREQUENCY - 2.0), Radio.FREQUENCY_STEP)
	return picked


@rpc("any_peer", "reliable")
func _request_frequency() -> void:
	if multiplayer.is_server():
		_set_frequency.rpc_id(multiplayer.get_remote_sender_id(), frequency)


@rpc("authority", "call_local", "reliable")
func _set_frequency(new_frequency: float) -> void:
	frequency = new_frequency
	if paint:
		paint.message = paint_message.replace("{frequency}", "%.1f" % frequency)


## SymbolCodePuzzle's display: what the voice reads, over and over.
func show_code(code: PackedInt32Array) -> void:
	var names := PackedStringArray()
	for symbol in code:
		names.append(Symbols.NAMES[symbol].to_upper())
	var reading := ". ".join(names)
	transcript = "...ATTENTION. ATTENTION. RELEASE FOR OCCUPANT.\n%s.\nREPEAT. %s." % [reading, reading]


func save_state() -> Variant:
	return frequency


func load_state(state: Variant) -> void:
	_set_frequency(state)

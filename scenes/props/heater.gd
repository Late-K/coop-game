class_name Heater
extends Interactable
## Runs on a heat cell. Using it opens the terminal on the heater: the player has to choose
## the cell from their items. Once fed, it warms the area, lights up and opens its doors
## (e.g. thaws a frozen bulkhead). The server owns whether it is on.

@export var doors: Array[Door] = []
## Story lines played for both players when it starts.
@export var on_lines: Array[String] = []

var is_on := false
## Saved (SaveGame): reloading after a death puts this back as it was at the last save,
## unless it should stay as it is now.
## (Its doors are saved themselves.)
@export var keep_on_reload := false

@onready var zone: TemperatureZone = $Zone
@onready var light: PowerLight = $Light
@onready var _hum := Sound.attach_loop("heater_loop", self, -4.0, 10.0)


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)


func get_prompt(_player: Player) -> String:
	return "Heater (running)" if is_on else "Examine heater"


func interact(player: Player) -> void:
	if not is_on:
		player.open_inventory(self)


func terminal_text() -> String:
	return "HEATER UNIT 4\n\nStatus: no power.\nAccepts a sealed thermal cell."


## Terminal device: only the heat cell fits. Anything else stays in your hands.
func use_slot_on(player: Player, index: int) -> bool:
	if is_on:
		return true
	if player.inventory.slots[index]["id"] != "heat_cell":
		player.notify("That doesn't fit")
		Sound.play_ui("code_wrong", -8.0)
		return false
	player.inventory.remove_from(index, 1)
	Sound.play_ui("keypad_press", -2.0, 0.7)
	_insert_cell.rpc_id(1)
	return true


@rpc("any_peer", "call_local", "reliable")
func _insert_cell() -> void:
	if not multiplayer.is_server() or is_on:
		return
	_turn_on.rpc()
	Story.play(on_lines)


@rpc("authority", "call_local", "reliable")
func _turn_on() -> void:
	_set_on(true)
	for door in doors:
		door.set_open(true)


func _set_on(on: bool) -> void:
	is_on = on
	if on:
		_hum.play()
	else:
		_hum.stop()
	zone.set_active(on)
	light.set_active(on)


func save_state() -> Variant:
	return is_on


func load_state(state: Variant) -> void:
	if state != is_on:
		_set_on(state)

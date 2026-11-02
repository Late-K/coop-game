class_name Heater
extends Interactable
## Runs on a heat cell. Once fed, it warms the area, lights up and opens its doors
## (e.g. thaws a frozen bulkhead). The server owns whether it is on.

@export var doors: Array[Door] = []
## Story lines played for both players when it starts.
@export var on_lines: Array[String] = []

var is_on := false

@onready var zone: TemperatureZone = $Zone
@onready var light: PowerLight = $Light


func get_prompt(player: Player) -> String:
	if is_on:
		return "Heater (running)"
	if player.inventory.has("heat_cell"):
		return "Insert heat cell"
	return "Heater (needs a heat cell)"


func interact(player: Player) -> void:
	if is_on or not player.inventory.has("heat_cell"):
		return
	player.inventory.remove("heat_cell", 1)
	_insert_cell.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _insert_cell() -> void:
	if not multiplayer.is_server() or is_on:
		return
	_turn_on.rpc()
	Story.play(on_lines)


@rpc("authority", "call_local", "reliable")
func _turn_on() -> void:
	is_on = true
	zone.set_active(true)
	light.set_active(true)
	for door in doors:
		door.set_open(true)

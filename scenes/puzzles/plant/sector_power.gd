class_name SectorPower
extends Node
## Sector 4's power coming back (Chapter 1, puzzle 8), once the `plant` catches: not all at
## once, a section at a time. First the heating (the `cold` zones switch off, the Visitor's
## frost lifts), then the `lights` that were dark come up one after another, then the dead
## `doors` (POWER locks) can be opened: storage, and each side's way down. Last, what was
## lying in the dark gets up: every enemy dormant with `wake_tag`.
## The server runs it; every machine sees it. Saved: powered stays powered.

## Seconds after the plant catches for each stage.
const HEAT_AT := 1.5
const LIGHTS_AT := 3.0
const LIGHT_STEP := 0.7
const DOORS_AT := 5.0
const WAKE_AT := 7.0

@export var plant: PlantRestart
@export var cold: Array[TemperatureZone] = []
@export var lights: Array[KitLight] = []
@export var doors: Array[Door] = []
@export var wake_tag := "sector4"
## Story lines for both players as the doors come back.
@export var lines: Array[String] = []
@export var keep_on_reload := true

var powered := false


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	for light in lights:
		light.power_off.call_deferred()
	plant.restored.connect(_on_plant_restored)


func _on_plant_restored() -> void:
	if multiplayer.is_server() and not powered:
		_restore.rpc()


@rpc("authority", "call_local", "reliable")
func _restore() -> void:
	powered = true
	await get_tree().create_timer(HEAT_AT).timeout
	for zone in cold:
		zone.set_active(false)
	await get_tree().create_timer(LIGHTS_AT - HEAT_AT).timeout
	for light in lights:
		light.power_on()
		await get_tree().create_timer(LIGHT_STEP).timeout
	var waited := LIGHTS_AT + LIGHT_STEP * lights.size()
	await get_tree().create_timer(maxf(DOORS_AT - waited, 0.1)).timeout
	if multiplayer.is_server():
		for door in doors:
			door.set_powered(true)
		Story.play(lines)
	await get_tree().create_timer(WAKE_AT - DOORS_AT).timeout
	_wake()


## Server: everything lying dormant under this tag gets up.
func _wake() -> void:
	if not multiplayer.is_server():
		return
	for enemy: Enemy in get_tree().get_nodes_in_group("dormant"):
		if enemy.wake_tag == wake_tag:
			enemy.wake()


func save_state() -> Variant:
	return powered


## Instant (behind a black screen): heat, light and doors back. The doors keep their own
## state; dormant enemies (put back by the reload) get up again.
func load_state(state: Variant) -> void:
	powered = state
	if not powered:
		return
	for zone in cold:
		zone.set_active(false)
	for light in lights:
		light.power_on()
	_wake.call_deferred()

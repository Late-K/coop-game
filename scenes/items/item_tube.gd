class_name ItemTube
extends Interactable
## Pneumatic tube linking two separated rooms. Sends the player's selected
## inventory slot to the partner tube, where it arrives as a pickup after a delay.
## Later: the noise could attract enemies, making every send a decision.

const TRANSIT_TIME := 4.0
const PICKUP_SCENE := "res://scenes/items/pickup.tscn"

@export var partner: ItemTube

@onready var output: Marker3D = $Output
@onready var light: OmniLight3D = $Light


func get_prompt(player: Player) -> String:
	var slot := player.inventory.slots[player.selected_slot]
	if slot.is_empty():
		return "Tube (select an item to send)"
	return "Send %s through the tube" % Items.display_name(slot["id"])


func interact(player: Player) -> void:
	player.send_through_tube(self)


@rpc("any_peer", "call_local", "reliable")
func request_send(id: String, count: int) -> void:
	if not multiplayer.is_server() or not Items.exists(id) or count <= 0:
		return
	_pulse.rpc()
	# Connected to a method (not awaited) so it is dropped if the level is unloaded meanwhile.
	get_tree().create_timer(TRANSIT_TIME).timeout.connect(_arrive.bind(id, count))


func _arrive(id: String, count: int) -> void:
	partner._pulse.rpc()
	var level := get_tree().get_first_node_in_group("level") as Level
	level.spawn_world_object(PICKUP_SCENE, partner.output.global_transform, {"item_id": id, "count": count})


@rpc("authority", "call_local", "reliable")
func _pulse() -> void:
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 3.0, 0.15)
	tween.tween_property(light, "light_energy", 0.0, 0.8)

class_name ItemTube
extends Interactable
## Pneumatic tube linking two separated rooms. Sends the player's selected
## inventory slot to the partner tube, where it arrives as a pickup on the tray
## beside it. The tray sits to the side on purpose: a pickup lying right in front
## would be nearer than the tube and steal the interact key from it.
## Sending is loud at both ends (TUBE_NOISE): husks come to the clatter, so every send is a
## decision (docs/design.md, Sharing).

const TRANSIT_TIME := 4.0
## How far the canister's clatter carries to enemies, at the sending end and at arrival.
const TUBE_NOISE := 12.0
const PICKUP_SCENE := "res://scenes/items/pickup.tscn"

@export var partner: ItemTube

@onready var output: Marker3D = $Output
@onready var light: OmniLight3D = $Light


func get_prompt(_player: Player) -> String:
	return "Send something through the tube"


## Opens the terminal on this tube: choosing a slot sends it.
func interact(player: Player) -> void:
	player.open_inventory(self)


func terminal_text() -> String:
	return "PNEUMATIC TUBE\n\nChoose an item to send to the other station.\nLoaded rounds travel with the gun."


func use_slot_on(player: Player, index: int) -> bool:
	player.send_slot_through_tube(index, self)
	return true


@rpc("any_peer", "call_local", "reliable")
func request_send(id: String, count: int) -> void:
	if not multiplayer.is_server() or not Items.exists(id) or count <= 0:
		return
	_pulse.rpc(false)
	Enemy.make_noise(get_tree(), global_position, TUBE_NOISE)
	# Connected to a method (not awaited) so it is dropped if the level is unloaded meanwhile.
	get_tree().create_timer(TRANSIT_TIME).timeout.connect(_arrive.bind(id, count))


func _arrive(id: String, count: int) -> void:
	partner._pulse.rpc(true)
	Enemy.make_noise(get_tree(), partner.global_position, TUBE_NOISE)
	var level := get_tree().get_first_node_in_group("level") as Level
	level.spawn_world_object(PICKUP_SCENE, partner.output.global_transform, {"item_id": id, "count": count})


@rpc("authority", "call_local", "reliable")
func _pulse(arriving: bool) -> void:
	Sound.play_at("tube_arrive" if arriving else "tube_send", global_position + Vector3.UP, 0.0, 20.0)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 3.0, 0.15)
	tween.tween_property(light, "light_energy", 0.0, 0.8)

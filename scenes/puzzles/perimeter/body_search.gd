class_name BodySearch
extends Interactable
## What the Visitor's first body still carries (Chapter 1, puzzle 4): the chapter's only
## pistol, a few rounds, and a photograph, the one thing that didn't come out of the pod with
## the copy. It's the Subject who gets here (duct M-2), and to the Subject it's a stranger.
## Searching takes whatever fits; the rest stays on the body. Only once the doors have come
## down (EntranceCrush adds it). The server owns what's left. Saved, and put back on reload
## with the inventory it went into.

## What's on the body, as [item id, count] pairs.
const GEAR := [["photograph", 1], ["pistol", 1], ["ammo", 6]]

@export var keep_on_reload := false

## What's still on it: item id -> count.
var remaining := {}
var _found := false


func _init() -> void:
	super()
	for item: Array in GEAR:
		remaining[item[0]] = item[1]


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	var reach := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.0, 2.4)
	reach.shape = box
	reach.position = Vector3(0, 1.0, -0.9)
	add_child(reach)
	if not multiplayer.is_server():
		_request_state.rpc_id(1)


func get_prompt(_player: Player) -> String:
	if remaining.is_empty():
		return ""
	return "Search the body"


func interact(player: Player) -> void:
	if not _found:
		_found = true
		Story.show_local("body_found")
	var took := false
	for id: String in remaining.keys(): # a copy: a host takes at once, changing remaining
		var fits := mini(player.inventory.space_for(id), remaining[id])
		if fits > 0:
			_take.rpc_id(1, id, fits)
			took = true
	if not took:
		player.notify("No room to carry anything else")


@rpc("any_peer", "call_local", "reliable")
func _take(id: String, count: int) -> void:
	if not multiplayer.is_server() or not remaining.has(id):
		return
	var peer := multiplayer.get_remote_sender_id()
	count = mini(count, remaining[id])
	remaining[id] -= count
	if remaining[id] <= 0:
		remaining.erase(id)
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == peer:
			player._receive_item.rpc_id(peer, id, count)
	_sync.rpc(remaining)


@rpc("any_peer", "reliable")
func _request_state() -> void:
	if multiplayer.is_server():
		_sync.rpc_id(multiplayer.get_remote_sender_id(), remaining)


@rpc("authority", "call_local", "reliable")
func _sync(new_remaining: Dictionary) -> void:
	remaining = new_remaining


func save_state() -> Variant:
	return remaining.duplicate()


func load_state(state: Variant) -> void:
	remaining = (state as Dictionary).duplicate()

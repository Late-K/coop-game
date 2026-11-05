class_name FrozenLocker
extends Interactable
## A supply locker frozen shut (Chapter 1, puzzle 7, past the guard post): a heat cell
## pressed into its thaw port opens it. Inside, `contents`, for whoever opened it, as much
## as they can carry; the rest stays in. This is where the Subject's second heat cell pays
## off, if it kept it rather than sending it to the Visitor. Back against a wall, facing
## +Z. Built in code. The server owns it; saved with the inventory it went into.

## What's inside: item id -> count.
@export var contents := {"ammo": 6, "medkit": 1}
@export var keep_on_reload := false

var thawed := false
var _frost: MeshInstance3D


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.3, 0.34, 0.36)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.9, 1.9, 0.5)
	body.mesh = body_mesh
	body.material_override = metal
	body.position = Vector3(0, 0.95, 0.25)
	add_child(body)
	var frost_material := StandardMaterial3D.new()
	frost_material.albedo_color = Color(0.78, 0.9, 1.0, 0.8)
	frost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frost_material.set_meta("retro_skip", true)
	_frost = MeshInstance3D.new()
	var frost_mesh := BoxMesh.new()
	frost_mesh.size = Vector3(0.96, 1.96, 0.56)
	_frost.mesh = frost_mesh
	_frost.material_override = frost_material
	_frost.position = body.position
	add_child(_frost)
	var solid := StaticBody3D.new()
	var solid_shape := CollisionShape3D.new()
	var solid_box := BoxShape3D.new()
	solid_box.size = body_mesh.size
	solid_shape.shape = solid_box
	solid_shape.position = body.position
	solid.add_child(solid_shape)
	add_child(solid)
	var reach := CollisionShape3D.new()
	var reach_box := BoxShape3D.new()
	reach_box.size = Vector3(1.4, 2.0, 1.0)
	reach.shape = reach_box
	reach.position = Vector3(0, 1.0, 0.9)
	add_child(reach)
	if not multiplayer.is_server():
		_request_state.rpc_id(1)


func get_prompt(_player: Player) -> String:
	if not thawed:
		return "Examine the frozen locker"
	return "Search the locker" if not contents.is_empty() else ""


func interact(player: Player) -> void:
	if not thawed:
		player.open_inventory(self)
		return
	var took := false
	for id: String in contents.keys(): # a copy: a host takes at once, changing contents
		var fits := mini(player.inventory.space_for(id), contents[id])
		if fits > 0:
			_take.rpc_id(1, id, fits)
			took = true
	if not took:
		player.notify("No room to carry anything else")


func terminal_text() -> String:
	return "SUPPLY LOCKER S-3\n\nFrozen shut. The thaw port takes a sealed thermal cell."


## Terminal device: only a heat cell thaws it.
func use_slot_on(player: Player, index: int) -> bool:
	if player.inventory.slots[index]["id"] != "heat_cell":
		player.notify("That doesn't fit")
		Sound.play_ui("code_wrong", -8.0)
		return false
	player.inventory.remove_from(index, 1)
	Sound.play_ui("keypad_press", -2.0, 0.7)
	_thaw.rpc_id(1)
	return true


@rpc("any_peer", "call_local", "reliable")
func _thaw() -> void:
	if multiplayer.is_server() and not thawed:
		_sync.rpc(true, contents)


@rpc("any_peer", "call_local", "reliable")
func _take(id: String, count: int) -> void:
	if not multiplayer.is_server() or not thawed or not contents.has(id):
		return
	var peer := multiplayer.get_remote_sender_id()
	count = mini(count, contents[id])
	contents[id] -= count
	if contents[id] <= 0:
		contents.erase(id)
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == peer:
			player._receive_item.rpc_id(peer, id, count)
	_sync.rpc(thawed, contents)


@rpc("any_peer", "reliable")
func _request_state() -> void:
	if multiplayer.is_server():
		_sync.rpc_id(multiplayer.get_remote_sender_id(), thawed, contents)


@rpc("authority", "call_local", "reliable")
func _sync(now_thawed: bool, now_contents: Dictionary) -> void:
	if now_thawed and not thawed:
		Sound.play_at("heater_loop", global_position + Vector3.UP, -6.0, 10.0)
	thawed = now_thawed
	contents = now_contents
	_frost.visible = not thawed


func save_state() -> Variant:
	return {"thawed": thawed, "contents": contents.duplicate()}


func load_state(state: Variant) -> void:
	thawed = state["thawed"]
	contents = (state["contents"] as Dictionary).duplicate()
	_frost.visible = not thawed

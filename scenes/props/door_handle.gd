class_name DoorHandle
extends Interactable
## The part of a Door players use: its prompt and interaction (Door.prompt_for / use), and,
## for a KEY door, the terminal device that takes the key. Built by the door itself.

var door: Door


func _init() -> void:
	super()
	name = "DoorHandle"
	var reach := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.0, 3.2) # either side of the door, along its width
	reach.shape = box
	add_child(reach)


func get_prompt(player: Player) -> String:
	return door.prompt_for(player)


func interact(player: Player) -> void:
	door.use(player)
	used.emit(player)


func terminal_text() -> String:
	return "LOCKED DOOR\n\nTakes: %s." % Items.display_name(door.key_item).to_lower()


func use_slot_on(player: Player, index: int) -> bool:
	return door.try_key(player, index)

class_name WayDown
extends Interactable
## The end of Chapter 1: each side's way down into the older facility, the Subject's lift
## and the Visitor's stairwell. Only its own player can take it. Taking it is leaving: they
## walk on into it as the screen goes black and quiet, a line of narration, and they wait
## there for the partner.
## Once both have gone down, separately, the chapter ends. Place it inside the room its POWER
## door opens onto (SectorPower), facing +Z. Built in code.

## Seconds into the way down before it goes wrong (`fatal`).
const FALL_AFTER := 4.5

@export_enum("subject", "visitor") var role := "subject"
## Narration on the way down, for whoever takes it.
@export var line := ""
## It doesn't get them to the bottom alive (the Subject's lift): a crash in the dark.
@export var fatal := false
## How far out in front (+Z) they walk to as the screen goes black: up to the lift's doors,
## onto the top of the stairs.
@export var walk_in := 0.5

var gone := false


func _ready() -> void:
	add_to_group("ways_down")
	var reach := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.0, 1.6)
	reach.shape = box
	reach.position = Vector3(0, 1.0, 0.8)
	add_child(reach)


func get_prompt(player: Player) -> String:
	if gone or Session.ROLE_NAMES[player.role].to_lower() != role:
		return ""
	return prompt


func interact(player: Player) -> void:
	player.leave_level(global_transform * Vector3(0, 0, walk_in))
	if line:
		Story.show_local(line)
	_went_down.rpc_id(1)
	if fatal:
		await get_tree().create_timer(FALL_AFTER).timeout
		Sound.play_ui("crush", 2.0, 0.8)
		MetaSave.record("deaths")


## Server: one more gone down. Both gone: the chapter is over.
@rpc("any_peer", "call_local", "reliable")
func _went_down() -> void:
	if not multiplayer.is_server() or gone:
		return
	_set_gone.rpc()
	print("[intake] the %s went down" % role)
	for way: WayDown in get_tree().get_nodes_in_group("ways_down"):
		if not way.gone:
			return
	(get_tree().get_first_node_in_group("level") as Level).finish_chapter()


@rpc("authority", "call_local", "reliable")
func _set_gone() -> void:
	gone = true

class_name StoryTrigger
extends Area3D
## Fires a story beat when players walk in. Detection runs on the server only;
## Story then shows each player its own version of the lines.
##
## A beat can also cut the matching players to a first-person shot (a fixed
## `cutaway` marker, or their own eyes turned toward the partner), open or close
## doors, and end the chapter.

enum Who { ANY, BOTH, SUBJECT, VISITOR }

const PLAYER_LAYER := 8 # physics layer 4, "player"

@export var line_ids: Array[String] = []
@export var who := Who.ANY
@export var once := true

@export_group("First-person beat")
## Players matching `who` hard-cut to this view for `cutaway_time` seconds.
@export var cutaway: Marker3D
## Instead of a marker: each player looks at the other from their own eyes.
@export var look_at_partner := false
@export var cutaway_time := 3.0

@export_group("World")
@export var open_doors: Array[Door] = []
@export var close_doors: Array[Door] = []
@export var ends_chapter := false

## Saved (SaveGame): reloading after a death puts this back as it was at the last save,
## unless it should stay as it is now. Beats don't replay by default.
@export var keep_on_reload := true

var _fired := false


func _init() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitorable = false


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	if multiplayer.is_server():
		body_entered.connect(_on_body_entered)
	else:
		set_deferred("monitoring", false)


func _on_body_entered(body: Node3D) -> void:
	if (once and _fired) or not body is Player or not _matches(body):
		return
	_fired = true
	Story.play(line_ids)
	for door in open_doors:
		door.sync_open.rpc(true)
	for door in close_doors:
		door.sync_open.rpc(false)
	if cutaway or look_at_partner:
		_play_cutaway.rpc()
	if ends_chapter:
		(get_tree().get_first_node_in_group("level") as Level).finish_chapter()


func save_state() -> Variant:
	return _fired


## A fired beat keeps the doors it moved where it put them.
func load_state(state: Variant) -> void:
	_fired = state
	if _fired:
		for door in open_doors:
			door.set_open(true)
		for door in close_doors:
			door.set_open(false)


func _matches(player: Player) -> bool:
	match who:
		Who.SUBJECT:
			return player.role == Session.Role.SUBJECT
		Who.VISITOR:
			return player.role == Session.Role.VISITOR
		Who.BOTH:
			return get_overlapping_bodies().filter(func(b: Node3D) -> bool: return b is Player).size() >= 2
	return true


@rpc("authority", "call_local", "reliable")
func _play_cutaway() -> void:
	var me: Player = null
	var partner: Player = null
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority():
			me = player
		else:
			partner = player
	if me == null:
		return
	if (who == Who.SUBJECT and me.role != Session.Role.SUBJECT) \
			or (who == Who.VISITOR and me.role != Session.Role.VISITOR):
		return
	if look_at_partner:
		if partner:
			var eyes := Transform3D(Basis(), me.head_position())
			me.play_cutaway(eyes.looking_at(partner.head_position()), cutaway_time)
	else:
		me.play_cutaway(cutaway.global_transform, cutaway_time)

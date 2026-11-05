class_name EntranceCrush
extends Node3D
## The end of Chapter 1's opening. The Visitor reaches the facility's outer doors and steps
## through, and the doors come down on top of them. A hard cut to black, one sound. Their
## first body, the only one certainly human, stays under the doors; they wake in the pod of
## their safe room (`wake_terminal`), printed, in third person, the handheld whole
## (Player.reprint_after_crush). On the Subject's radar the contact simply goes out.
## Not a death: nothing reloads, and it happens once. Saved, and kept on reload.
##
## Place it in the doorway: the body lies where this node stands, and the trigger is the
## `trigger` box around it. The server watches for the Visitor.

## The doors that come down.
@export var door: Door
## The safe room terminal whose pod the Visitor wakes in.
@export var wake_terminal: SaveTerminal
## Where the Visitor sets it off, around this node (x, z half-extents in metres).
@export var trigger := Vector2(1.6, 0.6)
@export var keep_on_reload := true

var done := false
## When it happened on this machine (seconds since start), for the radar's readouts.
var done_at := -INF

var _body: CharacterModel
## What the body still carries (puzzle 4): searchable once it's there.
var _search := BodySearch.new()


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	_search.name = "BodySearch"
	_search.monitorable = false
	add_child(_search)
	set_physics_process(multiplayer.is_server())


func _physics_process(_delta: float) -> void:
	if done:
		return
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.role == Session.Role.VISITOR and not player.is_dead:
			var offset := player.global_position - global_position
			if absf(offset.x) <= trigger.x and absf(offset.z) <= trigger.y:
				_crush(player)
				return


## Server: the doors come down, the body stays, the Visitor wakes inside.
func _crush(player: Player) -> void:
	print("[intake] the entrance doors came down on the Visitor")
	_slam.rpc()
	player.reprint_after_crush.rpc_id(player.get_multiplayer_authority(), wake_terminal.respawn_transform(false))
	Story.play(["intake_complete"])


@rpc("authority", "call_local", "reliable")
func _slam() -> void:
	done = true
	done_at = Time.get_ticks_msec() / 1000.0
	door.slam()
	Sound.play_at("crush", global_position + Vector3.UP, 4.0, 40.0, 0.0)
	_show_body()


func save_state() -> Variant:
	return done


## Instant (behind a black screen): the doors down and the body there, or neither.
func load_state(state: Variant) -> void:
	done = state
	if done:
		door.load_state({"open": false, "locked": true})
		_show_body()


func _show_body() -> void:
	if _body:
		return
	_body = preload("res://scenes/characters/character_model.tscn").instantiate()
	_body.look = CharacterModel.Look.VISITOR
	_body.pose = CharacterModel.Pose.CORPSE
	# Face down (an odd variation), head north: they fell forward into the airlock, the
	# doors across their legs.
	_body.variation = 1
	add_child(_body)
	_search.set_deferred("monitorable", true)

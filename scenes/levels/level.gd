class_name Level
extends Node3D
## Shared script for every level (chapters and the test level). Expects the nodes
## Players, PlayerSpawner, World, WorldSpawner, Placements and SpawnPoints/Subject + Visitor.
## The server spawns one player per peer at their role's start; PlayerSpawner replicates them.
##
## Anything that can be created or destroyed during play (pickups, enemies) is placed
## in the editor under `Placements`. On load every peer deletes those stand-ins and the
## server re-creates them through WorldSpawner, so their removal is replicated and a
## partner who joins late sees the world as it is now.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const INTRO_DELAY := 1.5
const CHAPTER_END_DELAY := 7.0

## Shown on the end card, e.g. "Chapter 1: Intake".
@export var chapter_title := ""
## Played for both players shortly after the level starts.
@export var intro_lines: Array[String] = []

@onready var players: Node3D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var world: Node3D = $World
@onready var world_spawner: MultiplayerSpawner = $WorldSpawner
@onready var placements: Node3D = $Placements
@onready var subject_start: Marker3D = $SpawnPoints/Subject
@onready var visitor_start: Marker3D = $SpawnPoints/Visitor


func _ready() -> void:
	add_to_group("level")
	# Must be set on every peer: the client runs them too when a spawn arrives.
	player_spawner.spawn_function = _spawn_player
	world_spawner.spawn_function = _spawn_world_object

	var placed: Array[Dictionary] = []
	for node: Node3D in placements.get_children():
		var extra: Dictionary = node.get_spawn_data() if node.has_method("get_spawn_data") else {}
		placed.append({"scene": node.scene_file_path, "transform": node.global_transform, "extra": extra})
		node.queue_free()

	if not multiplayer.is_server():
		return
	for data in placed:
		world_spawner.spawn(data)
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)
	_add_player(1)
	for id in multiplayer.get_peers():
		_add_player(id)
	get_tree().create_timer(INTRO_DELAY).timeout.connect(Story.play.bind(intro_lines))


## Server only. Shows the end card on both machines, then both return to the menu.
func finish_chapter() -> void:
	_finish_chapter.rpc()


@rpc("authority", "call_local", "reliable")
func _finish_chapter() -> void:
	MetaSave.record("chapters_completed")
	Story.show_card(chapter_title.to_upper())
	var main := get_tree().get_first_node_in_group("main")
	main.end_session_after(CHAPTER_END_DELAY, "%s complete." % chapter_title)


## Server only. Creates a replicated object (e.g. a pickup arriving through a tube).
func spawn_world_object(scene_path: String, at: Transform3D, extra := {}) -> void:
	world_spawner.spawn({"scene": scene_path, "transform": at, "extra": extra})


func _add_player(id: int) -> void:
	# Separated from the first second.
	Session.assign_free_role(id)
	var is_subject := Session.role_of(id) == Session.Role.SUBJECT
	var spawn_point := subject_start if is_subject else visitor_start
	player_spawner.spawn({"id": id, "position": spawn_point.global_position})
	print("[level] spawned player for peer %d" % id)


func _remove_player(id: int) -> void:
	var player := players.get_node_or_null(str(id))
	if player:
		player.queue_free()
	print("[level] removed player for peer %d" % id)


func _spawn_player(data: Dictionary) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(data["id"])
	player.position = data["position"]
	return player


func _spawn_world_object(data: Dictionary) -> Node:
	var node: Node3D = load(data["scene"]).instantiate()
	node.transform = data["transform"]
	if node.has_method("apply_spawn_data"):
		node.apply_spawn_data(data["extra"])
	return node

class_name Level
extends Node3D
## Greybox test level: two rooms joined by a corridor, one player spawn per room.
## The server spawns one player per peer; PlayerSpawner replicates them to the client.
##
## Anything that can be created or destroyed during play (pickups, enemies) is placed
## in the editor under `Placements`. On load every peer deletes those stand-ins and the
## server re-creates them through WorldSpawner, so their removal is replicated and a
## partner who joins late sees the world as it is now.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var players: Node3D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var world: Node3D = $World
@onready var world_spawner: MultiplayerSpawner = $WorldSpawner
@onready var placements: Node3D = $Placements
@onready var spawn_points: Array[Marker3D] = [$SpawnPoints/RoomA, $SpawnPoints/RoomB]


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


## Server only. Creates a replicated object (e.g. a pickup arriving through a tube).
func spawn_world_object(scene_path: String, at: Transform3D, extra := {}) -> void:
	world_spawner.spawn({"scene": scene_path, "transform": at, "extra": extra})


func _add_player(id: int) -> void:
	# Host starts in room A, the partner in room B — separated from the first second.
	var spawn_point := spawn_points[0] if id == 1 else spawn_points[1]
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

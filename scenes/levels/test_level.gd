extends Node3D
## Greybox test level: two rooms joined by a corridor, one player spawn per room.
## The server spawns one player per peer; PlayerSpawner replicates them to the client.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var players: Node3D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var spawn_points: Array[Marker3D] = [$SpawnPoints/RoomA, $SpawnPoints/RoomB]


func _ready() -> void:
	# Must be set on every peer: the client runs it too when a spawn arrives.
	player_spawner.spawn_function = _spawn_player
	if not multiplayer.is_server():
		return
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)
	_add_player(1)
	for id in multiplayer.get_peers():
		_add_player(id)


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

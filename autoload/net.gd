extends Node
## Owns the network connection.
## Gameplay code talks to `multiplayer` (signals, RPCs, authority), never to the transport,
## so ENet can later be swapped for GodotSteam without touching anything else.

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 1 # 2-player game: the host plus one client
## How long a silent partner (crash, pulled cable) is waited for before counting as gone, in ms.
## ENet's own default is up to 30 s; the game can't continue alone, so notice sooner.
const PEER_TIMEOUT_MIN := 3000
const PEER_TIMEOUT_MAX := 8000


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func _on_peer_connected(id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet:
		enet.get_peer(id).set_timeout(0, PEER_TIMEOUT_MIN, PEER_TIMEOUT_MAX)

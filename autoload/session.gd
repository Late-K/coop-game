extends Node
## Who is who in the current session. The server owns the role table and
## pushes it to both peers whenever it changes.

signal roles_changed

enum Role { NONE, SUBJECT, VISITOR }

const ROLE_NAMES := {Role.NONE: "No role", Role.SUBJECT: "Subject", Role.VISITOR: "Visitor"}
const ROLE_BLURBS := {
	Role.SUBJECT: "Wakes inside, in a test cell.",
	Role.VISITOR: "Comes in from the cold. Gets trapped.",
}

var roles := {} # peer id -> Role


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func role_of(peer_id: int) -> Role:
	return roles.get(peer_id, Role.NONE)


func local_role() -> Role:
	return role_of(multiplayer.get_unique_id())


## Peer id holding `role`, or 0 if nobody does.
func peer_with_role(role: Role) -> int:
	for id in roles:
		if roles[id] == role:
			return id
	return 0


func is_ready_to_start() -> bool:
	return peer_with_role(Role.SUBJECT) != 0 and peer_with_role(Role.VISITOR) != 0


func request_role(role: Role) -> void:
	_claim_role.rpc_id(1, role)


## Server only. Gives `peer_id` whichever role is still free (late joiners, dev shortcuts).
func assign_free_role(peer_id: int) -> void:
	if role_of(peer_id) != Role.NONE:
		return
	for role in [Role.SUBJECT, Role.VISITOR]:
		if peer_with_role(role) == 0:
			roles[peer_id] = role
			break
	_sync_roles.rpc(roles)


func reset() -> void:
	roles = {}
	roles_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _claim_role(role: Role) -> void:
	if not multiplayer.is_server() or role == Role.NONE:
		return
	var sender := multiplayer.get_remote_sender_id()
	var holder := peer_with_role(role)
	if holder != 0 and holder != sender:
		return
	roles[sender] = role
	_sync_roles.rpc(roles)


@rpc("authority", "call_local", "reliable")
func _sync_roles(new_roles: Dictionary) -> void:
	roles = new_roles
	roles_changed.emit()


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_sync_roles.rpc_id(id, roles)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		roles.erase(id)
		_sync_roles.rpc(roles)

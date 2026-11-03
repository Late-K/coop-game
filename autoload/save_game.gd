extends Node
## Saving, dying and reloading (docs/design.md, Core rules). The host owns the save; both
## machines keep a copy of the file, so either can host the next session.
##
## Saving: both players must stand at a save terminal and confirm (SavePrompt). The save
## holds the level, what is in the world (pickups, enemies: Level's World), every node in
## the "saved" group (doors, puzzles, triggers: `save_state()` / `load_state()`), each
## role's inventory, health and terminal, and the bodies.
##
## Dying: one death reloads both players to the save. The dead player wakes in the pod by
## their terminal; the survivor fades out and back in at theirs, sitting, as if waiting.
## Enemies and items reset. A saved node resets too, unless its `keep_on_reload` is set
## (e.g. a learned code stays solved). The body stays where it fell: bodies are kept in the
## save, across reloads and sessions, up to MAX_BODIES per role.
## A new chapter's start is saved straight away, so there is always something to reload.

signal statuses_changed
signal saved

## Where each player stands with saving.
enum Status { AWAY, AT_TERMINAL, READY }

const PATH := "user://save.dat"
const VERSION := 1
const MAX_BODIES := 6
const SAVED_GROUP := "saved"
## Server: how long both screens stay black before the world is put back.
const RELOAD_DELAY := 2.4

## Server: the save everything reloads to (also what is on disk).
var snapshot := {}
## Set by the lobby's Continue before the level loads; used up by the level.
var pending := {}
## peer id -> Status, on both machines.
var statuses := {}
## Server: a reload is under way.
var reloading := false

var _player_states := {} # server: peer -> the state they confirmed with


func has_save() -> bool:
	return not read_save().is_empty()


func read_save() -> Dictionary:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	if data is Dictionary and data.get("version", 0) == VERSION and ResourceLoader.exists(data.get("level", "")):
		return data
	return {}


## The save to restore from right now: a Continue that hasn't been used up, else the last save.
func _source() -> Dictionary:
	return pending if not pending.is_empty() else snapshot


# --- Level lifecycle ----------------------------------------------------------

## Server, from Level._ready once the world is spawned.
func level_started(level: Level) -> void:
	reloading = false
	statuses.clear()
	_player_states.clear()
	if pending.is_empty():
		snapshot = _capture(level)
		snapshot["players"] = {}
		snapshot["corpses"] = []
		_store(snapshot)
		return
	snapshot = pending
	pending = {}
	_apply_states(_saved_states(level, false))
	_sync_bodies(snapshot.get("corpses", []))


## Client, from Level._ready: ask for the state of saved nodes and the bodies.
func level_ready_on_client() -> void:
	_request_level_state.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_level_state() -> void:
	var level := _level()
	if not multiplayer.is_server() or level == null:
		return
	var peer := multiplayer.get_remote_sender_id()
	_apply_states.rpc_id(peer, _current_states(level))
	_sync_bodies.rpc_id(peer, snapshot.get("corpses", []))


## The local player, once spawned: puts it where the save has it (Continue).
func request_player_state() -> void:
	_request_player_state.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_player_state() -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var role := _role_name(peer)
	var state: Dictionary = _source().get("players", {}).get(role, {})
	var player := _player_of(peer)
	if state.is_empty() or player == null:
		return
	player.restore.rpc_id(peer, state, _spawn_transform(role, state, false), "start")


# --- Saving ----------------------------------------------------------------------

## The local player at a terminal: AT_TERMINAL on opening it, READY on confirming (with
## their state), AWAY on leaving.
func set_status(status: Status, terminal: Node = null, player_state := {}) -> void:
	var level := _level()
	var path := level.get_path_to(terminal) if terminal and level else NodePath()
	_set_status.rpc_id(1, status, path, player_state)


func status_of(peer: int) -> Status:
	return statuses.get(peer, Status.AWAY)


func partner_status() -> Status:
	var peers := multiplayer.get_peers()
	return status_of(peers[0]) if not peers.is_empty() else Status.AWAY


@rpc("any_peer", "call_local", "reliable")
func _set_status(status: int, terminal: NodePath, player_state: Dictionary) -> void:
	if not multiplayer.is_server() or reloading:
		return
	var peer := multiplayer.get_remote_sender_id()
	statuses[peer] = status
	if status == Status.READY:
		var state := player_state.duplicate(true)
		state["terminal"] = terminal
		_player_states[peer] = state
	else:
		_player_states.erase(peer)
	_sync_statuses.rpc(statuses)
	var peers := [1] + Array(multiplayer.get_peers())
	if peers.size() == 2 and peers.all(func(p: int) -> bool: return status_of(p) == Status.READY):
		_save()


func _save() -> void:
	var level := _level()
	var data := _capture(level)
	data["players"] = {}
	for peer: int in _player_states:
		data["players"][_role_name(peer)] = _player_states[peer]
	data["corpses"] = snapshot.get("corpses", [])
	snapshot = data
	_store(snapshot)
	statuses.clear()
	_player_states.clear()
	_sync_statuses.rpc(statuses)
	_saved.rpc()
	print("[save] saved %s" % data["level"])


@rpc("authority", "call_local", "reliable")
func _sync_statuses(new_statuses: Dictionary) -> void:
	statuses = new_statuses
	statuses_changed.emit()


@rpc("authority", "call_local", "reliable")
func _saved() -> void:
	saved.emit()


# --- Death and reload ----------------------------------------------------------------

## The dying player's machine, once its screen is black.
func report_death(at: Vector3, yaw: float) -> void:
	_report_death.rpc_id(1, at, yaw)


@rpc("any_peer", "call_local", "reliable")
func _report_death(at: Vector3, yaw: float) -> void:
	if not multiplayer.is_server() or reloading:
		return
	reloading = true
	var dead_peer := multiplayer.get_remote_sender_id()
	_add_body(_role_name(dead_peer), at, yaw)
	statuses.clear()
	_player_states.clear()
	_sync_statuses.rpc(statuses)
	_begin_reload.rpc(dead_peer)
	await get_tree().create_timer(RELOAD_DELAY).timeout
	if _level():
		await _reload(dead_peer)
	reloading = false


## Every machine: the survivor's screen goes black too.
@rpc("authority", "call_local", "reliable")
func _begin_reload(dead_peer: int) -> void:
	var me := _player_of(multiplayer.get_unique_id())
	if me and multiplayer.get_unique_id() != dead_peer:
		me.wait_for_reload()


func _reload(dead_peer: int) -> void:
	var level := _level()
	for node in level.world.get_children():
		node.queue_free()
	await get_tree().process_frame
	for entry: Dictionary in snapshot.get("world", []):
		level.world_spawner.spawn(entry)
	_apply_states.rpc(_saved_states(level, true))
	_sync_bodies.rpc(snapshot.get("corpses", []))
	for peer in [1] + Array(multiplayer.get_peers()):
		var role := _role_name(peer)
		var state: Dictionary = snapshot.get("players", {}).get(role, {})
		var player := _player_of(peer)
		if player:
			var dead: bool = peer == dead_peer
			# No terminal saved at yet (a death before the first save): no pod to wake in.
			var mode := ("pod" if _terminal_of(state) else "respawn") if dead else "waiting"
			player.restore.rpc_id(peer, state, _spawn_transform(role, state, not dead), mode)
	_store(snapshot) # the new body is kept even without a new save


func _add_body(role: String, at: Vector3, yaw: float) -> void:
	var bodies: Array = snapshot.get_or_add("corpses", [])
	bodies.append({"role": role, "position": at, "yaw": yaw, "variation": randi() % 1000})
	var mine := bodies.filter(func(body: Dictionary) -> bool: return body["role"] == role)
	if mine.size() > MAX_BODIES:
		bodies.erase(mine[0]) # the oldest is gone


@rpc("authority", "call_local", "reliable")
func _sync_bodies(bodies: Array) -> void:
	var level := _level()
	if level == null:
		return
	var holder := level.get_node_or_null("Bodies")
	if holder == null:
		holder = Node3D.new()
		holder.name = "Bodies"
		level.add_child(holder)
	for child in holder.get_children():
		child.queue_free()
	for body: Dictionary in bodies:
		var model: CharacterModel = preload("res://scenes/characters/character_model.tscn").instantiate()
		model.look = CharacterModel.Look.SUBJECT if body["role"] == "subject" else CharacterModel.Look.VISITOR
		model.pose = CharacterModel.Pose.CORPSE
		model.variation = body["variation"]
		holder.add_child(model)
		model.global_position = body["position"]
		model.rotation.y = body["yaw"]


# --- Saved nodes --------------------------------------------------------------------

## Every saved node's state as the save has it. With `keep_current`, nodes marked
## keep_on_reload use their state now instead, and come last, so a puzzle that stays
## solved re-opens the doors the reset just closed.
func _saved_states(level: Level, keep_current: bool) -> Array:
	var states: Dictionary = snapshot.get("states", {})
	var reset := []
	var kept := []
	for node in get_tree().get_nodes_in_group(SAVED_GROUP):
		if not level.is_ancestor_of(node):
			continue
		var path := level.get_path_to(node)
		if keep_current and node.keep_on_reload:
			kept.append([path, node.save_state()])
		elif states.has(path):
			reset.append([path, states[path]])
	return reset + kept


func _current_states(level: Level) -> Array:
	var states := []
	for node in get_tree().get_nodes_in_group(SAVED_GROUP):
		if level.is_ancestor_of(node):
			states.append([level.get_path_to(node), node.save_state()])
	return states


@rpc("authority", "call_local", "reliable")
func _apply_states(states: Array) -> void:
	var level := _level()
	if level == null:
		return
	for entry: Array in states:
		var node := level.get_node_or_null(entry[0])
		if node and node.has_method("load_state"):
			node.load_state(entry[1])


# --- Helpers ---------------------------------------------------------------------------

func _capture(level: Level) -> Dictionary:
	var world := []
	for node in level.world.get_children():
		if node.scene_file_path:
			var extra: Dictionary = node.get_spawn_data() if node.has_method("get_spawn_data") else {}
			world.append({"scene": node.scene_file_path, "transform": node.global_transform, "extra": extra})
	var states := {}
	for entry: Array in _current_states(level):
		states[entry[0]] = entry[1]
	return {"version": VERSION, "level": level.scene_file_path, "world": world, "states": states}


## Where a role comes back: their save terminal's pod (or its waiting spot), else their
## start point.
func _spawn_transform(role: String, state: Dictionary, waiting: bool) -> Transform3D:
	var terminal := _terminal_of(state)
	if terminal:
		return terminal.respawn_transform(waiting)
	var level := _level()
	return (level.subject_start if role == "subject" else level.visitor_start).global_transform


func _terminal_of(state: Dictionary) -> SaveTerminal:
	var path: NodePath = state.get("terminal", NodePath())
	return _level().get_node_or_null(path) as SaveTerminal if not path.is_empty() else null


func _store(data: Dictionary) -> void:
	_write(data)
	_store_copy.rpc(data)


@rpc("authority", "call_remote", "reliable")
func _store_copy(data: Dictionary) -> void:
	_write(data)


func _write(data: Dictionary) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)


func _level() -> Level:
	return get_tree().get_first_node_in_group("level") as Level


func _player_of(peer: int) -> Player:
	var level := _level()
	return level.players.get_node_or_null(str(peer)) as Player if level else null


func _role_name(peer: int) -> String:
	return Session.ROLE_NAMES[Session.role_of(peer)].to_lower()

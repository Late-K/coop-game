extends Node
## Root scene. Owns the menu, the HUD and the current level.
## Only the server picks the level; LevelSpawner replicates it to the client.
##
## Dev shortcut: pass `-- --host` or `-- --join[=ip]` on the command line
## (or in Debug > Customize Run Instances) to skip the menu.

const TEST_LEVEL_PATH := "res://scenes/levels/test_level.tscn"

@onready var level_root: Node = $Level
@onready var menu: MainMenu = $MainMenu
@onready var hud: Control = $Hud
@onready var hud_label: Label = $Hud/Label


func _ready() -> void:
	menu.host_requested.connect(_on_host_requested)
	menu.join_requested.connect(_on_join_requested)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	hud.hide()
	_handle_dev_args.call_deferred()


func _notification(what: int) -> void:
	# Disconnect before the tree is torn down, otherwise the partner receives
	# despawn messages for nodes it has already freed.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Net.leave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and Net.is_online():
		_return_to_menu("Left the session.")


func _on_host_requested() -> void:
	var err := Net.host()
	if err != OK:
		menu.set_status("Could not host: %s" % error_string(err))
		return
	print("[main] hosting on port %d" % Net.DEFAULT_PORT)
	_enter_game("Host — waiting for partner")
	_load_level(TEST_LEVEL_PATH)


func _on_join_requested(address: String) -> void:
	if address.is_empty():
		menu.set_status("Enter the host's IP address.")
		return
	var err := Net.join(address)
	if err != OK:
		menu.set_status("Could not join: %s" % error_string(err))
		return
	menu.set_busy(true)
	menu.set_status("Connecting to %s..." % address)


func _on_connected_to_server() -> void:
	print("[main] connected to server as peer %d" % multiplayer.get_unique_id())
	# The level arrives on its own through LevelSpawner.
	_enter_game("Client — connected")


func _on_connection_failed() -> void:
	Net.leave()
	menu.set_busy(false)
	menu.set_status("Could not connect (wrong address, or the session is full).")


func _on_server_disconnected() -> void:
	_return_to_menu("The host closed the session.")


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		hud_label.text = "Host — partner connected (peer %d)" % id + "   |   Esc: leave"


func _on_peer_disconnected(_id: int) -> void:
	if multiplayer.is_server():
		hud_label.text = "Host — partner disconnected" + "   |   Esc: leave"


func _load_level(path: String) -> void:
	_clear_level()
	level_root.add_child(load(path).instantiate(), true)


func _clear_level() -> void:
	for child in level_root.get_children():
		level_root.remove_child(child)
		child.queue_free()


func _enter_game(status: String) -> void:
	menu.hide()
	hud_label.text = status + "   |   Esc: leave"
	hud.show()


func _return_to_menu(status: String) -> void:
	print("[main] back to menu: %s" % status)
	Net.leave()
	_clear_level()
	hud.hide()
	menu.show()
	menu.set_busy(false)
	menu.set_status(status)


func _handle_dev_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			_on_host_requested()
		elif arg == "--join":
			_on_join_requested("127.0.0.1")
		elif arg.begins_with("--join="):
			_on_join_requested(arg.trim_prefix("--join="))

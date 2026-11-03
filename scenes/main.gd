extends Node
## Root scene. Owns the menu, the lobby, the HUD and the current level.
## Flow: menu -> host/join -> lobby (pick roles) -> host starts -> level.
## Only the server picks the level; LevelSpawner replicates it to the client.
##
## Dev shortcut: pass `-- --host` (add `--continue` to load the save) or `-- --join[=ip]` on the command line
## (or in Debug > Customize Run Instances) to skip the menu. `--host` also skips
## the lobby and starts at once; roles then go to whoever is free (`--role=visitor`
## picks one for the host).

const CHAPTER_1_PATH := "res://scenes/levels/chapter_1.tscn"
const TEST_LEVEL_PATH := "res://scenes/levels/test_level.tscn"
const KIT_SAMPLE_PATH := "res://scenes/levels/kit_sample.tscn"
const MENU_AMBIENCE := "amb_lab"

var _in_game := false
## True while the in-game pause menu is up (the game keeps running; your character waits).
var menu_open := false
var _pause_menu := PanelContainer.new()
var _pause_title := Label.new()
var _resume_button := Button.new()
## Pass `--level=test` (test level) or `--level=kit` (level kit sample) instead of Chapter 1.
var _level_path := CHAPTER_1_PATH
## Set when a chapter ends, so the host closing the session does not read as a disconnect.
var _end_status := ""

@onready var game_view: SubViewportContainer = $GameView
@onready var level_root: Node = $GameView/GameViewport/Level
@onready var level_spawner: MultiplayerSpawner = $LevelSpawner
@onready var menu: MainMenu = $MainMenu
@onready var lobby: Lobby = $Lobby
@onready var hud: Control = $Hud
## Cinematic black bars during play (Signalis does this); the HUD sits on top of them.
@onready var letterbox: Control = $Letterbox
@onready var hud_label: Label = $Hud/Label


func _ready() -> void:
	add_to_group("main")
	menu.host_requested.connect(_on_host_requested)
	menu.join_requested.connect(_on_join_requested)
	lobby.start_requested.connect(_start_game)
	lobby.continue_requested.connect(_continue_game)
	lobby.leave_requested.connect(_return_to_menu.bind("Left the lobby."))
	level_spawner.spawned.connect(_on_level_spawned)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	lobby.hide()
	hud.hide()
	Retro.attach(game_view)
	_build_pause_menu()
	Sound.set_ambience(MENU_AMBIENCE)
	_handle_dev_args.call_deferred()


func _notification(what: int) -> void:
	# Disconnect before the tree is torn down, otherwise the partner receives
	# despawn messages for nodes it has already freed.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Net.leave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _in_game:
		get_viewport().set_input_as_handled()
		_set_pause_menu(not menu_open)


## A small bordered menu on Esc: Resume, or leave the session (which ends it for both).
func _build_pause_menu() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0.94)
	frame.set_border_width_all(2)
	frame.border_color = Color(0.85, 0.85, 0.85)
	frame.set_content_margin_all(22)
	_pause_menu.add_theme_stylebox_override("panel", frame)
	_pause_menu.anchor_left = 0.5
	_pause_menu.anchor_right = 0.5
	_pause_menu.anchor_top = 0.5
	_pause_menu.anchor_bottom = 0.5
	_pause_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause_menu.visible = false
	add_child(_pause_menu)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(320, 0)
	column.add_theme_constant_override("separation", 10)
	_pause_menu.add_child(column)
	_pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_pause_title)
	_resume_button.text = "Resume"
	_resume_button.pressed.connect(_set_pause_menu.bind(false))
	column.add_child(_resume_button)
	column.add_child(Radio.make_device_button())
	var leave := Button.new()
	leave.text = "Leave session (ends it for both)"
	leave.pressed.connect(func() -> void:
		MetaSave.record("sessions_abandoned")
		_return_to_menu("Left the session.")
	)
	column.add_child(leave)


func _set_pause_menu(open: bool) -> void:
	menu_open = open
	_pause_menu.visible = open
	if open:
		_resume_button.grab_focus()


func _on_host_requested() -> void:
	var err := Net.host()
	if err != OK:
		menu.set_status("Could not host: %s" % error_string(err))
		return
	print("[main] hosting on port %d" % Net.DEFAULT_PORT)
	_show_lobby()


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
	# If the host is already in a level, it arrives right away through LevelSpawner.
	_show_lobby()


func _on_connection_failed() -> void:
	Net.leave()
	menu.set_busy(false)
	menu.set_status("Could not connect (wrong address, or the session is full).")


func _on_server_disconnected() -> void:
	_return_to_menu(_end_status if _end_status else "The host closed the session.")


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server() and _in_game:
		_set_hud_text("partner connected (peer %d)" % id)


## Zero Point can't be played alone: if the partner leaves mid-game, the session ends.
func _on_peer_disconnected(_id: int) -> void:
	if multiplayer.is_server() and _in_game:
		_return_to_menu(_end_status if _end_status else "Your partner left. Zero Point takes two.")


## Server only.
func _start_game() -> void:
	SaveGame.pending = {}
	_load_level(_level_path)
	_enter_game()


## Host: picks up from the last save (both machines keep a copy; the host's is used).
func _continue_game() -> void:
	var save := SaveGame.read_save()
	if save.is_empty():
		_start_game()
		return
	SaveGame.pending = save
	_load_level(save["level"])
	_enter_game()


## Called on both machines when a chapter ends.
func end_session_after(delay: float, status: String) -> void:
	_end_status = status
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if _in_game:
			_return_to_menu(status)
	)


## Client only: the host started (or had already started) the level.
func _on_level_spawned(_level: Node) -> void:
	_enter_game()


func _load_level(path: String) -> void:
	_clear_level()
	level_root.add_child(load(path).instantiate(), true)


func _clear_level() -> void:
	for child in level_root.get_children():
		level_root.remove_child(child)
		child.queue_free()


func _show_lobby() -> void:
	menu.hide()
	lobby.refresh()
	lobby.show()


func _enter_game() -> void:
	_in_game = true
	MetaSave.begin_session()
	menu.hide()
	lobby.hide()
	_set_hud_text("in session")
	letterbox.show()


func _set_hud_text(status: String) -> void:
	var role: String = Session.ROLE_NAMES[Session.local_role()]
	_pause_title.text = "%s — %s" % [role.to_upper(), status]


func _return_to_menu(status: String) -> void:
	print("[main] back to menu: %s" % status)
	_in_game = false
	_end_status = ""
	_set_pause_menu(false)
	Net.leave()
	Session.reset()
	Story.clear()
	_clear_level()
	hud.hide()
	letterbox.hide()
	lobby.hide()
	menu.show()
	Sound.set_ambience(MENU_AMBIENCE)
	menu.set_busy(false)
	menu.set_status(status)


func _handle_dev_args() -> void:
	var args := OS.get_cmdline_user_args()
	if "--level=test" in args:
		_level_path = TEST_LEVEL_PATH
	elif "--level=kit" in args:
		_level_path = KIT_SAMPLE_PATH
	for arg in args:
		if arg == "--host":
			_on_host_requested()
			if "--role=visitor" in args:
				Session.request_role(Session.Role.VISITOR)
			if "--continue" in args:
				_continue_game()
			else:
				_start_game()
		elif arg == "--join":
			_on_join_requested("127.0.0.1")
		elif arg.begins_with("--join="):
			_on_join_requested(arg.trim_prefix("--join="))

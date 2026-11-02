class_name Lobby
extends Control
## Role selection after connecting. Each player claims Subject or Visitor;
## the host starts once both roles are taken. Built in code like PlayerHud.

signal start_requested
signal leave_requested

var _role_buttons := {} # Session.Role -> Button
var _start_button := Button.new()
var _leave_button := Button.new()
var _status_label := Label.new()


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.03, 0.03, 0.04)
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(380, 0)
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)

	var title := Label.new()
	title.text = "Choose your role"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	for role in [Session.Role.SUBJECT, Session.Role.VISITOR]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.pressed.connect(Session.request_role.bind(role))
		column.add_child(button)
		_role_buttons[role] = button

	_start_button.text = "Start"
	_start_button.pressed.connect(start_requested.emit)
	column.add_child(_start_button)
	_leave_button.text = "Leave"
	_leave_button.pressed.connect(leave_requested.emit)
	column.add_child(_leave_button)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)

	Session.roles_changed.connect(refresh)
	multiplayer.peer_connected.connect(func(_id: int) -> void: refresh())
	multiplayer.peer_disconnected.connect(func(_id: int) -> void: refresh())
	refresh()


func refresh() -> void:
	var me := multiplayer.get_unique_id()
	for role in _role_buttons:
		var holder := Session.peer_with_role(role)
		var text: String = "%s\n%s" % [Session.ROLE_NAMES[role], Session.ROLE_BLURBS[role]]
		if holder == me:
			text += "  (you)"
		elif holder != 0:
			text += "  (partner)"
		_role_buttons[role].text = text
		_role_buttons[role].disabled = holder != 0 and holder != me

	_start_button.visible = multiplayer.is_server()
	_start_button.disabled = not Session.is_ready_to_start()
	if multiplayer.get_peers().is_empty():
		_status_label.text = "Waiting for your partner to join..."
	elif not Session.is_ready_to_start():
		_status_label.text = "Each player picks a different role."
	elif multiplayer.is_server():
		_status_label.text = "Ready."
	else:
		_status_label.text = "Ready. Waiting for the host to start."

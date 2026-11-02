class_name MainMenu
extends Control
## Host / Join / Quit. Only emits requests; `main.gd` decides what happens.

signal host_requested
signal join_requested(address: String)

@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var quit_button: Button = %QuitButton
@onready var address_edit: LineEdit = %AddressEdit
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	host_button.pressed.connect(host_requested.emit)
	join_button.pressed.connect(_request_join)
	address_edit.text_submitted.connect(func(_text: String) -> void: _request_join())
	quit_button.pressed.connect(get_tree().quit)


func set_status(text: String) -> void:
	status_label.text = text


## Disables Host/Join while a connection attempt is in flight.
func set_busy(busy: bool) -> void:
	host_button.disabled = busy
	join_button.disabled = busy
	address_edit.editable = not busy


func _request_join() -> void:
	join_requested.emit(address_edit.text.strip_edges())

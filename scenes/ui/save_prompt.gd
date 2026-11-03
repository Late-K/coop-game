class_name SavePrompt
extends Control
## The joint save screen at a save terminal, in the ZP-SYS terminal's style. Saving needs
## both players at a terminal: each confirms here, and the game saves when both have (see
## SaveGame). Tab or Esc leaves; the character stands still while it is open.

const SAVED_TIME := 1.6

var player: Player
var terminal: SaveTerminal

var _you := Label.new()
var _partner := Label.new()
var _message := Label.new()
var _hint := Label.new()
var _done := false


func _init() -> void:
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT) # created in code: give it the screen's size
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", InventoryScreen._style(InventoryScreen.SCREEN,
			InventoryScreen.PHOSPHOR, 3, 22, 26))
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -300
	frame.offset_right = 300
	frame.offset_top = -150
	frame.offset_bottom = 150
	add_child(frame)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	frame.add_child(page)
	page.add_child(InventoryScreen._label("ZP-SYS // OCCUPANCY RECORD", 16, InventoryScreen.PHOSPHOR))
	page.add_child(InventoryScreen._rule())
	page.add_child(InventoryScreen._label("RECORD PROGRESS?", 22, InventoryScreen.PHOSPHOR))
	var note := InventoryScreen._label("Both occupants must confirm, each at a terminal.", 14,
			InventoryScreen.PHOSPHOR.darkened(0.2))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)
	for label in [_you, _partner, _message]:
		label.add_theme_font_size_override("font_size", 16)
		page.add_child(label)
	page.add_child(InventoryScreen._spacer_v())
	page.add_child(InventoryScreen._rule())
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.modulate = InventoryScreen.DIM.lightened(0.3)
	page.add_child(_hint)
	SaveGame.statuses_changed.connect(refresh)
	SaveGame.saved.connect(_on_saved)


func open(owner_player: Player, at: SaveTerminal) -> void:
	player = owner_player
	terminal = at
	_done = false
	visible = true
	Story.suppressed = true
	SaveGame.set_status(SaveGame.Status.AT_TERMINAL, terminal)
	Sound.play_ui("keypad_press", -4.0, 0.8)
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	Story.suppressed = false
	if not _done:
		SaveGame.set_status(SaveGame.Status.AWAY)
	Sound.play_ui("keypad_press", -6.0, 0.6)


func _input(event: InputEvent) -> void:
	if not visible or _done:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if SaveGame.status_of(multiplayer.get_unique_id()) != SaveGame.Status.READY:
			SaveGame.set_status(SaveGame.Status.READY, terminal, player.save_state())
			Sound.play_ui("keypad_press", -2.0, 1.1)


func refresh() -> void:
	if not visible or _done:
		return
	var ready := SaveGame.status_of(multiplayer.get_unique_id()) == SaveGame.Status.READY
	_you.text = "YOU ........ %s" % ("READY" if ready else "AT TERMINAL")
	_you.modulate = InventoryScreen.PHOSPHOR
	var partner: SaveGame.Status = SaveGame.partner_status()
	_partner.text = "PARTNER .... %s" % ["NOT AT A TERMINAL", "AT A TERMINAL", "READY"][partner]
	_partner.modulate = InventoryScreen.PHOSPHOR if partner != SaveGame.Status.AWAY else PlayerHud.RADIO_COLOR
	_message.text = "WAITING FOR PARTNER." if ready else ""
	_message.modulate = InventoryScreen.PHOSPHOR.darkened(0.2)
	_hint.text = "[Tab] leave" if ready else "[E] confirm   [Tab] leave"


func _on_saved() -> void:
	if not visible:
		return
	_done = true
	_you.text = ""
	_partner.text = ""
	_message.text = MetaSave.format("PROGRESS RECORDED. OCCUPANT {iteration}.")
	_message.modulate = InventoryScreen.PHOSPHOR
	_hint.text = ""
	Sound.play_ui("code_right", -6.0)
	get_tree().create_timer(SAVED_TIME).timeout.connect(close)

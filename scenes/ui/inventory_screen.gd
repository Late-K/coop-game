class_name InventoryScreen
extends Control
## The player's own interface (Tab), built in code the first time it opens, in the local
## player's style (UiStyle). The Subject's is the ZP-SYS occupant terminal in cold cyan:
## part of the facility, and so part of PROCTOR; later chapters can corrupt it. The
## Visitor's is a handheld field unit, all in red, laid out its own way (PACK, RADIO, MAP, NOTES, LOG).
##
## ITEMS: status (condition ECG, body temperature, equipped weapon), the six carried slots,
## and the selected item's description and actions (Use, Equip, Combine, Inspect, Drop).
## RADIO: the tuner (RadioTuner): find stations, at the cost of the partner channel.
## MAP: the floor plans this player has found (MapView). FILES: documents read (FilesView).
## LOGS: every story line and message seen this session.
## Opened from an item box, the right column shows the box instead: choose a slot on either
## side to move it across. Opened from a device (tube, heater...), you choose which item to
## use on it; the device decides what happens (see `device`).
## The game keeps running while it is open (co-op can't pause); the character stands still.

const CAUTION_COLOR := Color(1.0, 0.75, 0.3)
const DANGER_COLOR := Color(1.0, 0.3, 0.25)
## Seconds to switch on (the tube's line opening up).
const POWER_TIME := 0.25

var player: Player
## The item box's storage while opened from one, else null.
var box: Inventory = null
## The machine the terminal was opened on, else null. It provides
## `terminal_text() -> String` (shown in the right column) and
## `use_slot_on(player, index) -> bool` (true closes the terminal).
var device: Node = null

var _selected := 0
var _combine_from := -1
var _inspecting := false
var _tab := "items"

var _slot_buttons: Array[Button] = []
var _box_buttons: Array[Button] = []
var _action_buttons := {}
var _role_label := Label.new()
var _condition_label := Label.new()
var _temperature_label := Label.new()
var _weapon_label := Label.new()
var _ecg := Control.new()
var _ecg_time := 0.0
var _item_name := Label.new()
var _item_text := Label.new()
var _item_icon := TextureRect.new()
var _hint := Label.new()
var _items_page := HBoxContainer.new()
var _radio_page: RadioTuner
var _map_page: MapView
var _files_page: FilesView
var _logs_page := ScrollContainer.new()
var _logs_list := VBoxContainer.new()
var _actions_box: BoxContainer = VBoxContainer.new()
var _box_panel := VBoxContainer.new()
var _device_label := Label.new()
var _tab_buttons := {}
var _notice := ""
var _notice_time := 0.0
var _built := false
var _screen_panel: Control
var _glass := ShaderMaterial.new()
var _clock := Label.new()
var _signal := Label.new()
## The handheld's chest-strap pulse: one reading every PULSE_STEP seconds, the last minute.
const PULSE_STEP := 1.5
const PULSE_SAMPLES := 40
var _pulse_history := PackedFloat32Array()
var _pulse_time := 0.0


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	mouse_filter = MOUSE_FILTER_STOP


## Built on first open, once the player's role (and so the style) is known.
func _build() -> void:
	_built = true
	theme = Theme.new()
	theme.default_font = UiStyle.font()
	# It fills the whole screen: the player's screen *is* the device. Both are tubes edge to
	# edge (the CRT glass below); what's on them is nothing alike.
	var frame := PanelContainer.new()
	frame.set_anchors_preset(PRESET_FULL_RECT)
	var tube := _style(UiStyle.screen, UiStyle.screen, 0, 0, 0)
	tube.content_margin_left = 84
	tube.content_margin_right = 84
	tube.content_margin_top = 58
	tube.content_margin_bottom = 58
	frame.add_theme_stylebox_override("panel", tube)
	var screen_panel := frame
	_screen_panel = screen_panel
	add_child(frame)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	screen_panel.add_child(page)

	var header := HBoxContainer.new()
	page.add_child(header)
	# The Subject's tabs sit in the header; the handheld's are soft keys along the bottom.
	var tab_bar := header
	if UiStyle.visitor():
		# A status bar: radio signal, battery, the time, and the pulse from the chest strap.
		for label in [_signal, _clock, _role_label]:
			label.add_theme_font_size_override("font_size", 14)
			label.modulate = UiStyle.accent
		header.add_child(_signal)
		header.add_child(_label("   BATT [###.]   ", 14, UiStyle.accent))
		header.add_child(_clock)
		header.add_child(_spacer())
		header.add_child(_role_label)
		tab_bar = HBoxContainer.new()
		tab_bar.add_theme_constant_override("separation", 6)
	else:
		header.add_child(_label(UiStyle.title, 16, UiStyle.accent))
		header.add_child(_spacer())
	for tab in ["items", "radio", "map", "files", "logs"]:
		var button := _softkey(UiStyle.tab_names[tab]) if UiStyle.visitor() else _button(UiStyle.tab_names[tab], 14)
		button.pressed.connect(_show_tab.bind(tab))
		tab_bar.add_child(button)
		_tab_buttons[tab] = button
	page.add_child(_rule())
	_radio_page = RadioTuner.new()
	_map_page = MapView.new()
	_files_page = FilesView.new()

	if UiStyle.visitor():
		_build_pack_page()
	else:
		_build_items_page()
	page.add_child(_items_page)
	_items_page.size_flags_vertical = SIZE_EXPAND_FILL
	_radio_page.size_flags_vertical = SIZE_EXPAND_FILL
	page.add_child(_radio_page)
	for extra: Control in [_map_page, _files_page]:
		extra.size_flags_vertical = SIZE_EXPAND_FILL
		page.add_child(extra)
	_logs_page.size_flags_vertical = SIZE_EXPAND_FILL
	_logs_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_logs_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_logs_page.add_child(_logs_list)
	page.add_child(_logs_page)

	page.add_child(_rule())
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.modulate = UiStyle.dim.lightened(0.3)
	page.add_child(_hint)
	if tab_bar != header:
		page.add_child(tab_bar)

	# The glass over everything: the CRT (curvature, scanlines, glow, the power-on line),
	# flashing in each device's own colour.
	var glass := ColorRect.new()
	glass.set_anchors_preset(PRESET_FULL_RECT)
	glass.mouse_filter = MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SavePrompt.CRT
	_glass.shader = shader
	glass.material = _glass # only once it has its shader, or it draws as a plain white rect
	_glass.set_shader_parameter("flash", Vector3(1.0, 0.6, 0.5) if UiStyle.visitor() else Vector3(0.75, 1.0, 0.95))
	add_child(glass)


## `target` is an item box's Inventory, an ItemTube, or null for the plain terminal.
func open(owner_player: Player, target: Variant = null) -> void:
	player = owner_player
	if not _built:
		_build()
	_map_page.player = player
	_files_page.player = player
	box = target as Inventory
	device = target as Node
	_combine_from = -1
	_inspecting = false
	if not player.inventory.changed.is_connected(refresh):
		player.inventory.changed.connect(refresh)
	if box and not box.changed.is_connected(refresh):
		box.changed.connect(refresh)
	visible = true
	Story.suppressed = true # lines keep playing into LOGS instead of covering the terminal
	# Switching on: the tube's line opening up.
	create_tween().tween_method(func(v: float) -> void: _glass.set_shader_parameter("power", v), 0.0, 1.0,
			POWER_TIME).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_show_tab("items")
	_slot_buttons[_selected].grab_focus()
	Sound.play_ui("keypad_press", -4.0, 0.8)


func close() -> void:
	visible = false
	Story.suppressed = false
	Radio.tuner_open = false
	if box and box.changed.is_connected(refresh):
		box.changed.disconnect(refresh)
	box = null
	device = null
	Sound.play_ui("keypad_press", -6.0, 0.6)


## Tab / Esc are caught before the GUI sees them: otherwise Tab moves focus between buttons
## (or types into the message field) instead of closing the terminal.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _tab == "map" and (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")):
		get_viewport().set_input_as_handled()
		_map_page.change_floor(1 if event.is_action_pressed("ui_up") else -1)
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _radio_page.is_typing():
			_radio_page.stop_typing()
		elif _combine_from >= 0 or _inspecting:
			_combine_from = -1
			_inspecting = false
			refresh()
		else:
			player.close_inventory()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and is_ancestor_of(focused):
			get_viewport().set_input_as_handled()
			focused.pressed.emit()


func _process(delta: float) -> void:
	if visible and UiStyle.visitor():
		_clock.text = Time.get_time_string_from_system().left(5)
		var bars := "----" if not Radio.powered else ("||||" if Radio.on_home_channel() else "||..")
		_signal.text = "SIG [%s]" % bars
		_pulse_time -= delta
		if _pulse_time <= 0.0 and is_instance_valid(player):
			_pulse_time = PULSE_STEP
			_pulse_history.append(_pulse())
			if _pulse_history.size() > PULSE_SAMPLES:
				_pulse_history = _pulse_history.slice(-PULSE_SAMPLES)
			_role_label.text = "PULSE %03d" % roundi(_pulse_history[-1])
	if visible:
		_ecg_time += delta
		_ecg.queue_redraw()
		if _notice_time > 0.0:
			_notice_time -= delta
			if _notice_time <= 0.0:
				_notice = ""
				refresh()


## Feedback from an action ("Loaded", "That doesn't fit"), shown in amber on the hint line.
func show_notice(text: String) -> void:
	_notice = text
	_notice_time = 2.0
	refresh()


# --- building ------------------------------------------------------------------

func _build_items_page() -> void:
	_items_page.add_theme_constant_override("separation", 18)

	var status := VBoxContainer.new()
	status.custom_minimum_size = Vector2(250, 0)
	status.add_theme_constant_override("separation", 8)
	_items_page.add_child(status)
	_role_label.add_theme_font_size_override("font_size", 22)
	_role_label.modulate = UiStyle.accent
	status.add_child(_role_label)
	_ecg.custom_minimum_size = Vector2(250, 80)
	_ecg.draw.connect(_draw_ecg)
	status.add_child(_ecg)
	for label in [_condition_label, _temperature_label, _weapon_label]:
		label.modulate = UiStyle.accent
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.add_child(label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_items_page.add_child(grid)
	for i in Inventory.SLOT_COUNT:
		var button := _slot_button(Vector2(124, 112))
		button.pressed.connect(_on_slot_pressed.bind(i))
		button.focus_entered.connect(_on_slot_focused.bind(i))
		grid.add_child(button)
		_slot_buttons.append(button)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	_items_page.add_child(details)
	_item_name.add_theme_font_size_override("font_size", 20)
	_item_name.modulate = UiStyle.accent
	details.add_child(_item_name)
	_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_icon.custom_minimum_size = Vector2(0, 110)
	_item_icon.visible = false
	details.add_child(_item_icon)
	_item_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_text.modulate = UiStyle.accent.darkened(0.15)
	_item_text.custom_minimum_size = Vector2(250, 0)
	details.add_child(_item_text)
	details.add_child(_spacer_v())
	details.add_child(_actions_box)
	for action in ["Use", "Equip", "Combine", "Inspect", "Drop"]:
		var button := _button(action.to_upper(), 15)
		button.pressed.connect(_on_action.bind(action))
		_actions_box.add_child(button)
		_action_buttons[action] = button

	_device_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_device_label.modulate = UiStyle.accent
	details.add_child(_device_label)
	details.add_child(_box_panel)
	_box_panel.add_child(_label("ITEM BOX", 16, UiStyle.accent))
	var box_grid := GridContainer.new()
	box_grid.columns = 4
	box_grid.add_theme_constant_override("h_separation", 4)
	box_grid.add_theme_constant_override("v_separation", 4)
	_box_panel.add_child(box_grid)
	for i in ItemBox.STASH_SLOTS:
		var button := _slot_button(Vector2(72, 52))
		button.pressed.connect(_on_box_slot_pressed.bind(i))
		box_grid.add_child(button)
		_box_buttons.append(button)


## The handheld's PACK page: the same slots, actions, box and device modes as the Subject's
## ITEMS, laid out like a cheap device: a numbered list of what you carry, the chosen
## item's picture and notes beside it, soft-key actions along its foot, and the pulse.
func _build_pack_page() -> void:
	_items_page.add_theme_constant_override("separation", 22)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.add_theme_constant_override("separation", 4)
	_items_page.add_child(left)
	left.add_child(_label("CARRYING", 13, UiStyle.dim.lightened(0.4)))
	for i in Inventory.SLOT_COUNT:
		var row := _row_button()
		row.pressed.connect(_on_slot_pressed.bind(i))
		row.focus_entered.connect(_on_slot_focused.bind(i))
		left.add_child(row)
		_slot_buttons.append(row)
	left.add_child(_spacer_v())
	left.add_child(_label("PULSE  /  60 s", 13, UiStyle.dim.lightened(0.4)))
	_ecg.custom_minimum_size = Vector2(0, 70)
	_ecg.draw.connect(_draw_pulse)
	left.add_child(_ecg)
	var vitals := HBoxContainer.new()
	vitals.add_theme_constant_override("separation", 24)
	left.add_child(vitals)
	for label in [_condition_label, _temperature_label]:
		label.modulate = UiStyle.accent
		vitals.add_child(label)
	_weapon_label.modulate = UiStyle.accent
	left.add_child(_weapon_label)

	var right := PanelContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", _style(UiStyle.panel, UiStyle.dim, 1, 0, 14))
	_items_page.add_child(right)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 10)
	right.add_child(details)
	_item_name.add_theme_font_size_override("font_size", 24)
	_item_name.modulate = UiStyle.accent
	details.add_child(_item_name)
	_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_icon.custom_minimum_size = Vector2(0, 120)
	_item_icon.modulate = UiStyle.accent # pictures show in the LCD's one colour
	_item_icon.visible = false
	details.add_child(_item_icon)
	_item_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_text.modulate = UiStyle.accent.darkened(0.1)
	details.add_child(_item_text)
	details.add_child(_spacer_v())
	_device_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_device_label.modulate = UiStyle.accent
	details.add_child(_device_label)
	details.add_child(_box_panel)
	_box_panel.add_child(_label("STORAGE BOX", 14, UiStyle.accent))
	var box_grid := GridContainer.new()
	box_grid.columns = 2
	box_grid.add_theme_constant_override("h_separation", 6)
	box_grid.add_theme_constant_override("v_separation", 2)
	_box_panel.add_child(box_grid)
	for i in ItemBox.STASH_SLOTS:
		var row := _row_button(true)
		row.pressed.connect(_on_box_slot_pressed.bind(i))
		box_grid.add_child(row)
		_box_buttons.append(row)
	_actions_box = HBoxContainer.new()
	_actions_box.add_theme_constant_override("separation", 6)
	details.add_child(_actions_box)
	for action in ["Use", "Equip", "Combine", "Inspect", "Drop"]:
		var key := _softkey("CHECK" if action == "Inspect" else action.to_upper())
		key.size_flags_horizontal = SIZE_EXPAND_FILL
		key.pressed.connect(_on_action.bind(action))
		_actions_box.add_child(key)
		_action_buttons[action] = key


## A list row on the handheld: number, small picture, name, count. Chosen rows invert.
func _row_button(compact := false) -> Button:
	var row := Button.new()
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, 30 if compact else 44)
	row.add_theme_font_size_override("font_size", 13 if compact else 16)
	row.add_theme_constant_override("icon_max_width", 0 if compact else 46)
	row.add_theme_constant_override("h_separation", 12)
	for state in ["icon_normal_color", "icon_focus_color", "icon_hover_color", "icon_pressed_color"]:
		row.add_theme_color_override(state, UiStyle.accent)
	var plain := _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 6)
	row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	row.add_theme_stylebox_override("hover", _style(UiStyle.fill, UiStyle.fill, 0, 0, 6))
	row.add_theme_stylebox_override("pressed", plain)
	return row


## A soft key: a labelled box along the foot of the screen, filled when it is the one chosen.
func _softkey(text: String) -> Button:
	var key := Button.new()
	key.text = text
	key.custom_minimum_size = Vector2(96, 30)
	key.add_theme_font_size_override("font_size", 14)
	key.add_theme_color_override("font_color", UiStyle.accent)
	key.add_theme_color_override("font_disabled_color", UiStyle.dim)
	key.add_theme_color_override("font_focus_color", UiStyle.screen)
	key.add_theme_color_override("font_hover_color", UiStyle.screen)
	key.add_theme_stylebox_override("normal", _style(UiStyle.screen, UiStyle.accent, 2, 3, 4))
	key.add_theme_stylebox_override("focus", _style(UiStyle.accent, UiStyle.accent, 2, 3, 4))
	key.add_theme_stylebox_override("hover", _style(UiStyle.accent, UiStyle.accent, 2, 3, 4))
	key.add_theme_stylebox_override("pressed", _style(UiStyle.accent.darkened(0.2), UiStyle.accent, 2, 3, 4))
	key.add_theme_stylebox_override("disabled", _style(UiStyle.screen, UiStyle.dim, 1, 3, 4))
	return key


# --- refresh --------------------------------------------------------------------

func refresh() -> void:
	if not visible or player == null:
		return
	_items_page.visible = _tab == "items"
	_logs_page.visible = _tab == "logs"
	_radio_page.visible = _tab == "radio"
	_map_page.visible = _tab == "map"
	_files_page.visible = _tab == "files"
	for tab in _tab_buttons:
		if UiStyle.visitor():
			# The chosen soft key is filled in.
			var chosen: bool = tab == _tab
			_tab_buttons[tab].add_theme_stylebox_override("normal", _style(UiStyle.accent if chosen else UiStyle.screen,
					UiStyle.accent, 2, 3, 4))
			_tab_buttons[tab].add_theme_color_override("font_color", UiStyle.screen if chosen else UiStyle.accent)
		else:
			_tab_buttons[tab].add_theme_color_override("font_color", UiStyle.accent if tab == _tab else UiStyle.dim)
	if _tab == "logs":
		_refresh_logs()
		_hint.text = "[Tab] close   [Mouse wheel] scroll"
		return
	if _tab == "map":
		_hint.text = "[Tab] close"
		_apply_notice()
		return
	if _tab == "files":
		_hint.text = "[Up/Down] choose   [Tab] close"
		_apply_notice()
		return
	if _tab == "radio":
		_hint.text = "[Left/Right] tune   [Up] power   [Down] write a message, [Enter] send   [Tab] close"
		_apply_notice()
		return

	var condition := _condition()
	_condition_label.modulate = _condition_color(condition)
	if UiStyle.visitor():
		# The handheld's own words; the pulse in the status bar is kept up in _process.
		_condition_label.text = "COND  %s" % {"FINE": "OK", "CAUTION": "HURT", "DANGER": "CRITICAL"}[condition]
		_temperature_label.text = "TEMP  %.1f C" % player.body_temperature()
		_weapon_label.text = "HELD  %s" % ("%s  %d/%d" % [Items.display_name(player.equipped).to_upper(),
				player.loaded_rounds, player.inventory.count_of("ammo")] if player.equipped else "-")
	else:
		_role_label.text = Session.ROLE_NAMES[player.role].to_upper()
		_condition_label.text = "CONDITION: %s" % condition
		_temperature_label.text = "BODY TEMP: %.1f °C" % player.body_temperature()
		if player.equipped:
			_weapon_label.text = "EQUIPPED: %s  %d / %d" % [Items.display_name(player.equipped).to_upper(),
					player.loaded_rounds, player.inventory.count_of("ammo")]
		else:
			_weapon_label.text = "EQUIPPED: NONE"

	for i in _slot_buttons.size():
		_fill_slot(_slot_buttons[i], player.inventory.slots[i], i == _selected, i == _combine_from, i)
	var slot := player.inventory.slots[_selected]
	_item_name.text = Items.display_name(slot["id"]).to_upper() if not slot.is_empty() else "EMPTY"
	_item_text.text = Items.description(slot["id"]) if not slot.is_empty() else ""
	_item_icon.visible = _inspecting and not slot.is_empty()
	_item_icon.texture = Items.icon(slot["id"]) if not slot.is_empty() else null

	_actions_box.visible = box == null and device == null
	_box_panel.visible = box != null
	_device_label.visible = device != null
	if device:
		_device_label.text = device.terminal_text()
		_hint.text = "[Tab] cancel   [E / click] use the chosen item here"
	elif box:
		for i in _box_buttons.size():
			_fill_slot(_box_buttons[i], box.slots[i], false, false)
		_hint.text = "[Tab] close   [E / click] move between your slots and the box"
	else:
		var item := "" if slot.is_empty() else String(slot["id"])
		_action_buttons["Use"].disabled = item == "" or Items.kind(item) not in ["consumable", "ammo"]
		_action_buttons["Equip"].disabled = item == "" or Items.kind(item) != "weapon"
		_action_buttons["Equip"].text = "UNEQUIP" if item != "" and player.equipped == item else "EQUIP"
		_action_buttons["Combine"].disabled = item == "" or Items.get_value(item, "combine", {}).is_empty()
		_action_buttons["Inspect"].disabled = item == ""
		_action_buttons["Drop"].disabled = item == ""
		_hint.text = "COMBINE WITH WHICH ITEM?   [Tab] cancel" if _combine_from >= 0 \
				else "[Tab] close   [Arrows] move   [E / click] select"
	_apply_notice()


func _apply_notice() -> void:
	_hint.modulate = Color(1.0, 0.75, 0.3) if _notice else UiStyle.dim.lightened(0.3)
	if _notice:
		_hint.text = _notice.to_upper()


func _fill_slot(button: Button, slot: Dictionary, selected: bool, marked: bool, index := -1) -> void:
	if UiStyle.visitor():
		_fill_row(button, slot, selected, marked, index)
		return
	if slot.is_empty():
		button.icon = null
		button.text = ""
	else:
		button.icon = Items.icon(slot["id"])
		var count := " x%d" % slot["count"] if Items.max_stack(slot["id"]) > 1 else ""
		button.text = Items.display_name(slot["id"]).to_upper() + count
	var border := Color(1.0, 0.75, 0.3) if marked else (UiStyle.accent if selected else UiStyle.dim)
	button.add_theme_stylebox_override("normal", _style(UiStyle.fill if selected else UiStyle.screen, border,
			2 if selected or marked else 1, 4, 6))


## A handheld list row: "01  [picture]  PISTOL  x1". The chosen row is filled in; the one
## waiting to be combined is outlined in white.
func _fill_row(row: Button, slot: Dictionary, selected: bool, marked: bool, index: int) -> void:
	var number := "%02d  " % (index + 1) if index >= 0 else ""
	if slot.is_empty():
		row.icon = null
		row.text = number + "-"
	else:
		row.icon = Items.icon(slot["id"]) if index >= 0 else null
		var count := "  x%d" % slot["count"] if Items.max_stack(slot["id"]) > 1 else ""
		row.text = number + Items.display_name(slot["id"]).to_upper() + count
	var ink := UiStyle.screen if selected else UiStyle.accent
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		row.add_theme_color_override(state, ink)
	# On the filled row the picture would be a dark block; it steps aside (keeping its space).
	var picture := Color(0, 0, 0, 0) if selected else UiStyle.accent
	for state in ["icon_normal_color", "icon_focus_color", "icon_hover_color", "icon_pressed_color"]:
		row.add_theme_color_override(state, picture)
	var back := UiStyle.accent if selected else Color(0, 0, 0, 0)
	var edge := Color(1.0, 0.95, 0.9) if marked else back
	row.add_theme_stylebox_override("normal", _style(back, edge, 2 if marked else 0, 0, 6))
	row.add_theme_stylebox_override("hover", _style(back if selected else UiStyle.fill, edge, 2 if marked else 0, 0, 6))


func _refresh_logs() -> void:
	for child in _logs_list.get_children():
		child.queue_free()
	if Story.history.is_empty():
		_logs_list.add_child(_label("NO ENTRIES.", 14, UiStyle.dim))
	for entry in Story.history:
		var line := _label(entry["text"], 14, entry["color"])
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(900, 0)
		_logs_list.add_child(line)
	await get_tree().process_frame
	_logs_page.scroll_vertical = int(_logs_page.get_v_scroll_bar().max_value)


## On the Visitor's red screen, danger is the one thing not red: it burns white.
func _condition_color(condition: String) -> Color:
	if UiStyle.visitor():
		return {"FINE": UiStyle.accent, "CAUTION": Color(1.0, 0.62, 0.35), "DANGER": Color(1.0, 0.95, 0.9)}[condition]
	return {"FINE": UiStyle.accent, "CAUTION": CAUTION_COLOR, "DANGER": DANGER_COLOR}[condition]


func _condition() -> String:
	if player.health > Player.MAX_HEALTH * 0.66:
		return "FINE"
	if player.health > Player.MAX_HEALTH * 0.33:
		return "CAUTION"
	return "DANGER"


## The Visitor's heart rate: higher when hurt or cold, never quite steady.
func _pulse() -> float:
	var resting: float = {"FINE": 74.0, "CAUTION": 104.0, "DANGER": 136.0}[_condition()]
	var cold := (1.0 - player.warmth / Player.MAX_WARMTH) * 28.0 if player.feels_cold else 0.0
	return resting + cold + randf_range(-4.0, 4.0)


## The handheld's pulse graph: a bar per reading, stepped like LCD segments, newest right.
func _draw_pulse() -> void:
	var area := _ecg.size
	_ecg.draw_rect(Rect2(Vector2.ZERO, area), UiStyle.panel)
	var width := area.x / PULSE_SAMPLES
	var color := _condition_color(_condition())
	for i in _pulse_history.size():
		var level := clampf((_pulse_history[i] - 50.0) / 110.0, 0.05, 1.0)
		var steps := ceili(level * 8.0)
		var x := area.x - (_pulse_history.size() - i) * width
		for s in steps:
			var h := area.y / 8.0
			_ecg.draw_rect(Rect2(x + 1, area.y - (s + 1) * h + 1, width - 2, h - 2), color)


## Heart trace. The Visitor's beats vary like a living pulse; the Subject's are identical,
## mechanically regular. Faster and redder as condition worsens.
func _draw_ecg() -> void:
	var area := _ecg.size
	var condition := _condition()
	var color := _condition_color(condition)
	var rate: float = {"FINE": 1.0, "CAUTION": 1.5, "DANGER": 2.3}[condition]
	var machine := player.role == Session.Role.SUBJECT
	_ecg.draw_rect(Rect2(Vector2.ZERO, area), UiStyle.panel)
	var points := PackedVector2Array()
	for x in range(0, int(area.x), 2):
		var t := (x / area.x) * 3.0 + _ecg_time * rate
		var beat := fmod(t, 1.0)
		if not machine:
			beat = fmod(t + 0.08 * sin(floor(t) * 2.3), 1.0)
		var y := 0.0
		if beat > 0.30 and beat < 0.34:
			y = -0.15
		elif beat > 0.38 and beat < 0.42:
			y = 0.9 if not machine else 0.75
		elif beat > 0.42 and beat < 0.46:
			y = -0.35
		elif beat > 0.6 and beat < 0.7:
			y = 0.2
		points.append(Vector2(x, area.y * 0.55 - y * area.y * 0.4))
	_ecg.draw_polyline(points, color, 2.0)


# --- actions --------------------------------------------------------------------

## Opens straight on a tab (e.g. FILES on the document just read).
func show_tab(tab: String, doc_id := "") -> void:
	_show_tab(tab)
	if tab == "files":
		_files_page.open(doc_id)


func _show_tab(tab: String) -> void:
	_tab = tab
	Radio.tuner_open = tab == "radio" and visible
	refresh()
	if tab == "items" and visible:
		_slot_buttons[_selected].grab_focus()
	elif tab == "radio" and visible:
		_radio_page.open()
	elif tab == "files" and visible:
		_files_page.open()
	elif tab == "map" and visible:
		_map_page.show_player_floor()
		_tab_buttons["map"].grab_focus()


func _on_slot_focused(index: int) -> void:
	if _selected != index:
		_selected = index
		_inspecting = false
		refresh()


func _on_slot_pressed(index: int) -> void:
	_selected = index
	if _combine_from >= 0:
		var from := _combine_from
		_combine_from = -1
		player.combine_slots(from, index)
	elif device:
		if not player.inventory.slots[index].is_empty() and device.use_slot_on(player, index):
			player.close_inventory()
			return
	elif box:
		player.store_slot(index, box)
	refresh()


func _on_box_slot_pressed(index: int) -> void:
	player.take_from_box(index, box)
	refresh()


func _on_action(action: String) -> void:
	match action:
		"Use":
			player.use_slot(_selected)
		"Equip":
			player.equip_slot(_selected)
		"Combine":
			_combine_from = _selected
		"Inspect":
			_inspecting = not _inspecting
		"Drop":
			player.drop_slot(_selected)
	refresh()
	if action != "Inspect":
		_slot_buttons[_selected].grab_focus()


# --- widgets (static: RadioTuner uses them too) -------------------------------------

static func _style(bg: Color, border: Color, width: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	return label


static func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", UiStyle.accent)
	button.add_theme_color_override("font_focus_color", UiStyle.screen)
	button.add_theme_color_override("font_hover_color", UiStyle.screen)
	button.add_theme_color_override("font_disabled_color", UiStyle.dim.darkened(0.3))
	button.add_theme_stylebox_override("normal", _style(UiStyle.screen, UiStyle.dim, 1, 2, 6))
	button.add_theme_stylebox_override("hover", _style(UiStyle.accent, UiStyle.accent, 1, 2, 6))
	button.add_theme_stylebox_override("focus", _style(UiStyle.accent, UiStyle.accent, 1, 2, 6))
	button.add_theme_stylebox_override("pressed", _style(UiStyle.accent.darkened(0.2), UiStyle.accent, 1, 2, 6))
	button.add_theme_stylebox_override("disabled", _style(UiStyle.screen, UiStyle.dim.darkened(0.5), 1, 2, 6))
	return button


func _slot_button(min_size: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = min_size
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", UiStyle.accent)
	button.add_theme_color_override("font_focus_color", UiStyle.accent)
	button.add_theme_color_override("font_hover_color", UiStyle.accent)
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), UiStyle.accent, 2, 4, 6))
	button.add_theme_stylebox_override("hover", _style(UiStyle.fill, UiStyle.accent, 1, 4, 6))
	button.add_theme_stylebox_override("pressed", _style(UiStyle.fill.lightened(0.1), UiStyle.accent, 2, 4, 6))
	return button


static func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = UiStyle.dim
	rule.custom_minimum_size = Vector2(0, 1)
	return rule


static func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	return spacer


static func _spacer_v() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	return spacer

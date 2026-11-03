class_name InventoryScreen
extends Control
## The occupant terminal (Tab): a ZP-SYS screen in the system's cold cyan, built in code.
## It is part of the facility, and so part of PROCTOR; later chapters can corrupt it.
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

const PHOSPHOR := Color(0.45, 0.95, 0.82)
const DIM := Color(0.2, 0.42, 0.37)
const SCREEN := Color(0.015, 0.03, 0.03)
const CONDITION_COLORS := {
	"FINE": Color(0.45, 0.95, 0.82), "CAUTION": Color(1.0, 0.75, 0.3), "DANGER": Color(1.0, 0.3, 0.25),
}
const SCANLINES := """
shader_type canvas_item;
uniform float time_scale = 1.0;
void fragment() {
	float line = step(0.5, fract(FRAGCOORD.y / 3.0));
	vec2 centred = UV - 0.5;
	float edge = smoothstep(0.35, 0.75, length(centred * vec2(1.0, 1.3)));
	float flicker = 0.02 * sin(TIME * 60.0 * time_scale);
	COLOR = vec4(0.0, 0.0, 0.0, line * 0.22 + edge * 0.55 + flicker);
}
"""

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
var _radio_page := RadioTuner.new()
var _map_page := MapView.new()
var _files_page := FilesView.new()
var _logs_page := ScrollContainer.new()
var _logs_list := VBoxContainer.new()
var _actions_box := VBoxContainer.new()
var _box_panel := VBoxContainer.new()
var _device_label := Label.new()
var _tab_buttons := {}
var _notice := ""
var _notice_time := 0.0


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _style(SCREEN, PHOSPHOR, 3, 22, 26))
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -500
	frame.offset_right = 500
	frame.offset_top = -270
	frame.offset_bottom = 270
	add_child(frame)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	frame.add_child(page)

	var header := HBoxContainer.new()
	page.add_child(header)
	header.add_child(_label("ZP-SYS // OCCUPANT TERMINAL", 16, PHOSPHOR))
	header.add_child(_spacer())
	for tab in ["items", "radio", "map", "files", "logs"]:
		var button := _button(tab.to_upper(), 14)
		button.pressed.connect(_show_tab.bind(tab))
		header.add_child(button)
		_tab_buttons[tab] = button
	page.add_child(_rule())

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
	_hint.modulate = DIM.lightened(0.3)
	page.add_child(_hint)

	var lines := ColorRect.new()
	lines.set_anchors_preset(PRESET_FULL_RECT)
	lines.mouse_filter = MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = SCANLINES
	lines.material = material
	frame.add_child(lines)


## `target` is an item box's Inventory, an ItemTube, or null for the plain terminal.
func open(owner_player: Player, target: Variant = null) -> void:
	player = owner_player
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
	_role_label.modulate = PHOSPHOR
	status.add_child(_role_label)
	_ecg.custom_minimum_size = Vector2(250, 80)
	_ecg.draw.connect(_draw_ecg)
	status.add_child(_ecg)
	for label in [_condition_label, _temperature_label, _weapon_label]:
		label.modulate = PHOSPHOR
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
	_item_name.modulate = PHOSPHOR
	details.add_child(_item_name)
	_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_icon.custom_minimum_size = Vector2(0, 110)
	_item_icon.visible = false
	details.add_child(_item_icon)
	_item_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_text.modulate = PHOSPHOR.darkened(0.15)
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
	_device_label.modulate = PHOSPHOR
	details.add_child(_device_label)
	details.add_child(_box_panel)
	_box_panel.add_child(_label("ITEM BOX", 16, PHOSPHOR))
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
		_tab_buttons[tab].add_theme_color_override("font_color", PHOSPHOR if tab == _tab else DIM)
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

	_role_label.text = Session.ROLE_NAMES[player.role].to_upper()
	var condition := _condition()
	_condition_label.text = "CONDITION: %s" % condition
	_condition_label.modulate = CONDITION_COLORS[condition]
	_temperature_label.text = "BODY TEMP: %.1f °C" % player.body_temperature()
	if player.equipped:
		_weapon_label.text = "EQUIPPED: %s  %d / %d" % [Items.display_name(player.equipped).to_upper(),
				player.loaded_rounds, player.inventory.count_of("ammo")]
	else:
		_weapon_label.text = "EQUIPPED: NONE"

	for i in _slot_buttons.size():
		_fill_slot(_slot_buttons[i], player.inventory.slots[i], i == _selected, i == _combine_from)
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
	_hint.modulate = Color(1.0, 0.75, 0.3) if _notice else DIM.lightened(0.3)
	if _notice:
		_hint.text = _notice.to_upper()


func _fill_slot(button: Button, slot: Dictionary, selected: bool, marked: bool) -> void:
	if slot.is_empty():
		button.icon = null
		button.text = ""
	else:
		button.icon = Items.icon(slot["id"])
		var count := " x%d" % slot["count"] if Items.max_stack(slot["id"]) > 1 else ""
		button.text = Items.display_name(slot["id"]).to_upper() + count
	var border := Color(1.0, 0.75, 0.3) if marked else (PHOSPHOR if selected else DIM)
	button.add_theme_stylebox_override("normal", _style(Color(0.04, 0.09, 0.08) if selected else SCREEN, border,
			2 if selected or marked else 1, 4, 6))


func _refresh_logs() -> void:
	for child in _logs_list.get_children():
		child.queue_free()
	if Story.history.is_empty():
		_logs_list.add_child(_label("NO ENTRIES.", 14, DIM))
	for entry in Story.history:
		var line := _label(entry["text"], 14, entry["color"])
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(900, 0)
		_logs_list.add_child(line)
	await get_tree().process_frame
	_logs_page.scroll_vertical = int(_logs_page.get_v_scroll_bar().max_value)


func _condition() -> String:
	if player.health > Player.MAX_HEALTH * 0.66:
		return "FINE"
	if player.health > Player.MAX_HEALTH * 0.33:
		return "CAUTION"
	return "DANGER"


## Heart trace. The Visitor's beats vary like a living pulse; the Subject's are identical,
## mechanically regular. Faster and redder as condition worsens.
func _draw_ecg() -> void:
	var area := _ecg.size
	var condition := _condition()
	var color: Color = CONDITION_COLORS[condition]
	var rate: float = {"FINE": 1.0, "CAUTION": 1.5, "DANGER": 2.3}[condition]
	var machine := player.role == Session.Role.SUBJECT
	_ecg.draw_rect(Rect2(Vector2.ZERO, area), Color(0.02, 0.05, 0.05))
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
	button.add_theme_color_override("font_color", PHOSPHOR)
	button.add_theme_color_override("font_focus_color", SCREEN)
	button.add_theme_color_override("font_hover_color", SCREEN)
	button.add_theme_color_override("font_disabled_color", DIM.darkened(0.3))
	button.add_theme_stylebox_override("normal", _style(SCREEN, DIM, 1, 2, 6))
	button.add_theme_stylebox_override("hover", _style(PHOSPHOR, PHOSPHOR, 1, 2, 6))
	button.add_theme_stylebox_override("focus", _style(PHOSPHOR, PHOSPHOR, 1, 2, 6))
	button.add_theme_stylebox_override("pressed", _style(PHOSPHOR.darkened(0.2), PHOSPHOR, 1, 2, 6))
	button.add_theme_stylebox_override("disabled", _style(SCREEN, DIM.darkened(0.5), 1, 2, 6))
	return button


func _slot_button(min_size: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = min_size
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", PHOSPHOR)
	button.add_theme_color_override("font_focus_color", PHOSPHOR)
	button.add_theme_color_override("font_hover_color", PHOSPHOR)
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), PHOSPHOR, 2, 4, 6))
	button.add_theme_stylebox_override("hover", _style(Color(0.04, 0.09, 0.08), PHOSPHOR, 1, 4, 6))
	button.add_theme_stylebox_override("pressed", _style(Color(0.06, 0.14, 0.12), PHOSPHOR, 2, 4, 6))
	return button


static func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = DIM
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

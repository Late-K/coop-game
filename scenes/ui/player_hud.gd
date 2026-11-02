class_name PlayerHud
extends Control
## The local player's HUD: interact prompt, short messages, health, inventory slots, ammo.
## Built in code so the whole layout is restyled in one place. Never blocks the mouse.

const SLOT_SIZE := Vector2(104, 52)
const MESSAGE_TIME := 2.0

var _prompt_label := Label.new()
var _message_label := Label.new()
var _health_bar := ProgressBar.new()
var _temperature_label := Label.new()
var _ammo_label := Label.new()
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _style_normal := StyleBoxFlat.new()
var _style_selected := StyleBoxFlat.new()
var _message_tween: Tween


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_style_normal.bg_color = Color(0, 0, 0, 0.55)
	_style_normal.set_border_width_all(1)
	_style_normal.border_color = Color(0.4, 0.4, 0.45)
	_style_selected.bg_color = Color(0.1, 0.1, 0.1, 0.75)
	_style_selected.set_border_width_all(2)
	_style_selected.border_color = Color(0.9, 0.85, 0.6)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	margin.add_child(column)

	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_prompt_label)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.modulate.a = 0.0
	column.add_child(_message_label)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	column.add_child(bar)

	_health_bar.custom_minimum_size = Vector2(200, 20)
	_health_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	_health_bar.show_percentage = false
	bar.add_child(_health_bar)
	_temperature_label.size_flags_vertical = SIZE_SHRINK_CENTER
	bar.add_child(_temperature_label)
	bar.add_child(_make_spacer())
	for i in Inventory.SLOT_COUNT:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = SLOT_SIZE
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		panel.add_child(label)
		bar.add_child(panel)
		_slot_panels.append(panel)
		_slot_labels.append(label)
	bar.add_child(_make_spacer())
	_ammo_label.custom_minimum_size = Vector2(200, 0)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.size_flags_vertical = SIZE_SHRINK_CENTER
	bar.add_child(_ammo_label)

	_ignore_mouse(self)


func refresh(player: Player) -> void:
	_health_bar.max_value = Player.MAX_HEALTH
	_health_bar.value = player.health
	var temperature := player.body_temperature()
	_temperature_label.text = "%.1f °C" % temperature
	_temperature_label.modulate = Color(0.55, 0.75, 1.0) if temperature < 33.0 else Color.WHITE
	for i in Inventory.SLOT_COUNT:
		var slot := player.inventory.slots[i]
		var text := "%d" % (i + 1)
		if not slot.is_empty():
			text = Items.display_name(slot["id"])
			if Items.max_stack(slot["id"]) > 1:
				text += "\nx%d" % slot["count"]
		_slot_labels[i].text = text
		_slot_labels[i].modulate.a = 1.0 if not slot.is_empty() else 0.35
		var style := _style_selected if i == player.selected_slot else _style_normal
		_slot_panels[i].add_theme_stylebox_override("panel", style)
	if player.inventory.has("pistol"):
		_ammo_label.text = "Pistol  %d / %d" % [player.loaded_rounds, player.inventory.count_of("ammo")]
	else:
		_ammo_label.text = ""


func set_prompt(text: String) -> void:
	_prompt_label.text = text


func show_message(text: String) -> void:
	_message_label.text = text
	if _message_tween:
		_message_tween.kill()
	_message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_TIME)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.5)


func _make_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	return spacer


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

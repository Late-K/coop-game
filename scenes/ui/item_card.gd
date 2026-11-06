class_name ItemCard
extends Control
## A close look at a thing the first time it's picked up: the screen dims, the item comes up
## large in the middle with its name and what it is, and play waits until the player moves
## on ([E], click, or Space). Each kind of item gets this once per session (Player); after
## that a pickup is just a line on the HUD. In the device's own style (UiStyle).

signal closed

const OPEN_TIME := 0.25
const ICON_SIZE := 128.0

var _icon := TextureRect.new()
var _name := Label.new()
var _text := Label.new()
var _swatch := ColorRect.new()
var _shown_at := 0.0


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT) # created in code: give it the screen's size
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.72)
	back.set_anchors_preset(PRESET_FULL_RECT)
	back.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(back)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(PRESET_FULL_RECT)
	centre.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", InventoryScreen._style(UiStyle.panel, UiStyle.dim, 1, 2, 18))
	card.custom_minimum_size = Vector2(440, 0)
	centre.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var frame := CenterContainer.new()
	frame.custom_minimum_size = Vector2(0, ICON_SIZE + 16)
	column.add_child(frame)
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_icon)
	_swatch.custom_minimum_size = Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
	frame.add_child(_swatch)
	_name = InventoryScreen._label("", 24, UiStyle.accent)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_name)
	_text = InventoryScreen._label("", 14, UiStyle.accent.darkened(0.15))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.custom_minimum_size = Vector2(400, 0)
	column.add_child(_text)
	var hint := InventoryScreen._label("[E] Continue", 12, UiStyle.dim.lightened(0.3))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


## Shows `id` (and how many were taken).
func show_item(id: String, count: int) -> void:
	var icon := Items.icon(id)
	_icon.texture = icon
	_icon.visible = icon != null
	_swatch.visible = icon == null # no picture yet: its colour, as on the shelf
	_swatch.color = Items.color(id)
	_name.text = Items.display_name(id).to_upper() + (" x%d" % count if count > 1 else "")
	_text.text = Items.description(id)
	visible = true
	_shown_at = Time.get_ticks_msec() / 1000.0
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, OPEN_TIME)
	Sound.play_ui("keypad_press", -6.0, 0.7)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Swallow everything while it's up; a short beat before it can be dismissed.
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() / 1000.0 - _shown_at < OPEN_TIME:
		return
	var button := event as InputEventMouseButton
	var click: bool = button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("skip_line"):
		visible = false
		Sound.play_ui("keypad_press", -10.0, 0.9)
		closed.emit()

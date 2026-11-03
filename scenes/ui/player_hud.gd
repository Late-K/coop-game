class_name PlayerHud
extends Control
## The local player's in-game HUD, kept nearly empty: health, cold and inventory live in the
## ZP-SYS terminal (Tab) and in screen vignettes, not on screen. What remains is the interact
## prompt, short messages in the same bordered box as story lines, an ammo readout that
## appears only while aiming, and the radio readout (talking, unread messages) bottom left.
## Messages are written and read in the terminal's RADIO tab. Built in code; never blocks
## the mouse.

const MESSAGE_TIME := 2.0
const TEXT_COLOR := Color(0.88, 0.88, 0.88)
const RADIO_COLOR := Color(1.0, 0.72, 0.35)

var _prompt_label := Label.new()
var _message_box := PanelContainer.new()
var _message_label := Label.new()
var _ammo_label := Label.new()
var _radio_label := Label.new()
var _message_tween: Tween


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0.92)
	frame.set_border_width_all(2)
	frame.border_color = Color(0.85, 0.85, 0.85)
	frame.content_margin_left = 14
	frame.content_margin_right = 14
	frame.content_margin_top = 6
	frame.content_margin_bottom = 6
	_message_box.add_theme_stylebox_override("panel", frame)
	_message_box.anchor_left = 0.5
	_message_box.anchor_right = 0.5
	_message_box.anchor_top = 1.0
	_message_box.anchor_bottom = 1.0
	_message_box.offset_top = -100
	_message_box.grow_horizontal = GROW_DIRECTION_BOTH
	_message_box.modulate.a = 0.0
	_message_label.add_theme_font_size_override("font_size", 16)
	_message_label.modulate = TEXT_COLOR
	_message_box.add_child(_message_label)
	add_child(_message_box)

	_prompt_label.anchor_left = 0.0
	_prompt_label.anchor_right = 1.0
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_top = -40
	_prompt_label.offset_bottom = -16
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.modulate = TEXT_COLOR
	add_child(_prompt_label)

	_ammo_label.anchor_left = 1.0
	_ammo_label.anchor_right = 1.0
	_ammo_label.anchor_top = 1.0
	_ammo_label.anchor_bottom = 1.0
	_ammo_label.offset_left = -260
	_ammo_label.offset_right = -24
	_ammo_label.offset_top = -40
	_ammo_label.offset_bottom = -16
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.modulate = TEXT_COLOR
	add_child(_ammo_label)

	_radio_label.anchor_top = 1.0
	_radio_label.anchor_bottom = 1.0
	_radio_label.offset_left = 24
	_radio_label.offset_right = 300
	_radio_label.offset_top = -64
	_radio_label.offset_bottom = -16
	_radio_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_radio_label.modulate = RADIO_COLOR
	add_child(_radio_label)

	for node in [self, _message_box, _message_label, _prompt_label, _ammo_label, _radio_label]:
		node.mouse_filter = MOUSE_FILTER_IGNORE


func set_prompt(text: String) -> void:
	_prompt_label.text = text


## Shown only while aiming, like a weapon readout.
func set_ammo(shown: bool, text: String) -> void:
	_ammo_label.visible = shown
	_ammo_label.text = text


## Restyles the HUD for this machine's player (UiStyle): ZP-SYS cyan on black for the
## Subject, the handheld's red on near-black for the Visitor. Story lines keep their own box.
func apply_style() -> void:
	theme = Theme.new()
	theme.default_font = UiStyle.font()
	var frame := StyleBoxFlat.new()
	frame.set_content_margin_all(8)
	frame.content_margin_left = 14
	frame.content_margin_right = 14
	if UiStyle.visitor():
		frame.bg_color = Color(UiStyle.screen, 0.95)
		frame.border_color = UiStyle.accent
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(5)
	else:
		frame.bg_color = Color(0, 0, 0, 0.92)
		frame.border_color = UiStyle.accent.darkened(0.25)
		frame.set_border_width_all(1)
	_message_box.add_theme_stylebox_override("panel", frame)
	var text := UiStyle.accent if UiStyle.visitor() else UiStyle.accent.lightened(0.35)
	for label in [_message_label, _prompt_label, _ammo_label]:
		label.modulate = text


## Radio.status_text(): bottom left, empty when nobody is talking.
func set_radio(text: String) -> void:
	_radio_label.text = text


func show_message(text: String) -> void:
	_message_label.text = text
	_message_box.reset_size()
	if _message_tween:
		_message_tween.kill()
	_message_box.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_TIME)
	_message_tween.tween_property(_message_box, "modulate:a", 0.0, 0.5)

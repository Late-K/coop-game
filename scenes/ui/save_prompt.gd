class_name SavePrompt
extends Control
## The save terminal's own screen. Using a terminal cuts to first person at it, and then its
## screen becomes the whole screen: a green CRT that powers on, curved, scanlined and
## glowing, the same for both players (it is the facility's machine, not theirs).
## Saving needs both players, each at a terminal: each confirms here, and the game saves
## when both have (see SaveGame). Tab or Esc leaves, back out of first person.

const GREEN := Color(0.4, 1.0, 0.55)
const DARK := Color(0.01, 0.035, 0.015)
const SAVED_TIME := 1.8
const POWER_TIME := 0.35
## Curvature, scanlines, glow, vignette and the power-on line, over everything below it.
const CRT := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float power = 1.0;
uniform vec3 flash = vec3(0.7, 1.0, 0.75);
void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	c *= 1.0 + 0.32 * dot(c, c); // CURVE: keep in step with through_glass
	vec2 uv = c + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col = texture(screen_tex, uv).rgb;
		vec3 glow = textureLod(screen_tex, uv, 2.5).rgb;
		col += glow * 0.55;
		col *= 0.78 + 0.22 * sin(FRAGCOORD.y * 2.1);
		col *= 1.0 - dot(c, c) * 1.6;
		col *= 0.97 + 0.03 * sin(TIME * 57.0);
		float band = step(abs(uv.y - 0.5), max(power, 0.004) * 0.5);
		col = col * band + flash * band * (1.0 - power) * 0.8;
		COLOR = vec4(col, 1.0);
	}
}
"""

## The CRT's curvature (CRT's `0.32`): a point on the glass shows what's under this far out.
const CURVE := 0.32

var player: Player
var terminal: SaveTerminal

var _you := Label.new()
var _partner := Label.new()
var _message := Label.new()
var _hint := Label.new()
var _crt := ShaderMaterial.new()
var _done := false


func _init() -> void:
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT) # created in code: give it the screen's size
	mouse_filter = MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = DARK
	back.set_anchors_preset(PRESET_FULL_RECT)
	add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 120 if side in ["left", "right"] else 90)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)
	page.add_child(_line("ZP-SYS // OCCUPANCY RECORD", 22))
	page.add_child(_line("-".repeat(64), 18))
	page.add_child(_line("RECORD PROGRESS?", 40))
	page.add_child(_line("Both occupants must confirm, each at a terminal.", 20))
	for label in [_you, _partner, _message]:
		label.add_theme_font_size_override("font_size", 26)
		label.modulate = GREEN
		page.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	page.add_child(spacer)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.modulate = GREEN.darkened(0.35)
	page.add_child(_hint)
	var glass := ColorRect.new()
	glass.set_anchors_preset(PRESET_FULL_RECT)
	glass.mouse_filter = MOUSE_FILTER_IGNORE
	_crt.shader = Shader.new()
	_crt.shader.code = CRT
	glass.material = _crt
	add_child(glass)
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
	Sound.play_ui("radio_unkey", -14.0, 0.6) # the tube warming up
	_crt.set_shader_parameter("power", 0.0)
	create_tween().tween_method(func(v: float) -> void: _crt.set_shader_parameter("power", v), 0.0, 1.0, POWER_TIME) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	refresh()


## Leaves the screen; unless `leave_focus` is false (a death or reload is taking over),
## the player steps back out of first person too.
func close(leave_focus := true) -> void:
	if not visible:
		return
	visible = false
	Story.suppressed = false
	if not _done:
		SaveGame.set_status(SaveGame.Status.AWAY)
	Sound.play_ui("keypad_press", -6.0, 0.6)
	if leave_focus and player:
		player.leave_focus(terminal)


## Where the pointer really is on a screen under the curved glass: the CRT shader shows each
## point of the glass what lies a little further out (see CRT), so a mouse event at `at`
## is about the interface at the returned point. `size`: the screen's size.
static func through_glass(at: Vector2, size: Vector2) -> Vector2:
	var c := at / size - Vector2(0.5, 0.5)
	c *= 1.0 + CURVE * c.dot(c)
	return (c + Vector2(0.5, 0.5)) * size


## For a screen under the glass (this, the terminal): a mouse event is handled again where
## the pointer really points, and true is returned for the original, which goes no further.
static func bend_mouse(node: Control, event: InputEvent) -> bool:
	if not event is InputEventMouse or event.has_meta("through_glass"):
		return false
	var viewport := node.get_viewport()
	var bent: InputEventMouse = event.duplicate()
	bent.position = through_glass(event.position, viewport.get_visible_rect().size)
	bent.global_position = bent.position
	bent.set_meta("through_glass", true)
	viewport.set_input_as_handled()
	viewport.push_input(bent, true)
	return true


func _input(event: InputEvent) -> void:
	if not visible or _done:
		return
	if bend_mouse(self, event):
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
	var partner: SaveGame.Status = SaveGame.partner_status()
	_partner.text = "PARTNER .... %s" % ["NOT AT A TERMINAL", "AT A TERMINAL", "READY"][partner]
	_partner.modulate = GREEN if partner != SaveGame.Status.AWAY else GREEN.darkened(0.45)
	_message.text = "WAITING FOR PARTNER_" if ready else ""
	_hint.text = "[TAB] LEAVE" if ready else "[E] CONFIRM     [TAB] LEAVE"


func _on_saved() -> void:
	if not visible:
		return
	_done = true
	_you.text = ""
	_partner.text = ""
	_message.text = MetaSave.format("PROGRESS RECORDED. OCCUPANT {iteration}.")
	_hint.text = ""
	Sound.play_ui("code_right", -6.0)
	get_tree().create_timer(SAVED_TIME).timeout.connect(close)


func _line(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = GREEN
	return label

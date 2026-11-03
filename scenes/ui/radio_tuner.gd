class_name RadioTuner
extends HBoxContainer
## The terminal's RADIO tab: a tuner for the radio band (see Radio). A scrolling scale under
## a fixed needle, a signal meter, an oscilloscope, and what a station says once it comes in
## clearly. Tuning away from the partner channel cuts you off from your partner (voice and
## messages) until you tune back, or they tune to you. This is also the only place to
## write a text message (for players without a microphone); recent ones are listed.

## MHz shown either side of the needle.
const SCALE_SPAN := 4.0
## Holding a direction sweeps after this long, at SWEEP_RATE steps per second.
const SWEEP_DELAY := 0.35
const SWEEP_RATE := 14.0
const TYPE_RATE := 30.0
const MESSAGES_SHOWN := 3

## The scale. Focus it and use Left/Right (or A/D) to tune.
var dial := Control.new()
var _frequency_label: Label
var _channel_label: Label
var _meter_label: Label
var _transcript: Label
var _messages := VBoxContainer.new()
var _chat_input := LineEdit.new()
var _home: Button
var _scope := Control.new()
var _held_direction := 0
var _held := 0.0
var _sweep := 0.0
var _time := 0.0
var _shown_station: RadioSignal = null
var _typed := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	add_theme_constant_override("separation", 18)
	var status := VBoxContainer.new()
	status.custom_minimum_size = Vector2(250, 0)
	status.add_theme_constant_override("separation", 8)
	add_child(status)
	status.add_child(InventoryScreen._label("RADIO", 22, InventoryScreen.PHOSPHOR))
	_frequency_label = InventoryScreen._label("", 34, InventoryScreen.PHOSPHOR)
	status.add_child(_frequency_label)
	_channel_label = InventoryScreen._label("", 14, InventoryScreen.PHOSPHOR)
	_channel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_child(_channel_label)
	_meter_label = InventoryScreen._label("", 14, InventoryScreen.PHOSPHOR)
	status.add_child(_meter_label)
	status.add_child(InventoryScreen._spacer_v())
	_home = InventoryScreen._button("PARTNER CHANNEL %.1f" % Radio.HOME_FREQUENCY, 14)
	_home.pressed.connect(func() -> void:
		Radio.tune(Radio.HOME_FREQUENCY)
		dial.grab_focus()
	)
	status.add_child(_home)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	add_child(main)
	dial.custom_minimum_size = Vector2(0, 78)
	dial.focus_mode = FOCUS_ALL
	dial.draw.connect(_draw_dial)
	dial.gui_input.connect(_on_dial_input)
	main.add_child(dial)
	_scope.custom_minimum_size = Vector2(0, 80)
	_scope.draw.connect(_draw_scope)
	main.add_child(_scope)
	_transcript = InventoryScreen._label("", 15, InventoryScreen.PHOSPHOR)
	_transcript.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_transcript.custom_minimum_size = Vector2(0, 70)
	main.add_child(_transcript)
	main.add_child(InventoryScreen._label("MESSAGES", 12, InventoryScreen.DIM.lightened(0.3)))
	main.add_child(_messages)

	var field := InventoryScreen._style(InventoryScreen.SCREEN, InventoryScreen.DIM, 1, 2, 6)
	var focused := InventoryScreen._style(InventoryScreen.SCREEN, PlayerHud.RADIO_COLOR, 1, 2, 6)
	_chat_input.add_theme_stylebox_override("normal", field)
	_chat_input.add_theme_stylebox_override("focus", focused)
	_chat_input.add_theme_color_override("font_color", PlayerHud.RADIO_COLOR)
	_chat_input.add_theme_color_override("font_placeholder_color", InventoryScreen.DIM.lightened(0.2))
	_chat_input.add_theme_font_size_override("font_size", 13)
	_chat_input.placeholder_text = "WRITE A MESSAGE ON THIS FREQUENCY..."
	_chat_input.max_length = Radio.CHAT_MAX
	_chat_input.keep_editing_on_text_submit = true
	_chat_input.text_submitted.connect(_on_chat_submitted)
	# Reached with the keyboard, a LineEdit only starts editing when told to.
	_chat_input.focus_entered.connect(func() -> void:
		Radio.typing = true
		_chat_input.edit()
	)
	_chat_input.focus_exited.connect(func() -> void: Radio.typing = false)
	main.add_child(_chat_input)


func open() -> void:
	# Down from the dial: the message field, then the partner channel button.
	dial.focus_neighbor_bottom = dial.get_path_to(_chat_input)
	_chat_input.focus_neighbor_top = _chat_input.get_path_to(dial)
	_chat_input.focus_neighbor_bottom = _chat_input.get_path_to(_home)
	_home.focus_neighbor_top = _home.get_path_to(_chat_input)
	dial.grab_focus()


func _on_chat_submitted(text: String) -> void:
	Radio.send_chat(text)
	_chat_input.clear()


func is_typing() -> bool:
	return _chat_input.has_focus()


## Tab / Esc leave the field first (back to the dial); the next press closes the terminal.
func stop_typing() -> void:
	dial.grab_focus()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_tune_held(delta)

	var home := Radio.on_home_channel()
	_frequency_label.text = "%.1f MHz" % Radio.frequency
	_channel_label.text = "PARTNER CHANNEL" if home \
			else "OFF CHANNEL\nYour partner can't hear you here unless they tune in too."
	_channel_label.modulate = InventoryScreen.PHOSPHOR if home else PlayerHud.RADIO_COLOR
	var strength := Radio.station_strength
	var bars := clampi(roundi(strength * 8.0), 0, 8)
	_meter_label.text = "SIGNAL [%s%s]" % ["|".repeat(bars), ".".repeat(8 - bars)]
	_update_transcript(delta)
	_update_messages()
	dial.queue_redraw()
	_scope.queue_redraw()


## One step on press, then a sweep while held.
func _tune_held(delta: float) -> void:
	var direction := 0
	if dial.has_focus():
		direction = int(Input.is_action_pressed("ui_right") or Input.is_action_pressed("move_right")) \
				- int(Input.is_action_pressed("ui_left") or Input.is_action_pressed("move_left"))
	if direction == 0:
		_held_direction = 0
		return
	if direction != _held_direction:
		_held_direction = direction
		_held = 0.0
		_sweep = 0.0
		_step(direction)
		return
	_held += delta
	if _held > SWEEP_DELAY:
		_sweep += delta * SWEEP_RATE
		while _sweep >= 1.0:
			_sweep -= 1.0
			_step(direction)


func _step(direction: int) -> void:
	var before := Radio.frequency
	Radio.tune(Radio.frequency + direction * Radio.FREQUENCY_STEP)
	if Radio.frequency != before:
		Sound.play_ui("keypad_press", -20.0, 1.8)


## Left/Right belong to the dial while it has focus, not to focus navigation.
func _on_dial_input(event: InputEvent) -> void:
	for action in ["ui_left", "ui_right", "move_left", "move_right"]:
		if event.is_action(action):
			dial.accept_event()
			return


func _update_transcript(delta: float) -> void:
	var station := Radio.station
	if station and Radio.station_strength >= Radio.LOCK_STRENGTH:
		if station != _shown_station:
			_shown_station = station
			_typed = 0.0
		var text := MetaSave.format(station.transcript)
		_typed = minf(_typed + delta * TYPE_RATE, text.length())
		_transcript.text = text.left(int(_typed))
		return
	_shown_station = null
	if Radio.on_home_channel():
		_transcript.text = "Hold [V] to talk, or write a message below."
	elif station and Radio.station_strength > 0.15:
		_transcript.text = "SIGNAL DETECTED. FINE-TUNE."
	else:
		_transcript.text = ""


func _update_messages() -> void:
	var lines := Radio.chat_history.slice(-MESSAGES_SHOWN)
	while _messages.get_child_count() < lines.size():
		var label := InventoryScreen._label("", 13, PlayerHud.RADIO_COLOR)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size = Vector2(560, 0)
		_messages.add_child(label)
	for i in lines.size():
		_messages.get_child(i).text = lines[i]


## A scale that scrolls under a fixed needle: ticks every 0.2 MHz, numbers every 1 MHz,
## the partner channel marked CH, and the whole band as a thin bar along the bottom.
func _draw_dial() -> void:
	var area := dial.size
	var font := dial.get_theme_font("font", "Label")
	var phosphor := InventoryScreen.PHOSPHOR
	var dim := InventoryScreen.DIM
	dial.draw_rect(Rect2(Vector2.ZERO, area), Color(0.02, 0.05, 0.05))
	var center := area.x / 2.0
	var per_mhz := area.x / (SCALE_SPAN * 2.0)
	for i in range(floori((Radio.frequency - SCALE_SPAN) * 5.0), ceili((Radio.frequency + SCALE_SPAN) * 5.0) + 1):
		var f := i / 5.0
		if f < Radio.MIN_FREQUENCY or f > Radio.MAX_FREQUENCY:
			continue
		var x := center + (f - Radio.frequency) * per_mhz
		if x < 4.0 or x > area.x - 4.0:
			continue
		var major := i % 5 == 0
		dial.draw_line(Vector2(x, 44), Vector2(x, 44 - (18.0 if major else 8.0)), phosphor if major else dim, 1.0)
		if major and x > 16.0 and x < area.x - 16.0:
			var text := "%d" % roundi(f)
			dial.draw_string(font, Vector2(x - 12, 58), text, HORIZONTAL_ALIGNMENT_CENTER, 24, 12, dim.lightened(0.4))
	var home_x := center + (Radio.HOME_FREQUENCY - Radio.frequency) * per_mhz
	if home_x > 0.0 and home_x < area.x:
		dial.draw_string(font, Vector2(home_x - 12, 14), "CH", HORIZONTAL_ALIGNMENT_CENTER, 24, 12, PlayerHud.RADIO_COLOR)
	dial.draw_line(Vector2(center, 4), Vector2(center, 50), Color(1.0, 0.35, 0.3), 2.0)
	var band := (Radio.frequency - Radio.MIN_FREQUENCY) / (Radio.MAX_FREQUENCY - Radio.MIN_FREQUENCY)
	dial.draw_line(Vector2(8, area.y - 8), Vector2(area.x - 8, area.y - 8), dim, 1.0)
	dial.draw_rect(Rect2(8 + band * (area.x - 16) - 2, area.y - 12, 4, 8), phosphor)
	if dial.has_focus():
		dial.draw_rect(Rect2(Vector2.ZERO, area), dim.lightened(0.2), false, 1.0)


## The trace: the station's shape grows out of the noise as it is tuned in. On the partner
## channel the line is flat, and moves while the partner talks.
func _draw_scope() -> void:
	var area := _scope.size
	_scope.draw_rect(Rect2(Vector2.ZERO, area), Color(0.02, 0.05, 0.05))
	_scope.draw_line(Vector2(0, area.y / 2.0), Vector2(area.x, area.y / 2.0), InventoryScreen.DIM, 1.0)
	var strength := Radio.station_strength
	var shape := Radio.station.shape if Radio.station else ""
	var noise := 0.0 if Radio.on_home_channel() else (1.0 - strength) * 0.7
	if Radio.on_home_channel() and Radio.receiving:
		shape = "voice"
		strength = 0.8
	var points := PackedVector2Array()
	for x in range(0, int(area.x), 3):
		var t := x / area.x
		var wave := 0.0
		match shape:
			"tone":
				wave = sin(t * 60.0 + _time * 9.0)
			"pulse":
				wave = sin(t * 90.0) * (1.0 if fmod(_time * 2.5 + t * 3.0, 1.0) < 0.45 else 0.0)
			"voice":
				wave = sin(t * 47.0 + _time * 6.0) * sin(t * 9.0 + _time * 2.3) * (0.5 + 0.5 * sin(_time * 4.1))
		var y := wave * strength + _rng.randf_range(-1.0, 1.0) * noise + _rng.randf_range(-0.03, 0.03)
		points.append(Vector2(x, area.y / 2.0 - clampf(y, -1.0, 1.0) * area.y * 0.42))
	_scope.draw_polyline(points, InventoryScreen.PHOSPHOR, 1.5)

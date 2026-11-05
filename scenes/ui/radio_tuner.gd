class_name RadioTuner
extends HBoxContainer
## The terminal's RADIO tab: a tuner for the radio band (see Radio). A scrolling scale under
## a fixed needle, a signal meter, an oscilloscope, and what a station says once it comes in
## clearly. Like a real set: whoever is tuned to the same frequency hears you, wherever on
## the band that is. PING sends a call tone, CALL keeps calling, SCAN runs up the band until
## something comes in, and one frequency can be kept in memory (STORE, then MEM to go back).
## This is also the only place to write a text message (for players without a microphone);
## recent ones are listed.

## MHz shown either side of the needle.
const SCALE_SPAN := 4.0
## Holding a direction sweeps after this long, at SWEEP_RATE steps per second, speeding up
## to SWEEP_MAX over SWEEP_RAMP seconds. With Shift each step is COARSE_STEPS (1 MHz).
const SWEEP_DELAY := 0.25
const SWEEP_RATE := 20.0
const SWEEP_MAX := 160.0
const SWEEP_RAMP := 1.5
const COARSE_STEPS := 10
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
var _store: Button
var _ping: Button
var _call: Button
var _scan: Button
var _power: Button
var _scope := Control.new()
var _held_direction := 0
var _held := 0.0
var _sweep := 0.0
var _time := 0.0
## When the dial last clicked (so a fast sweep doesn't rattle).
var _clicked := -1.0
var _shown_station: RadioSignal = null
var _typed := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	add_theme_constant_override("separation", 18)
	var status := VBoxContainer.new()
	status.custom_minimum_size = Vector2(250, 0)
	status.add_theme_constant_override("separation", 8)
	add_child(status)
	status.add_child(InventoryScreen._label("RADIO", 22, UiStyle.accent))
	_power = InventoryScreen._button("POWER: ON", 14)
	_power.pressed.connect(func() -> void: Radio.set_powered(not Radio.powered))
	status.add_child(_power)
	_frequency_label = InventoryScreen._label("", 34, UiStyle.accent)
	status.add_child(_frequency_label)
	_channel_label = InventoryScreen._label("", 14, UiStyle.accent)
	_channel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_child(_channel_label)
	_meter_label = InventoryScreen._label("", 14, UiStyle.accent)
	status.add_child(_meter_label)
	status.add_child(InventoryScreen._spacer_v())
	_ping = InventoryScreen._button("PING  [B]", 14)
	_ping.pressed.connect(Radio.send_ping)
	status.add_child(_ping)
	_call = InventoryScreen._button("", 14)
	_call.pressed.connect(func() -> void: Radio.set_calling(not Radio.calling))
	status.add_child(_call)
	_scan = InventoryScreen._button("", 14)
	_scan.pressed.connect(func() -> void: Radio.set_scanning(not Radio.scanning))
	status.add_child(_scan)
	_home = InventoryScreen._button("", 14)
	_home.pressed.connect(func() -> void:
		Radio.set_scanning(false)
		Radio.tune(Radio.channel)
		dial.grab_focus()
	)
	status.add_child(_home)
	_store = InventoryScreen._button("STORE", 14)
	_store.pressed.connect(func() -> void:
		Radio.store(Radio.frequency)
		Sound.play_ui("keypad_press", -10.0, 1.4)
	)
	status.add_child(_store)

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
	_transcript = InventoryScreen._label("", 15, UiStyle.accent)
	_transcript.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_transcript.custom_minimum_size = Vector2(0, 70)
	main.add_child(_transcript)
	main.add_child(InventoryScreen._label("MESSAGES", 12, UiStyle.dim.lightened(0.3)))
	main.add_child(_messages)

	var field := InventoryScreen._style(UiStyle.screen, UiStyle.dim, 1, 2, 6)
	var focused := InventoryScreen._style(UiStyle.screen, PlayerHud.RADIO_COLOR, 1, 2, 6)
	_chat_input.add_theme_stylebox_override("normal", field)
	_chat_input.add_theme_stylebox_override("focus", focused)
	_chat_input.add_theme_color_override("font_color", PlayerHud.RADIO_COLOR)
	_chat_input.add_theme_color_override("font_placeholder_color", UiStyle.dim.lightened(0.2))
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
	# Down from the dial: the message field, then the buttons in a column. Up: power.
	dial.focus_neighbor_top = dial.get_path_to(_power)
	_power.focus_neighbor_bottom = _power.get_path_to(dial)
	var chain: Array[Control] = [dial, _chat_input, _ping, _call, _scan, _home, _store]
	for i in chain.size() - 1:
		chain[i].focus_neighbor_bottom = chain[i].get_path_to(chain[i + 1])
		chain[i + 1].focus_neighbor_top = chain[i + 1].get_path_to(chain[i])
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

	_power.text = "POWER: ON" if Radio.powered else "POWER: OFF"
	_chat_input.editable = Radio.powered
	for button: Button in [_ping, _call, _scan, _store]:
		button.disabled = not Radio.powered
	_call.text = "CALL: ON" if Radio.calling else "CALL: OFF"
	_scan.text = "SCAN: ON" if Radio.scanning else "SCAN"
	_home.visible = Radio.channel_known
	_home.text = "MEM %.1f" % Radio.channel
	if not Radio.powered:
		_frequency_label.text = "----- MHz"
		_channel_label.text = "POWER OFF\nNo voice, messages or stations. Nothing can track it."
		_channel_label.modulate = PlayerHud.RADIO_COLOR
		_meter_label.text = ""
		_transcript.text = ""
		_update_messages()
		dial.queue_redraw()
		_scope.queue_redraw()
		return
	var home := Radio.on_home_channel()
	_frequency_label.text = "%.1f MHz" % Radio.frequency
	_channel_label.text = "SCANNING..." if Radio.scanning \
			else "MEMORY" if home \
			else "Anyone tuned here hears you."
	_channel_label.modulate = UiStyle.accent if home else PlayerHud.RADIO_COLOR
	var strength := maxf(Radio.station_strength, Radio.partner_signal)
	var bars := clampi(roundi(strength * 8.0), 0, 8)
	_meter_label.text = "SIGNAL [%s%s]" % ["|".repeat(bars), ".".repeat(8 - bars)]
	_update_transcript(delta)
	_update_messages()
	dial.queue_redraw()
	_scope.queue_redraw()


## One step on press, then a sweep while held.
func _tune_held(delta: float) -> void:
	var direction := 0
	if dial.has_focus() and Radio.powered:
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
		# Faster the longer it's held, as a dial spun harder.
		var ramp := clampf((_held - SWEEP_DELAY) / SWEEP_RAMP, 0.0, 1.0)
		_sweep += delta * lerpf(SWEEP_RATE, SWEEP_MAX, ramp * ramp)
		while _sweep >= 1.0:
			_sweep -= 1.0
			_step(direction)


## One step of the dial (a whole MHz with Shift held).
func _step(direction: int) -> void:
	Radio.set_scanning(false) # a hand on the dial stops the scan
	var before := Radio.frequency
	var steps := COARSE_STEPS if Input.is_key_pressed(KEY_SHIFT) else 1
	Radio.tune(Radio.frequency + direction * steps * Radio.FREQUENCY_STEP)
	if Radio.frequency != before and _time - _clicked > 0.04:
		_clicked = _time
		Sound.play_ui("keypad_press", -20.0, 1.8)


## Left/Right belong to the dial while it has focus, not to focus navigation. The mouse
## wheel turns it too.
func _on_dial_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel and wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if Radio.powered:
			_step(1 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		dial.accept_event()
		return
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
	if Radio.partner_signal >= Radio.LOCK_STRENGTH:
		_transcript.text = "SOMEONE IS ON THE AIR HERE."
	elif Radio.partner_signal > 0.0:
		_transcript.text = "A TRANSMISSION, OFF TUNE. FINE-TUNE."
	elif station and Radio.station_strength > 0.15:
		_transcript.text = "SIGNAL DETECTED. FINE-TUNE."
	else:
		_transcript.text = "Hold [V] to talk, [B] to ping, or write a message below."


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
## the frequency in memory marked MEM, and the whole band as a thin bar along the bottom.
func _draw_dial() -> void:
	var area := dial.size
	var font := dial.get_theme_font("font", "Label")
	var phosphor := UiStyle.accent
	var dim := UiStyle.dim
	dial.draw_rect(Rect2(Vector2.ZERO, area), UiStyle.panel)
	if not Radio.powered:
		if dial.has_focus():
			dial.draw_rect(Rect2(Vector2.ZERO, area), dim.lightened(0.2), false, 1.0)
		return
	if UiStyle.visitor():
		_draw_band(area, font)
		return
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
	var home_x := center + (Radio.channel - Radio.frequency) * per_mhz
	if Radio.channel_known and home_x > 0.0 and home_x < area.x:
		dial.draw_string(font, Vector2(home_x - 16, 14), "MEM", HORIZONTAL_ALIGNMENT_CENTER, 32, 12, PlayerHud.RADIO_COLOR)
	dial.draw_line(Vector2(center, 4), Vector2(center, 50), Color(1.0, 0.35, 0.3), 2.0)
	var band := (Radio.frequency - Radio.MIN_FREQUENCY) / (Radio.MAX_FREQUENCY - Radio.MIN_FREQUENCY)
	dial.draw_line(Vector2(8, area.y - 8), Vector2(area.x - 8, area.y - 8), dim, 1.0)
	dial.draw_rect(Rect2(8 + band * (area.x - 16) - 2, area.y - 12, 4, 8), phosphor)
	if dial.has_focus():
		dial.draw_rect(Rect2(Vector2.ZERO, area), dim.lightened(0.2), false, 1.0)


## The trace: the station's shape grows out of the noise as it is tuned in. On the frequency
## in memory the line is flat (squelched), and moves while anyone is on the air.
func _draw_scope() -> void:
	var area := _scope.size
	_scope.draw_rect(Rect2(Vector2.ZERO, area), UiStyle.panel)
	_scope.draw_line(Vector2(0, area.y / 2.0), Vector2(area.x, area.y / 2.0), UiStyle.dim, 1.0)
	if not Radio.powered:
		return
	if UiStyle.visitor():
		_draw_meter(area)
		return
	var strength := Radio.station_strength
	var shape := Radio.station.shape if Radio.station else ""
	var noise := 0.0 if Radio.on_home_channel() else (1.0 - strength) * 0.7
	if Radio.partner_signal > 0.0:
		shape = "voice"
		strength = Radio.partner_signal * 0.8
		noise = (1.0 - Radio.partner_signal) * 0.5
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
	_scope.draw_polyline(points, UiStyle.accent, 1.5)


## The handheld's tuner: the whole band as one row of LCD segments, lit up to where it is
## tuned, a pointer under it, the frequency in memory marked. No scrolling scale.
func _draw_band(area: Vector2, font: Font) -> void:
	var accent := UiStyle.accent
	var segments := 80
	var width := (area.x - 24.0) / segments
	var at := (Radio.frequency - Radio.MIN_FREQUENCY) / (Radio.MAX_FREQUENCY - Radio.MIN_FREQUENCY)
	for i in segments:
		var lit := float(i) / segments <= at
		var rect := Rect2(12 + i * width + 1, 14, width - 2, 22)
		dial.draw_rect(rect, accent if lit else UiStyle.dim.darkened(0.4))
	var pointer := 12 + at * (area.x - 24.0)
	dial.draw_colored_polygon(PackedVector2Array([Vector2(pointer, 40), Vector2(pointer - 6, 50), Vector2(pointer + 6, 50)]), accent)
	var home := 12 + (Radio.channel - Radio.MIN_FREQUENCY) / (Radio.MAX_FREQUENCY - Radio.MIN_FREQUENCY) * (area.x - 24.0)
	if Radio.channel_known:
		dial.draw_string(font, Vector2(home - 16, 66), "MEM", HORIZONTAL_ALIGNMENT_CENTER, 32, 12, PlayerHud.RADIO_COLOR)
	for mhz in [100, 120, 140, 160, 180]:
		var x := 12 + float(mhz - Radio.MIN_FREQUENCY) / (Radio.MAX_FREQUENCY - Radio.MIN_FREQUENCY) * (area.x - 24.0)
		dial.draw_string(font, Vector2(x - 16, 10), str(mhz), HORIZONTAL_ALIGNMENT_CENTER, 32, 10, UiStyle.dim.lightened(0.5))
	if dial.has_focus():
		dial.draw_rect(Rect2(Vector2.ZERO, area), UiStyle.dim, false, 1.0)


## The handheld's signal meter: a bar graph, each bar stepped into segments. A station rises
## out of the hiss in a shape of its own; on the frequency in memory it's still until
## someone is on the air.
func _draw_meter(area: Vector2) -> void:
	var bars := 32
	var width := area.x / bars
	var strength := Radio.station_strength
	var shape := Radio.station.shape if Radio.station else ""
	var noise := 0.0 if Radio.on_home_channel() else (1.0 - strength) * 0.8
	if Radio.partner_signal > 0.0:
		shape = "voice"
		strength = Radio.partner_signal * 0.8
		noise = (1.0 - Radio.partner_signal) * 0.6
	for i in bars:
		var t := float(i) / bars
		var wave := 0.0
		match shape:
			"tone":
				wave = 0.6 + 0.3 * sin(t * 12.0 + _time * 6.0)
			"pulse":
				wave = 0.9 if fmod(_time * 2.5 + t * 3.0, 1.0) < 0.45 else 0.1
			"voice":
				wave = 0.5 + 0.5 * absf(sin(t * 9.0 + _time * 5.0) * sin(_time * 3.7 + t * 4.0))
		var level := clampf(wave * strength + _rng.randf() * noise + 0.04, 0.0, 1.0)
		var steps := ceili(level * 10.0)
		for s in steps:
			var h := area.y / 10.0
			_scope.draw_rect(Rect2(i * width + 2, area.y - (s + 1) * h + 1, width - 4, h - 2), UiStyle.accent)

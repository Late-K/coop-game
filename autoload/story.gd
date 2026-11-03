extends Node
## Story lines (subtitles). The server decides *when* a beat plays; each peer
## decides *what it sees*.
##
## Lines live in res://story/lines.json, keyed by id:
##   "speaker"  which voice is talking (optional). Never shown: it only picks the colour
##              of the whole line, so names can be uncovered by the story itself.
##   "text"     shown to both players, or
##   "subject" / "visitor"  per-role text. Give only one of them for a private line.
##   "if"       only shown when MetaSave.check(condition) holds on that machine.
##   "keep"     true if the line must never be dropped (puzzle hints, key beats).
## Texts may use MetaSave placeholders such as {iteration}.
##
## Pacing: lines sent together (one beat) play in order. When a newer beat arrives,
## the current line wraps up shortly after it finishes typing, and older lines still
## waiting are dropped unless marked "keep". Players can skip with skip_line (Space):
## the first press finishes the typing, the second moves on. PROCTOR notices both.

const LINES_PATH := "res://story/lines.json"
const CHARS_PER_SECOND := 40.0
const MIN_HOLD := 2.0
const HOLD_PER_CHAR := 0.035
## How long a fully typed line stays up once a newer beat is waiting.
const INTERRUPT_GRACE := 1.0
## PROCTOR comments after this many dropped / skipped lines in a session.
const RUSH_COMMENT_AT := 2
const SKIP_COMMENT_AT := 3
## Voices are told apart by colour only. ZP-SYS (cold cyan) is the mask, a degraded
## emergency system. PROCTOR (a warm, wrong red) is what is under it; it only speaks
## when the players step outside the script (die, skip, rush, shoot each other, quit
## and return). Lines without a speaker are narration: player characters never speak,
## and there are no inner thoughts either; what they notice is told plainly.
const SPEAKER_COLORS := {"ZP-SYS": Color(0.6, 0.9, 1.0), "PROCTOR": Color(1.0, 0.42, 0.42)}
const NARRATION_COLOR := Color(0.92, 0.92, 0.92)
## Typing sound per voice (see Sound.blip); narration has the soft one.
const SPEAKER_BLIPS := {"ZP-SYS": "sys", "PROCTOR": "proctor"}
## One blip every this many typed characters.
const BLIP_EVERY := 3

var _lines := {}
## Every line shown this session, oldest first: {"text": String, "color": Color}. Read by the
## terminal's LOGS tab.
var history: Array[Dictionary] = []
## While true (e.g. the terminal is open) lines still play and land in history, unseen.
var suppressed := false
## Waiting lines: {"id": String, "beat": int}. Lines of one beat share a number.
var _queue: Array[Dictionary] = []
var _next_beat := 0
var _current_beat := -1
var _played_once := {} # server: ids already used by play_once()
var _commented := {} # this machine: reactions PROCTOR already made this session
var _dropped := 0
var _skipped := 0
var _showing := false
var _skip_requested := false
## Lines appear in a black box with a thin white border at the bottom of the screen.
var _box := PanelContainer.new()
var _label := RichTextLabel.new()
var _skip_hint := Label.new()
var _card := Label.new()


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
	if parsed is Dictionary:
		_lines = parsed
	else:
		push_error("Could not parse %s" % LINES_PATH)

	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0.92)
	frame.set_border_width_all(2)
	frame.border_color = Color(0.85, 0.85, 0.85)
	frame.content_margin_left = 18
	frame.content_margin_right = 18
	frame.content_margin_top = 12
	frame.content_margin_bottom = 8
	_box.add_theme_stylebox_override("panel", frame)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.2
	_box.anchor_right = 0.8
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_top = -215.0
	_box.offset_bottom = -110.0
	_box.visible = false
	layer.add_child(_box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(column)

	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", 18)
	_label.add_theme_font_size_override("italics_font_size", 18)
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_label)

	_skip_hint.text = "[Space] v"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.add_theme_font_size_override("font_size", 12)
	_skip_hint.modulate = Color(1, 1, 1, 0.4)
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_skip_hint)

	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.add_theme_font_size_override("font_size", 40)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	layer.add_child(_card)


func _unhandled_input(event: InputEvent) -> void:
	if _showing and event.is_action_pressed("skip_line"):
		_skip_requested = true
		get_viewport().set_input_as_handled()


## Server only. Plays one beat (lines in order) on both peers.
func play(ids: Array[String]) -> void:
	if not ids.is_empty():
		_queue_beat.rpc(ids)


## Server only. Plays a line the first time it is asked for in this session.
func play_once(id: String) -> void:
	if not _played_once.has(id):
		_played_once[id] = true
		play([id])


## Shows a line on this machine only (e.g. a reaction to your own death).
func show_local(id: String) -> void:
	_enqueue_beat([id])


## Big centred title (e.g. end of chapter) that fades in and stays until clear().
func show_card(text: String) -> void:
	_card.text = text
	Sound.play_ui("sting_chapter")
	create_tween().tween_property(_card, "modulate:a", 1.0, 1.5)


func clear() -> void:
	_queue.clear()
	_played_once.clear()
	history.clear()
	_commented.clear()
	_dropped = 0
	_skipped = 0
	_label.text = ""
	_box.visible = false
	_card.modulate.a = 0.0


@rpc("authority", "call_local", "reliable")
func _queue_beat(ids: Array[String]) -> void:
	_enqueue_beat(ids)


func _enqueue_beat(ids: Array[String]) -> void:
	if _showing:
		_drop_stale_lines()
	var beat := _next_beat
	_next_beat += 1
	for id in ids:
		if _lines.has(id):
			_queue.append({"id": id, "beat": beat})
		else:
			push_warning("Unknown story line: %s" % id)
	if _dropped >= RUSH_COMMENT_AT:
		_comment_once("rushing")
	if not _showing:
		_show_queue()


## A newer beat has arrived: whatever older lines are still waiting are out of date.
func _drop_stale_lines() -> void:
	var kept: Array[Dictionary] = []
	for entry in _queue:
		var line: Dictionary = _lines[entry["id"]]
		if line.get("keep", false) or _resolve_text(line).is_empty():
			kept.append(entry)
		else:
			_dropped += 1
	_queue = kept


## Queues one of PROCTOR's reactions to how the players treat its lines, once per session.
func _comment_once(id: String) -> void:
	if _commented.has(id) or not _lines.has(id):
		return
	_commented[id] = true
	_queue.append({"id": id, "beat": _next_beat})
	_next_beat += 1


func _newer_beat_waiting() -> bool:
	return not _queue.is_empty() and _queue[0]["beat"] != _current_beat


func _show_queue() -> void:
	_showing = true
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		_current_beat = entry["beat"]
		var line: Dictionary = _lines[entry["id"]]
		var text := _resolve_text(line)
		if text.is_empty():
			continue
		_display(line, text)
		var type_time := text.length() / CHARS_PER_SECOND
		var hold := maxf(MIN_HOLD, text.length() * HOLD_PER_CHAR)
		var typing := create_tween()
		typing.tween_property(_label, "visible_ratio", 1.0, type_time)
		var elapsed := 0.0
		var blipped := 0
		var blip_voice: String = SPEAKER_BLIPS.get(line.get("speaker", ""), "narration")
		if line.get("speaker", "") == "PROCTOR":
			Sound.play_ui("static", -6.0)
		_skip_requested = false
		_box.visible = not suppressed
		while elapsed < type_time + hold:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
			var typed := int(_label.visible_ratio * text.length())
			if elapsed < type_time and typed - blipped >= BLIP_EVERY:
				blipped = typed
				Sound.blip(blip_voice)
			if _skip_requested:
				_skip_requested = false
				if elapsed < type_time:
					typing.kill()
					_label.visible_ratio = 1.0
					elapsed = type_time
				else:
					_on_line_skipped()
					break
			elif _newer_beat_waiting() and elapsed >= type_time + INTERRUPT_GRACE:
				break
			_box.visible = not suppressed
	_label.text = ""
	_box.visible = false
	_showing = false


func _display(line: Dictionary, text: String) -> void:
	var speaker: String = line.get("speaker", "")
	var color: Color = SPEAKER_COLORS.get(speaker, NARRATION_COLOR)
	_label.text = "[color=#%s]%s[/color]" % [color.to_html(false), text]
	history.append({"text": text, "color": color})
	_label.visible_ratio = 0.0
	print("[story] %s: %s" % [speaker, text])


func _on_line_skipped() -> void:
	_skipped += 1
	MetaSave.record("lines_skipped")
	if _skipped >= SKIP_COMMENT_AT:
		_comment_once("skipping")


func _resolve_text(line: Dictionary) -> String:
	if line.has("if") and not MetaSave.check(line["if"]):
		return ""
	var key := "subject" if Session.local_role() == Session.Role.SUBJECT else "visitor"
	var text: String = line.get(key, line.get("text", ""))
	return MetaSave.format(text)

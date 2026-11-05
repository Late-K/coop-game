class_name CctvBank
extends ConsoleScreen
## The security office's CCTV (Chapter 1, puzzle 4), used in first person: one monitor that
## cycles through the facility's cameras, live, every few seconds (Left/Right to switch).
## The cameras are Marker3Ds placed in the level (`cameras`, named by `labels`). The feeds
## from the chamber wing are dead (`dead_labels`): NO SIGNAL. The `archive` holds old
## recordings: a camera's view aged into tape, dated years back, a blurred occupant standing
## in it (puzzle 6 reads the red paint behind them). No camera ever shows a player (they're
## drawn on Player.VISUAL_LAYER, which these leave out), so never the partner. One small
## camera renders the current feed, only while someone is near enough to look.

const FEED := Vector2i(192, 144)
const CYCLE := 4.5
const TEXT := Color(0.85, 0.9, 0.85)
const DIM := Color(0.5, 0.55, 0.5)

@export var cameras: Array[Marker3D] = []
@export var labels: Array[String] = []
@export var dead_labels: Array[String] = []
## Old recordings: where each was filmed from, and its label.
@export var archive: Array[Marker3D] = []
@export var archive_labels: Array[String] = []

var _feed := SubViewport.new()
var _eye := Camera3D.new()
var _index := 0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	prompt = "Watch the monitors"
	super()
	_feed.size = FEED
	_feed.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_eye.fov = 55.0
	_eye.cull_mask &= ~(Player.VISUAL_LAYER | RoomShroud.SHROUD_LAYER) # never a player; rooms seen as they are
	_eye.environment = load("res://kit/facility_environment.tres")
	_feed.add_child(_eye)
	add_child(_feed)
	_show_feed(0)


func _process(delta: float) -> void:
	var watched := has_local_focus or _local_player_near()
	_feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS if watched else SubViewport.UPDATE_DISABLED
	if not watched:
		return
	_time += delta
	if _time >= CYCLE:
		_show_feed(_index + 1)
	canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not has_local_focus:
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		_show_feed(_index + 1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		get_viewport().set_input_as_handled()
		_show_feed(_index - 1)


func _feed_count() -> int:
	return cameras.size() + archive.size() + dead_labels.size()


func _archived(index: int) -> bool:
	return index >= cameras.size() and index < cameras.size() + archive.size()


func _show_feed(index: int) -> void:
	_time = 0.0
	_index = posmod(index, maxi(_feed_count(), 1))
	if _index < cameras.size():
		_eye.global_transform = cameras[_index].global_transform
	elif _archived(_index):
		_eye.global_transform = archive[_index - cameras.size()].global_transform
	if has_local_focus:
		Sound.play_ui("keypad_press", -14.0, 1.6)


func _local_player_near() -> bool:
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority():
			return player.global_position.distance_to(global_position) < 7.0
	return false


func _draw_screen() -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_rect(Rect2(Vector2.ZERO, PIXELS), Color(0.02, 0.02, 0.02))
	var view := Rect2(10, 40, PIXELS.x - 20, (PIXELS.x - 20) * 0.75)
	var live := _index < cameras.size()
	var label := ""
	if live:
		label = labels[_index] if _index < labels.size() else ""
	elif _archived(_index):
		label = archive_labels[_index - cameras.size()]
	else:
		label = dead_labels[_index - cameras.size() - archive.size()]
	if _archived(_index):
		_draw_recording(view)
	elif live:
		canvas.draw_texture_rect(_feed.get_texture(), view, false, Color(0.85, 0.95, 0.85))
		# Scanlines and a timestamp, the way the old system burned them in.
		for y in range(int(view.position.y), int(view.end.y), 3):
			canvas.draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), Color(0, 0, 0, 0.25), 1.0)
		canvas.draw_string(font, view.position + Vector2(6, 14), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.3, 0.25))
	else:
		# Dead feed: snow and the words.
		for i in 260:
			var at := view.position + Vector2(_rng.randf() * view.size.x, _rng.randf() * view.size.y)
			canvas.draw_rect(Rect2(at, Vector2(3, 2)), Color(1, 1, 1, _rng.randf_range(0.05, 0.3)))
		canvas.draw_string(font, view.get_center() + Vector2(-34, 4), "NO SIGNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)
	canvas.draw_rect(view, DIM, false, 1.0)
	canvas.draw_string(font, Vector2(10, 18), "SECURITY // CCTV", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
	canvas.draw_string(font, Vector2(10, 32), "CAM %02d  %s" % [_index + 1, label], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)
	canvas.draw_string(font, Vector2(10, PIXELS.y - 12), "[Left/Right] camera   %d / %d" % [_index + 1, _feed_count()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DIM)


## An old tape: the camera's view gone grey and soft, grain, a band rolling through, the
## date it was taken, and the occupant of that test standing in it, too blurred to make out.
func _draw_recording(view: Rect2) -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_texture_rect(_feed.get_texture(), view, false, Color(0.75, 0.72, 0.62))
	var figure := view.position + Vector2(view.size.x * 0.16, view.size.y * 0.3)
	for i in 6:
		var jitter := Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-1, 1))
		canvas.draw_rect(Rect2(figure + jitter + Vector2(-8 - i, i * 4), Vector2(16 + i * 2, view.size.y * 0.42 - i * 6)),
				Color(0.08, 0.08, 0.07, 0.16))
	canvas.draw_circle(figure + Vector2(_rng.randf_range(-2, 2), -6), 9.0, Color(0.1, 0.1, 0.09, 0.3))
	for i in 380:
		var at := view.position + Vector2(_rng.randf() * view.size.x, _rng.randf() * view.size.y)
		canvas.draw_rect(Rect2(at, Vector2(2, 1)), Color(1, 1, 1, _rng.randf_range(0.03, 0.18)))
	var band := view.position.y + fposmod(Time.get_ticks_msec() / 25.0, view.size.y)
	canvas.draw_rect(Rect2(view.position.x, band, view.size.x, 6), Color(1, 1, 1, 0.12))
	canvas.draw_string(font, view.position + Vector2(6, 14), "PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)
	canvas.draw_string(font, view.end + Vector2(-112, -8), "11.03.1987  04:12", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)

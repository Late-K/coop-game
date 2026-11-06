class_name InteractCue
extends Control
## A small boxed icon over the thing in reach (Player._update_prompt): what using it does, at
## a glance, in the world rather than only in the prompt line. Our own pictograms:
##   door:   a doorway with an arrow through it (doors, stairs)
##   take:   an arrow down into a tray (items)
##   look:   an eye (consoles, panels, documents: things looked at up close)
##   use:    a pressed button (anything else)
##   locked: a padlock, in red (a door or device that won't give yet)
## It pops in when something comes into reach and follows it on screen.

const SIZE := 34.0
const USABLE := Color(0.6, 0.92, 1.0)
const BLOCKED := Color(1.0, 0.28, 0.22)
const BACK := Color(0.02, 0.03, 0.04, 0.85)
const POP_TIME := 0.12

var kind := "use"
var _target: Object = null
var _pop: Tween


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(SIZE, SIZE)
	pivot_offset = size / 2.0


## Show `cue` ("door", "take", "look", "use", "locked") for `target`, centred over `at`
## (screen pixels). Coming into reach of something new, it pops in.
func point_at(target: Object, at: Vector2, cue: String) -> void:
	if target != _target or not visible:
		_target = target
		visible = true
		scale = Vector2.ONE * 0.5
		if _pop:
			_pop.kill()
		_pop = create_tween()
		_pop.tween_property(self, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if cue != kind:
		kind = cue
		queue_redraw()
	position = (at - size / 2.0).round()


func clear() -> void:
	visible = false
	_target = null


func _draw() -> void:
	var colour := BLOCKED if kind == "locked" else USABLE
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), colour, false, 2.0)
	var c := size / 2.0
	match kind:
		"door":
			draw_polyline(PackedVector2Array([c + Vector2(-8, 9), c + Vector2(-8, -9), c + Vector2(4, -9), c + Vector2(4, 9)]), colour, 2.0)
			draw_line(c + Vector2(-2, 0), c + Vector2(10, 0), colour, 2.0)
			draw_polyline(PackedVector2Array([c + Vector2(6, -4), c + Vector2(10, 0), c + Vector2(6, 4)]), colour, 2.0)
		"take":
			draw_line(c + Vector2(0, -10), c + Vector2(0, 3), colour, 2.0)
			draw_polyline(PackedVector2Array([c + Vector2(-5, -2), c + Vector2(0, 3), c + Vector2(5, -2)]), colour, 2.0)
			draw_polyline(PackedVector2Array([c + Vector2(-9, 3), c + Vector2(-9, 9), c + Vector2(9, 9), c + Vector2(9, 3)]), colour, 2.0)
		"look":
			draw_arc(c + Vector2(0, 7), 11.0, PI * 1.18, PI * 1.82, 10, colour, 2.0)
			draw_arc(c + Vector2(0, -7), 11.0, PI * 0.18, PI * 0.82, 10, colour, 2.0)
			draw_circle(c, 3.0, colour)
		"locked":
			draw_rect(Rect2(c + Vector2(-7, -2), Vector2(14, 11)), colour)
			draw_arc(c + Vector2(0, -3), 5.0, PI, TAU, 8, colour, 2.0)
			draw_line(c + Vector2(-5, -3), c + Vector2(-5, -1), colour, 2.0)
			draw_line(c + Vector2(5, -3), c + Vector2(5, -1), colour, 2.0)
			draw_rect(Rect2(c + Vector2(-1, 2), Vector2(2, 4)), BACK)
		_:
			draw_rect(Rect2(c + Vector2(-8, -8), Vector2(16, 16)), colour, false, 2.0)
			draw_rect(Rect2(c + Vector2(-3, -3), Vector2(6, 6)), colour)

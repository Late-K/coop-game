class_name PressureGauge
extends ConsoleScreen
## The generator's restart console (Chapter 1, puzzle 7), the Subject's side: using it is
## holding the restart lever, and pressure builds for as long as you stay at it. The dial
## shows the needle and six numbered bands; the band the next breaker belongs in is lit.
## Only whoever stands here can see it, so they call it to the breaker room.

const TEXT := Color(0.45, 0.95, 0.82)
const DIM := Color(0.2, 0.42, 0.37)
const BAND := Color(1.0, 0.75, 0.35)

var plant: PlantRestart

var _holding := false


func _ready() -> void:
	prompt = "Hold the restart lever"
	super()


func _process(_delta: float) -> void:
	# Holding the lever is standing at it (in first person); stepping back lets go.
	if has_local_focus != _holding and plant:
		_holding = has_local_focus
		plant.set_holding.rpc_id(1, _holding)
	if is_visible_in_tree():
		canvas.queue_redraw()


func _draw_screen() -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_rect(Rect2(Vector2.ZERO, PIXELS), Color(0.01, 0.03, 0.03))
	canvas.draw_string(font, Vector2(8, 14), "GENERATOR 4 // RESTART PRESSURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)
	if plant == null:
		return
	var centre := Vector2(PIXELS.x / 2.0, PIXELS.y * 0.62)
	var radius := PIXELS.x * 0.4
	# The dial: a half circle from 0 (left) to 100 (right), the six bands marked and numbered.
	canvas.draw_arc(centre, radius, PI, TAU, 48, DIM, 2.0)
	var next := plant.next_band()
	for band in PlantRestart.BANDS.size():
		var from: float = PlantRestart.BANDS[band]
		var lit := band == next
		var colour := BAND if lit else DIM
		canvas.draw_arc(centre, radius - 8, _angle(from), _angle(from + PlantRestart.BAND_WIDTH), 8, colour, 10.0 if lit else 6.0)
		var label_at := centre + Vector2.from_angle(_angle(from + PlantRestart.BAND_WIDTH / 2.0)) * (radius - 30)
		canvas.draw_string(font, label_at - Vector2(4, -4), str(band + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, colour)
	var needle := Vector2.from_angle(_angle(plant.pressure)) * (radius - 4)
	canvas.draw_line(centre, centre + needle, Color(1, 0.35, 0.3), 3.0)
	canvas.draw_circle(centre, 6, TEXT)
	var status := "PLANT ONLINE" if plant.done else ("PRESSURE %d" % roundi(plant.pressure) if plant.holding else "LEVER RELEASED")
	canvas.draw_string(font, Vector2(8, PIXELS.y - 40), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)
	if not plant.done:
		var hint := "BREAKER %d OF 6: AT BAND %d" % [next + 1, next + 1] if next >= 0 else ""
		canvas.draw_string(font, Vector2(8, PIXELS.y - 22), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, BAND)
		canvas.draw_string(font, Vector2(8, PIXELS.y - 8), "[Stay here] hold the lever   [E] let go", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DIM)


## 0 pressure at the left of the dial, 100 at the right.
func _angle(value: float) -> float:
	return PI + clampf(value / 100.0, 0.0, 1.0) * PI

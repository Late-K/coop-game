class_name CalibrationChart
extends Interactable
## The Test 01 calibration chart (Chapter 1, puzzle 3), pinned up in the Visitor's intake
## office and read in first person: every glyph with its value, and the procedure. The
## values come from the `puzzle` (different every playthrough). The Visitor can't see the
## glyphs in the chamber; the Subject can't see this. Back against a wall, facing +Z.

const PIXELS := Vector2i(240, 300)
const BOARD := Vector2(1.0, 1.25)
const PAPER := Color(0.82, 0.78, 0.66)
const INK := Color(0.16, 0.13, 0.11)
const FADED := Color(0.45, 0.4, 0.34)

@export var puzzle: CalibrationPuzzle

var _canvas := Control.new()


func _ready() -> void:
	prompt = "Read the calibration chart"
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(BOARD.x + 0.08, BOARD.y + 0.08, 0.03)
	frame.mesh = frame_mesh
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.22, 0.15)
	frame.material_override = wood
	frame.position = Vector3(0, 1.55, 0.015)
	add_child(frame)
	var viewport := SubViewport.new()
	viewport.size = PIXELS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_canvas.size = PIXELS
	_canvas.draw.connect(_draw_chart)
	viewport.add_child(_canvas)
	add_child(viewport)
	var paper := Sprite3D.new()
	paper.texture = viewport.get_texture()
	paper.pixel_size = BOARD.x / PIXELS.x
	paper.position = Vector3(0, 1.55, 0.035)
	paper.set_meta("retro_skip", true)
	add_child(paper)
	var reach := CollisionShape3D.new()
	var reach_box := BoxShape3D.new()
	reach_box.size = Vector3(1.4, 2.0, 1.0)
	reach.shape = reach_box
	reach.position = Vector3(0, 1.0, 0.8)
	add_child(reach)
	var eye := Marker3D.new()
	eye.position = Vector3(0, 1.55, 1.15)
	add_child(eye)
	view_point = eye


func _process(_delta: float) -> void:
	_canvas.queue_redraw()


func _draw_chart() -> void:
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, PIXELS), PAPER)
	_canvas.draw_string(font, Vector2(12, 22), "TEST 01 // CALIBRATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	_canvas.draw_line(Vector2(12, 30), Vector2(PIXELS.x - 12, 30), INK, 1.0)
	var values := puzzle.values if puzzle else PackedInt32Array()
	if values.is_empty():
		_canvas.draw_string(font, Vector2(12, 56), "(table not yet issued)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, FADED)
	for symbol in values.size():
		var column := symbol % 2
		var row := symbol / 2
		var at := Vector2(24 + column * 108, 44 + row * 38)
		var cell := Rect2(symbol * Symbols.CELL, 0, Symbols.CELL, Symbols.CELL)
		_canvas.draw_texture_rect_region(Symbols.texture, Rect2(at, Vector2(28, 28)), cell, INK)
		_canvas.draw_string(font, at + Vector2(38, 21), "= %d" % values[symbol], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	var lines := [
		"PROCEDURE: present the occupant",
		"to each plate in ascending order",
		"of value.",
		"The plate whose value is the last",
		"digit of the occupant's number is",
		"the occupant's own. Do not",
		"present it.",
	]
	for i in lines.size():
		_canvas.draw_string(font, Vector2(12, 206 + i * 13), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)

class_name OccupantRegister
extends ConsoleScreen
## ZP-SYS's occupant register (Chapter 1, the Subject's side), used in first person: every
## occupant the facility has run, by number. The Subject's predecessors, all in the same
## pod, all recycled; the Subject, active. Once the entrance doors have come down (`crush`),
## two new lines: INTAKE 1, terminated at the entrance, and INTAKE 2, printed, with its
## pattern already on file and the release code for its safe room. The Subject reads the
## code to the Visitor, who keys it in (puzzle 1, "Release": a SymbolCodePuzzle with this
## as its display).

const TEXT := Color(0.45, 0.95, 0.82)
const DIM := Color(0.2, 0.45, 0.4)
const NEW := Color(1.0, 0.75, 0.35)
const WARNING := Color(1.0, 0.4, 0.35)
const SYMBOL_PIXELS := 20.0
## Predecessors listed above the Subject.
const HISTORY := 5
## Seconds after the doors come down before the new lines are written.
const UPDATE_DELAY := 8.0

@export var crush: EntranceCrush

var _code := PackedInt32Array()


func _ready() -> void:
	prompt = "Read the occupant register"
	super()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		canvas.queue_redraw()


## SymbolCodePuzzle's display: the release code.
func show_code(code: PackedInt32Array) -> void:
	_code = code


func _updated() -> bool:
	return crush != null and crush.done and Time.get_ticks_msec() / 1000.0 - crush.done_at >= UPDATE_DELAY


func _draw_screen() -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_rect(Rect2(Vector2.ZERO, PIXELS), Color(0.01, 0.03, 0.03))
	canvas.draw_string(font, Vector2(8, 14), "ZP-SYS // OCCUPANT REGISTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)
	canvas.draw_line(Vector2(8, 20), Vector2(PIXELS.x - 8, 20), DIM, 1.0)
	_row(36, ["NO.", "DESIGNATION", "POD", "STATUS"], DIM)
	var current := int(MetaSave.format("{iteration}"))
	var y := 52.0
	for i in range(HISTORY, 0, -1):
		_row(y, [str(current - i), "SUBJECT", "P-4", "RECYCLED"], DIM)
		y += 16.0
	_row(y, [str(current), "SUBJECT", "P-4", "ACTIVE"], TEXT)
	y += 16.0
	if not _updated():
		_row(y, ["--", "PERIMETER", "--", "UNSCHEDULED"], DIM)
		return
	_row(y, ["I-1", "INTAKE 1", "ENTR.", "TERMINATED"], DIM)
	y += 16.0
	_row(y, ["I-2", "INTAKE 2", "I-POD", "PRINTED"], NEW)
	y += 26.0
	canvas.draw_line(Vector2(8, y - 10), Vector2(PIXELS.x - 8, y - 10), DIM, 1.0)
	canvas.draw_string(font, Vector2(8, y + 4), "INTAKE 2: PATTERN ON FILE. SOURCE: --", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, NEW)
	canvas.draw_string(font, Vector2(8, y + 20), "HELD IN SAFE ROOM I. RELEASE CODE:", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, NEW)
	for i in _code.size():
		var cell := Rect2(_code[i] * Symbols.CELL, 0, Symbols.CELL, Symbols.CELL)
		var at := Vector2(16 + i * (SYMBOL_PIXELS + 14), y + 30)
		canvas.draw_texture_rect_region(Symbols.texture, Rect2(at, Vector2.ONE * SYMBOL_PIXELS), cell, NEW)
	# Puzzle 5's warning, for whoever reads this side: what waits in Intake 2's way.
	canvas.draw_line(Vector2(8, y + 62), Vector2(PIXELS.x - 8, y + 62), DIM, 1.0)
	canvas.draw_string(font, Vector2(8, y + 78), "NOTICE: ACOUSTIC UNIT ACTIVE: RECORDS (INTAKE)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, WARNING)
	canvas.draw_string(font, Vector2(8, y + 92), "RADIOS DRAW IT. RADIO SILENCE ADVISED.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, WARNING)


func _row(y: float, cells: Array, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var columns := [8, 56, 168, 214]
	for i in cells.size():
		canvas.draw_string(font, Vector2(columns[i], y), cells[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)

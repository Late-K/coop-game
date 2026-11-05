class_name CalibrationPuzzle
extends Node3D
## Chamber 01, "Calibration" (Chapter 1, puzzle 3). A row of floor plates, each under a
## glyph on the wall in the facility's cyan code: only the Subject sees them. The Visitor
## has the Test 01 chart (CalibrationChart): a value for every glyph, and the rule. Present
## the occupant to the plates in ascending order of value, but not to the plate whose value
## is the last digit of the occupant's own number (the Subject's, from its wake and the
## register). Each side has half: the Subject names the glyphs and its number, the Visitor
## reads back the order. A wrong plate resets the row; the right four open the `exit`.
##
## Plates sit in a row along local X, `spacing` apart, the glyphs `glyph_offset` from each
## (on the wall behind). Built in code. The server owns the state (which glyphs, their
## values, the steps so far) and pushes it to both machines. Saved; solved stays solved.

const PLATES := 5
const PLATE_SIZE := 1.3
const GLYPH_SIZE := 0.8
const CODE_COLOR := Color(0.45, 0.95, 0.82)
const IDLE_COLOR := Color(0.55, 0.58, 0.6)
const LIT_COLOR := Color(0.35, 0.95, 1.0)
const WRONG_COLOR := Color(1.0, 0.25, 0.2)

@export var exit: Door
@export var spacing := 2.2
## From each plate to its glyph on the wall (e.g. up and back to the north wall).
@export var glyph_offset := Vector3(0, 1.7, -2.4)
## Story lines for both players once it's solved.
@export var solved_lines: Array[String] = []
@export var keep_on_reload := true

## The glyph (a Symbols index) over each plate.
var glyphs := PackedInt32Array()
## The value of every glyph (Symbols.COUNT of them, distinct digits): what the chart lists.
var values := PackedInt32Array()
## Plates stepped on correctly so far, in order.
var stepped := PackedInt32Array()
var solved := false
## The digit the Subject leaves out (the last of its occupant number); -1 until reported.
var occupant_digit := -1

var _panels: Array[StandardMaterial3D] = []
var _glyph_sprites: Array[Sprite3D] = []
var _on_plate := -1


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	add_to_group("calibration")
	_build()
	set_physics_process(multiplayer.is_server())
	Session.roles_changed.connect(_report_occupant)
	MetaSave.session_started.connect(_report_occupant)
	_report_occupant()
	if not multiplayer.is_server():
		_request_state.rpc_id(1)


## The Subject's machine tells the server the occupant's number: the meta layer counts on
## each machine, so only the Subject's own is the one it was greeted with. Again whenever a
## session begins (the number moves on, also when a save is continued).
func _report_occupant() -> void:
	if Session.local_role() == Session.Role.SUBJECT:
		_occupant_reported.rpc_id(1, int(MetaSave.format("{iteration}")))


@rpc("any_peer", "call_local", "reliable")
func _occupant_reported(number: int) -> void:
	# A new number reissues the table, unless the calibration is already done.
	if not multiplayer.is_server() or solved or number % 10 == occupant_digit:
		return
	occupant_digit = number % 10
	stepped = PackedInt32Array()
	_configure()
	_broadcast()


## Server: five different glyphs over the plates, a different digit for every glyph, one of
## the five carrying the occupant's digit.
func _configure() -> void:
	var symbols := range(Symbols.COUNT)
	symbols.shuffle()
	glyphs = PackedInt32Array(symbols.slice(0, PLATES))
	var digits := range(10)
	digits.erase(occupant_digit)
	digits.shuffle()
	values.resize(Symbols.COUNT)
	var own := glyphs[randi() % PLATES]
	for symbol in Symbols.COUNT:
		values[symbol] = occupant_digit if symbol == own else digits.pop_back()
	var names := PackedStringArray()
	for plate in order():
		names.append("%s (%d)" % [Symbols.NAMES[glyphs[plate]], values[glyphs[plate]]])
	print("[calibration] occupant digit %d; order: %s" % [occupant_digit, ", ".join(names)])


## The plates to step on, in order: ascending value, the occupant's own left out.
func order() -> PackedInt32Array:
	var plates: Array = []
	for plate in glyphs.size():
		if values[glyphs[plate]] != occupant_digit:
			plates.append(plate)
	plates.sort_custom(func(a: int, b: int) -> bool: return values[glyphs[a]] < values[glyphs[b]])
	return PackedInt32Array(plates)


## Server: watch the Subject's feet.
func _physics_process(_delta: float) -> void:
	if solved or glyphs.is_empty():
		return
	var plate := -1
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.role == Session.Role.SUBJECT and not player.is_dead:
			plate = _plate_under(player.global_position)
	if plate != _on_plate:
		_on_plate = plate
		if plate >= 0:
			_step(plate)


func _plate_under(at: Vector3) -> int:
	var local := to_local(at)
	for plate in PLATES:
		var centre := _plate_position(plate)
		if absf(local.x - centre.x) <= PLATE_SIZE / 2.0 and absf(local.z - centre.z) <= PLATE_SIZE / 2.0:
			return plate
	return -1


func _step(plate: int) -> void:
	if plate in stepped:
		return
	var expected := order()
	if plate == expected[stepped.size()]:
		stepped.append(plate)
		solved = stepped.size() == expected.size()
		_feedback.rpc(plate, true)
		if solved:
			if exit.lock == Door.Lock.CODE:
				exit.unlock()
			else:
				exit.sync_open.rpc(true)
			Story.play(solved_lines)
	else:
		stepped = PackedInt32Array()
		_feedback.rpc(plate, false)
	_broadcast()


@rpc("any_peer", "reliable")
func _request_state() -> void:
	if multiplayer.is_server():
		_apply_state.rpc_id(multiplayer.get_remote_sender_id(), glyphs, values, stepped, solved, occupant_digit)


func _broadcast() -> void:
	_apply_state.rpc(glyphs, values, stepped, solved, occupant_digit)


@rpc("authority", "call_local", "reliable")
func _apply_state(new_glyphs: PackedInt32Array, new_values: PackedInt32Array, new_stepped: PackedInt32Array,
		new_solved: bool, digit: int) -> void:
	glyphs = new_glyphs
	values = new_values
	stepped = new_stepped
	solved = new_solved
	occupant_digit = digit
	for plate in PLATES:
		_glyph_sprites[plate].visible = plate < glyphs.size()
		if plate < glyphs.size():
			_glyph_sprites[plate].frame = glyphs[plate]
		_panels[plate].albedo_color = LIT_COLOR if plate in stepped else IDLE_COLOR
		_panels[plate].emission = _panels[plate].albedo_color


@rpc("authority", "call_local", "reliable")
func _feedback(plate: int, right: bool) -> void:
	var at := to_global(_plate_position(plate)) + Vector3.UP * 0.3
	if right:
		Sound.play_at("keypad_press", at, 2.0, 15.0, 0.0, 1.4)
		return
	Sound.play_at("code_wrong", at, 2.0, 18.0, 0.0)
	var material := _panels[plate]
	var tween := create_tween()
	tween.tween_property(material, "albedo_color", WRONG_COLOR, 0.05)
	tween.tween_property(material, "albedo_color", IDLE_COLOR, 0.6)


func save_state() -> Variant:
	return {"glyphs": glyphs, "values": values, "solved": solved, "digit": occupant_digit}


func load_state(state: Variant) -> void:
	var done: bool = state["solved"]
	var lit := order_for(state) if done else PackedInt32Array()
	_apply_state(state["glyphs"], state["values"], lit, done, state["digit"])
	if done:
		exit.load_state({"open": exit.lock != Door.Lock.CODE, "locked": false})


## The solved order for a saved state (to light every plate again on load).
func order_for(state: Dictionary) -> PackedInt32Array:
	glyphs = state["glyphs"]
	values = state["values"]
	occupant_digit = state["digit"]
	return order()


func _plate_position(plate: int) -> Vector3:
	return Vector3((plate - (PLATES - 1) / 2.0) * spacing, 0, 0)


## Plates in the floor, glyphs on the wall (the Subject's code: hidden on the Visitor's
## machine), each glyph its own sprite so the row reads left to right.
func _build() -> void:
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.16, 0.17, 0.18)
	var glyph_holder := Node3D.new()
	add_child(glyph_holder)
	var only_subject := RoleVisibility.new()
	only_subject.visible_to = "subject"
	glyph_holder.add_child(only_subject)
	for plate in PLATES:
		var at := _plate_position(plate)
		var base := MeshInstance3D.new()
		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(PLATE_SIZE, 0.06, PLATE_SIZE)
		base.mesh = base_mesh
		base.material_override = rim
		base.position = at + Vector3.UP * 0.03
		add_child(base)
		var panel_material := StandardMaterial3D.new()
		panel_material.albedo_color = IDLE_COLOR
		panel_material.emission_enabled = true
		panel_material.emission = IDLE_COLOR
		panel_material.emission_energy_multiplier = 0.6
		panel_material.set_meta("retro_skip", true)
		var panel := MeshInstance3D.new()
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(PLATE_SIZE - 0.3, 0.02, PLATE_SIZE - 0.3)
		panel.mesh = panel_mesh
		panel.material_override = panel_material
		panel.position = at + Vector3.UP * 0.07
		add_child(panel)
		_panels.append(panel_material)
		var glyph := Symbols.make_sprite(0, GLYPH_SIZE)
		glyph.modulate = CODE_COLOR
		glyph.shaded = false
		glyph.visible = false
		glyph.position = at + glyph_offset
		glyph_holder.add_child(glyph)
		_glyph_sprites.append(glyph)

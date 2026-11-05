class_name BreakerPanel
extends Interactable
## Breaker room B (Chapter 1, puzzle 7), the Visitor's side: six breakers, B1 to B6, thrown
## with the mouse in first person. It only reports which was pulled; PlantRestart decides.
## A thrown breaker stays down with its lamp lit; a vented sequence knocks them all back up.
## Back against a wall, facing +Z. Built in code.

signal breaker_pressed(breaker: int)

const BREAKERS := 6
const SPACING := 0.24
const CLICKABLE_LAYER := 16 # physics layer 5, "clickable"
const OFF := Color(0.5, 0.12, 0.1)
const ON := Color(0.3, 1.0, 0.45)

var plant: PlantRestart

var _levers: Array[Node3D] = []
var _lamps: Array[StandardMaterial3D] = []


func _ready() -> void:
	prompt = "Use the breaker panel"
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.21, 0.22)
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(BREAKERS * SPACING + 0.2, 0.8, 0.12)
	box.mesh = box_mesh
	box.material_override = dark
	box.position = Vector3(0, 1.4, 0.06)
	add_child(box)
	var title := Label3D.new()
	title.text = "BREAKER ROOM B // SECTOR 4"
	title.font_size = 18
	title.pixel_size = 0.003
	title.position = Vector3(0, 1.88, 0.125)
	title.modulate = Color(0.85, 0.85, 0.75)
	add_child(title)
	for i in BREAKERS:
		_add_breaker(i)
	var reach := CollisionShape3D.new()
	var reach_box := BoxShape3D.new()
	reach_box.size = Vector3(1.8, 2.0, 1.0)
	reach.shape = reach_box
	reach.position = Vector3(0, 1.0, 0.7)
	add_child(reach)
	var eye := Marker3D.new()
	eye.position = Vector3(0, 1.45, 1.0)
	add_child(eye)
	view_point = eye


## Breakers (1-6) that are down.
func show_thrown(thrown: PackedInt32Array) -> void:
	for i in BREAKERS:
		var down := (i + 1) in thrown
		_levers[i].rotation.x = 0.9 if down else -0.9
		_lamps[i].albedo_color = ON if down else OFF
		_lamps[i].emission = _lamps[i].albedo_color


## `breaker` went down (or, with -1 and not `right`, the lot came back up).
func clunk(breaker: int, right: bool) -> void:
	var at := global_position + Vector3.UP * 1.4
	Sound.play_at("door", at, -6.0, 15.0, 0.0, 1.8 if right else 0.7)


func _add_breaker(i: int) -> void:
	var x := (i - (BREAKERS - 1) / 2.0) * SPACING
	var label := Label3D.new()
	label.text = "B%d" % (i + 1)
	label.font_size = 20
	label.pixel_size = 0.003
	label.position = Vector3(x, 1.72, 0.125)
	add_child(label)
	var lamp_material := StandardMaterial3D.new()
	lamp_material.albedo_color = OFF
	lamp_material.emission_enabled = true
	lamp_material.emission = OFF
	lamp_material.set_meta("retro_skip", true)
	var lamp := MeshInstance3D.new()
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.06, 0.04, 0.02)
	lamp.mesh = lamp_mesh
	lamp.material_override = lamp_material
	lamp.position = Vector3(x, 1.12, 0.13)
	add_child(lamp)
	_lamps.append(lamp_material)
	# The lever: pivots at the panel, handle out front.
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 1.4, 0.13)
	pivot.rotation.x = -0.9
	add_child(pivot)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.06, 0.06, 0.22)
	handle.mesh = handle_mesh
	handle.position = Vector3(0, 0, 0.1)
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.75, 0.7, 0.55)
	handle.material_override = handle_material
	pivot.add_child(handle)
	_levers.append(pivot)
	var button := Area3D.new()
	button.collision_layer = CLICKABLE_LAYER
	button.collision_mask = 0
	button.monitoring = false
	button.monitorable = false
	button.position = Vector3(x, 1.4, 0.2)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SPACING * 0.9, 0.5, 0.2)
	shape.shape = box
	button.add_child(shape)
	button.input_event.connect(_on_input.bind(i + 1))
	add_child(button)


func _on_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int, breaker: int) -> void:
	if not has_local_focus:
		return
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		breaker_pressed.emit(breaker)

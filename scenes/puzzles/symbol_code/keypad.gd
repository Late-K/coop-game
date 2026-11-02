class_name Keypad
extends Interactable
## Wall keypad with one button per symbol and a small screen showing what was entered.
## Buttons are clicked with the mouse, and only while the local player is focused
## on the keypad in first person. It only reports presses; the puzzle decides.

signal symbol_pressed(symbol: int)

const ENTRY_SLOTS := 4
const COLUMNS := 4
const BUTTON_SIZE := 0.14
const BUTTON_SPACING := 0.17
const BUTTON_TOP_Y := 1.36
const CLICKABLE_LAYER := 16 # physics layer 5, "clickable"
const SCREEN_IDLE := Color(0.05, 0.08, 0.06)
const SCREEN_CORRECT := Color(0.1, 0.6, 0.2)
const SCREEN_WRONG := Color(0.7, 0.1, 0.1)

var _button_material := StandardMaterial3D.new()
var _screen_material := StandardMaterial3D.new()
var _entry_sprites: Array[Sprite3D] = []

@onready var screen: MeshInstance3D = $Screen
@onready var buttons_root: Node3D = $Buttons


func _ready() -> void:
	_button_material.albedo_color = Color(0.2, 0.2, 0.22)
	_screen_material.albedo_color = SCREEN_IDLE
	screen.material_override = _screen_material
	for symbol in Symbols.COUNT:
		_add_button(symbol)
	for i in ENTRY_SLOTS:
		var sprite := Symbols.make_sprite(0, 0.09)
		sprite.position = Vector3((i - (ENTRY_SLOTS - 1) / 2.0) * 0.13, 0, 0.006)
		sprite.modulate = Color(0.5, 1.0, 0.6)
		sprite.visible = false
		screen.add_child(sprite)
		_entry_sprites.append(sprite)


func show_entry(entered: PackedInt32Array) -> void:
	for i in ENTRY_SLOTS:
		_entry_sprites[i].visible = i < entered.size()
		if i < entered.size():
			_entry_sprites[i].frame = entered[i]


func flash(correct: bool) -> void:
	var tween := create_tween()
	if correct:
		tween.tween_property(_screen_material, "albedo_color", SCREEN_CORRECT, 0.2)
	else:
		tween.tween_property(_screen_material, "albedo_color", SCREEN_WRONG, 0.1)
		tween.tween_property(_screen_material, "albedo_color", SCREEN_IDLE, 0.6)


func _add_button(symbol: int) -> void:
	var button := Area3D.new()
	button.collision_layer = CLICKABLE_LAYER
	button.collision_mask = 0
	button.monitoring = false
	button.monitorable = false
	var column := symbol % COLUMNS
	var row := floori(float(symbol) / COLUMNS)
	button.position = Vector3((column - (COLUMNS - 1) / 2.0) * BUTTON_SPACING, BUTTON_TOP_Y - row * BUTTON_SPACING, 0.08)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BUTTON_SIZE, BUTTON_SIZE, 0.04)
	shape.shape = box
	button.add_child(shape)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	mesh.material_override = _button_material
	button.add_child(mesh)

	var sprite := Symbols.make_sprite(symbol, BUTTON_SIZE * 0.75)
	sprite.position.z = 0.021
	button.add_child(sprite)

	button.input_event.connect(_on_button_input_event.bind(symbol))
	button.mouse_entered.connect(func() -> void:
		if has_local_focus:
			mesh.scale = Vector3.ONE * 1.1
	)
	button.mouse_exited.connect(func() -> void: mesh.scale = Vector3.ONE)
	buttons_root.add_child(button)


func _on_button_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3,
		_shape_index: int, symbol: int) -> void:
	if not has_local_focus:
		return
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		symbol_pressed.emit(symbol)

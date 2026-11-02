class_name Keypad
extends Interactable
## Wall keypad with one button per symbol and a small screen showing what was entered.
## Buttons are clicked with the mouse, and only while the local player is focused
## on the keypad in first person. It only reports presses; the puzzle decides.

signal symbol_pressed(symbol: int)

## Shown on the screen while nothing is entered (e.g. a riddle). Empty for none.
@export var screen_text := ""

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
var _screen_label: Label3D

@onready var screen: MeshInstance3D = $Screen
@onready var buttons_root: Node3D = $Buttons


func _ready() -> void:
	_button_material.albedo_color = Color(0.2, 0.2, 0.22)
	_screen_material.albedo_color = SCREEN_IDLE
	_screen_material.set_meta("retro_skip", true) # flash() tweens it
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
	if screen_text:
		_screen_label = Label3D.new()
		_screen_label.text = screen_text
		_screen_label.font_size = 14
		_screen_label.pixel_size = 0.002
		_screen_label.modulate = Color(0.5, 1.0, 0.6)
		_screen_label.position.z = 0.006
		screen.add_child(_screen_label)


func show_entry(entered: PackedInt32Array) -> void:
	if _screen_label:
		_screen_label.visible = entered.is_empty()
	for i in ENTRY_SLOTS:
		_entry_sprites[i].visible = i < entered.size()
		if i < entered.size():
			_entry_sprites[i].frame = entered[i]


func flash(correct: bool) -> void:
	Sound.play_at("code_right" if correct else "code_wrong", global_position + Vector3.UP * 1.4, 0.0, 20.0, 0.0)
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
		Sound.play_ui("keypad_press")
		symbol_pressed.emit(symbol)

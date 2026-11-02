class_name CodeMonitor
extends Interactable
## Wall monitor that displays a symbol code. Too small to read from the top-down
## view, so the player has to step up to it (first person) and describe it over radio.

const SLOTS := 4
const SYMBOL_SIZE := 0.13
const SYMBOL_COLOR := Color(0.5, 1.0, 0.6)

var _sprites: Array[Sprite3D] = []

@onready var screen: MeshInstance3D = $Screen


func _ready() -> void:
	var screen_material := StandardMaterial3D.new()
	screen_material.albedo_color = Color(0.03, 0.05, 0.04)
	screen.material_override = screen_material
	for i in SLOTS:
		var sprite := Symbols.make_sprite(0, SYMBOL_SIZE)
		sprite.position = Vector3((i - (SLOTS - 1) / 2.0) * (SYMBOL_SIZE + 0.04), 0, 0.006)
		sprite.modulate = SYMBOL_COLOR
		sprite.visible = false
		screen.add_child(sprite)
		_sprites.append(sprite)


func show_code(code: PackedInt32Array) -> void:
	for i in SLOTS:
		_sprites[i].visible = i < code.size()
		if i < code.size():
			_sprites[i].frame = code[i]

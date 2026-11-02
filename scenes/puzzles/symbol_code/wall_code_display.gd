class_name WallCodeDisplay
extends Node3D
## Shows a symbol code painted flat on top of walls: one symbol per child Marker3D,
## in child order. Only the top-down camera can see wall tops; at eye level they are
## out of sight, so the characters "should not" know the code. That is the point.

const SYMBOL_SIZE := 1.0
const PAINT_COLOR := Color(0.85, 0.15, 0.1)

var _sprites: Array[Sprite3D] = []


func _ready() -> void:
	for marker in get_children():
		if marker is Marker3D:
			var sprite := Symbols.make_sprite(0, SYMBOL_SIZE)
			sprite.axis = Vector3.AXIS_Y
			sprite.modulate = PAINT_COLOR
			sprite.visible = false
			marker.add_child(sprite)
			_sprites.append(sprite)


func show_code(code: PackedInt32Array) -> void:
	for i in _sprites.size():
		_sprites[i].visible = i < code.size()
		if i < code.size():
			_sprites[i].frame = code[i]

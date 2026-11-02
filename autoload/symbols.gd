extends Node
## Puzzle symbols, drawn procedurally once into a sprite sheet at startup.
## Shapes are picked to be easy to name out loud ("the hourglass", "the zigzag"),
## because players describe them to each other over the radio.

const COUNT := 8
const CELL := 128
const NAMES: Array[String] = ["circle", "triangle", "square", "cross", "diamond", "star", "hourglass", "zigzag"]
const RADIUS := 40.0
const LINE_WIDTH := 9.0

var texture: Texture2D


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CELL * COUNT, CELL)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := Control.new()
	canvas.draw.connect(_draw_sheet.bind(canvas))
	viewport.add_child(canvas)
	add_child(viewport)
	texture = viewport.get_texture()


## A Sprite3D showing one symbol, `size` metres wide. Tint it with `modulate`.
func make_sprite(symbol: int, size: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.hframes = COUNT
	sprite.frame = clampi(symbol, 0, COUNT - 1)
	sprite.pixel_size = size / CELL
	return sprite


func _draw_sheet(canvas: Control) -> void:
	for i in COUNT:
		_draw_symbol(canvas, i, Vector2(CELL * (i + 0.5), CELL * 0.5))


func _draw_symbol(canvas: Control, symbol: int, c: Vector2) -> void:
	var r := RADIUS
	var color := Color.WHITE
	match symbol:
		0: # circle
			canvas.draw_arc(c, r, 0.0, TAU, 48, color, LINE_WIDTH, true)
		1: # triangle
			_draw_shape(canvas, c, [Vector2(0, -r), Vector2(r * 0.9, r * 0.7), Vector2(-r * 0.9, r * 0.7)], true)
		2: # square
			var s := r * 0.8
			_draw_shape(canvas, c, [Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)], true)
		3: # cross
			var s := r * 0.8
			canvas.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), color, LINE_WIDTH, true)
			canvas.draw_line(c + Vector2(s, -s), c + Vector2(-s, s), color, LINE_WIDTH, true)
		4: # diamond
			_draw_shape(canvas, c, [Vector2(0, -r), Vector2(r * 0.75, 0), Vector2(0, r), Vector2(-r * 0.75, 0)], true)
		5: # star
			var points: Array[Vector2] = []
			for i in 10:
				var angle := -PI / 2.0 + i * PI / 5.0
				var radius := r if i % 2 == 0 else r * 0.42
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			_draw_shape(canvas, c, points, true)
		6: # hourglass
			var s := r * 0.75
			_draw_shape(canvas, c, [Vector2(-s, -r), Vector2(s, -r), Vector2(-s, r), Vector2(s, r)], true)
		7: # zigzag
			_draw_shape(canvas, c, [Vector2(-r, r * 0.4), Vector2(-r * 0.5, -r * 0.4), Vector2(0, r * 0.4),
					Vector2(r * 0.5, -r * 0.4), Vector2(r, r * 0.4)], false)


func _draw_shape(canvas: Control, c: Vector2, offsets: Array[Vector2], closed: bool) -> void:
	var points := PackedVector2Array()
	for offset in offsets:
		points.append(c + offset)
	if closed:
		points.append(points[0])
	canvas.draw_polyline(points, Color.WHITE, LINE_WIDTH, true)

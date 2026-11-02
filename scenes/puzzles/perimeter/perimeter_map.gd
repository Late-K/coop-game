class_name PerimeterMap
extends Node3D
## The Subject's map of the snowfield: the ice ridges, every marker post with its
## symbol, which lamps are lit, and the airlock. It does not show the Visitor.
## Finding them is the puzzle.

const PIXELS := Vector2i(256, 256)
const HEADER_HEIGHT := 16.0
const LINE_COLOR := Color(0.3, 0.9, 0.5)
const LIT_COLOR := Color(1.0, 0.75, 0.35)
const SYMBOL_PIXELS := 22.0

@export var network: BeaconNetwork
## The snowfield on the floor, as (x, z, width, depth).
@export var world_rect := Rect2(24, -32, 58, 64)
@export var airlock_position := Vector2(26, 4.5)
## Ridges and drifts the Visitor can't cross, in the same floor coordinates.
@export var walls: Array[Rect2] = []
@export var screen_width := 0.9

var _canvas := Control.new()


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = PIXELS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_canvas.draw.connect(_draw_map)
	viewport.add_child(_canvas)
	add_child(viewport)
	var screen := Sprite3D.new()
	screen.texture = viewport.get_texture()
	screen.pixel_size = screen_width / PIXELS.x
	screen.position = Vector3(0, 1.5, 0.11)
	add_child(screen)
	network.lamps_changed.connect(_canvas.queue_redraw)


func _to_map(floor_position: Vector2) -> Vector2:
	var area := Vector2(PIXELS.x, PIXELS.y - HEADER_HEIGHT) - Vector2(8, 8)
	var scale := minf(area.x / world_rect.size.x, area.y / world_rect.size.y)
	return Vector2(4, HEADER_HEIGHT + 4) + (floor_position - world_rect.position) * scale


func _draw_map() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, PIXELS), Color(0.02, 0.05, 0.04))
	_canvas.draw_string(ThemeDB.fallback_font, Vector2(6, 12), "PERIMETER // LIGHTS %d/%d" %
			[network.lit.size(), BeaconNetwork.MAX_LIT], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LINE_COLOR)
	for wall in walls:
		var top_left := _to_map(wall.position)
		_canvas.draw_rect(Rect2(top_left, _to_map(wall.end) - top_left), LINE_COLOR * Color(1, 1, 1, 0.45))
	var airlock := _to_map(airlock_position)
	_canvas.draw_rect(Rect2(airlock - Vector2(5, 8), Vector2(10, 16)), LINE_COLOR, false, 1.0)
	_canvas.draw_string(ThemeDB.fallback_font, airlock + Vector2(-4, 20), "AIRLOCK",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, LINE_COLOR)
	for lamp in network.lamps:
		var at := _to_map(Vector2(lamp.global_position.x, lamp.global_position.z))
		var lit := lamp.symbol in network.lit
		if lit:
			_canvas.draw_circle(at, SYMBOL_PIXELS * 0.7, LIT_COLOR * Color(1, 1, 1, 0.35))
		var cell := Rect2(lamp.symbol * Symbols.CELL, 0, Symbols.CELL, Symbols.CELL)
		var rect := Rect2(at - Vector2.ONE * SYMBOL_PIXELS / 2.0, Vector2.ONE * SYMBOL_PIXELS)
		_canvas.draw_texture_rect_region(Symbols.texture, rect, cell, LIT_COLOR if lit else LINE_COLOR)

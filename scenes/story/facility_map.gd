class_name FacilityMap
extends Node3D
## Wall monitor with a live map of the facility and a dot for each player, updated
## every frame. The players find themselves being watched (the first meta hint).
## Each machine draws its own iteration number in the header.

const PIXELS := Vector2i(256, 160)
const HEADER_HEIGHT := 16.0
const LINE_COLOR := Color(0.3, 0.9, 0.5)
const DOT_COLORS := {Session.Role.SUBJECT: Color(0.85, 0.9, 1.0), Session.Role.VISITOR: Color(1.0, 0.55, 0.25)}

## The part of the world the map covers, as (x, z, width, depth) on the floor.
@export var world_rect := Rect2(-27, -36, 54, 51)
## Room outlines in the same floor coordinates.
@export var rooms: Array[Rect2] = []
@export var screen_width := 1.1

var _canvas := Control.new()
var _time := 0.0


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
	screen.position = Vector3(0, 1.5, 0.11) # just in front of the frame's face
	add_child(screen)


func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()


func _draw_map() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, PIXELS), Color(0.02, 0.05, 0.04))
	_canvas.draw_string(ThemeDB.fallback_font, Vector2(6, 12),
			MetaSave.format("ZERO POINT // ITERATION {iteration}"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LINE_COLOR)
	var map_area := Vector2(PIXELS.x, PIXELS.y - HEADER_HEIGHT) - Vector2(8, 8)
	var scale := minf(map_area.x / world_rect.size.x, map_area.y / world_rect.size.y)
	var origin := Vector2(4, HEADER_HEIGHT + 4)
	for room in rooms:
		var rect := Rect2(origin + (room.position - world_rect.position) * scale, room.size * scale)
		_canvas.draw_rect(rect, LINE_COLOR * Color(1, 1, 1, 0.6), false, 1.0)
	var blink_on := fmod(_time, 1.0) < 0.7
	for player: Player in get_tree().get_nodes_in_group("players"):
		if not blink_on:
			continue
		var floor_position := Vector2(player.global_position.x, player.global_position.z)
		var dot := origin + (floor_position - world_rect.position) * scale
		_canvas.draw_circle(dot, 3.0, DOT_COLORS.get(player.role, Color.WHITE))

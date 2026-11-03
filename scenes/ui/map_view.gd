class_name MapView
extends Control
## The terminal's MAP tab: the rooms (MapRoom) of every area this player has a floor plan
## for, with doors, save rooms and the player's own position. Never the partner's: where
## they are is something to ask. The map runs on the radio and goes dark when it is off.

const PADDING := 28.0
const ROOM_FILL := Color(0.04, 0.11, 0.1)
const DOOR_COLOR := Color(1.0, 0.72, 0.35)
const SAVE_COLOR := Color(0.3, 1.0, 0.45)

var player: Player
var _time := 0.0


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_time += delta
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.05))
	if player == null:
		return
	if not Radio.powered:
		_centred(font, "NO SIGNAL\nThe map runs on the radio. Switch it on in the RADIO tab.", PlayerHud.RADIO_COLOR)
		return
	var rooms: Array[MapRoom] = []
	for room: MapRoom in get_tree().get_nodes_in_group("map_rooms"):
		if player.maps.has(room.area):
			rooms.append(room)
	if rooms.is_empty():
		_centred(font, "NO MAP DATA\nFloor plans are posted on the walls of the facility.", InventoryScreen.DIM.lightened(0.4))
		return

	var bounds := rooms[0].rect()
	for room in rooms:
		bounds = bounds.merge(room.rect())
	bounds = bounds.grow(2.0)
	var scale := minf((size.x - PADDING * 2.0) / bounds.size.x, (size.y - PADDING * 2.0) / bounds.size.y)
	var offset := (size - bounds.size * scale) / 2.0
	var to_map := func(world: Vector2) -> Vector2: return offset + (world - bounds.position) * scale

	for room in rooms:
		var r := room.rect()
		var on_map := Rect2(to_map.call(r.position), r.size * scale)
		draw_rect(on_map, ROOM_FILL)
		draw_rect(on_map, InventoryScreen.PHOSPHOR, false, 1.5)
		if room.label and on_map.size.x > room.label.length() * 7.0:
			draw_string(font, on_map.position + Vector2(4, 14), room.label, HORIZONTAL_ALIGNMENT_LEFT,
					on_map.size.x - 8, 11, InventoryScreen.PHOSPHOR.darkened(0.2))
	# Doors and save rooms inside the mapped rooms.
	for door: Door in get_tree().get_nodes_in_group("doors"):
		if _inside(rooms, door.global_position):
			var across := Vector2(door.global_basis.z.x, door.global_basis.z.z) * 1.5
			var at := Vector2(door.global_position.x, door.global_position.z)
			draw_line(to_map.call(at - across), to_map.call(at + across), DOOR_COLOR, 3.0)
	for terminal in get_tree().get_nodes_in_group("save_terminals"):
		if _inside(rooms, terminal.global_position):
			var at: Vector2 = to_map.call(Vector2(terminal.global_position.x, terminal.global_position.z))
			draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), SAVE_COLOR)
	# You: an arrow pointing where you face, blinking.
	var here: Vector2 = to_map.call(Vector2(player.global_position.x, player.global_position.z))
	var facing := Vector2(-player.global_basis.z.x, -player.global_basis.z.z).normalized()
	var side := Vector2(-facing.y, facing.x)
	var arrow := PackedVector2Array([here + facing * 9.0, here - facing * 5.0 + side * 6.0, here - facing * 5.0 - side * 6.0])
	draw_colored_polygon(arrow, Color(1, 1, 1, 0.55 + 0.45 * sin(_time * 6.0)))
	# Legend.
	var y := size.y - 10.0
	draw_colored_polygon(PackedVector2Array([Vector2(12, y - 9), Vector2(8, y), Vector2(16, y)]), Color.WHITE)
	draw_string(font, Vector2(22, y), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, InventoryScreen.PHOSPHOR)
	draw_rect(Rect2(62, y - 8, 8, 8), SAVE_COLOR)
	draw_string(font, Vector2(76, y), "SAVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, InventoryScreen.PHOSPHOR)
	draw_line(Vector2(118, y - 4), Vector2(132, y - 4), DOOR_COLOR, 3.0)
	draw_string(font, Vector2(138, y), "DOOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, InventoryScreen.PHOSPHOR)
	draw_string(font, Vector2(8, 16), " / ".join(player.maps.values()).to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 16, 12, InventoryScreen.PHOSPHOR)


func _inside(rooms: Array[MapRoom], world: Vector3) -> bool:
	for room in rooms:
		if room.rect().grow(1.2).has_point(Vector2(world.x, world.z)):
			return true
	return false


func _centred(font: Font, text: String, color: Color) -> void:
	var lines := text.split("\n")
	for i in lines.size():
		draw_string(font, Vector2(0, size.y / 2.0 - 10 + i * 20), lines[i], HORIZONTAL_ALIGNMENT_CENTER, size.x,
				14 if i == 0 else 12, color)

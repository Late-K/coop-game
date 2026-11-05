class_name MapView
extends Control
## The terminal's MAP tab, Signalis-style: the rooms (MapRoom) of every area this player has
## a floor plan for, one floor at a time, rooms you have been in drawn brighter than ones you
## only know from the plan, doors marked by state (open, locked, barred, no power), save
## rooms, and your own position. Never the partner's: where they are is something to ask.
## The map runs on the radio and goes dark when it is off. Up/Down changes floor.

const PADDING := 28.0
const SAVE_COLOR := Color(0.3, 1.0, 0.45)
const KEY_COLOR := Color(1.0, 0.75, 0.3)
const POWER_COLOR := Color(0.55, 0.55, 0.55)
const ICE_COLOR := Color(0.6, 0.85, 1.0)

var player: Player
## The floor on screen (MapRoom.floor). Reset to the player's own floor when the tab opens.
var shown_floor := 0
var _time := 0.0


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_time += delta
		queue_redraw()


func show_player_floor() -> void:
	if player:
		shown_floor = floori((player.global_position.y + 0.5) / Kit.CELL.y)


## Up/Down: the next floor that has mapped rooms, if any.
func change_floor(step: int) -> void:
	var floors := _known_floors()
	var at := floors.find(shown_floor)
	if floors.size() > 1 and at >= 0:
		shown_floor = floors[clampi(at + step, 0, floors.size() - 1)]
		Sound.play_ui("keypad_press", -14.0, 1.4)


## Barred doors are red on the Subject's screen; on the Visitor's red screen they burn white.
static func door_color(state: String) -> Color:
	match state:
		"key":
			return KEY_COLOR
		"barred":
			return Color(1.0, 0.95, 0.9) if UiStyle.visitor() else Color(1.0, 0.3, 0.25)
		"power":
			return POWER_COLOR
		"iced":
			return ICE_COLOR
		"shut":
			return UiStyle.dim.lightened(0.3)
	return UiStyle.accent


func _known_floors() -> Array[int]:
	var floors: Array[int] = []
	for room: MapRoom in get_tree().get_nodes_in_group("map_rooms"):
		if player.maps.has(room.area) and room.floor not in floors:
			floors.append(room.floor)
	floors.sort()
	return floors


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.panel)
	if player == null:
		return
	if not Radio.powered:
		_centred(font, "NO SIGNAL\nThe map runs on the radio. Switch it on in the RADIO tab.", PlayerHud.RADIO_COLOR)
		return
	var rooms: Array[MapRoom] = []
	var everywhere: Array[MapRoom] = []
	for room: MapRoom in get_tree().get_nodes_in_group("map_rooms"):
		if player.maps.has(room.area):
			everywhere.append(room)
			if room.floor == shown_floor:
				rooms.append(room)
	if everywhere.is_empty():
		_centred(font, "NO MAP DATA\nFloor plans are posted on the walls of the facility.", UiStyle.dim.lightened(0.4))
		return

	if UiStyle.visitor():
		# The handheld's map: a dot grid, rooms as dashed outlines with no fill.
		for gx in range(8, int(size.x), 16):
			for gy in range(8, int(size.y), 16):
				draw_rect(Rect2(gx, gy, 1, 1), UiStyle.dim)
	# Framed on every mapped floor at once, so the map doesn't jump when changing floor.
	var bounds := everywhere[0].rect()
	for room in everywhere:
		bounds = bounds.merge(room.rect())
	bounds = bounds.grow(2.0)
	var scale := minf((size.x - PADDING * 2.0) / bounds.size.x, (size.y - PADDING * 2.0) / bounds.size.y)
	var offset := (size - bounds.size * scale) / 2.0
	var to_map := func(world: Vector2) -> Vector2: return offset + (world - bounds.position) * scale

	for room in rooms:
		var r := room.rect()
		var on_map := Rect2(to_map.call(r.position), r.size * scale)
		var visited := player.visited_room(room)
		var ink := UiStyle.accent if visited else UiStyle.dim.lightened(0.25)
		if UiStyle.visitor():
			_dashed_rect(on_map, ink)
		else:
			if visited:
				draw_rect(on_map, UiStyle.fill)
			draw_rect(on_map, ink, false, 1.5)
		if room.label and on_map.size.x > room.label.length() * 7.0:
			draw_string(font, on_map.position + Vector2(4, 14), room.label, HORIZONTAL_ALIGNMENT_LEFT,
					on_map.size.x - 8, 11, ink.darkened(0.15))
	# Doors (by state) and save rooms inside the mapped rooms on this floor.
	for door: Door in get_tree().get_nodes_in_group("doors"):
		var frame := door.frame_position()
		if _inside(rooms, frame):
			var across := Vector2(door.global_basis.z.x, door.global_basis.z.z) * 1.5
			var at := Vector2(frame.x, frame.z)
			_draw_door(to_map.call(at - across), to_map.call(at + across), door.map_state())
	for terminal in get_tree().get_nodes_in_group("save_terminals"):
		if _inside(rooms, terminal.global_position):
			var at: Vector2 = to_map.call(Vector2(terminal.global_position.x, terminal.global_position.z))
			draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), SAVE_COLOR)
	# You, if you're on this floor: an arrow (or the handheld's crosshair), blinking.
	if floori((player.global_position.y + 0.5) / Kit.CELL.y) == shown_floor:
		var here: Vector2 = to_map.call(Vector2(player.global_position.x, player.global_position.z))
		var facing := Vector2(-player.global_basis.z.x, -player.global_basis.z.z).normalized()
		var side := Vector2(-facing.y, facing.x)
		var blink := Color(1, 1, 1, 0.55 + 0.45 * sin(_time * 6.0))
		if UiStyle.visitor():
			draw_line(here - Vector2(10, 0), here + Vector2(10, 0), blink, 2.0)
			draw_line(here - Vector2(0, 10), here + Vector2(0, 10), blink, 2.0)
			draw_line(here, here + facing * 16.0, blink, 2.0)
		else:
			var arrow := PackedVector2Array([here + facing * 9.0, here - facing * 5.0 + side * 6.0, here - facing * 5.0 - side * 6.0])
			draw_colored_polygon(arrow, blink)
	_draw_legend(font)
	var title := " / ".join(player.maps.values()).to_upper()
	var floors := _known_floors()
	if floors.size() > 1:
		title += "    FLOOR %d  [Up/Down]" % (shown_floor + 1)
	draw_string(font, Vector2(8, 16), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 12, UiStyle.accent)


## A door across the wall: a solid line when open, dim when shut; locked doors carry a key
## mark, barred doors a cross, unpowered ones are dashed, frozen ones dotted in ice blue.
func _draw_door(from: Vector2, to: Vector2, state: String) -> void:
	var color := door_color(state)
	var mid := (from + to) / 2.0
	match state:
		"power":
			draw_dashed_line(from, to, color, 3.0, 3.0)
		"iced":
			draw_dashed_line(from, to, color, 3.0, 1.5)
		"barred":
			draw_line(from, to, color, 3.0)
			draw_line(mid - Vector2(5, 5), mid + Vector2(5, 5), color, 2.0)
			draw_line(mid - Vector2(5, -5), mid + Vector2(5, -5), color, 2.0)
		"key":
			draw_line(from, to, color, 3.0)
			draw_rect(Rect2(mid - Vector2(4, 4), Vector2(8, 8)), color)
		_:
			draw_line(from, to, color, 3.0)


func _draw_legend(font: Font) -> void:
	var y := size.y - 10.0
	var x := 8.0
	if UiStyle.visitor():
		draw_line(Vector2(x - 1, y - 4), Vector2(x + 9, y - 4), Color.WHITE, 2.0)
		draw_line(Vector2(x + 4, y - 9), Vector2(x + 4, y + 1), Color.WHITE, 2.0)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(x + 4, y - 9), Vector2(x, y), Vector2(x + 8, y)]), Color.WHITE)
	draw_string(font, Vector2(x + 14, y), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.accent)
	x += 50.0
	draw_rect(Rect2(x, y - 8, 8, 8), SAVE_COLOR)
	draw_string(font, Vector2(x + 14, y), "SAVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.accent)
	x += 56.0
	for entry in [["open", "OPEN"], ["key", "LOCKED"], ["barred", "BARRED"], ["power", "NO POWER"], ["iced", "FROZEN"]]:
		_draw_door(Vector2(x, y - 4), Vector2(x + 16, y - 4), entry[0])
		draw_string(font, Vector2(x + 22, y), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.accent)
		x += 30.0 + entry[1].length() * 8.0


func _dashed_rect(rect: Rect2, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 6.0)


func _inside(rooms: Array[MapRoom], world: Vector3) -> bool:
	var level := floori((world.y + 0.5) / Kit.CELL.y)
	for room in rooms:
		if room.floor == level and room.rect().grow(1.2).has_point(Vector2(world.x, world.z)):
			return true
	return false


func _centred(font: Font, text: String, color: Color) -> void:
	var lines := text.split("\n")
	for i in lines.size():
		draw_string(font, Vector2(0, size.y / 2.0 - 10 + i * 20), lines[i], HORIZONTAL_ALIGNMENT_CENTER, size.x,
				14 if i == 0 else 12, color)

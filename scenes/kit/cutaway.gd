class_name Cutaway
## What the camera shows of the world: only the area the local player is in (the rooms lit
## together, see RoomShroud), seen whole, like an open diorama in black. A map of the level,
## one pixel per grid cell, read by every world shader (cutaway.gdshaderinc):
##   KEEP:      the area's rooms and their walls: drawn.
##   WALL_ROW:  a room's near (south) wall, cut down to the floor (a door in it keeps only
##              its threshold). Not where another room of the area lies past it: that wall
##              is the other room's back wall, and stays.
##   IN_FRONT:  the cells south of it, as deep as anything standing there could reach up into
##              the view (a room a storey up included): everything cleared, however tall, the
##              black boxes over dark rooms too, so nothing stands between camera and room.
##   OUTSIDE:   everything else: no world geometry drawn at all (dark rooms keep their black
##              boxes, which hide anything not drawn through the world shader).
## The area only changes going through a door, in the black of its fade (Player), so the
## walls never change in view; within an area nothing changes as you walk between rooms.
##
## Objects are sorted too (sort_objects): the map cuts by pixel, which misses what isn't
## drawn through the world shader (text on signs, paper, glass, glints) and what hangs on a
## near wall that's been cut (it would float where the wall was). Anything standing outside
## the area, or on a cut near wall, goes onto HIDDEN_LAYER, which the main camera leaves
## out (CCTV still sees it); back inside, it gets its own layers again.

const OUTSIDE := 0
const WALL_ROW := 96
const IN_FRONT := 160
const KEEP := 255
## Cells of black void left round the level's rooms in the map.
const BORDER := 12
## Render layer 12, "outside": what the main camera doesn't draw (sort_objects).
const HIDDEN_LAYER := 1 << 11

## The map for the rooms lit now, seen from `pitch` degrees: {"texture": ImageTexture,
## "origin": Vector2 (world x, z of pixel 0, 0), "floor": float (the area's floor height)},
## or {} when nothing is lit.
static func build(tree: SceneTree, pitch: float) -> Dictionary:
	var shrouds: Array = tree.get_nodes_in_group("shrouds")
	var lit: Array = shrouds.filter(func(s: RoomShroud) -> bool: return not s.dark)
	if lit.is_empty():
		return {}
	var low := Vector2i(1 << 20, 1 << 20)
	var high := -low
	for shroud: RoomShroud in shrouds:
		var b := shroud.bounds()
		low = low.min(Vector2i(floori(b.position.x), floori(b.position.y)) - Vector2i.ONE * BORDER)
		high = high.max(Vector2i(ceili(b.end.x), ceili(b.end.y)) + Vector2i.ONE * BORDER)
	var size := high - low
	var map := Image.create(size.x, size.y, false, Image.FORMAT_R8) # all OUTSIDE
	# The area's rooms, with their walls, are kept; their own floors noted.
	var floors := {}
	for shroud: RoomShroud in lit:
		var r := _cells(shroud)
		for x in range(r.position.x - 1, r.end.x + 1):
			for z in range(r.position.y - 1, r.end.y + 1):
				_write(map, Vector2i(x, z) - low, KEEP)
				if r.has_point(Vector2i(x, z)):
					floors[Vector2i(x, z)] = true
	var depth := ceili((Kit.CELL.y + RoomShroud.HEIGHT) / tan(deg_to_rad(pitch))) + 1
	for shroud: RoomShroud in lit:
		var r := _cells(shroud)
		var row := r.end.y # the near wall's row
		for x in range(r.position.x - 1, r.end.x + 1):
			if not floors.has(Vector2i(x, row + 1)):
				_write(map, Vector2i(x, row) - low, WALL_ROW)
			for into in range(1, depth + 1):
				var at := Vector2i(x, row + into) - low
				if _read(map, at) == KEEP or _read(map, at) == WALL_ROW:
					break # another room of the area
				_write(map, at, IN_FRONT)
	var floor_y: float = (lit[0] as RoomShroud).floor * Kit.CELL.y
	return {"texture": ImageTexture.create_from_image(map), "image": map, "origin": Vector2(low), "floor": floor_y}


## Every object of the level, by where it stands on `data`'s map (Cutaway.build): inside
## the area as it was, outside it (or on a near wall that's cut) hidden from the main camera.
## The players and enemies move about, and are left alone; so are the black boxes. With no
## `data` (nothing lit) everything is shown.
static func sort_objects(tree: SceneTree, data: Dictionary) -> void:
	var level := tree.get_first_node_in_group("level")
	if level == null:
		return
	var actors: Array[Node] = []
	actors.append_array(tree.get_nodes_in_group("players"))
	actors.append_array(tree.get_nodes_in_group("enemies"))
	for node in level.find_children("*", "GeometryInstance3D", true, false):
		var thing := node as GeometryInstance3D
		if thing.layers == RoomShroud.SHROUD_LAYER or actors.any(func(a: Node) -> bool: return a.is_ancestor_of(thing)):
			continue
		var inside := true
		if not data.is_empty():
			var at := thing.global_position
			var origin: Vector2 = data["origin"]
			# A step south of where it hangs: something on a near wall's face counts as the wall.
			var mark := _read(data["image"], Vector2i(floori(at.x - origin.x), floori(at.z + 0.15 - origin.y)))
			inside = mark == KEEP or (mark == WALL_ROW and at.y - float(data["floor"]) < 0.3)
		if not inside and not thing.has_meta("cutaway_layers"):
			thing.set_meta("cutaway_layers", thing.layers)
			thing.layers = HIDDEN_LAYER
		elif inside and thing.has_meta("cutaway_layers"):
			thing.layers = thing.get_meta("cutaway_layers")
			thing.remove_meta("cutaway_layers")


## A room's floor as grid cells (x, z; end exclusive).
static func _cells(shroud: RoomShroud) -> Rect2i:
	var b := shroud.bounds()
	return Rect2i(roundi(b.position.x), roundi(b.position.y), roundi(b.size.x), roundi(b.size.y))


static func _read(map: Image, at: Vector2i) -> int:
	if at.x < 0 or at.y < 0 or at.x >= map.get_width() or at.y >= map.get_height():
		return OUTSIDE
	return map.get_pixel(at.x, at.y).r8


static func _write(map: Image, at: Vector2i, value: int) -> void:
	if at.x >= 0 and at.y >= 0 and at.x < map.get_width() and at.y < map.get_height():
		map.set_pixel(at.x, at.y, Color8(value, 0, 0))

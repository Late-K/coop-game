class_name RoomShroud
extends Node3D
## Darkness over a room the local player isn't in. One per room, `size` metres across (X by
## Z, centred here) on its `floor`: a solid black box that hides the room and everything in
## it from the top-down camera. Rooms joined without a door (a gap, an opening) share a
## `zone` and are lit together; only what's past a door stays dark, and a door held open for
## good (Door.held_open) joins both sides.
##
## Nothing fades or shows through: going through a door, the whole screen fades to black
## and back (Player.pass_through), and in the dark the room left goes black and the one
## entered is lit, all at once. The local player drives this (RoomShroud.update).
## Drawn on its own render layer (SHROUD_LAYER), which CCTV cameras leave out.

const SHROUD_LAYER := 1 << 10 # render layer 11, "shroud"
const SHADER := preload("res://shaders/room_shroud.gdshader")
const HEIGHT := 3.2 # well above the walls, so nothing tall in a dark room shows over it
## How far into its walls the box reaches: to their middle (a wall is one cell thick).
const WALL_REACH := 0.5

@export var size := Vector2(8, 8)
@export var floor := 0
## Rooms with the same zone light together (empty: on its own).
@export var zone := ""

## A door opened or shut somewhere (Door.set_open): what's lit is worked out again.
static var doors_changed := true
## Goes up whenever which rooms are lit changes (Cutaway is rebuilt then).
static var lit_version := 0

## Dark (the box drawn) or lit (gone).
var dark := true


func _ready() -> void:
	add_to_group("shrouds")
	# Out to the middle of its walls (a door between two dark rooms, a panel on the wall, is
	# covered from both sides; the lit room's own face of a shared wall stays in front) and
	# up to the top of them (lamps under the ceiling line, tall props).
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x + WALL_REACH * 2.0, HEIGHT, size.y + WALL_REACH * 2.0)
	box.mesh = mesh
	var black := ShaderMaterial.new()
	black.shader = SHADER # black, and cut with the near wall of the room the player's in
	box.material_override = black
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box.layers = SHROUD_LAYER
	box.position.y = floor * Kit.CELL.y + HEIGHT / 2.0
	add_child(box)


func contains(world: Vector3) -> bool:
	if floori((world.y + 0.5) / Kit.CELL.y) != floor:
		return false
	var local := world - global_position
	return absf(local.x) <= size.x / 2.0 and absf(local.z) <= size.y / 2.0


## The room `world` is in, or null.
static func at(tree: SceneTree, world: Vector3) -> RoomShroud:
	for shroud: RoomShroud in tree.get_nodes_in_group("shrouds"):
		if shroud.contains(world):
			return shroud
	return null


## The room's floor rectangle (x0, x1, z0, z1) in world metres.
func bounds() -> Rect2:
	return Rect2(global_position.x - size.x / 2.0, global_position.z - size.y / 2.0, size.x, size.y)


func set_dark(now_dark: bool) -> void:
	if now_dark != dark:
		lit_version += 1
	dark = now_dark
	visible = now_dark


## Which rooms light together: its zone, or the room alone.
func _key() -> String:
	return zone if not zone.is_empty() else str(get_path())


## The local player is at `world`: light the room it's in, with the rooms joined to it
## without a door or past a door held open for good, and darken the rest, at once. Outside
## every room (a doorway, a corridor with none, outdoors) it keeps the last room. Returns
## the room it's in now.
static func update(tree: SceneTree, world: Vector3, current: RoomShroud) -> RoomShroud:
	var shrouds := tree.get_nodes_in_group("shrouds")
	var here: RoomShroud = null
	for shroud: RoomShroud in shrouds:
		if shroud.contains(world):
			here = shroud
	if here == null:
		here = current
	if here == null or (here == current and not doors_changed):
		return current
	doors_changed = false
	var held := {} # key -> keys across doors held open
	for door: Door in tree.get_nodes_in_group("doors"):
		if not door.held_open():
			continue
		var sides: Array[String] = []
		var across := door.global_basis.x.normalized() * 1.5
		var floor_at := door.frame_position() - Vector3(0, Kit.WALL_HEIGHT / 2.0, 0)
		for at in [floor_at + across, floor_at - across]:
			for shroud: RoomShroud in shrouds:
				if shroud.contains(at):
					sides.append(shroud._key())
		if sides.size() == 2:
			held.get_or_add(sides[0], []).append(sides[1])
			held.get_or_add(sides[1], []).append(sides[0])
	var lit := {here._key(): true}
	var frontier: Array = [here._key()]
	while not frontier.is_empty():
		for next: String in held.get(frontier.pop_back(), []):
			if not lit.has(next):
				lit[next] = true
				frontier.append(next)
	for shroud: RoomShroud in shrouds:
		shroud.set_dark(not lit.has(shroud._key()))
	return here

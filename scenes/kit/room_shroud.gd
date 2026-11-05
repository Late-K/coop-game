class_name RoomShroud
extends Node3D
## Darkness over a room the local player isn't in. One per room, `size` metres across (X by
## Z, centred here) on its `floor`: a black box that hides the room and everything in it
## from the top-down camera. Rooms joined without a door (a gap, an opening) share a `zone`
## and light up together; only what's past a door stays dark.
##
## Opening a door shows nothing of the room past it: it lights the moment you step in, the
## lights flickering on (and the camera moves to it then, Player._update_camera). The room
## you left stays lit while the door behind you is open, and fades out as it rises
## (Door.MOVE_TIME). A door held open for good (Door.held_open) joins both sides.
## The local player drives all this (RoomShroud.update).
## Drawn on its own render layer (SHROUD_LAYER), which CCTV cameras leave out.

const SHROUD_LAYER := 1 << 10 # render layer 11, "shroud"
const HEIGHT := 2.55
## How far into its walls the box reaches: to their middle (a wall is one cell thick).
const WALL_REACH := 0.5
## Lights coming on: (darkness, seconds) steps, a fluorescent catching.
const FLICKER := [[0.0, 0.05], [0.7, 0.07], [0.0, 0.08], [0.45, 0.05]]

@export var size := Vector2(8, 8)
@export var floor := 0
## Rooms with the same zone light together (empty: on its own).
@export var zone := ""

## A door opened or shut somewhere (Door.set_open): what's lit is worked out again.
static var doors_changed := true

## Dark (the box drawn), or lit (fading out or gone).
var dark := true
var _black: StandardMaterial3D
var _fade: Tween


func _ready() -> void:
	add_to_group("shrouds")
	# Out to the middle of its walls (a door between two dark rooms, a panel on the wall, is
	# covered from both sides; the lit room's own face of a shared wall stays in front) and
	# up to the top of them (lamps under the ceiling line, tall props).
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x + WALL_REACH * 2.0, HEIGHT, size.y + WALL_REACH * 2.0)
	box.mesh = mesh
	_black = StandardMaterial3D.new()
	_black.albedo_color = Color.BLACK
	_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_black.set_meta("retro_skip", true)
	box.material_override = _black
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box.layers = SHROUD_LAYER
	box.position.y = floor * Kit.CELL.y + HEIGHT / 2.0
	add_child(box)


func contains(world: Vector3) -> bool:
	if floori((world.y + 0.5) / Kit.CELL.y) != floor:
		return false
	var local := world - global_position
	return absf(local.x) <= size.x / 2.0 and absf(local.z) <= size.y / 2.0


## Lit: on at once, with a flicker (or with none, `instant`). Dark: fading out over a door's
## travel (or at once). Solid black when dark, so nothing behind it sorts wrongly;
## see-through only on the way.
func set_dark(now_dark: bool, instant := false) -> void:
	if now_dark == dark and not instant:
		return
	dark = now_dark
	if _fade:
		_fade.kill()
	if instant:
		_settle(1.0 if dark else 0.0)
		return
	visible = true
	_black.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fade = create_tween()
	if dark:
		_fade.tween_property(_black, "albedo_color:a", 1.0, Door.MOVE_TIME).set_trans(Tween.TRANS_SINE)
		_fade.tween_callback(_settle.bind(1.0))
	else:
		for step: Array in FLICKER:
			_fade.tween_callback(func() -> void: _black.albedo_color.a = step[0])
			_fade.tween_interval(step[1])
		_fade.tween_callback(_settle.bind(0.0))


func _settle(alpha: float) -> void:
	_black.albedo_color.a = alpha
	_black.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	visible = alpha > 0.0


## Which rooms light together: its zone, or the room alone.
func _key() -> String:
	return zone if not zone.is_empty() else str(get_path())


## The local player is at `world`: light the room it's in (with the rooms joined to it
## without a door, or past a door held open for good); keep lit what's still lit through a
## door standing open; darken the rest. Outside every room (a doorway, a corridor with none,
## outdoors) it keeps the last room. The first time, it's all at once. Returns the room
## it's in now.
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
	var open := {} # key -> keys across doors open for now
	var lit_now := {} # keys lit (or lighting) at the moment
	for shroud: RoomShroud in shrouds:
		if not shroud.dark:
			lit_now[shroud._key()] = true
	for door: Door in tree.get_nodes_in_group("doors"):
		if not door.is_open:
			continue
		var sides: Array[String] = []
		var across := door.global_basis.x.normalized() * 1.5
		var floor_at := door.frame_position() - Vector3(0, Kit.WALL_HEIGHT / 2.0, 0)
		for at in [floor_at + across, floor_at - across]:
			for shroud: RoomShroud in shrouds:
				if shroud.contains(at):
					sides.append(shroud._key())
		if sides.size() == 2:
			var links := held if door.held_open() else open
			links.get_or_add(sides[0], []).append(sides[1])
			links.get_or_add(sides[1], []).append(sides[0])
	var lit := {here._key(): true}
	var frontier: Array = [here._key()]
	while not frontier.is_empty():
		var key: String = frontier.pop_back()
		for next: String in held.get(key, []):
			if not lit.has(next):
				lit[next] = true
				frontier.append(next)
		# Through an open door only what's lit already stays lit: nothing new comes on.
		for next: String in open.get(key, []):
			if not lit.has(next) and lit_now.has(next):
				lit[next] = true
				frontier.append(next)
	for shroud: RoomShroud in shrouds:
		shroud.set_dark(not lit.has(shroud._key()), current == null)
	return here

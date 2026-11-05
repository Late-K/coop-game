class_name LevelGrid
extends GridMap
## A level's architecture, painted from the kit (res://kit/kit_library.tres) on Kit.CELL.
## Paint floors where people walk and walls where the building is solid; leave cells empty
## for the void (pits, the outside of the building). Several storeys stack on the grid's
## floor index (y).
##
## At runtime every indoor cell that isn't wall (floors, low pieces) gets a ceiling tile at
## the ceiling line, on visual layer 2: only the first-person camera sees ceilings, so the
## top-down camera keeps looking straight into the rooms. Snow floors are outdoors and get
## none.

const LIBRARY := preload("res://kit/kit_library.tres")
const CEILING_MATERIAL := preload("res://kit/materials/ceiling.tres")
## Floor pieces that stay open to the sky.
const OUTDOOR_FLOORS: Array[String] = ["floor_snow"]
## Visual layer seen only by the first-person camera (see the player's cameras).
const FIRST_PERSON_LAYER := 2

## Black mass filling the void around the building, this many cells out (twice that to the
## south, where the camera looks from).
const VOID_MARGIN := 8
## No black mass within this many cells of an outdoor floor: outside is the whiteout.
const OUTDOOR_CLEARANCE := 3

## Build ceilings over indoor floors.
@export var ceilings := true
## Fill empty cells around the building with solid black (visual only, no collision), so
## the outsides of walls never show and rooms read as hollows carved out of black mass.
## Empty cells inside the building fill too: there are no pits.
@export var fill_void := true


func _init() -> void:
	if mesh_library == null:
		mesh_library = LIBRARY
	cell_size = Kit.CELL
	cell_center_y = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if ceilings:
		_build_ceilings()
	if fill_void:
		_build_void()


## Walkable ground for the enemies' navigation map (Level bakes it): a quad on every floor
## cell. Walls, low pieces and empty cells are simply not walkable; the bake keeps agents
## clear of the edges.
func add_navigation_source(source: NavigationMeshSourceGeometryData3D) -> void:
	var faces := PackedVector3Array()
	for cell in get_used_cells():
		if not mesh_library.get_item_name(get_cell_item(cell)).begins_with("floor_"):
			continue
		var a := Vector3(cell.x, cell.y * Kit.CELL.y, cell.z)
		var b := a + Vector3(1, 0, 0)
		var c := a + Vector3(1, 0, 1)
		var d := a + Vector3(0, 0, 1)
		faces.append_array([a, b, c, a, c, d, a, c, b, a, d, c]) # both windings: one faces up
	source.add_faces(faces, global_transform)


func _build_void() -> void:
	var used := get_used_cells()
	if used.is_empty():
		return
	var low := Vector3i(used[0])
	var high := Vector3i(used[0])
	var near_outdoors := {}
	for cell in used:
		low = low.min(cell)
		high = high.max(cell)
		if mesh_library.get_item_name(get_cell_item(cell)) in OUTDOOR_FLOORS:
			for dx in range(-OUTDOOR_CLEARANCE, OUTDOOR_CLEARANCE + 1):
				for dz in range(-OUTDOOR_CLEARANCE, OUTDOOR_CLEARANCE + 1):
					near_outdoors[Vector3i(cell.x + dx, cell.y, cell.z + dz)] = true
	# Upper storeys fill only around their own rooms, and never over a floor below: the black
	# would bury the storey underneath from the top-down camera.
	var near_upper := {}
	for cell in used:
		if cell.y > low.y:
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					near_upper[Vector3i(cell.x + dx, cell.y, cell.z + dz)] = true
	var transforms: Array[Transform3D] = []
	for y in range(low.y, high.y + 1):
		for x in range(low.x - VOID_MARGIN, high.x + VOID_MARGIN + 1):
			for z in range(low.z - VOID_MARGIN, high.z + VOID_MARGIN * 2 + 1):
				var cell := Vector3i(x, y, z)
				if y > low.y and (not near_upper.has(cell) or _floor_below(cell)):
					continue
				if get_cell_item(cell + Vector3i.UP) != INVALID_CELL_ITEM:
					continue # a room above stands here: its floor is the top of this column
				if get_cell_item(cell) == INVALID_CELL_ITEM and not near_outdoors.has(cell):
					var at := map_to_local(cell)
					at.y = y * Kit.CELL.y + (Kit.WALL_HEIGHT - 0.5) / 2.0
					transforms.append(Transform3D(Basis(), at))
	if transforms.is_empty():
		return
	var block := BoxMesh.new()
	block.size = Vector3(1, Kit.WALL_HEIGHT + 0.5, 1)
	var blocks := MultiMesh.new()
	blocks.transform_format = MultiMesh.TRANSFORM_3D
	blocks.mesh = block
	blocks.instance_count = transforms.size()
	for i in transforms.size():
		blocks.set_instance_transform(i, transforms[i])
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	var mass := MultiMeshInstance3D.new()
	mass.name = "Void"
	mass.multimesh = blocks
	mass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mass.material_override = black
	add_child(mass)


## Something walkable or built in this column on a storey beneath `cell` (a few down).
func _floor_below(cell: Vector3i) -> bool:
	for y in range(cell.y - 1, cell.y - 5, -1):
		if get_cell_item(Vector3i(cell.x, y, cell.z)) != INVALID_CELL_ITEM:
			return true
	return false


func _build_ceilings() -> void:
	var cells: Array[Vector3i] = []
	for cell in get_used_cells():
		var item_name := mesh_library.get_item_name(get_cell_item(cell))
		if not item_name.begins_with("wall_") and item_name not in OUTDOOR_FLOORS:
			cells.append(cell)
	if cells.is_empty():
		return
	var tile := PlaneMesh.new()
	tile.size = Vector2.ONE
	tile.flip_faces = true # faces down, into the room
	var tiles := MultiMesh.new()
	tiles.transform_format = MultiMesh.TRANSFORM_3D
	tiles.mesh = tile
	tiles.instance_count = cells.size()
	for i in cells.size():
		var at := map_to_local(cells[i])
		at.y = cells[i].y * Kit.CELL.y + Kit.WALL_HEIGHT
		tiles.set_instance_transform(i, Transform3D(Basis(), at))
	var ceiling := MultiMeshInstance3D.new()
	ceiling.name = "Ceilings"
	ceiling.multimesh = tiles
	ceiling.layers = 1 << (FIRST_PERSON_LAYER - 1)
	ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ceiling.material_override = CEILING_MATERIAL
	add_child(ceiling)

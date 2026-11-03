extends Node
## Builds scenes/levels/kit_sample.tscn from the level template: a small showcase of every
## kit piece (a lab, a corridor, a storage room and an outdoor yard), playable with
## `-- --host --level=kit`. Rerunning overwrites the scene. Runs as a scene (not with -s)
## because the level and prop scripts need the game's autoloads:
##   godot --headless --path . res://tools/build_kit_sample.tscn

const OUT := "res://scenes/levels/kit_sample.tscn"
const PROPS := "res://scenes/kit/props/"
const FACE_NORTH := Basis(Vector3.UP, PI) # a prop's front (+Z) turned to face -Z
const FACE_WEST := Basis(Vector3.UP, -PI / 2)

## Item ids from tools/build_kit.gd.
const FLOOR_TILES := 0
const FLOOR_GRATE := 1
const FLOOR_CONCRETE := 2
const FLOOR_HAZARD := 3
const FLOOR_SNOW := 4
const WALL_PANEL := 10
const WALL_CONCRETE := 11
const WALL_LAB := 12
const WALL_ICE := 13
const LOW_PANEL := 21

## name: [x0, x1, z0, z1 (cells, end exclusive), floor, wall]
const ROOMS := {
	"Lab": [1, 11, 1, 9, FLOOR_TILES, WALL_LAB],
	"Corridor": [12, 20, 3, 6, FLOOR_GRATE, WALL_CONCRETE],
	"Storage": [21, 33, -2, 12, FLOOR_CONCRETE, WALL_PANEL],
	"Yard": [24, 30, 13, 19, FLOOR_SNOW, WALL_ICE],
}

var level: Level


func _ready() -> void:
	level = (load("res://scenes/levels/level_template.tscn") as PackedScene).instantiate()
	level.name = "KitSample"
	level.scene_file_path = ""
	level.chapter_title = "Level kit sample"
	_paint()
	_furnish()
	_frame()
	level.get_node("SpawnPoints/Subject").position = Vector3(4, 0.1, 5)
	level.get_node("SpawnPoints/Visitor").position = Vector3(7, 0.1, 5)
	var scene := PackedScene.new()
	scene.pack(level)
	print("kit sample -> %s (%s)" % [OUT, error_string(ResourceSaver.save(scene, OUT))])
	level.free()
	get_tree().quit()


func _paint() -> void:
	var grid: LevelGrid = level.get_node("LevelGrid")
	var floors := {}
	var styles := {}
	for room: String in ROOMS:
		var r: Array = ROOMS[room]
		for x in range(r[0], r[1]):
			for z in range(r[2], r[3]):
				floors[Vector2i(x, z)] = r[4]
	# Doorways through the 1-cell walls (3 cells wide), and an open gap out to the yard.
	for z in range(3, 6):
		floors[Vector2i(11, z)] = FLOOR_HAZARD
		floors[Vector2i(20, z)] = FLOOR_HAZARD
	for x in range(25, 28):
		floors[Vector2i(x, 12)] = FLOOR_CONCRETE
	# A counter in the lab: low pieces replace the floor under them.
	for x in range(3, 7):
		floors[Vector2i(x, 6)] = LOW_PANEL

	for cell: Vector2i in floors:
		grid.set_cell_item(Vector3i(cell.x, 0, cell.y), floors[cell])
	# Every empty cell touching a floor becomes wall, in the style of the room it bounds.
	for room: String in ROOMS:
		var r: Array = ROOMS[room]
		for x in range(r[0] - 1, r[1] + 1):
			for z in range(r[2] - 1, r[3] + 1):
				var cell := Vector2i(x, z)
				if not floors.has(cell) and not styles.has(cell):
					styles[cell] = r[5]
	for cell: Vector2i in styles:
		grid.set_cell_item(Vector3i(cell.x, 0, cell.y), styles[cell])


func _furnish() -> void:
	# Doors sit in the middle of the wall cell; door.tscn spans Z, so east/west walls need
	# no rotation (north/south walls: turn it 90 degrees).
	for at in [Vector3(11.5, 1.25, 4.5), Vector3(20.5, 1.25, 4.5)]:
		var door := _place("res://scenes/props/door.tscn", "Doors", at)
		door.start_open = true

	# Lab: desks along the north wall, lockers on the south wall, one lamp.
	for x in [3, 6, 9]:
		_place(PROPS + "desk.tscn", "Props", Vector3(x, 0, 1.45))
	_place(PROPS + "lockers.tscn", "Props", Vector3(8, 0, 8.75), FACE_NORTH)
	_place(PROPS + "ceiling_light.tscn", "Lights", Vector3(6, 0, 4))

	# Corridor: pipes along the north wall and a failing lamp.
	for x in [13, 15, 17, 19]:
		_place(PROPS + "pipes.tscn", "Props", Vector3(x, 0, 3))
	var lamp := _place(PROPS + "ceiling_light.tscn", "Lights", Vector3(16, 0, 4.5))
	var light: KitLight = lamp.get_node("Light")
	light.flicker = true
	light.light_energy = 1.6
	light.light_color = Color(0.75, 0.9, 1.0)
	level.set_editable_instance(lamp, true)

	# Storage: shelving on the north wall under a wall lamp, crates, barrels, rubble, a vent.
	for x in [23, 26, 29]:
		_place(PROPS + "shelf.tscn", "Props", Vector3(x, 0, -1.75))
	_place(PROPS + "wall_lamp.tscn", "Lights", Vector3(27.5, 0, -2))
	_place(PROPS + "ceiling_light.tscn", "Lights", Vector3(27, 0, 8))
	_place(PROPS + "crate.tscn", "Props", Vector3(24.5, 0, 6.5))
	_place(PROPS + "crate.tscn", "Props", Vector3(25.6, 0, 6.6), Basis(Vector3.UP, 0.2))
	_place(PROPS + "crate.tscn", "Props", Vector3(24.6, 1, 6.5), Basis(Vector3.UP, -0.15))
	for at in [Vector3(31.5, 0, 9.5), Vector3(30.7, 0, 10.4), Vector3(31.5, 0, 10.6)]:
		_place(PROPS + "barrel.tscn", "Props", at)
	_place(PROPS + "debris.tscn", "Props", Vector3(28, 0, 5))
	_place(PROPS + "debris.tscn", "Props", Vector3(22.5, 0, 9), Basis(Vector3.UP, 1.4))
	_place(PROPS + "vent.tscn", "Props", Vector3(33, 0, 4), FACE_WEST)

	# Yard: outdoors, so the whiteout look, wind and snow underfoot, and a little static.
	var yard := EnvironmentZone.new()
	yard.name = "Yard"
	yard.environment = load("res://kit/whiteout_environment.tres")
	yard.ambience = "amb_whiteout"
	yard.footsteps = "step_snow"
	yard.radio_interference = 0.3
	_add(yard, "Zones", Vector3(27, 1.5, 16))
	_add_box_shape(yard, Vector3(6, 3, 6))
	_place(PROPS + "barrel.tscn", "Props", Vector3(28.5, -0.3, 17), Basis(Vector3.RIGHT, 0.25))

	# Enemies: a husk in the storage room, a listener by the yard (it tracks radios).
	_place("res://scenes/enemies/enemy.tscn", "Placements", Vector3(29, 0, 2), FACE_NORTH)
	_place("res://scenes/enemies/listener.tscn", "Placements", Vector3(27, 0, 15))


## One camera zone per room, sized to the room: the camera frames it whole. Corridors get
## none: the camera follows the player through them.
func _frame() -> void:
	for room: String in ROOMS:
		if room == "Corridor":
			continue
		var r: Array = ROOMS[room]
		var zone := _place("res://scenes/kit/camera_zone.tscn", "CameraZones",
				Vector3((r[0] + r[1]) / 2.0, 1.5, (r[2] + r[3]) / 2.0))
		zone.name = room
		var shape := BoxShape3D.new()
		shape.size = Vector3(r[1] - r[0], 3, r[3] - r[2])
		zone.get_node("CollisionShape3D").shape = shape
		level.set_editable_instance(zone, true)


func _place(path: String, parent: String, at: Vector3, basis := Basis()) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate()
	_add(node, parent, at, basis)
	return node


func _add(node: Node3D, parent: String, at: Vector3, basis := Basis()) -> void:
	level.get_node(parent).add_child(node, true)
	node.owner = level
	node.transform = Transform3D(basis, at)


func _add_box_shape(area: Area3D, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	collision.owner = level

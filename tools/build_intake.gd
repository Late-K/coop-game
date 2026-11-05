extends Node
## Builds scenes/levels/intake.tscn, Chapter 1 "Intake" (docs/design.md), from the level
## template: the opening (the snowfield, the radar, the crush) and puzzles 1 to 8, through
## to each side's way down. It's the chapter the game starts (`-- --host` to skip the menu).
## Rerunning overwrites the scene:
##   godot --headless --path . res://tools/build_intake.tscn
##
## Each area has its own look (see docs/level_kit.md, Area sets): the Subject's rooms are
## test chambers (white panels, decaying), the Visitor's are offices (carpet, wallpaper,
## wood), outside is snow and ice, and the two safe rooms are furnished exactly alike.
## The two sides never connect: a void lies between them, and only the radio crosses it.

const OUT := "res://scenes/levels/intake.tscn"
const PROPS := "res://scenes/kit/props/"
const FACE_NORTH := Basis(Vector3.UP, PI)
const FACE_WEST := Basis(Vector3.UP, -PI / 2)
const FACE_EAST := Basis(Vector3.UP, PI / 2)
const TURN := Basis(Vector3.UP, PI / 2) # door.tscn spans Z: turned for north/south walls

const FLOOR_GRATE := 1
const FLOOR_CONCRETE := 2
const FLOOR_HAZARD := 3
const FLOOR_SNOW := 4
const FLOOR_CHAMBER := 5
const FLOOR_CARPET := 6
const FLOOR_LINOLEUM := 7
const FLOOR_SAFE := 8
const WALL_CONCRETE := 11
const WALL_ICE := 13
const WALL_CHAMBER := 14
const WALL_DECAYED := 15
const WALL_OFFICE := 16
const WALL_MACHINERY := 17
const WALL_SAFE := 18

## The contact channel: where the beacon calls, and what the radar prints.
const CONTACT_CHANNEL := 131.7

## name: [x0, x1, z0, z1 (cells, end exclusive), floor, wall]
const ROOMS := {
	# The Subject: a test cell, a decayed passage, the radar control room, a save room.
	"PodCell": [-26, -20, 2, 10, FLOOR_CHAMBER, WALL_CHAMBER],
	"Passage": [-19, -13, 3, 7, FLOOR_CHAMBER, WALL_DECAYED],
	"RadarControl": [-12, -1, -1, 11, FLOOR_CHAMBER, WALL_DECAYED],
	"SubjectSafeRoom": [0, 6, 2, 9, FLOOR_SAFE, WALL_SAFE],
	# Puzzle 2, "Heat": the stores off the passage (heat cells, the tube, the first husk) and
	# the room behind them.
	"Stores": [-19, -13, -9, 2, FLOOR_CONCRETE, WALL_MACHINERY],
	"StoresBack": [-19, -13, -15, -10, FLOOR_GRATE, WALL_MACHINERY],
	# Puzzle 3, "Calibration": chamber 01, the machinery behind its rotten west wall, and
	# the way on once it's solved.
	"Chamber01": [-24, -10, -27, -16, FLOOR_CHAMBER, WALL_DECAYED],
	"Machinery01": [-28, -25, -27, -16, FLOOR_GRATE, WALL_MACHINERY],
	"Chamber01Exit": [-9, -3, -21, -17, FLOOR_CHAMBER, WALL_CHAMBER],
	# Puzzle 6, "Two frequencies": chamber 02, and the way on (to the plant, to come).
	"Chamber02": [-9, 4, -32, -22, FLOOR_CHAMBER, WALL_DECAYED],
	"Chamber02Exit": [5, 11, -30, -25, FLOOR_CHAMBER, WALL_CHAMBER],
	# Puzzle 7, "The plant": chamber 03 (collapsed), the machinery past its gap (a guard post,
	# a frozen locker, husks), a save room, and the generator hall, whose east wall is the
	# breaker room's west wall.
	"Chamber03": [5, 11, -43, -31, FLOOR_CHAMBER, WALL_DECAYED],
	"Machinery02": [12, 19, -44, -37, FLOOR_GRATE, WALL_MACHINERY],
	"PlantSafeRoom": [12, 18, -51, -45, FLOOR_SAFE, WALL_SAFE],
	"GeneratorHall": [12, 19, -36, -22, FLOOR_CONCRETE, WALL_MACHINERY],
	# Puzzle 8, "Ways down": the Subject's lift off chamber 02's exit corridor, and a supply
	# store off the generator hall, both dead until the power comes back.
	"Lift": [5, 11, -24, -20, FLOOR_GRATE, WALL_MACHINERY],
	"PowerStore": [13, 17, -21, -18, FLOOR_CONCRETE, WALL_MACHINERY],
	# The Visitor: the airlock, the intake office behind it, a safe room with the pod.
	"Airlock": [20, 25, 23, 29, FLOOR_CONCRETE, WALL_MACHINERY],
	"IntakeOffice": [16, 30, 12, 22, FLOOR_CARPET, WALL_OFFICE],
	"VisitorSafeRoom": [31, 38, 13, 20, FLOOR_SAFE, WALL_SAFE],
	# Behind the intake office's frozen door: the security wing (a husk) and its office.
	"SecurityWing": [22, 30, 3, 11, FLOOR_LINOLEUM, WALL_OFFICE],
	"SecurityOffice": [20, 30, -6, 2, FLOOR_CARPET, WALL_OFFICE],
	# Puzzle 4: duct M-2, from the wing round the office's west side to the airlock.
	"DuctNorth": [12, 21, 4, 9, FLOOR_GRATE, WALL_MACHINERY],
	"DuctWest": [12, 15, 9, 25, FLOOR_GRATE, WALL_MACHINERY],
	"DuctSouth": [12, 19, 25, 29, FLOOR_GRATE, WALL_MACHINERY],
	# The way into the duct, from the Subject's side: out of the radar control room's south
	# wall (a KEY door) along a service run. The Subject finds the Visitor's body.
	"ServiceRun": [-6, 12, 12, 16, FLOOR_GRATE, WALL_MACHINERY],
	# Puzzle 5: records, north of the security office: shelves, the power schematic, a
	# listener.
	"Records": [18, 32, -20, -7, FLOOR_LINOLEUM, WALL_OFFICE],
	# Puzzle 7, the Visitor's half: breaker room B past records, and a save room beside it.
	"BreakerRoom": [20, 30, -32, -21, FLOOR_CONCRETE, WALL_MACHINERY],
	"BreakerSafeRoom": [31, 37, -32, -26, FLOOR_SAFE, WALL_SAFE],
	# Puzzle 8, the Visitor's: the stairwell north of the breaker room, and a store off the
	# security wing.
	"Stairwell": [22, 28, -38, -33, FLOOR_CONCRETE, WALL_CONCRETE],
	"SecurityStore": [31, 35, 3, 8, FLOOR_LINOLEUM, WALL_OFFICE],
	# Outside.
	"Snowfield": [2, 43, 30, 77, FLOOR_SNOW, WALL_ICE],
}

## Rooms a storey up (storey 1), the same way: [x0, x1, z0, z1, floor, wall]. Reached by
## Stairs; placed over empty ground so nothing below is buried.
const UPPER_ROOMS := {
	# Puzzle 5: the records archive loft, up the stairs in records' north-east corner.
	"RecordsLoft": [34, 40, -20, -12, FLOOR_LINOLEUM, WALL_OFFICE],
}

## Ridges across the snowfield (ice walls), as [x0, x1, z]: a zigzag north.
const RIDGES := [[2, 31, 62], [14, 43, 50], [2, 29, 39]]

## Marker posts: symbol -> where it stands (x, z).
const POSTS := {
	0: Vector2(10, 68), 1: Vector2(35, 67), 2: Vector2(38, 56), 3: Vector2(24, 55),
	4: Vector2(8, 45), 5: Vector2(20, 44), 6: Vector2(36, 34), 7: Vector2(26, 32),
}

var level: Level


func _ready() -> void:
	level = (load("res://scenes/levels/level_template.tscn") as PackedScene).instantiate()
	level.name = "Intake"
	level.scene_file_path = ""
	level.chapter_title = "Chapter 1: Intake"
	level.visitor_opening = true
	level.intro_lines = ["intro", "whiteout"]
	_paint()
	_subject_side()
	_visitor_side()
	_outside()
	_frame()
	_map()
	_shroud()
	# In front of the pod: where the wake leaves the Subject, and where a death before the
	# first save brings them back.
	level.get_node("SpawnPoints/Subject").position = Vector3(-23, 0.1, 3.6)
	level.get_node("SpawnPoints/Visitor").position = Vector3(8, 0.1, 73)
	var scene := PackedScene.new()
	scene.pack(level)
	print("intake -> %s (%s)" % [OUT, error_string(ResourceSaver.save(scene, OUT))])
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
	for ridge: Array in RIDGES:
		for x in range(ridge[0], ridge[1]):
			floors.erase(Vector2i(x, ridge[2]))
			styles[Vector2i(x, ridge[2])] = WALL_ICE
	# Doorways (3 cells) through the 1-cell walls.
	for z in range(4, 7):
		floors[Vector2i(-20, z)] = FLOOR_CHAMBER
		floors[Vector2i(-13, z)] = FLOOR_HAZARD
		floors[Vector2i(-1, z)] = FLOOR_SAFE
	for x in range(21, 24):
		floors[Vector2i(x, 29)] = FLOOR_HAZARD # the entrance
		floors[Vector2i(x, 22)] = FLOOR_HAZARD # airlock to intake
	for z in range(15, 18):
		floors[Vector2i(30, z)] = FLOOR_SAFE
	for x in range(-18, -15):
		floors[Vector2i(x, 2)] = FLOOR_HAZARD # passage to stores
		floors[Vector2i(x, -10)] = FLOOR_GRATE # stores to the back
		floors[Vector2i(x, -16)] = FLOOR_HAZARD # the back to chamber 01
	for z in range(-20, -17):
		floors[Vector2i(-10, z)] = FLOOR_HAZARD # chamber 01's exit
	floors[Vector2i(-25, -21)] = FLOOR_GRATE # the gap rotted through its west wall
	for x in range(-7, -4):
		floors[Vector2i(x, -22)] = FLOOR_HAZARD # chamber 01's exit corridor to chamber 02
	for z in range(-29, -26):
		floors[Vector2i(4, z)] = FLOOR_HAZARD # chamber 02's exit
	for x in range(-5, -2):
		floors[Vector2i(x, 11)] = FLOOR_HAZARD # radar control's key door into the service run
	for z in range(25, 28):
		floors[Vector2i(19, z)] = FLOOR_GRATE # the duct opening into the airlock
	for x in range(6, 9):
		floors[Vector2i(x, -31)] = FLOOR_HAZARD # chamber 02's exit corridor to chamber 03
	floors[Vector2i(11, -40)] = FLOOR_GRATE # the gap in chamber 03's east wall
	for x in range(14, 17):
		floors[Vector2i(x, -37)] = FLOOR_HAZARD # machinery to the generator hall
		floors[Vector2i(x, -45)] = FLOOR_SAFE # machinery to the plant's save room
	for x in range(24, 27):
		floors[Vector2i(x, -21)] = FLOOR_HAZARD # records to the breaker room
	for x in range(7, 10):
		floors[Vector2i(x, -25)] = FLOOR_HAZARD # chamber 02's exit corridor to the lift
	for x in range(14, 17):
		floors[Vector2i(x, -22)] = FLOOR_HAZARD # generator hall to its store
	for x in range(24, 27):
		floors[Vector2i(x, -33)] = FLOOR_HAZARD # breaker room to the stairwell
	for z in range(4, 7):
		floors[Vector2i(30, z)] = FLOOR_HAZARD # security wing to its store
	for z in range(-30, -27):
		floors[Vector2i(30, z)] = FLOOR_SAFE # breaker room to its save room
	for x in range(27, 30):
		floors[Vector2i(x, -7)] = FLOOR_LINOLEUM # security office to records
	for x in range(25, 28):
		floors[Vector2i(x, 11)] = FLOOR_HAZARD # the frozen door
		floors[Vector2i(x, 2)] = FLOOR_LINOLEUM # wing to security office
	for cell: Vector2i in floors:
		grid.set_cell_item(Vector3i(cell.x, 0, cell.y), floors[cell])
	# Every empty cell touching a floor becomes wall, in the style of the room it bounds.
	# Safe rooms claim their walls first: they must look the same on every side.
	var order := ROOMS.keys().filter(func(room: String) -> bool: return room.ends_with("SafeRoom"))
	order.append_array(ROOMS.keys().filter(func(room: String) -> bool: return not room.ends_with("SafeRoom")))
	for room: String in order:
		var r: Array = ROOMS[room]
		for x in range(r[0] - 1, r[1] + 1):
			for z in range(r[2] - 1, r[3] + 1):
				var cell := Vector2i(x, z)
				if not floors.has(cell) and not styles.has(cell):
					styles[cell] = r[5]
	# The facility's outer face along the snowfield is concrete, not ice.
	for x in range(1, 44):
		if styles.has(Vector2i(x, 29)):
			styles[Vector2i(x, 29)] = WALL_CONCRETE
	for cell: Vector2i in styles:
		grid.set_cell_item(Vector3i(cell.x, 0, cell.y), styles[cell])
	# The storey above: its rooms and their walls, at grid storey 1.
	for room: String in UPPER_ROOMS:
		var r: Array = UPPER_ROOMS[room]
		for x in range(r[0] - 1, r[1] + 1):
			for z in range(r[2] - 1, r[3] + 1):
				var inside: bool = x >= r[0] and x < r[1] and z >= r[2] and z < r[3]
				grid.set_cell_item(Vector3i(x, 1, z), r[4] if inside else r[5])


## The Subject's rooms: white test-chamber panels, going to rot the further from the pod.
func _subject_side() -> void:
	# The cell door opens when the Subject is up (SubjectWake), and stays open: a death
	# before the first save must not shut them back in.
	var cell_door := _door(Vector3(-19.5, 1.25, 5.5), Basis(), false)
	cell_door.name = "CellDoor"
	cell_door.keep_on_reload = true
	_door(Vector3(-12.5, 1.25, 5.5), Basis(), true)
	_door(Vector3(-0.5, 1.25, 5.5), Basis(), true)

	# Pod cell: clean and cold, the pod on the north wall. Dark until the Subject wakes.
	var pod := WakePod.new()
	pod.name = "WakePod"
	_add(pod, "Props", Vector3(-23, 0, 2))
	var wake := SubjectWake.new()
	wake.name = "SubjectWake"
	wake.pod = pod
	wake.door = cell_door
	wake.lights.append(_light(Vector3(-23, 0, 6), Color(0.85, 0.92, 1.0), 2.2))
	_level_add(wake)
	_place(PROPS + "fallen_panels.tscn", "Props", Vector3(-21, 0, 8.5))
	# Passage: the panels giving out, tissue grown through a gap.
	_light(Vector3(-16, 0, 5), Color(0.8, 0.9, 1.0), 1.4, true)
	_place(PROPS + "growth.tscn", "Props", Vector3(-15, 0, 3.6))
	_place(PROPS + "fallen_panels.tscn", "Props", Vector3(-17.5, 0, 6), Basis(Vector3.UP, 1.2))

	# Radar control: the scope and the lights panel on the north wall, consoles around.
	var network := BeaconNetwork.new()
	network.name = "PerimeterNetwork"
	var lights_panel := _place("res://scenes/puzzles/symbol_code/keypad.tscn", "Props", Vector3(-9.5, 0, -1))
	lights_panel.name = "PerimeterLights"
	lights_panel.prompt = "Use the perimeter lights"
	lights_panel.screen_text = "PERIMETER LIGHTS\nRESERVE: 2 AT ONCE"
	var scope := RadarScope.new()
	scope.name = "RadarScope"
	_add(scope, "Props", Vector3(-5, 0, -0.62))
	_place(PROPS + "desk.tscn", "Props", Vector3(-11, 0, -0.55))
	# The occupant register: after the crush, INTAKE 2 and its release code (puzzle 1).
	var register := OccupantRegister.new()
	register.name = "OccupantRegister"
	_add(register, "Props", Vector3(-2.4, 0, -0.62))
	_place(PROPS + "lockers.tscn", "Props", Vector3(-11.75, 0, 8), FACE_EAST)
	_place(PROPS + "fallen_panels.tscn", "Props", Vector3(-3, 0, 8))
	_place(PROPS + "growth.tscn", "Props", Vector3(-11, 0, 3), Basis(Vector3.UP, 2.0))
	for x in [-11, -9, -7, -5, -3]:
		_place(PROPS + "pipes.tscn", "Props", Vector3(x, 0, -1))
	_light(Vector3(-7, 0, 2), Color(0.8, 0.9, 1.0), 1.6)
	_light(Vector3(-4, 0, 7), Color(0.8, 0.9, 1.0), 0.9, true)

	_safe_room(ROOMS["SubjectSafeRoom"], "SubjectSafeRoom")
	_stores()
	_chamber_01()
	_chamber_02()
	_plant()
	_level_add(network)
	network.keypad = lights_panel
	scope.network = network
	for symbol: int in POSTS:
		var post := BeaconLamp.new()
		post.name = "Post%d" % symbol
		post.symbol = symbol
		_add(post, "Story", Vector3(POSTS[symbol].x, 0, POSTS[symbol].y))
		network.lamps.append(post)


## The Visitor's rooms: the airlock, an intake office gone cold, a safe room with the pod.
func _visitor_side() -> void:
	var entrance := _door(Vector3(22.5, 1.25, 29.5), TURN, false)
	entrance.name = "Entrance"
	entrance.start_open = true
	var inner := _door(Vector3(22.5, 1.25, 22.5), TURN, false)
	inner.name = "AirlockInner"
	inner.lock = Door.Lock.POWER
	# The safe room is sealed until the release code is keyed in (puzzle 1, "Release").
	var safe_door := _door(Vector3(30.5, 1.25, 16.5), Basis(), false)
	safe_door.name = "SafeRoomIDoor"
	safe_door.lock = Door.Lock.CODE
	safe_door.keep_on_reload = true
	_wall_lamp(Vector3(22.5, 0, 23), Color(0.85, 0.9, 1.0), 2.0)
	# A failing light over the outer doors, so the camera (and the duct) find the body.
	_light(Vector3(22.5, 0, 27.6), Color(0.85, 0.9, 1.0), 1.4, true)

	# Intake office: desks in rows, cabinets and a whiteboard on the north wall, a dead plant.
	for x in [18.5, 21.5, 24.5]:
		for z in [15.0, 18.0]:
			_place(PROPS + "desk.tscn", "Props", Vector3(x, 0, z))
			_place(PROPS + "office_chair.tscn", "Props", Vector3(x - 0.3, 0, z + 0.75), FACE_NORTH)
	for x in [17, 17.6, 18.2]:
		_place(PROPS + "filing_cabinet.tscn", "Props", Vector3(x, 0, 12.3))
	# The Test 01 calibration chart (puzzle 3) where the whiteboard was.
	var chart := CalibrationChart.new()
	chart.name = "CalibrationChart"
	chart.puzzle = level.get_node("Props/Calibration")
	_add(chart, "Props", Vector3(20.5, 0, 12))
	_place(PROPS + "filing_cabinet.tscn", "Props", Vector3(28.6, 0, 12.3))
	_place(PROPS + "dead_plant.tscn", "Props", Vector3(29.2, 0, 13.2))
	_place(PROPS + "dead_plant.tscn", "Props", Vector3(16.6, 0, 20.5))
	_light(Vector3(19.5, 0, 15.5), Color(1.0, 0.85, 0.6), 2.4)
	_light(Vector3(25.5, 0, 15.5), Color(1.0, 0.85, 0.6), 1.8, true)
	_light(Vector3(23, 0, 19.5), Color(1.0, 0.85, 0.6), 1.6)

	_heat()
	var wake_terminal := _safe_room(ROOMS["VisitorSafeRoom"], "VisitorSafeRoom")
	# The entrance doors come down on the Visitor: the body stays in the doorway, and they
	# wake in this safe room's pod (EntranceCrush).
	var crush := EntranceCrush.new()
	crush.name = "EntranceCrush"
	crush.door = entrance
	crush.wake_terminal = wake_terminal
	_add(crush, "Story", Vector3(22.5, 0, 29.45))
	var keypad := _place("res://scenes/puzzles/symbol_code/keypad.tscn", "Props", Vector3(31, 0, 14.2), FACE_EAST)
	keypad.name = "ReleaseKeypad"
	keypad.prompt = "Use the door keypad"
	keypad.screen_text = "SAFE ROOM I\nSEALED\nENTER RELEASE CODE"
	var release := SymbolCodePuzzle.new()
	release.name = "Release"
	release.keypad = keypad
	release.display = level.get_node("Props/OccupantRegister")
	release.doors.append(safe_door)
	release.solved_lines.append("released")
	_level_add(release)
	(level.get_node("Props/OccupantRegister") as OccupantRegister).crush = crush


## Puzzle 2, the Subject's half: the stores, dark between the shelves, with two heat cells,
## a med kit, the only tube station on this side, and the Subject's first husk. No weapon:
## round the shelving, a shove, out through a door that shuts itself behind you.
func _stores() -> void:
	var front := _door(Vector3(-16.5, 1.25, 2.5), TURN, true)
	front.name = "StoresDoor"
	var back := _door(Vector3(-16.5, 1.25, -9.5), TURN, true)
	back.name = "StoresBackDoor"
	# A shelving island down the middle: a loop to run round.
	for z in [-6.0, -3.8]:
		_place(PROPS + "shelf.tscn", "Props", Vector3(-16.5, 0, z), FACE_EAST)
	_place(PROPS + "crate.tscn", "Props", Vector3(-18.4, 0, -0.5))
	_place(PROPS + "crate.tscn", "Props", Vector3(-18.4, 1, -0.5), Basis(Vector3.UP, 0.2))
	_place(PROPS + "barrel.tscn", "Props", Vector3(-13.6, 0, -4.5))
	_place(PROPS + "pipes.tscn", "Props", Vector3(-16, 0, -9))
	var tube: ItemTube = _place("res://scenes/items/item_tube.tscn", "Props", Vector3(-13, 0, -1.6), FACE_WEST)
	tube.name = "StoresTube"
	_pickup("heat_cell", Vector3(-14.1, 0.1, -8.3))
	_pickup("heat_cell", Vector3(-14.9, 0.1, -8.6))
	_pickup("medkit", Vector3(-18.4, 0.1, -8.4))
	# In the middle of the stores, well clear of both doors (Enemy.DOOR_CLEAR).
	_place("res://scenes/enemies/enemy.tscn", "Placements", Vector3(-16.5, 0, -4.5))
	_wall_lamp(Vector3(-16.5, 0, -9), Color(0.75, 0.85, 1.0), 1.2)
	_light(Vector3(-15, 0, 0), Color(0.8, 0.9, 1.0), 0.7, true)
	_light(Vector3(-16.5, 0, -12.5), Color(0.8, 0.9, 1.0), 0.8)
	_place(PROPS + "debris.tscn", "Props", Vector3(-15, 0, -13))


## Puzzle 7, the Subject's half: chamber 03 has collapsed; the way on is the gap in its
## east wall, into machinery where a dead guard still has a pistol (the Subject's first
## weapon, before the husks), and a supply locker frozen shut that the second heat cell
## opens. Beyond: a save room, and the generator hall with its restart lever on the east
## wall. The breaker room is on the other side of that wall.
func _plant() -> void:
	var entry := _door(Vector3(7.5, 1.25, -30.5), TURN, true)
	entry.name = "Chamber03Entry"
	# Chamber 03, fallen in: panels and rubble everywhere, its own exit buried.
	for spot: Array in [[5.5, -41.5, 0.3], [9, -42, 1.1], [7, -38, 2.3], [5.5, -35.5, 0.8], [9.4, -34, 2.9]]:
		_place(PROPS + "fallen_panels.tscn", "Props", Vector3(spot[0], 0, spot[1]), Basis(Vector3.UP, spot[2]))
	for spot: Array in [[6.5, -42.5], [8, -40.5], [5, -39], [9.5, -37]]:
		_place(PROPS + "debris.tscn", "Props", Vector3(spot[0], 0, spot[1]), Basis(Vector3.UP, spot[0]))
	_place(PROPS + "crate.tscn", "Props", Vector3(7.5, 0, -42.4), Basis(Vector3.UP, 0.4))
	_place(PROPS + "crate.tscn", "Props", Vector3(8.4, 0, -41.8), Basis(Vector3.UP, -0.3))
	_place(PROPS + "growth.tscn", "Props", Vector3(10, 0, -40), Basis(Vector3.UP, 1.4))
	_light(Vector3(7.5, 0, -36), Color(0.85, 0.92, 1.0), 0.9, true)
	# The machinery past the gap: the guard post right by it, a frozen locker, then husks.
	var guard: CharacterModel = _place("res://scenes/characters/character_model.tscn", "Props", Vector3(13.2, 0, -42.2),
			Basis(Vector3.UP, 2.0))
	guard.look = CharacterModel.Look.HUSK
	guard.pose = CharacterModel.Pose.CORPSE
	guard.variation = 4
	_place(PROPS + "desk.tscn", "Props", Vector3(12.9, 0, -38.6), FACE_EAST)
	# (No pistol: there's one in the chapter, and it's on the body in the airlock.)
	var rounds := _place("res://scenes/items/pickup.tscn", "Placements", Vector3(12.6, 0.1, -41.1))
	rounds.item_id = "ammo"
	rounds.count = 4
	var locker := FrozenLocker.new()
	locker.name = "FrozenLocker"
	_add(locker, "Props", Vector3(12.9, 0, -44))
	for at in [Vector3(17.6, 0, -38.6), Vector3(17.8, 0, -42.6)]: # clear of both doors
		_place("res://scenes/enemies/enemy.tscn", "Placements", at, FACE_NORTH)
	for x in [13, 15, 17]:
		_place(PROPS + "pipes.tscn", "Props", Vector3(x, 0, -44))
	_place(PROPS + "piston.tscn", "Props", Vector3(18.4, 0, -40.5))
	_wall_lamp(Vector3(15.5, 0, -44), Color(1.0, 0.6, 0.35), 0.9)
	var hall_door := _door(Vector3(15.5, 1.25, -36.5), TURN, true)
	hall_door.name = "GeneratorHallDoor"
	_door(Vector3(15.5, 1.25, -44.5), TURN, true)
	_safe_room(ROOMS["PlantSafeRoom"], "PlantSafeRoom")
	# The generator hall: the machine down the middle, the restart console on the east wall.
	var gauge := PressureGauge.new()
	gauge.name = "PressureGauge"
	_add(gauge, "Props", Vector3(18.38, 0, -27), FACE_WEST)
	for z in [-33.0, -30.5, -24.5]:
		_place(PROPS + "piston.tscn", "Props", Vector3(14.5, 0, z))
		_place(PROPS + "piston.tscn", "Props", Vector3(16, 0, z))
	for spot in [Vector3(13, 0, -27.5), Vector3(13.6, 0, -28.4)]:
		_place(PROPS + "barrel.tscn", "Props", spot)
	for x in [13, 15, 17]:
		_place(PROPS + "pipes.tscn", "Props", Vector3(x, 0, -36))


## Puzzle 6, chamber 02: the exit wants a code no one in the chamber can see. The red
## paint on the north wall gives a frequency (unreadable to the Subject); the Visitor reads
## it off an old recording of this test in the CCTV archive. Tuned there, a numbers station
## in the chamber reads the code, and the Subject keys it in, off the partner channel.
func _chamber_02() -> void:
	var entry := _door(Vector3(-5.5, 1.25, -21.5), TURN, true)
	entry.name = "Chamber02Entry"
	var exit := _door(Vector3(4.5, 1.25, -27.5), Basis(), false)
	exit.name = "Chamber02Exit"
	exit.lock = Door.Lock.CODE
	exit.keep_on_reload = true
	# On a clean stretch of the decayed wall (its tissue patch falls at x = -2.5 here).
	var paint: WallText = _place("res://scenes/story/wall_text.tscn", "Story", Vector3(0.6, 1.45, -31.98))
	paint.name = "Chamber02Paint"
	paint.letter_size = 0.5
	var station := CodeStation.new()
	station.name = "Chamber02Station"
	station.paint = paint
	station.audible_range = 28.0
	_add(station, "Story", Vector3(-2.5, 1.5, -27))
	var keypad := _place("res://scenes/puzzles/symbol_code/keypad.tscn", "Props", Vector3(4, 0, -25.3), FACE_WEST)
	keypad.name = "Chamber02Keypad"
	keypad.prompt = "Use the release keypad"
	keypad.screen_text = "TEST 02\nRELEASE BY VOICE\nLISTEN"
	var code := SymbolCodePuzzle.new()
	code.name = "Chamber02Code"
	code.keypad = keypad
	code.display = station
	code.doors.append(exit)
	code.solved_lines.append("chamber02_done")
	_level_add(code)
	var archive := Marker3D.new()
	archive.name = "ArchiveTest02"
	var at := Vector3(0.8, 1.95, -28.6)
	_add(archive, "Story", at, Basis.looking_at(Vector3(0.6, 1.45, -32) - at, Vector3.UP))
	_light(Vector3(-2.5, 0, -28), Color(0.85, 0.92, 1.0), 1.6)
	_light(Vector3(8, 0, -27.5), Color(0.8, 0.9, 1.0), 0.8, true)
	_place(PROPS + "growth.tscn", "Props", Vector3(-8, 0, -30.5), Basis(Vector3.UP, 0.9))
	_place(PROPS + "fallen_panels.tscn", "Props", Vector3(2, 0, -30.8))
	_place(PROPS + "fallen_panels.tscn", "Props", Vector3(-7.5, 0, -24), Basis(Vector3.UP, 2.2))


## Puzzle 3, chamber 01: five plates under five glyphs only the Subject sees, an exit
## that opens when they're stepped in the chart's order, and a gap rotted through the west
## wall into the machinery behind (a side route; puzzle 4 sends the Subject in there).
func _chamber_01() -> void:
	var entry := _door(Vector3(-16.5, 1.25, -15.5), TURN, true)
	entry.name = "Chamber01Entry"
	var exit := _door(Vector3(-9.5, 1.25, -18.5), Basis(), false)
	exit.name = "Chamber01Exit"
	exit.lock = Door.Lock.CODE
	exit.keep_on_reload = true
	var puzzle := CalibrationPuzzle.new()
	puzzle.name = "Calibration"
	puzzle.exit = exit
	puzzle.spacing = 2.4
	puzzle.glyph_offset = Vector3(0, 1.7, -2.48)
	puzzle.solved_lines.append("calibration_done")
	_add(puzzle, "Props", Vector3(-17, 0, -24.5))
	_light(Vector3(-17, 0, -22), Color(0.85, 0.92, 1.0), 1.8)
	_light(Vector3(-13, 0, -18.5), Color(0.8, 0.9, 1.0), 0.8, true)
	# The rot: panels down by the gap, tissue grown through it.
	_place(PROPS + "fallen_panels.tscn", "Props", Vector3(-23.2, 0, -20.2), Basis(Vector3.UP, 0.7))
	_place(PROPS + "growth.tscn", "Props", Vector3(-23.8, 0, -21.5))
	_place(PROPS + "growth.tscn", "Props", Vector3(-26.8, 0, -21), Basis(Vector3.UP, 2.4))
	_place(PROPS + "fallen_panels.tscn", "Props", Vector3(-12, 0, -17.6))
	# Behind the wall: the machinery the chamber's panels hang from.
	for z in [-25.0, -22.0, -19.0]:
		_place(PROPS + "piston.tscn", "Props", Vector3(-27.4, 0, z))
	for z in [-26, -24, -22, -20, -18]:
		_place(PROPS + "pipes.tscn", "Props", Vector3(-25, 0, z), FACE_WEST)
	_wall_lamp(Vector3(-25.6, 0, -27), Color(1.0, 0.6, 0.35), 1.2)
	# Puzzle 4: the maintenance locker at the far end, the service key in front of it, and a
	# husk loose among the pistons between it and the gap.
	_place(PROPS + "lockers.tscn", "Props", Vector3(-26.6, 0, -26.75))
	var spare := _place("res://scenes/items/pickup.tscn", "Placements", Vector3(-26.6, 0.1, -25.6))
	spare.item_id = "ammo"
	spare.count = 4
	_place("res://scenes/enemies/enemy.tscn", "Placements", Vector3(-26.4, 0, -23.5))
	_light(Vector3(-6.5, 0, -19.5), Color(0.85, 0.92, 1.0), 1.2)


## Puzzle 2, the Visitor's half: the intake office is freezing; the door north to the
## security wing is frozen shut beside a dead heater that takes a heat cell (sent through
## the tube from the stores). Beyond it, a dark wing with a husk, and the security office
## behind a door that shuts itself.
func _heat() -> void:
	var iced := _door(Vector3(26.5, 1.25, 11.5), TURN, false)
	iced.name = "FrozenDoor"
	iced.lock = Door.Lock.ICE
	iced.keep_on_reload = false # it took a heat cell: it refreezes when the cell comes back
	var heater: Heater = _place("res://scenes/props/heater.tscn", "Props", Vector3(23.6, 0, 12))
	heater.name = "OfficeHeater"
	heater.doors.append(iced)
	heater.on_lines.append("heater_on")
	var tube: ItemTube = _place("res://scenes/items/item_tube.tscn", "Props", Vector3(16, 0, 15.6), FACE_EAST)
	tube.name = "OfficeTube"
	var stores_tube: ItemTube = level.get_node("Props/StoresTube")
	tube.partner = stores_tube
	stores_tube.partner = tube
	_pickup("medkit", Vector3(28.4, 0.1, 20.6))
	for room in ["IntakeOffice", "SecurityWing", "SecurityOffice"]:
		var r: Array = ROOMS[room]
		var cold := TemperatureZone.new()
		cold.name = room + "Cold"
		cold.warmth_rate = -0.6
		_add(cold, "Zones", Vector3((r[0] + r[1]) / 2.0, 1.5, (r[2] + r[3]) / 2.0))
		_add_box_shape(cold, Vector3(r[1] - r[0], 4, r[3] - r[2]))

	# The security wing: dark, one failing lamp, a husk, desks pushed into an island.
	var office_door := _door(Vector3(26.5, 1.25, 2.5), TURN, true)
	office_door.name = "SecurityOfficeDoor"
	_place(PROPS + "desk.tscn", "Props", Vector3(25.5, 0, 6.5), Basis(Vector3.UP, 0.3))
	_place(PROPS + "filing_cabinet.tscn", "Props", Vector3(27.2, 0, 7.4), Basis(Vector3.UP, -1.2))
	_place(PROPS + "lockers.tscn", "Props", Vector3(22.25, 0, 9.4), FACE_EAST)
	_place(PROPS + "dead_plant.tscn", "Props", Vector3(29.3, 0, 3.6))
	_place("res://scenes/enemies/enemy.tscn", "Placements", Vector3(23.5, 0, 4.2), FACE_NORTH)
	_light(Vector3(26, 0, 8), Color(1.0, 0.85, 0.6), 0.8, true)
	# The security office: the CCTV bank on the north wall between two desks, lockers, and
	# the maintenance notice naming the duct (puzzle 4).
	_place(PROPS + "desk.tscn", "Props", Vector3(21.5, 0, -5.5))
	_place(PROPS + "filing_cabinet.tscn", "Props", Vector3(29.4, 0, -1.2), FACE_WEST)
	_place(PROPS + "lockers.tscn", "Props", Vector3(20.25, 0, -1.5), FACE_EAST)
	_place(PROPS + "office_chair.tscn", "Props", Vector3(24, 0, -4.2), FACE_NORTH)
	_light(Vector3(24.5, 0, -3), Color(1.0, 0.85, 0.6), 1.4)
	var note := _place("res://scenes/story/document.tscn", "Story", Vector3(21.2, 0.81, -5.4))
	note.doc_id = "duct_note"
	# Duct M-2's key is kept here, with Security; the duct starts on the chamber side.
	_pickup("service_key", Vector3(22.6, 0.85, -5.4))
	_body_route()
	_records()
	_breakers()
	_ways_down()


## Puzzle 4, "The body": the CCTV shows the body in the airlock; the airlock is sealed
## from Intake, so the way in is duct M-2, behind a door in the security wing that takes
## the service key. The key is the Subject's to find (behind chamber 01) and send.
func _body_route() -> void:
	var cctv := CctvBank.new()
	cctv.name = "CctvBank"
	for feed: Array in [
			["AIRLOCK", Vector3(20.6, 2.3, 23.4), Vector3(22.5, 0.2, 28.6)],
			["INTAKE OFFICE", Vector3(16.6, 2.3, 12.6), Vector3(23.5, 0.5, 18)],
			["SECURITY WING", Vector3(29.4, 2.3, 10.4), Vector3(24.5, 0.5, 4.5)],
			["DUCT M-2", Vector3(13, 2.3, 4.6), Vector3(13.5, 0.3, 14)]]:
		var camera := Marker3D.new()
		camera.name = "Cam" + feed[0].replace(" ", "").replace("-", "")
		var at: Vector3 = feed[1]
		var target: Vector3 = feed[2]
		_add(camera, "Story", at, Basis.looking_at(target - at, Vector3.UP))
		cctv.cameras.append(camera)
		cctv.labels.append(feed[0])
	cctv.dead_labels.assign(["CHAMBER WING // TEST 01", "CHAMBER WING // TEST 02", "TEST CELL P-4"])
	cctv.archive.append(level.get_node("Story/ArchiveTest02"))
	cctv.archive_labels.append("ARCHIVE // TEST 02")
	_add(cctv, "Props", Vector3(24.3, 0, -5.38))
	var duct_door := _door(Vector3(-3.5, 1.25, 11.5), TURN, false)
	duct_door.name = "DuctDoor"
	duct_door.lock = Door.Lock.KEY
	duct_door.key_item = "service_key"
	for z in [10.0, 18.0]:
		_wall_lamp(Vector3(13.5, 0, z - 1.0), Color(1.0, 0.6, 0.35), 0.8)
	_wall_lamp(Vector3(16, 0, 4), Color(1.0, 0.6, 0.35), 0.9)
	_light(Vector3(15.5, 0, 26.5), Color(0.8, 0.85, 1.0), 0.7, true)
	for x in [13, 15, 17, 19]:
		_place(PROPS + "pipes.tscn", "Props", Vector3(x, 0, 4))
	_place(PROPS + "vent.tscn", "Props", Vector3(15, 0, 14), FACE_WEST)


## Puzzle 7, the Visitor's half: breaker room B, past the records listener: the coldest
## room yet, its heater dead (the Subject's second heat cell lights it, if it was sent), six
## breakers on the west wall, which is the generator hall's east wall. The restart needs
## both: PlantRestart joins the gauge and the panel. A save room beside it.
func _breakers() -> void:
	var door := _door(Vector3(25.5, 1.25, -20.5), TURN, true)
	door.name = "BreakerRoomDoor"
	_door(Vector3(30.5, 1.25, -28.5), Basis(), true)
	var panel := BreakerPanel.new()
	panel.name = "BreakerPanel"
	_add(panel, "Props", Vector3(20, 0, -27), FACE_EAST)
	var heater: Heater = _place("res://scenes/props/heater.tscn", "Props", Vector3(20, 0, -24.6), FACE_EAST)
	heater.name = "BreakerHeater"
	var r: Array = ROOMS["BreakerRoom"]
	var cold := TemperatureZone.new()
	cold.name = "BreakerRoomCold"
	cold.warmth_rate = -2.5
	_add(cold, "Zones", Vector3((r[0] + r[1]) / 2.0, 1.5, (r[2] + r[3]) / 2.0))
	_add_box_shape(cold, Vector3(r[1] - r[0], 4, r[3] - r[2]))
	for x in [22, 24, 26, 28]:
		_place(PROPS + "pipes.tscn", "Props", Vector3(x, 0, -32))
	_place(PROPS + "lockers.tscn", "Props", Vector3(29.75, 0, -23.5), FACE_WEST)
	_place(PROPS + "crate.tscn", "Props", Vector3(28.5, 0, -31))
	_safe_room(ROOMS["BreakerSafeRoom"], "BreakerSafeRoom")
	# Dark until the plant catches; a failing emergency lamp on each side till then.
	_light(Vector3(25, 0, -24), Color(0.8, 0.85, 1.0), 0.45, true)
	_light(Vector3(15.5, 0, -24), Color(0.8, 0.85, 1.0), 0.4, true)
	var plant := PlantRestart.new()
	plant.name = "PlantRestart"
	plant.gauge = level.get_node("Props/PressureGauge")
	plant.panel = panel
	plant.lights.append(_light(Vector3(25, 0, -28), Color(0.85, 0.92, 1.0), 2.0))
	plant.lights.append(_light(Vector3(15.5, 0, -30), Color(0.85, 0.92, 1.0), 2.0))
	plant.done_lines.append("plant_online")
	plant.vent_lines.append("plant_vented")
	_level_add(plant)


## Puzzle 8, "Ways down": once the plant catches, SectorPower brings sector 4 back a
## section at a time: the cold lifts (the Visitor's offices and the breaker room), the dark
## rooms light up, the dead doors open (a store on each side with supplies, and each side's
## way down), and the husks lying dormant behind them get up. The Subject takes the lift,
## the Visitor the stairwell; separately, and the chapter ends.
func _ways_down() -> void:
	var dark: Array[KitLight] = []
	var dead: Array[Door] = []
	# The Subject's lift, a husk lying in it.
	var lift_door := _door(Vector3(8.5, 1.25, -24.5), TURN, false)
	lift_door.name = "LiftDoor"
	dead.append(lift_door)
	var lift := WayDown.new()
	lift.name = "Lift"
	lift.role = "subject"
	lift.prompt = "Take the lift down"
	lift.line = "went_down_subject"
	lift.fatal = true # the Subject dies on the way down; chapter 2 wakes it somewhere deeper
	_add(lift, "Props", Vector3(8, 0, -20), FACE_NORTH)
	_sign("LIFT C-1 // DOWN ONLY", Vector3(8, 2.1, -20.03), FACE_NORTH)
	_dormant(Vector3(6.2, 0, -22.4))
	dark.append(_light(Vector3(8, 0, -22.5), Color(0.85, 0.92, 1.0), 1.2))
	# The generator hall's store.
	var store_door := _door(Vector3(15.5, 1.25, -21.5), TURN, false)
	store_door.name = "PowerStoreDoor"
	dead.append(store_door)
	_place(PROPS + "shelf.tscn", "Props", Vector3(15, 0, -18.25), FACE_NORTH)
	var rounds := _place("res://scenes/items/pickup.tscn", "Placements", Vector3(14, 0.1, -19.6))
	rounds.item_id = "ammo"
	rounds.count = 6
	_pickup("medkit", Vector3(16.2, 0.1, -19.6))
	dark.append(_light(Vector3(15, 0, -19.5), Color(0.85, 0.92, 1.0), 1.0))
	# The Visitor's stairwell, a husk lying at the top of it.
	var stair_door := _door(Vector3(25.5, 1.25, -32.5), TURN, false)
	stair_door.name = "StairwellDoor"
	dead.append(stair_door)
	var stairs := WayDown.new()
	stairs.name = "Stairwell"
	stairs.role = "visitor"
	stairs.prompt = "Go down the stairs"
	stairs.line = "went_down_visitor"
	stairs.walk_in = 0.9 # onto the top step (the black drop)
	_add(stairs, "Props", Vector3(25, 0, -38))
	var drop := MeshInstance3D.new()
	var drop_mesh := BoxMesh.new()
	drop_mesh.size = Vector3(2.4, 0.02, 1.6)
	drop.mesh = drop_mesh
	var black := StandardMaterial3D.new()
	black.albedo_color = Color.BLACK
	drop.material_override = black
	_add(drop, "Props", Vector3(25, 0.02, -37.1))
	_sign("STAIRWELL C // LEVELS -1 TO -6", Vector3(25, 2.1, -37.97), Basis())
	_dormant(Vector3(23, 0, -35.5))
	dark.append(_light(Vector3(25, 0, -35.5), Color(1.0, 0.85, 0.6), 1.0))
	# The security wing's store.
	var wing_store := _door(Vector3(30.5, 1.25, 5.5), Basis(), false)
	wing_store.name = "SecurityStoreDoor"
	dead.append(wing_store)
	_place(PROPS + "shelf.tscn", "Props", Vector3(33, 0, 3.25))
	var wing_rounds := _place("res://scenes/items/pickup.tscn", "Placements", Vector3(32, 0.1, 4.6))
	wing_rounds.item_id = "ammo"
	wing_rounds.count = 6
	_pickup("medkit", Vector3(33.8, 0.1, 4.6))
	dark.append(_light(Vector3(33, 0, 5.5), Color(1.0, 0.85, 0.6), 1.0))
	for door in dead:
		door.lock = Door.Lock.POWER
		door.keep_on_reload = true
	var power := SectorPower.new()
	power.name = "SectorPower"
	power.plant = level.get_node("PlantRestart")
	for zone in ["IntakeOfficeCold", "SecurityWingCold", "SecurityOfficeCold", "BreakerRoomCold"]:
		power.cold.append(level.get_node("Zones/" + zone))
	power.lights = dark
	power.doors = dead
	power.lines.append("power_returning")
	_level_add(power)


## A husk lying dormant until the power comes back (SectorPower wakes "sector4").
func _dormant(at: Vector3) -> void:
	var husk := _place("res://scenes/enemies/enemy.tscn", "Placements", at, Basis(Vector3.UP, at.x))
	husk.wake_tag = "sector4"


func _sign(text: String, at: Vector3, basis: Basis) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 22
	label.pixel_size = 0.004
	label.modulate = Color(0.9, 0.82, 0.6)
	label.outline_size = 0
	_add(label, "Story", at, basis)


## Puzzle 5, "Records": shelves in rows that make you zigzag to the far corner, where the
## power schematic is filed (puzzle 7 needs it). A listener stands among them: blind, but
## it hunts any radio that's on, through walls, from the security office too. The Visitor
## reads the floor plan by the door, switches off (no partner, no map, no HUD), and crosses
## from memory. The Subject is warned (the register, ZP-SYS) and can only wait.
func _records() -> void:
	var door := _door(Vector3(28.5, 1.25, -6.5), TURN, true)
	door.name = "RecordsDoor"
	var plan := _place("res://scenes/map/floor_plan.tscn", "Story", Vector3(25.9, 0, -6))
	plan.area = "records"
	plan.area_name = "Records"
	var warning := Label3D.new()
	warning.name = "RecordsSign"
	warning.text = "RECORDS\nACOUSTIC UNIT IN USE\nRADIOS OFF BEYOND THIS DOOR"
	warning.font_size = 22
	warning.pixel_size = 0.004
	warning.modulate = Color(0.9, 0.82, 0.6)
	warning.outline_size = 0
	_add(warning, "Story", Vector3(25.9, 2.18, -5.97))
	# Rows of shelving, each open at one end, alternating: a zigzag north and west.
	for row: Array in [[-10.0, [19, 21, 23, 25]], [-13.0, [23, 25, 27, 29, 31]], [-16.0, [19, 21, 23, 25, 27]]]:
		for x: int in row[1]:
			_place(PROPS + "shelf.tscn", "Props", Vector3(x, 0, row[0]))
	for x in [23.5, 24.6]:
		_place(PROPS + "filing_cabinet.tscn", "Props", Vector3(x, 0, -19.7))
	_place(PROPS + "desk.tscn", "Props", Vector3(19.6, 0, -19.4))
	# Up the stairs in the far corner, the archive loft: the power schematic is filed there.
	# The listener can't follow (the storeys share no navigation).
	var up := Stairs.new()
	up.name = "RecordsStairsUp"
	_add(up, "Props", Vector3(32, 0, -18.5), FACE_WEST)
	var down := Stairs.new()
	down.name = "RecordsStairsDown"
	down.up = false
	_add(down, "Props", Vector3(34, Kit.CELL.y, -18.5), FACE_EAST)
	up.other = down
	down.other = up
	var loft: Array = UPPER_ROOMS["RecordsLoft"]
	for x in [36.0, 38.0]:
		_place(PROPS + "shelf.tscn", "Props", Vector3(x, Kit.CELL.y, loft[2] + 0.25))
	_place(PROPS + "desk.tscn", "Props", Vector3(37.5, Kit.CELL.y, loft[3] - 1.4), FACE_NORTH)
	var schematic := _place("res://scenes/story/document.tscn", "Story", Vector3(37.6, Kit.CELL.y + 0.81, loft[3] - 1.5))
	schematic.doc_id = "power_schematic"
	for x in [35.2, 35.8]:
		_place(PROPS + "filing_cabinet.tscn", "Props", Vector3(x, Kit.CELL.y, loft[3] - 0.3), FACE_NORTH)
	_light(Vector3(37, Kit.CELL.y, -16), Color(1.0, 0.85, 0.6), 0.9, true)
	_place("res://scenes/enemies/listener.tscn", "Placements", Vector3(25, 0, -14.5))
	_light(Vector3(29, 0, -9), Color(1.0, 0.85, 0.6), 0.6, true)
	_light(Vector3(20, 0, -18), Color(1.0, 0.85, 0.6), 0.5)
	var trigger := StoryTrigger.new()
	trigger.name = "RecordsWarning"
	trigger.line_ids.append("records_warning")
	trigger.who = StoryTrigger.Who.VISITOR
	_add(trigger, "Story", Vector3(26, 1, -2.5))
	_add_box_shape(trigger, Vector3(10, 2, 7))


func _pickup(item: String, at: Vector3) -> void:
	var pickup := _place("res://scenes/items/pickup.tscn", "Placements", at)
	pickup.item_id = item


## The snowfield: marker posts (placed with the network), the whiteout, the cold, and the
## beacon calling on the contact channel.
func _outside() -> void:
	var field: Array = ROOMS["Snowfield"]
	var size := Vector3(field[1] - field[0], 4, field[3] - field[2])
	var centre := Vector3((field[0] + field[1]) / 2.0, 1.5, (field[2] + field[3]) / 2.0)
	var whiteout := EnvironmentZone.new()
	whiteout.name = "Whiteout"
	whiteout.environment = load("res://kit/whiteout_environment.tres")
	whiteout.ambience = "amb_whiteout"
	whiteout.footsteps = "step_snow"
	whiteout.radio_interference = 0.2
	whiteout.lethal = false
	whiteout.snowfall = true
	_add(whiteout, "Zones", centre)
	_add_box_shape(whiteout, size)
	var cold := TemperatureZone.new()
	cold.name = "Cold"
	cold.warmth_rate = -1.2
	_add(cold, "Zones", centre)
	_add_box_shape(cold, size)

	var beacon := ContactBeacon.new()
	beacon.name = "ContactBeacon"
	beacon.frequency = CONTACT_CHANNEL
	beacon.sound = "radio_beacon"
	_add(beacon, "Story", Vector3(22.5, 2, 26))
	var scope: RadarScope = level.get_node("Props/RadarScope")
	scope.beacon = beacon
	scope.field = Rect2(field[0], field[2], field[1] - field[0], field[3] - field[2])
	scope.entrance = Vector2(22.5, 29)
	scope.scope_range = 50.0
	scope.crush = level.get_node("Story/EntranceCrush")


## A safe room, furnished the same everywhere: the save terminal with its pod and an item
## box on the north wall, the sign, a radiator and a bench on the east wall, one warm lamp,
## and the SafeRoom zone over the floor (a haven no enemy enters).
func _safe_room(r: Array, room_name: String) -> SaveTerminal:
	var x0: float = r[0]
	var x1: float = r[1]
	var z0: float = r[2]
	var z1: float = r[3]
	var terminal: SaveTerminal = _place("res://scenes/props/save_terminal.tscn", "Props", Vector3(x0 + 0.9, 0, z0))
	terminal.name = room_name + "Terminal"
	_place("res://scenes/props/item_box.tscn", "Props", Vector3(x0 + 3.6, 0, z0 + 0.05))
	_place(PROPS + "safe_sign.tscn", "Props", Vector3(x1 - 1.0, 0, z0))
	_place(PROPS + "radiator.tscn", "Props", Vector3(x1, 0, z0 + 1.6), FACE_WEST)
	_place(PROPS + "bench.tscn", "Props", Vector3(x1 - 0.3, 0, z1 - 2.4), FACE_WEST)
	_light(Vector3((x0 + x1) / 2.0, 0, (z0 + z1) / 2.0 - 0.5), Color(1.0, 0.72, 0.45), 1.8)
	var haven := _place("res://scenes/zones/safe_room.tscn", "Zones", Vector3((x0 + x1) / 2.0, 0, (z0 + z1) / 2.0))
	haven.name = room_name
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, 3, z1 - z0)
	haven.get_node("CollisionShape3D").shape = box
	level.set_editable_instance(haven, true)
	return terminal


## The MAP: every room in an area, revealed by that area's floor plan. Each side has its
## own plan; the ducts and the machinery behind the chambers are on nobody's.
func _map() -> void:
	var areas := {
		"chamber_wing": {"PodCell": "TEST CELL", "Passage": "", "RadarControl": "RADAR", "SubjectSafeRoom": "SAFE",
				"Stores": "STORES", "StoresBack": "", "Chamber01": "TEST 01", "Chamber01Exit": "",
				"Chamber02": "TEST 02", "Chamber02Exit": "",
				"Chamber03": "TEST 03", "GeneratorHall": "GENERATOR", "PlantSafeRoom": "SAFE",
				"Lift": "LIFT", "PowerStore": "STORE"},
		"intake_wing": {"Airlock": "AIRLOCK", "IntakeOffice": "INTAKE", "VisitorSafeRoom": "SAFE",
				"SecurityWing": "", "SecurityOffice": "SECURITY",
				"BreakerRoom": "BREAKERS B", "BreakerSafeRoom": "SAFE",
				"Stairwell": "STAIRS", "SecurityStore": "STORE"},
		"records": {"Records": "RECORDS", "RecordsLoft": "ARCHIVE"},
	}
	for area: String in areas:
		for room: String in areas[area]:
			var upper := UPPER_ROOMS.has(room)
			var r: Array = UPPER_ROOMS[room] if upper else ROOMS[room]
			var map_room := MapRoom.new()
			map_room.name = "Map" + room
			map_room.size = Vector2(r[1] - r[0], r[3] - r[2])
			map_room.label = areas[area][room]
			map_room.area = area
			map_room.floor = 1 if upper else 0
			_add(map_room, "Story", Vector3((r[0] + r[1]) / 2.0, Kit.CELL.y if upper else 0.0, (r[2] + r[3]) / 2.0))
	var chamber_plan := _place("res://scenes/map/floor_plan.tscn", "Story", Vector3(-12, 0, 8.6), FACE_EAST)
	chamber_plan.area = "chamber_wing"
	chamber_plan.area_name = "Chamber wing"
	var intake_plan := _place("res://scenes/map/floor_plan.tscn", "Story", Vector3(16, 0, 19.6), FACE_EAST)
	intake_plan.area = "intake_wing"
	intake_plan.area_name = "Intake wing"


## Every room black but the ones you can reach without a door (RoomShroud): one shroud per
## room, indoors, each in the zone of rooms it connects to through openings and gaps.
func _shroud() -> void:
	var zones := _door_zones(0)
	for room: String in ROOMS:
		if room == "Snowfield":
			continue
		var r: Array = ROOMS[room]
		var shroud := RoomShroud.new()
		shroud.name = "Shroud" + room
		shroud.size = Vector2(r[1] - r[0], r[3] - r[2])
		shroud.zone = "z%d" % zones.get(Vector2i(r[0], r[2]), -1)
		_add(shroud, "Story", Vector3((r[0] + r[1]) / 2.0, 0, (r[2] + r[3]) / 2.0))
	for room: String in UPPER_ROOMS:
		var r: Array = UPPER_ROOMS[room]
		var shroud := RoomShroud.new()
		shroud.name = "Shroud" + room
		shroud.size = Vector2(r[1] - r[0], r[3] - r[2])
		shroud.floor = 1
		shroud.zone = "u%d" % _door_zones(1).get(Vector2i(r[0], r[2]), -1)
		_add(shroud, "Story", Vector3((r[0] + r[1]) / 2.0, 0, (r[2] + r[3]) / 2.0))


## Which open area every walkable cell of a storey belongs to (cell -> area number): flooded
## through floors, with every door's cells as walls. Rooms in one area need no door between.
func _door_zones(storey: int) -> Dictionary:
	var grid: LevelGrid = level.get_node("LevelGrid")
	var open := {}
	for cell in grid.get_used_cells():
		if cell.y == storey and not grid.mesh_library.get_item_name(grid.get_cell_item(cell)).begins_with("wall_"):
			open[Vector2i(cell.x, cell.z)] = true
	for door: Node3D in level.get_node("Doors").get_children():
		for k in [-1, 0, 1]:
			var at: Vector3 = door.position + door.transform.basis.z * k
			open.erase(Vector2i(floori(at.x), floori(at.z)))
	var zone_of := {}
	var next := 0
	for start: Vector2i in open:
		if zone_of.has(start):
			continue
		var frontier: Array[Vector2i] = [start]
		zone_of[start] = next
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near: Vector2i = cell + step
				if open.has(near) and not zone_of.has(near):
					zone_of[near] = next
					frontier.append(near)
		next += 1
	return zone_of


## One camera zone per room, sized to it. The passage and the snowfield get none (the
## camera follows; the Visitor is in first person outside anyway).
func _frame() -> void:
	for room: String in ROOMS:
		if room in ["Passage", "Snowfield", "DuctNorth", "DuctWest", "DuctSouth", "ServiceRun"]:
			continue
		var r: Array = ROOMS[room]
		var zone := _place("res://scenes/kit/camera_zone.tscn", "CameraZones",
				Vector3((r[0] + r[1]) / 2.0, 1.5, (r[2] + r[3]) / 2.0))
		zone.name = room
		var shape := BoxShape3D.new()
		shape.size = Vector3(r[1] - r[0], 3, r[3] - r[2])
		zone.get_node("CollisionShape3D").shape = shape
		level.set_editable_instance(zone, true)
	for room: String in UPPER_ROOMS:
		var r: Array = UPPER_ROOMS[room]
		var zone := _place("res://scenes/kit/camera_zone.tscn", "CameraZones",
				Vector3((r[0] + r[1]) / 2.0, Kit.CELL.y + 1.5, (r[2] + r[3]) / 2.0))
		zone.name = room
		var shape := BoxShape3D.new()
		shape.size = Vector3(r[1] - r[0], 3, r[3] - r[2])
		zone.get_node("CollisionShape3D").shape = shape
		level.set_editable_instance(zone, true)


func _door(at: Vector3, basis: Basis, manual: bool) -> Door:
	var door: Door = _place("res://scenes/props/door.tscn", "Doors", at, basis)
	door.manual = manual
	return door


func _light(at: Vector3, color: Color, energy: float, flicker := false) -> KitLight:
	var lamp := _place(PROPS + "ceiling_light.tscn", "Lights", at)
	var light: KitLight = lamp.get_node("Light")
	light.light_color = color
	light.light_energy = energy
	light.flicker = flicker
	level.set_editable_instance(lamp, true)
	return light


func _wall_lamp(at: Vector3, color: Color, energy: float) -> void:
	var lamp := _place(PROPS + "wall_lamp.tscn", "Lights", at)
	var light: KitLight = lamp.get_node("Light")
	light.light_color = color
	light.light_energy = energy
	level.set_editable_instance(lamp, true)


func _place(path: String, parent: String, at: Vector3, basis := Basis()) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate()
	_add(node, parent, at, basis)
	return node


func _add(node: Node3D, parent: String, at: Vector3, basis := Basis()) -> void:
	level.get_node(parent).add_child(node, true)
	node.owner = level
	node.transform = Transform3D(basis, at)


func _level_add(node: Node) -> void:
	level.add_child(node, true)
	node.owner = level


func _add_box_shape(area: Area3D, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	collision.owner = level

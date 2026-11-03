class_name Kit
## Measurements every level is built to. Rooms, doors and props all assume these, so they
## fit together and read the same from the top-down camera. See docs/level_kit.md.

## One grid cell: 1 m square, one storey (floor to ceiling line) high.
const CELL := Vector3(1.0, 2.5, 1.0)
const WALL_HEIGHT := 2.5
## Door openings are this many cells wide (door.tscn is 3 m).
const DOOR_WIDTH := 3
## Narrowest corridor: room for a player to pass an enemy, and for the camera to frame it.
const MIN_CORRIDOR := 3

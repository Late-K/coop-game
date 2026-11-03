class_name SafeRoom
extends Area3D
## A save room's haven: nothing can hurt you inside one. Put safe_room.tscn in **Zones**
## over the save room and size its box to the room's floor (not the doorway).
## - Enemies never walk in. Anyone who reaches one is lost to them: a chasing enemy gives
##   up at the door and wanders back to where it started.
## - Noises made inside don't carry out, and listeners can't hear a radio in one.
## - The Visitor warms up here, whatever cold zones overlap it.
## - Its own calm ambience, for the local player standing inside.
## Lights and the heater are the room's own (level design): always lit, always warm.

## Warmth per second inside (at least this, however cold the area around it).
@export var warmth_rate := 8.0
## Background loop while inside (a sound name, see Sound).
@export var ambience := "amb_safe"

var _box := AABB()


## True when `world` is inside any safe room.
static func covers(tree: SceneTree, world: Vector3) -> bool:
	for room: SafeRoom in tree.get_nodes_in_group("safe_rooms"):
		if room.contains(world):
			return true
	return false


func _init() -> void:
	collision_layer = TemperatureZone.ZONE_LAYER
	collision_mask = 0
	monitoring = false


func _ready() -> void:
	add_to_group("safe_rooms")
	for child in get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			_box = AABB(child.position - child.shape.size / 2.0, child.shape.size)
			return


func contains(world: Vector3) -> bool:
	return _box.has_volume() and _box.has_point(to_local(world))

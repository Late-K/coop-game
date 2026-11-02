class_name EnvironmentZone
extends Area3D
## Swaps the look (fog, light, colour) for the local player while they stand inside,
## e.g. a whiteout outdoors. Only that player's cameras change; the partner keeps theirs.

@export var environment: Environment


func _init() -> void:
	collision_layer = TemperatureZone.ZONE_LAYER
	collision_mask = 0
	monitoring = false

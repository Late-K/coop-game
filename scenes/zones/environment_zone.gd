class_name EnvironmentZone
extends Area3D
## Changes how an area looks and sounds for the local player while they stand inside,
## e.g. the whiteout: fog, wind, snow underfoot. Only that player is affected; the
## partner keeps their own. Leave a field empty to keep the level's default.

## Fog, light and colour for this player's cameras.
@export var environment: Environment
## Background loop (a sound name, see Sound), e.g. "amb_whiteout".
@export var ambience := ""
## Footstep sound for anyone walking here, e.g. "step_snow".
@export var footsteps := ""


func _init() -> void:
	collision_layer = TemperatureZone.ZONE_LAYER
	collision_mask = 0
	monitoring = false

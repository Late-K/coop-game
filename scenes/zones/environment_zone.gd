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
## Radio static and drop-outs while standing here (0 clear, 1 unusable). The worse of the
## two players' spots wins, for both of them.
@export_range(0.0, 1.0) var radio_interference := 0.0
## Driving snow around whoever stands here (the blizzard outside).
@export var snowfall := false
## False where nothing can kill yet (outside, before the airlock): dying here is a collapse
## instead, and the player wakes at the nearest recovery point (a lit lamp). No reload.
@export var lethal := true


func _init() -> void:
	collision_layer = TemperatureZone.ZONE_LAYER
	collision_mask = 0
	monitoring = false

class_name TemperatureZone
extends Area3D
## Changes the warmth of players standing inside, in warmth per second:
## negative for cold (drafts, breached rooms), positive for heat (heaters, vents).
## Overlapping zones add up. Only characters that feel cold are affected.

const ZONE_LAYER := 32 # physics layer 6, "zones"

@export var warmth_rate := -2.0
## Inactive zones do nothing until something (a puzzle, a heater) calls set_active(true).
@export var active := true


func _init() -> void:
	collision_layer = ZONE_LAYER
	collision_mask = 0
	monitoring = false


func _ready() -> void:
	monitorable = active


func set_active(value: bool) -> void:
	active = value
	set_deferred("monitorable", value)

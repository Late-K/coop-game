class_name CameraZone
extends Area3D
## While the local player stands inside, the top-down camera frames this zone instead of
## following the player: the room becomes a fixed composition the character moves through,
## as in Signalis. The framing point is the zone's own position plus `focus_offset`, seen
## from `distance` metres so the whole room (and everything in it) fits on screen.

@export var focus_offset := Vector3.ZERO
@export var distance := Player.CAMERA_DISTANCE


func _init() -> void:
	collision_layer = TemperatureZone.ZONE_LAYER
	collision_mask = 0
	monitoring = false


func focus_point() -> Vector3:
	return global_position + focus_offset

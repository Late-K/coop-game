class_name CameraZone
extends Area3D
## While the local player stands inside, the top-down camera frames this zone instead of
## following the player: the room becomes a fixed composition the character moves through,
## as in Signalis. The framing point is the zone's own position plus `focus_offset`, seen
## from `distance` metres so the whole room (and everything in it) fits on screen.
##
## With `fit_to_shape` (the kit's camera_zone.tscn), the distance is worked out from the
## zone's box: draw the box over the room and the whole room fits.

@export var focus_offset := Vector3.ZERO
@export var distance := Player.CAMERA_DISTANCE
## Set `distance` from the size of the first box CollisionShape3D child.
@export var fit_to_shape := false


func _init() -> void:
	collision_layer = TemperatureZone.ZONE_LAYER
	collision_mask = 0
	monitoring = false


func _ready() -> void:
	if not fit_to_shape:
		return
	for child in get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			distance = framing_distance(child.shape.size.x, child.shape.size.z)
			return


func focus_point() -> Vector3:
	return global_position + focus_offset


## Distance that fits a room `width` x `depth` metres on screen. The camera looks down 60
## degrees with a 32 degree vertical field of view (54 horizontal): a room L deep appears
## about 0.866 L tall plus 1.25 m of its far wall, and about 40% of the screen height is
## free for it once letterbox, HUD and subtitles are counted.
static func framing_distance(width: float, depth: float) -> float:
	var fit_width := width / 0.866
	var fit_depth := (0.866 * depth + 1.25) / 0.40
	return snappedf(maxf(16.0, maxf(fit_width, fit_depth)), 0.1)

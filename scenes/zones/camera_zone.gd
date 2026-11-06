class_name CameraZone
extends Area3D
## No longer read by the player's camera, which now frames the room it's in from the
## room itself (Player._framed); kept for the kit's sample level.
##
## While the local player stands inside, the top-down camera frames this zone instead of
## following the player: the room becomes a fixed composition the character moves through.
## The framing point is the zone's own position plus `focus_offset`, seen from `distance`
## metres and `pitch` degrees down, so the whole room (and everything in it) fits on screen.
## Moving from one zone to the next is a cut, not a glide (Player._update_camera).
##
## With `fit_to_shape` (the kit's camera_zone.tscn), the distance is worked out from the
## zone's box and the pitch: draw the box over the room and the whole room fits.

@export var focus_offset := Vector3.ZERO
@export var distance := Player.CAMERA_DISTANCE
## How steeply the camera looks down: 90 straight down, lower is more oblique (a tight
## corridor, a small room seen across), higher is more of a plan (a big hall).
@export_range(35.0, 80.0, 1.0) var pitch := Player.CAMERA_PITCH
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
			distance = framing_distance(child.shape.size.x, child.shape.size.z, pitch)
			return


func focus_point() -> Vector3:
	return global_position + focus_offset


## Distance that fits a room `width` x `depth` metres on screen, looking down `pitch`
## degrees with a 32 degree vertical field of view (54 horizontal): a room L deep appears
## about sin(pitch) L tall plus cos(pitch) of its far wall, and about 40% of the screen
## height is free for it once letterbox, HUD and subtitles are counted.
static func framing_distance(width: float, depth: float, pitch_degrees := Player.CAMERA_PITCH) -> float:
	var p := deg_to_rad(pitch_degrees)
	var fit_width := width / 0.866
	var fit_depth := (sin(p) * depth + Kit.WALL_HEIGHT * cos(p)) / 0.40
	return snappedf(maxf(12.0, maxf(fit_width, fit_depth)), 0.1)

// The cutaway: the main camera shows only the area the local player is in, whole, as an open
// diorama in black (Cutaway, scenes/kit/cutaway.gd, builds the map; the local player sets it
// whenever the area changes, in the black of a door's fade).
// `cutaway_mask`: one pixel per grid cell (see Cutaway): KEEP drawn; WALL_ROW, a near wall,
// gone down to the floor (a door keeps its threshold); IN_FRONT, everything cleared, however
// tall, black boxes too; OUTSIDE (and off the map), no world geometry at all.
// `cutaway_area`: x, z of the map's first cell in the world, the area's floor height, and
// whether it's on. `cutaway_camera`: the main camera's position: other cameras (CCTV) see
// the world uncut. What's cleared shows only black, never another room.
global uniform sampler2D cutaway_mask;
global uniform vec4 cutaway_area;
global uniform vec3 cutaway_camera;

// True where this fragment at `world`, drawn by a camera at `camera`, is cut away. `box`:
// it's a dark room's black box, which only the area's front is cut out of.
bool cutaway_cut(vec3 world, vec3 camera, bool box) {
	if (cutaway_area.w < 0.5 || distance(camera, cutaway_camera) > 0.5) {
		return false;
	}
	ivec2 size = textureSize(cutaway_mask, 0);
	ivec2 cell = ivec2(floor(vec2(world.x - cutaway_area.x, world.z - cutaway_area.y)));
	float mark = 0.0;
	if (cell.x >= 0 && cell.y >= 0 && cell.x < size.x && cell.y < size.y) {
		mark = texelFetch(cutaway_mask, cell, 0).r;
	}
	if (mark > 0.9) {
		return false; // the area
	}
	if (mark > 0.5) {
		return world.y > cutaway_area.z - 0.5; // in front: everything
	}
	if (mark > 0.2) {
		// the near wall, not its threshold (nor anything a storey above it)
		return world.y > cutaway_area.z + 0.02 && world.y < cutaway_area.z + 3.4;
	}
	return !box; // outside: nothing of the world (dark rooms keep their black boxes)
}

// The black box over a dark room (RoomShroud): solid black, never faded or see-through, cut
// only with the near wall of the room the player is in (cutaway), where it reaches into it.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

#include "res://shaders/cutaway.gdshaderinc"

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (cutaway_cut(world, INV_VIEW_MATRIX[3].xyz, true)) {
		discard;
	}
	ALBEDO = vec3(0.0);
}

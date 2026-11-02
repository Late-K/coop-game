// Applied to the low-res game view as it is scaled up to the window:
// reduce colour depth (PS1: 15-bit, 32 levels per channel) and hide the banding
// with a 4x4 ordered dither aligned to the big pixels.
shader_type canvas_item;

uniform float color_levels = 32.0;
uniform float dither_strength = 1.0;
uniform vec2 resolution = vec2(480.0, 270.0);

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	ivec2 cell = ivec2(floor(UV * resolution)) % 4;
	float threshold = BAYER[cell.y * 4 + cell.x] / 16.0 - 0.5;
	color.rgb += threshold * dither_strength / color_levels;
	color.rgb = floor(color.rgb * (color_levels - 1.0) + 0.5) / (color_levels - 1.0);
	COLOR = color;
}

// Applied to the low-res game view as it is scaled up to the window:
// reduce colour depth (PS1: 15-bit, 32 levels per channel) and hide the banding
// with a 4x4 ordered dither aligned to the big pixels. A vignette darkens the edges.
shader_type canvas_item;

uniform float color_levels = 32.0;
uniform float dither_strength = 1.0;
uniform vec2 resolution = vec2(480.0, 270.0);
uniform float vignette = 0.6;
// Condition, instead of HUD bars: a red edge as health falls, a frost-blue one as cold sets in.
uniform float hurt = 0.0;
uniform float cold = 0.0;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec2 from_center = (UV - 0.5) * vec2(resolution.x / resolution.y, 1.0);
	color.rgb *= mix(1.0, smoothstep(0.95, 0.3, length(from_center)), vignette);
	float edge = smoothstep(0.45, 0.95, length(from_center));
	color.rgb = mix(color.rgb, vec3(0.4, 0.02, 0.02), edge * hurt * 0.75);
	color.rgb = mix(color.rgb, vec3(0.6, 0.75, 0.9), edge * cold * 0.35);
	ivec2 cell = ivec2(floor(UV * resolution)) % 4;
	float threshold = BAYER[cell.y * 4 + cell.x] / 16.0 - 0.5;
	color.rgb += threshold * dither_strength / color_levels;
	color.rgb = floor(color.rgb * (color_levels - 1.0) + 0.5) / (color_levels - 1.0);
	COLOR = color;
}

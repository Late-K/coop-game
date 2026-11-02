// Shared PS1-style surface: vertices snap to the low-res pixel grid (the wobble),
// textures are sampled nearest and warp without perspective correction (affine).
// Both effects switch off when the global `retro_resolution` is zero (F2 in game).
// Retro (autoload) swaps StandardMaterial3Ds for this and copies their parameters.

global uniform vec2 retro_resolution;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float metallic = 0.0;
uniform float roughness = 1.0;
uniform vec2 uv_scale = vec2(1.0);

varying vec3 affine_uv;

void vertex() {
	UV *= uv_scale;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (retro_resolution.x > 0.0) {
		vec2 half_resolution = retro_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * half_resolution) / half_resolution * clip.w;
	}
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = retro_resolution.x > 0.0 ? affine_uv.xy / affine_uv.z : UV;
	ALBEDO = albedo_color.rgb * texture(albedo_texture, uv).rgb;
	EMISSION = emission_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}

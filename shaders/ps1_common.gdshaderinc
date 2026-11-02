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
// Upward-facing surfaces render pure black: the tops of solid walls vanish into the void,
// so rooms read as lit dioramas in darkness (as in Signalis / Undertale). Set per material
// with the "retro_black_tops" meta; pillars a puzzle needs to be seen from above leave it off.
uniform bool black_tops = false;
// World-mapped textures (StandardMaterial3D "uv1 world triplanar"): CSG rooms have no useful
// UVs, so floors take albedo_texture laid out on the ground at uv_scale repeats per metre,
// and walls take wall_texture (falls back to albedo_texture): uv_scale.x repeats per metre
// along the wall, stretched once over wall_height from floor to top.
uniform bool world_uv = false;
uniform float wall_height = 2.5;
uniform bool has_wall_texture = false;
uniform sampler2D wall_texture : source_color, filter_nearest, repeat_enable, hint_default_white;

varying vec3 affine_uv;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	UV *= uv_scale;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (retro_resolution.x > 0.0) {
		vec2 half_resolution = retro_resolution * 0.5;
		clip.xy = round(clip.xy / clip.w * half_resolution) / half_resolution * clip.w;
	}
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec3 texel;
	if (world_uv) {
		vec3 n = abs(world_normal);
		if (n.y >= n.x && n.y >= n.z) {
			texel = texture(albedo_texture, world_position.xz * uv_scale).rgb;
		} else {
			float along = n.x > n.z ? world_position.z : world_position.x;
			vec2 wall_uv = vec2(along * uv_scale.x, (wall_height - world_position.y) / wall_height);
			texel = has_wall_texture ? texture(wall_texture, wall_uv).rgb : texture(albedo_texture, wall_uv).rgb;
		}
	} else {
		vec2 uv = retro_resolution.x > 0.0 ? affine_uv.xy / affine_uv.z : UV;
		texel = texture(albedo_texture, uv).rgb;
	}
	ALBEDO = albedo_color.rgb * texel;
	EMISSION = emission_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	if (black_tops && world_normal.y > 0.7) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.0);
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
	}
}

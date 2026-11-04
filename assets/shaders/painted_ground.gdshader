shader_type spatial;

// World-space metres keep the brush size stable when PlaneMesh.size changes.
varying vec2 ground_position;

group_uniforms Palette;
uniform vec4 base_color : source_color = vec4(0.24, 0.29, 0.35, 1.0);
uniform vec4 violet_color : source_color = vec4(0.30, 0.29, 0.36, 1.0);
uniform vec4 rose_color : source_color = vec4(0.34, 0.30, 0.35, 1.0);
uniform vec4 sage_color : source_color = vec4(0.26, 0.32, 0.33, 1.0);

group_uniforms Patches;
uniform float patch_scale : hint_range(4.0, 40.0, 0.5) = 8.5;
uniform float coverage : hint_range(0.0, 1.0, 0.01) = 0.53;
uniform float edge_softness : hint_range(0.002, 0.12, 0.001) = 0.010;
uniform float warp_strength : hint_range(0.0, 1.5, 0.01) = 0.35;
uniform float edge_irregularity : hint_range(0.0, 0.12, 0.001) = 0.05;
uniform float calm_amount : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float pattern_seed : hint_range(0.0, 100.0, 1.0) = 7.0;
uniform vec2 pattern_offset = vec2(0.0);

group_uniforms Surface;
uniform float surface_roughness : hint_range(0.0, 1.0, 0.01) = 0.95;
uniform float surface_specular : hint_range(0.0, 1.0, 0.01) = 0.12;

group_uniforms DistributionMask;
uniform bool use_distribution_mask = false;
// Data texture: no source_color conversion. White allows paint, black keeps base.
uniform sampler2D distribution_mask : hint_default_white, filter_linear, repeat_disable;
uniform float mask_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
group_uniforms;

float hash_value(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float broad_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 blend = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash_value(cell), hash_value(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash_value(cell + vec2(0.0, 1.0)), hash_value(cell + vec2(1.0)), blend.x),
		blend.y
	);
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = (ground_position + pattern_offset) / max(patch_scale, 0.001);
	p += vec2(pattern_seed * 3.17, pattern_seed * -1.93);
	vec2 warp = vec2(broad_noise(p * 1.3 + vec2(13.2, 7.9)),
		broad_noise(p * 1.3 + vec2(-8.4, 21.6))) * 2.0 - 1.0;
	vec2 brush = p + warp * warp_strength;
	float field = broad_noise(brush) * 0.80
		+ broad_noise(brush * 1.85 + vec2(31.4, -12.7)) * 0.20;
	// This changes the contour only. It is never multiplied into the albedo.
	field += ((broad_noise(brush * 9.0 + vec2(5.2, 44.1)) - 0.5)
		+ (broad_noise(brush * vec2(23.0, 14.0) + vec2(-7.6, 9.3)) - 0.5) * 0.30) * edge_irregularity;
	float quiet_region = 1.0 - smoothstep(0.30, 0.62,
		broad_noise(p * 0.38 + vec2(17.6, -29.2)));
	field -= quiet_region * calm_amount * 0.36;
	float threshold = mix(0.84, 0.20, coverage);
	float painted = smoothstep(threshold - edge_softness, threshold + edge_softness, field);
	painted *= smoothstep(0.0, 0.02, coverage);

	// Quantized colour regions: flat interiors, with narrow softened seams.
	float region = broad_noise(p * 0.62 + vec2(-42.8, 19.3));
	vec3 paint = mix(violet_color.rgb, rose_color.rgb, smoothstep(0.38, 0.41, region));
	paint = mix(paint, sage_color.rgb, smoothstep(0.60, 0.63, region));
	if (use_distribution_mask) {
		painted *= mix(1.0, texture(distribution_mask, UV).r, mask_strength);
	}
	ALBEDO = mix(base_color.rgb, paint, painted);
	ROUGHNESS = surface_roughness;
	SPECULAR = surface_specular;
	METALLIC = 0.0;
}

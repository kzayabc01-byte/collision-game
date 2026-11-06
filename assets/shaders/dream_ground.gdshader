shader_type spatial;
render_mode unshaded, fog_disabled;

// RGBA stores four paint weights, not display colours or transparency.
group_uniforms Layout;
uniform sampler2D layer_weights : filter_linear_mipmap, repeat_disable;
/** Physical size of the current GroundVisual, in metres (X, Z). */
uniform vec2 ground_size = vec2(124.0, 98.0);
/** Width / height of the painted reference. Extra ground mirrors at the edges. */
uniform float reference_aspect = 1.77683316;
uniform vec2 layout_offset = vec2(0.0);
uniform float layout_scale : hint_range(0.5, 2.0, 0.01) = 1.0;

group_uniforms Pigments;
// The mask mixes these pigments; they are not four solid final colour regions.
uniform vec4 blue_pigment : source_color = vec4(0.13, 0.18, 0.34, 1.0);
uniform vec4 rose_pigment : source_color = vec4(0.70, 0.39, 0.68, 1.0);
uniform vec4 teal_pigment : source_color = vec4(0.12, 0.65, 0.65, 1.0);
uniform vec4 lavender_pigment : source_color = vec4(0.46, 0.47, 0.81, 1.0);
uniform float rose_amount : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float teal_amount : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float lavender_amount : hint_range(0.0, 2.0, 0.01) = 1.0;

group_uniforms Finish;
uniform float saturation : hint_range(0.0, 1.5, 0.01) = 1.0;
uniform float brightness : hint_range(0.5, 1.5, 0.01) = 1.0;
/** Optional subtle grain, in world space. The painted mask already has brushwork. */
uniform float grain_strength : hint_range(0.0, 0.05, 0.001) = 0.003;
uniform float grain_size : hint_range(0.05, 1.0, 0.01) = 0.18;
group_uniforms;

varying vec2 ground_position;

vec3 srgb_to_linear(vec3 value) {
	return mix(value / 12.92, pow((value + vec3(0.055)) / 1.055, vec3(2.4)),
		step(vec3(0.04045), value));
}

vec3 linear_to_srgb(vec3 value) {
	return mix(value * 12.92, 1.055 * pow(value, vec3(1.0 / 2.4)) - vec3(0.055),
		step(vec3(0.0031308), value));
}

vec3 linear_pigment(vec3 value) {
	// Compatibility supplies sRGB colour uniforms; Forward+/Mobile supply linear.
	if (OUTPUT_IS_SRGB) {
		return srgb_to_linear(value);
	}
	return value;
}

float grain_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Keep brush proportions on 124 x 98: preserve the whole central reference,
	// extending its top/bottom by reflection instead of stretching a 16:9 image.
	vec2 map_uv = (UV - vec2(0.5)) / layout_scale;
	map_uv.y *= ground_size.y * reference_aspect / ground_size.x;
	map_uv += vec2(0.5) + layout_offset;
	map_uv = vec2(1.0) - abs(mod(map_uv, vec2(2.0)) - vec2(1.0));
	vec4 weights = texture(layer_weights, map_uv);
	weights *= vec4(1.0, rose_amount, teal_amount, lavender_amount);
	weights /= max(dot(weights, vec4(1.0)), 0.0001);
	vec3 paint = linear_pigment(blue_pigment.rgb) * weights.r
		+ linear_pigment(rose_pigment.rgb) * weights.g
		+ linear_pigment(teal_pigment.rgb) * weights.b
		+ linear_pigment(lavender_pigment.rgb) * weights.a;
	float grey = dot(paint, vec3(0.2126, 0.7152, 0.0722));
	paint = mix(vec3(grey), paint, saturation);
	// Fade subpixel grain when zoomed out, avoiding shimmer on the game camera.
	vec2 grain_uv = ground_position / max(grain_size, 0.001);
	float footprint = max(length(dFdx(grain_uv)), length(dFdy(grain_uv)));
	float grain = (grain_hash(floor(grain_uv)) - 0.5)
		* (1.0 - smoothstep(0.5, 1.5, footprint));
	paint = clamp(paint * brightness * (1.0 + grain * grain_strength), vec3(0.0), vec3(1.0));
	if (OUTPUT_IS_SRGB) {
		paint = linear_to_srgb(paint);
	}
	ALBEDO = paint;
}

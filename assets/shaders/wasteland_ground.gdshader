shader_type spatial;
render_mode unshaded, fog_disabled;

// GroundVisual and its existing OuterBackdrop share world-space soil.
// Only the silhouette mask uses the authored, non-repeating 124 x 98 UVs.
group_uniforms Soil;
uniform vec4 soil_blue : source_color = vec4(0.265, 0.289, 0.430, 1.0);
uniform vec4 soil_lavender : source_color = vec4(0.318, 0.305, 0.452, 1.0);
uniform vec4 soil_slate : source_color = vec4(0.281, 0.312, 0.414, 1.0);
uniform float broad_scale : hint_range(4.0, 40.0, 0.5) = 12.5;
uniform float soil_variation : hint_range(0.0, 0.35, 0.005) = 0.15;
uniform float mottle_strength : hint_range(0.0, 0.2, 0.005) = 0.035;
uniform float fine_grain : hint_range(0.0, 0.04, 0.001) = 0.008;
uniform float brightness : hint_range(0.3, 1.5, 0.01) = 0.63;
uniform vec2 soil_offset = vec2(13.71, -29.18);

group_uniforms VegetationImprint;
uniform sampler2D grass_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec4 imprint_color : source_color = vec4(0.215, 0.251, 0.324, 1.0);
uniform float imprint_strength : hint_range(0.0, 0.8, 0.01) = 0.27;
uniform float mask_edge_fade : hint_range(0.001, 0.1, 0.001) = 0.025;
group_uniforms;

varying vec2 ground_position;

float hash21(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float soft_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

vec3 srgb_to_linear(vec3 c) {
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 linear_to_srgb(vec3 c) {
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 paint_color(vec3 c) {
    if (OUTPUT_IS_SRGB) { return srgb_to_linear(c); }
    return c;
}

void vertex() {
    ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    vec2 p = (ground_position + soil_offset) / max(broad_scale, 0.01);
    vec2 warp = vec2(soft_noise(p * 1.73 + 8.31), soft_noise(p * 1.53 - 31.2)) - 0.5;
    vec2 q = p + warp;
    float broad = soft_noise(q);
    float middle = soft_noise(q * 3.17 + vec2(47.1, -8.3));
    float patch = smoothstep(0.28, 0.72, broad * 0.78 + middle * 0.22);
    vec3 soil = mix(paint_color(soil_blue.rgb), paint_color(soil_lavender.rgb), patch);
    float slate = smoothstep(0.43, 0.8, soft_noise(q * 0.71 + vec2(-18.0, 92.0)));
    soil = mix(soil, paint_color(soil_slate.rgb), slate * 0.55);
    float cloud = soft_noise(q * 1.43 + vec2(21.6, -54.1));
    soil *= 1.0 + (cloud - 0.5) * soil_variation * 2.0;

    // Small soft, irregular marks, with no quantized cells or hard cracks.
    vec2 brush = ground_position * 1.14 + warp * 1.8;
    vec2 brush_warp = vec2(soft_noise(brush * 0.73), soft_noise(brush * 0.91 + 10.0));
    float mottle = soft_noise(brush + brush_warp) * 0.65
        + soft_noise(brush * 2.15 + brush_warp * 1.3 + 43.7) * 0.35;
    mottle = smoothstep(0.29, 0.71, mottle);
    float texture_fade = 1.0 - smoothstep(0.7, 1.6, max(length(dFdx(brush)), length(dFdy(brush))));
    soil *= 1.0 + (mottle - 0.5) * mottle_strength * 2.0 * texture_fade;
    vec2 fine = ground_position * 16.7;
    float grain_fade = 1.0 - smoothstep(0.3, 1.2, max(length(dFdx(fine)), length(dFdy(fine))));
    soil *= 1.0 + (soft_noise(fine) - 0.5) * fine_grain * grain_fade;

    // Black outside this ground: the backdrop continues soil, never a stretched mask edge.
    vec2 margin = min(UV, vec2(1.0) - UV);
    float inside = smoothstep(0.0, mask_edge_fade, min(margin.x, margin.y));
    float imprint = texture(grass_mask, clamp(UV, vec2(0.0), vec2(1.0))).r * inside;
    soil = mix(soil, paint_color(imprint_color.rgb), imprint * imprint_strength);
    soil = clamp(soil * brightness, vec3(0.0), vec3(1.0));
    ALBEDO = OUTPUT_IS_SRGB ? linear_to_srgb(soil) : soil;
}

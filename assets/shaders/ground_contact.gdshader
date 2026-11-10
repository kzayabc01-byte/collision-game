shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, shadows_disabled;
// Small editable contact shading for decorative props on an unlit ground.
uniform float opacity : hint_range(0.0, 0.4, 0.01) = 0.16;
void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float d = dot(p, p);
    ALBEDO = vec3(0.055, 0.066, 0.10);
    ALPHA = (1.0 - smoothstep(0.08, 0.96, d)) * opacity;
}

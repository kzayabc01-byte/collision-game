shader_type spatial;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 cell = abs(fract(world_position.xz / 2.0 + 0.5) - 0.5);
    float grid = 1.0 - smoothstep(0.008, 0.02, min(cell.x, cell.y));
    float center = 1.0 - smoothstep(4.5, 4.7, length(world_position.xz));
    vec3 base = mix(vec3(0.075, 0.13, 0.16), vec3(0.10, 0.19, 0.20), center);
    ALBEDO = base + grid * vec3(0.025, 0.055, 0.06);
    ROUGHNESS = 0.92;
}

shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform vec4 syrup_color : source_color = vec4(0.94, 0.45, 0.65, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float variation = 0.0;
float blob(vec2 p, vec2 center, vec2 radius) {
	return length((p-center)/radius)-1.0;
}
float join(float a, float b) {
	float h = clamp(0.5 + 0.5*(b-a)/0.35, 0.0, 1.0);
	return mix(b, a, h) - 0.35*h*(1.0-h);
}
void fragment() {
	vec2 p = (UV-0.5)*2.0;
	p += vec2(sin(p.y*16.0+variation), sin(p.x*13.0+variation))*0.014;
	float d = blob(p, vec2(-0.2, 0.0), vec2(0.32, 0.31));
	d = join(d, blob(p, vec2(0.08, 0.04), vec2(0.39, 0.18)));
	d = join(d, blob(p, vec2(0.35, -0.13), vec2(0.24, 0.09)));
	d = join(d, blob(p, vec2(0.13, 0.26), vec2(0.19, 0.12)));
	d = join(d, blob(p, vec2(-0.14, -0.31), vec2(0.13, 0.18)));
	d = min(d, blob(p, vec2(0.71, 0.08), vec2(0.105, 0.07)));
	d = min(d, blob(p, vec2(0.54, 0.37), vec2(0.08, 0.06)));
	d = min(d, blob(p, vec2(-0.53, 0.21), vec2(0.07, 0.09)));
	d = min(d, blob(p, vec2(0.64, -0.4), vec2(0.055, 0.05)));
	d += 0.035*sin(p.x*35.0+variation)*sin(p.y*29.0);
	float edge = 1.0-smoothstep(-0.1, 0.02, d);
	float glint = (1.0-smoothstep(0.0, 0.10, abs(d+0.24))) * (1.0-smoothstep(-0.4, 0.0, p.y)) * 0.10;
	ALBEDO = syrup_color.rgb*(0.82+0.18*smoothstep(-0.5, 0.1, p.y)) + vec3(glint);
	ROUGHNESS = 0.18;
	SPECULAR = 0.8;
	ALPHA = edge*fade*0.86;
}

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec2 p = (UV-0.5)*2.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float star = 1.0-smoothstep(0.0, 0.045, r-(0.19+0.37*pow(abs(cos(angle*4.0)), 9.0)));
	float arc = (1.0-smoothstep(0.025, 0.055, abs(r-0.78))) * step(0.2, sin(angle*3.0));
	ALBEDO = mix(vec3(1.0,0.65,0.22),vec3(1.0,0.96,0.76),star);
	ALPHA = max(star,arc)*fade;
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 body_color : source_color = vec4(0.53, 0.27, 0.72, 1.0);
uniform vec4 base_color : source_color = vec4(0.36, 0.76, 0.78, 1.0);
uniform vec4 rim_color : source_color = vec4(0.70, 0.74, 1.0, 1.0);
uniform float glaze_roughness : hint_range(0.05, 0.8) = 0.24;
uniform float rim_strength : hint_range(0.0, 0.5) = 0.10;
varying float local_height;

void vertex() {
	local_height = VERTEX.y;
}

void fragment() {
	float height_blend = smoothstep(-0.65, -0.15, local_height);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = mix(base_color.rgb, body_color.rgb, height_blend);
	EMISSION = rim_color.rgb * rim * rim_strength;
	ROUGHNESS = glaze_roughness;
	SPECULAR = 0.55;
	METALLIC = 0.0;
}

shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform float wind_strength = 0.12;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.7 + w.x * 0.6 + w.z * 0.4) * wind_strength * COLOR.a;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
}

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}

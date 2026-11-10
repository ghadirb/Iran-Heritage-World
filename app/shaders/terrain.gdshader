shader_type spatial;
render_mode cull_back;

varying vec3 wpos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vnoise(wpos.xz * 0.3) * 0.45 + vnoise(wpos.xz * 1.6) * 0.3 + vnoise(wpos.xz * 6.5) * 0.15 + vnoise(wpos.xz * 22.0) * 0.1;
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = base * (0.66 + n * 0.62);
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}

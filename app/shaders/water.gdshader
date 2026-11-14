shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

varying vec2 wuv;

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
	wuv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float flow = TIME * 0.9;
	float w1 = vnoise(vec2(wuv.x * 1.8, wuv.y * 0.7 + flow));
	float w2 = vnoise(vec2(wuv.x * 3.9 + 4.0, wuv.y * 1.6 + flow * 1.7));
	float ripple = w1 * 0.6 + w2 * 0.4;
	float edge = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x);
	vec3 shallow = vec3(0.30, 0.72, 0.78);
	vec3 deep = vec3(0.04, 0.27, 0.42);
	vec3 col = mix(shallow, deep, edge * 0.75 + ripple * 0.18);
	float foam = (1.0 - edge) * smoothstep(0.45, 0.8, ripple + (1.0 - edge) * 0.35);
	ALBEDO = mix(col, vec3(0.95, 0.99, 1.0), foam * 0.7);
	ALPHA = mix(0.9, 0.62, edge);
	ROUGHNESS = 0.06;
	SPECULAR = 0.85;
	METALLIC = 0.0;
	NORMAL = normalize(NORMAL + vec3((ripple - 0.5) * 0.35, 0.0, (w2 - 0.5) * 0.25));
}

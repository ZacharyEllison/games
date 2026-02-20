shader_type canvas_item;

uniform vec4 sky_top_color : source_color = vec4(0.27, 0.64, 1.0, 1.0);
uniform vec4 sky_bottom_color : source_color = vec4(0.79, 0.92, 1.0, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float cloud_scale : hint_range(1.0, 12.0, 0.1) = 4.5;
uniform float cloud_speed : hint_range(0.0, 0.3, 0.001) = 0.03;
uniform float cloud_density : hint_range(0.2, 0.9, 0.01) = 0.58;
uniform float cloud_softness : hint_range(0.01, 0.3, 0.01) = 0.12;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;

	for (int i = 0; i < 5; i++) {
		value += value_noise(p) * amp;
		p *= 2.02;
		amp *= 0.5;
	}

	return value;
}

void fragment() {
	vec2 uv = UV;

	vec3 sky = mix(sky_top_color.rgb, sky_bottom_color.rgb, uv.y);

	// +TIME on x makes cloud shapes drift left across the screen.
	vec2 cloud_uv = vec2(uv.x + TIME * cloud_speed, uv.y);
	float base = fbm(cloud_uv * cloud_scale);
	float large = fbm(cloud_uv * (cloud_scale * 0.55) + vec2(7.3, 2.1));
	float cloud_field = mix(base, large, 0.35);
	float cloud_mask = smoothstep(
		cloud_density - cloud_softness,
		cloud_density + cloud_softness,
		cloud_field
	);

	float lower_fade = 1.0 - smoothstep(0.55, 1.0, uv.y);
	cloud_mask *= mix(0.45, 1.0, lower_fade);

	vec3 color = mix(sky, cloud_color.rgb, cloud_mask * 0.8);
	COLOR = vec4(color, 1.0);
}

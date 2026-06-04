shader_type canvas_item;

uniform float speed = 1.0;
uniform float gold_mode = 0.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a < 0.01) {
		discard;
	}
	float t = TIME * speed;
	vec3 rgb;
	if (gold_mode > 0.5) {
		float shimmer = 0.85 + 0.15 * sin(t * 4.0);
		rgb = vec3(1.0, 0.82, 0.15) * shimmer;
	} else {
		float hue = fract(t * 0.15 + UV.x * 0.2);
		float h = hue * 6.0;
		float x = 1.0 - abs(mod(h, 2.0) - 1.0);
		if (h < 1.0) rgb = vec3(1.0, x, 0.0);
		else if (h < 2.0) rgb = vec3(x, 1.0, 0.0);
		else if (h < 3.0) rgb = vec3(0.0, 1.0, x);
		else if (h < 4.0) rgb = vec3(0.0, x, 1.0);
		else if (h < 5.0) rgb = vec3(x, 0.0, 1.0);
		else rgb = vec3(1.0, 0.0, x);
	}
	COLOR = vec4(rgb, col.a);
}

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform float pulse = 0.0;
void fragment() {
	vec2 pixel = abs(floor(UV * 7.0) - vec2(3.0));
	float arms = max((1.0 - step(0.5, pixel.x)) * (1.0 - step(2.5, pixel.y)),
		(1.0 - step(0.5, pixel.y)) * (1.0 - step(2.5, pixel.x)));
	float core = 1.0 - step(0.5, max(pixel.x, pixel.y));
	if (arms < 0.5) { discard; }
	vec3 color = mix(vec3(1.0, 0.88, 0.60), vec3(1.0, 1.0, 0.94), core);
	ALBEDO = color;
	EMISSION = color * core * 0.55;
	ALPHA = pulse * arms;
}

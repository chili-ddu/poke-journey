shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform float strength = 1.0;
void fragment() {
	float row = abs(floor(UV.y * 5.0) - 2.0);
	float core = 1.0 - step(0.5, row);
	float halo = 1.0 - step(1.5, row);
	if (halo < 0.5) { discard; }
	vec3 color = mix(vec3(1.0, 0.79, 0.40), vec3(1.0, 0.98, 0.83), core);
	ALBEDO = color;
	EMISSION = color * core * 0.65;
	ALPHA = mix(0.18, 0.85, core) * strength;
}

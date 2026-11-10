shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void fragment() {
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	ALBEDO = vec3(0.0);
	ALPHA = 0.24 * smoothstep(0.0, 0.065, edge);
}

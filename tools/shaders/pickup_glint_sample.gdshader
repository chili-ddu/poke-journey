shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D icon_tex : source_color, filter_nearest, repeat_disable;
uniform float progress = 0.0;
uniform float opacity = 1.0;

void fragment() {
	vec2 pixels = vec2(textureSize(icon_tex, 0));
	vec2 uv = (floor(UV * pixels) + 0.5) / pixels;
	vec4 source = texture(icon_tex, uv);
	if (source.a < 0.5 || max(source.r, max(source.g, source.b)) < 0.20) { discard; }
	// Two crisp brightness steps, clipped to the existing icon pixels.
	float center = mix(0.12, 1.65, clamp(progress / 0.72, 0.0, 1.0));
	float distance_to_band = abs(uv.x + uv.y * 0.75 - center);
	float outer = 1.0 - step(0.14, distance_to_band);
	float core = 1.0 - step(0.065, distance_to_band);
	float envelope = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.62, 0.80, progress));
	vec3 color = mix(vec3(1.0, 0.88, 0.59), vec3(1.0, 0.99, 0.91), core);
	ALBEDO = color;
	EMISSION = color * core * 0.35;
	ALPHA = source.a * outer * mix(0.50, 0.92, core) * envelope * opacity;
}

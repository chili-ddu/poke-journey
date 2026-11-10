shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D fragments : source_color, filter_nearest, repeat_disable;
uniform vec4 frame_px; // Atlas origin and dimensions, in pixels.
uniform bool neutral = false;
uniform float phase : hint_range(0.0,1.0);

void fragment() {
	vec2 dims = vec2(textureSize(fragments, 0));
	vec2 lo = frame_px.xy + 0.5;
	vec2 hi = frame_px.xy + frame_px.zw - 0.5;
	vec2 pixel = clamp(floor(UV * dims) + 0.5, lo, hi);
	vec4 ink = texture(fragments, pixel / dims);
	if (ink.a < 0.01) { discard; }

	vec2 local = pixel - lo;
	float upper = texture(fragments, max(pixel - vec2(1.0), lo) / dims).a;
	float edge = smoothstep(0.08, 0.72, ink.a - upper);
	float warm = smoothstep(0.02, 0.24, ink.r - ink.b);
	// The droplet lip catches light later than the ember tip.
	float travel = phase * 51.0 - 11.0 + warm * 4.0;
	float band = 1.0 - smoothstep(0.6, 3.4, abs(dot(local - frame_px.zw * 0.5, vec2(0.7,-0.35)) - travel));
	float glint = edge * band;
	vec3 highlight = mix(vec3(0.74,0.90,0.97),vec3(1.0,0.78,0.49),warm);
	if (neutral) { highlight = vec3(1.0); }
	ALBEDO = mix(ink.rgb,highlight,glint*0.42);
	ALPHA = ink.a * mix(0.72 - 0.18*phase, 0.94, glint);
}

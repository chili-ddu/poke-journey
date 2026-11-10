shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D wallpaper_tex : source_color, filter_nearest;
uniform float depth_shade : hint_range(0.0, 0.5) = 0.30;

void fragment() {
	vec4 original = texture(wallpaper_tex, UV);
	// The original pixels stay intact; neutral shading darkens the receding edge.
	float shade = 1.0 - depth_shade * (1.0 - UV.y);
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float frame_contact = mix(0.94, 1.0, smoothstep(0.018, 0.065, edge));
	ALBEDO = original.rgb * shade * frame_contact;
	ALPHA = original.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

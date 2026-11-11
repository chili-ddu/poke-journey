shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;
uniform sampler2D sprite_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 frame_uv;
uniform vec4 cue_color : source_color = vec4(0.45, 0.85, 1.0, 0.38);
uniform bool outline = false;
void fragment() {
	float mask = texture(sprite_tex, frame_uv.xy + UV * frame_uv.zw).a;
	if (mask < 0.5) { discard; }
	float depth = texture(scene_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 scene = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_distance = -scene.z / scene.w;
	// Ignore the player's own depth and coplanar rounding; only foreground occluders reveal the cue.
	if (-VERTEX.z <= scene_distance + 0.015) { discard; }
	ALBEDO = cue_color.rgb;
	ALPHA = cue_color.a;
	if (outline) {
		vec2 uv = frame_uv.xy + UV * frame_uv.zw;
		vec2 px = 1.0 / vec2(textureSize(sprite_tex, 0));
		float inside = min(min(texture(sprite_tex, uv + vec2(px.x,0.0)).a,
			texture(sprite_tex, uv - vec2(px.x,0.0)).a),
			min(texture(sprite_tex, uv + vec2(0.0,px.y)).a,
			texture(sprite_tex, uv - vec2(0.0,px.y)).a));
		ALBEDO = mix(vec3(0.16,0.21,0.28), cue_color.rgb, inside);
		ALPHA = mix(0.82,0.20,inside);
	}
}

shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 feet;
uniform float actor_depth;

void vertex() {
	// Each tuft shares a root. Only its tips part as the actor approaches.
	vec2 offset = UV2 - feet;
	float contact = 1.0 - smoothstep(0.13, 0.76, length(offset));
	VERTEX.xz += offset * contact * COLOR.r * 0.52;
	VERTEX.y -= 0.10 * contact * COLOR.r;

	// Match the body's depth bias locally, keeping the projected roots fixed.
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float near_actor = 1.0 - smoothstep(0.78, 1.40, length(offset));
	vec4 clip = PROJECTION_MATRIX * view_pos;
	vec4 biased = PROJECTION_MATRIX * vec4(view_pos.xyz - normalize(view_pos.xyz) * actor_depth * near_actor, 1.0);
	clip.z = biased.z / biased.w * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 leaf = texture(atlas, UV);
	ALBEDO = leaf.rgb;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}

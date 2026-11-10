shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D sprite_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D pattern_tex : source_color, filter_linear, repeat_enable;
uniform vec4 frame_uv;
uniform vec4 local_rect;
uniform float period = 32.0;
uniform float scroll = 0.0;
uniform float strength = 0.0;
uniform bool heal = false;
uniform vec4 bands = vec4(0.0);
uniform float heal_top = 0.0;
uniform float heal_height = 1.0;
void fragment() {
	float mask = texture(sprite_tex, frame_uv.xy + UV * frame_uv.zw).a;
	if (mask < 0.5) { discard; }
	vec2 local = local_rect.xy + UV * local_rect.zw;
	if (heal) {
		int i = clamp(int(floor((local.y - heal_top) / heal_height * 4.0)), 0, 3);
		float a = i == 0 ? bands.x : (i == 1 ? bands.y : (i == 2 ? bands.z : bands.w));
		ALBEDO = vec3(1.0, 1.0, 0.55);
		ALPHA = mask * a * strength;
	} else {
		vec4 p = texture(pattern_tex, (local + vec2(0.0, scroll)) / period);
		ALBEDO = p.rgb;
		ALPHA = mask * p.a * strength;
	}
}

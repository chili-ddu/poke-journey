shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D flame_tex : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform float age = 0.0;
uniform float phase = 0.0;
uniform float heat = 1.0;

void fragment() {
	vec2 size = vec2(textureSize(flame_tex, 0));
	vec2 uv = (floor(UV * size) + 0.5) / size;
	vec4 source = texture(flame_tex, uv);
	if (source.a < 0.01) { discard; }
	// Heat flows inside the existing pixel silhouette, never as metallic sheen.
	float clock = floor(age * 18.0) / 18.0;
	float center = 0.5 + sin(uv.y * 9.0 - clock * 11.0 + phase) * 0.07;
	float width = 0.045 + uv.y * 0.12;
	float core = 1.0 - step(width, abs(uv.x - center));
	float shoulder = 1.0 - step(width + 0.08, abs(uv.x - center));
	float pulse = 0.78 + sin(clock * 15.0 + phase) * 0.14;
	float warmth = (core * 0.70 + shoulder * 0.16) * heat * pulse;
	vec3 base = source.rgb * tint.rgb;
	vec3 hot = source.rgb * vec3(1.0, 0.76, 0.34);
	ALBEDO = mix(base, hot, warmth);
	EMISSION = hot * core * heat * 0.08;
	ALPHA = source.a * tint.a;
}

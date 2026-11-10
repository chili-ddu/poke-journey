shader_type canvas_item;
// Distort only the 3D viewport texture; HUD and floating text are separate layers.
uniform int fracture_count = 0;
uniform vec4 fractures[15]; // UV center, strength, phase
uniform vec2 viewport_pixels = vec2(960.0, 540.0);
void fragment() {
	vec2 displacement = vec2(0.0);
	for (int i = 0; i < fracture_count; i++) {
		vec2 local = (UV - fractures[i].xy) * viewport_pixels;
		float mask = 1.0 - smoothstep(3.0, 18.0, length(local));
		float ripple = sin(local.y * 0.35 + local.x * 0.16 - fractures[i].w * 18.0);
		displacement += vec2(ripple, ripple * 0.35) * mask * fractures[i].z * 1.4;
	}
	float magnitude = length(displacement);
	displacement *= min(1.0, 2.0 / max(magnitude, 0.001));
	vec2 sample_uv = clamp(UV + displacement / viewport_pixels, vec2(0.0), vec2(1.0));
	COLOR = texture(TEXTURE, sample_uv);
}

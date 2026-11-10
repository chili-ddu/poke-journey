shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

// Sample-only lighting inside the original soft sprite. The source alpha,
// texture, colour, dimensions and projectile trajectory remain the game ones.
uniform sampler2D effect_tex : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 flow = vec2(1.0, 0.0);
uniform float age = 0.0;
uniform float phase = 0.0;
uniform float strength = 1.0;
uniform int family = 0;

void vertex() {
	// A custom ShaderMaterial replaces Sprite3D's built-in billboard shader.
	// Retain the original camera-facing quad and its world scale explicitly.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec4 source = texture(effect_tex, UV);
	if (source.a < 0.001) { discard; }
	vec2 p = UV - vec2(0.5);
	vec2 forward = normalize(flow);
	float x = dot(p, forward);
	float y = dot(p, vec2(-forward.y, forward.x));
	vec3 base = source.rgb * tint.rgb;
	float light = 0.0;
	float shade = 0.0;
	float glow = 0.0;
	float white_mix = 0.65;
	if (family == 0) {
		// Soft, changing conduction line; never physical impact sparks.
		float bend = sin(x * 26.0 - age * 32.0 + phase) * 0.04
			+ sin(x * 44.0 + age * 20.0 + phase) * 0.025;
		float core = exp(-pow((y - bend) / 0.060, 2.0));
		float pulse = 0.68 + sin(age * 21.0 - x * 18.0 + phase) * 0.20;
		light = core * pulse * 0.48;
		shade = (1.0 - core) * 0.14;
		glow = core * pulse * 0.09;
	} else if (family == 1) {
		// Broad surface reflection that rolls with the leaves' travel.
		float sweep = sin(age * 7.0 + phase) * 0.38;
		float sheen = exp(-pow((x + y * 0.55 - sweep) / 0.14, 2.0));
		float facing = 0.55 + sin(age * 11.0 + phase) * 0.2;
		light = sheen * facing * 0.50;
		shade = (1.0 - sheen) * 0.16;
		white_mix = 0.35;
	} else if (family == 2) {
		// Three translucent currents across the same misty volume.
		float curl = sin(x * 13.0 - age * 12.0 + phase) * 0.11;
		float bands = pow(0.5 + 0.5 * cos((y - curl) * 22.0), 3.0);
		float passing = 0.65 + sin(x * 17.0 - age * 16.0 + phase) * 0.20;
		light = bands * passing * 0.42;
		shade = (1.0 - bands) * 0.16;
		glow = bands * 0.025;
		white_mix = 0.50;
	} else {
		// Internal refraction-like motion; no ring or icon above the target.
		float r = length(p);
		float a = atan(y, x + 0.00001);
		float waves = pow(0.5 + 0.5 * sin(r * 24.0 - age * 9.0 + a * 2.0 + phase), 3.0);
		float core = exp(-r * r * 20.0);
		light = waves * core * 0.34;
		shade = (1.0 - waves) * 0.14;
		glow = waves * core * 0.07;
		white_mix = 0.55;
	}
	ALBEDO = mix(base * (1.0 - shade * strength), mix(base, vec3(1.0), white_mix), light * strength);
	EMISSION = base * glow * strength;
	ALPHA = source.a * tint.a;
}

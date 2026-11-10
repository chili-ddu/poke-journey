shader_type spatial;
render_mode cull_disabled;

uniform sampler2D rock_texture : source_color, filter_nearest, repeat_enable;
varying vec3 terrain_position;
varying vec3 terrain_normal;

void vertex() {
	terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// One native earth face per bank, independent of the region's altitude.
	// Blend the horizontal projections around round elbows without stretching.
	vec2 weights = max(abs(normalize(terrain_normal).xz), vec2(0.001));
	weights /= weights.x + weights.y;
	float depth = clamp(UV.y, 0.03125, 0.96875);
	vec3 side_x = texture(rock_texture, vec2(terrain_position.z, depth)).rgb;
	vec3 side_z = texture(rock_texture, vec2(terrain_position.x, depth)).rgb;
	ALBEDO = side_x * weights.x + side_z * weights.y;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

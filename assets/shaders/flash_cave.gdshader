shader_type canvas_item;
render_mode unshaded;
uniform float aspect_ratio = 1.7778;
uniform vec2 player_center = vec2(0.5);
uniform vec2 helper_center = vec2(-10.0);
uniform float helper_strength = 0.0;
void fragment() {
	vec2 scale = vec2(aspect_ratio, 1.0);
	float player_distance = length((UV-player_center)*scale);
	float helper_distance = length((UV-helper_center)*scale);
	float near_player = 1.0-smoothstep(0.035,0.09,player_distance);
	float lamp = 1.0-smoothstep(0.24,0.60,helper_distance);
	// Once Flash is active, Pikachu is the sole center of the revealed area.
	float visible = mix(near_player,lamp,clamp(helper_strength,0.0,1.0));
	COLOR = vec4(0.008,0.012,0.025,0.96*(1.0-visible));
}

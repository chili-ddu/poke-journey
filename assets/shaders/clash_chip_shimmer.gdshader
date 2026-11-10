shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
#include "res://assets/shaders/clash_chip_reflection.gdshaderinc"

void fragment() {
	shade_chip(UV, ALBEDO, EMISSION, ALPHA);
	if (ALPHA < .015) { discard; }
}

shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/clash_chip_reflection.gdshaderinc"

void fragment() {
	vec3 ink;
	vec3 gleam;
	float alpha;
	shade_chip(UV, ink, gleam, alpha);
	COLOR = vec4(ink + gleam, alpha);
}

uniform sampler2D fragments : source_color, filter_nearest, repeat_disable;
uniform vec4 frame_px;
uniform float phase : hint_range(0.0,1.0);
uniform float offset_phase;
uniform bool colored_chip = false;
uniform vec4 chip_tint : source_color = vec4(1.0);
uniform vec4 shine_tint : source_color = vec4(1.0);

vec4 chip(vec2 p) {
	vec2 uv=(frame_px.xy+clamp(p,vec2(0.0),frame_px.zw-1.0)+0.5)/vec2(textureSize(fragments,0));
	return texture(fragments,uv);
}

// Select an exposed leading pixel. Adjacent transparent pixels sample the
// same moving point so the short gleam travels with the fragment.
float reflection(vec2 p) {
	vec4 ink=chip(p);
	float lip=ink.a-max(chip(p+vec2(1,-1)).a,chip(p+vec2(1,0)).a);
	vec2 rel=p-frame_px.zw*.5;
	float group=dot(rel,vec2(.017,.032));
	float beat=fract(2.35*phase-group+offset_phase);
	float pulse=1.0-smoothstep(.035,.16,abs(beat-.5));
	return max(0.0,lip)*pulse*smoothstep(4.0,11.0,rel.x);
}

void shade_chip(vec2 uv, out vec3 color, out vec3 emission, out float alpha) {
	vec2 p=floor(uv*vec2(textureSize(fragments,0)))-frame_px.xy;
	vec4 ink=chip(p);
	float core=reflection(p);
	float arms=max(max(reflection(p+vec2(1,0)),reflection(p-vec2(1,0))),
		max(reflection(p+vec2(0,1)),reflection(p-vec2(0,1))))*.56;
	float tips=max(reflection(p+vec2(0,2)),reflection(p-vec2(0,2)))*.24;
	float shine=max(core,max(arms,tips));
	float base=ink.a*(colored_chip ? mix(.98,.78,phase) : mix(.70,.45,phase));
	float opacity=max(base,shine);
	vec3 tint=mix(shine_tint.rgb,vec3(1.0),core*(colored_chip ? .08 : .82));
	color=mix(ink.rgb*chip_tint.rgb,tint,clamp(shine/max(opacity,.001),0.0,1.0));
	emission=tint*(core*.40+arms*.16);
	alpha=opacity;
}

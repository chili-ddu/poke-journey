shader_type canvas_item;
// Retain the existing viewport's sound-refraction inputs in this isolated study.
uniform int fracture_count=0;
uniform vec4 fractures[15];
uniform vec2 viewport_pixels=vec2(384.0,216.0);
uniform int lens_count=0;
uniform vec4 lenses[4]; // centre UV, radius in screen pixels, animation phase
uniform float lens_strength=1.0;

void fragment(){
	vec2 displacement=vec2(0.0);
	for(int i=0;i<fracture_count;i++){
		vec2 p=(UV-fractures[i].xy)*viewport_pixels;
		float mask=1.0-smoothstep(3.0,18.0,length(p));
		float ripple=sin(p.y*0.35+p.x*0.16-fractures[i].w*18.0);
		displacement+=vec2(ripple,ripple*0.35)*mask*fractures[i].z*1.4;
	}
	float highlight=0.0;
	float shade=0.0;
	for(int i=0;i<lens_count;i++){
		vec2 p=(UV-lenses[i].xy)*viewport_pixels;
		float r=length(p)/max(1.0,lenses[i].z);
		float field=1.0-smoothstep(0.25,1.0,r);
		float wave=sin(r*18.0-lenses[i].w*14.0);
		displacement+=normalize(p+vec2(0.001))*field*wave*1.85*lens_strength;
		float arc=0.5+0.5*sin(atan(p.y,p.x+0.00001)-lenses[i].w*4.0);
		float front=0.56+0.10*sin(lenses[i].w*10.0);
		float edge=exp(-pow((r-front)/0.10,2.0));
		highlight+=edge*arc*0.14;
		shade+=edge*(1.0-arc)*0.07;
	}
	displacement*=min(1.0,2.0/max(length(displacement),0.001));
	vec2 uv=clamp(UV+displacement/viewport_pixels,vec2(0.0),vec2(1.0));
	vec4 scene=texture(TEXTURE,uv);
	COLOR=vec4(mix(scene.rgb*(1.0-min(0.08,shade)),vec3(0.94,0.95,0.98),min(0.16,highlight)),scene.a);
}

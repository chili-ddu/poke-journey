shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec2 flow=vec2(1.0,0.0);
uniform float age=0.0;
uniform float phase=0.0;
uniform int family=0;
uniform float strength=1.0;
uniform vec2 shape_aspect=vec2(1.0);

void vertex(){
	VERTEX.xy*=shape_aspect;
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(
		vec4(INV_VIEW_MATRIX[0].xyz*length(MODEL_MATRIX[0].xyz),0.0),
		vec4(INV_VIEW_MATRIX[1].xyz*length(MODEL_MATRIX[1].xyz),0.0),
		vec4(INV_VIEW_MATRIX[2].xyz*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);
}

void fragment(){
	vec2 p=UV-vec2(0.5);
	float alpha=0.0;
	vec3 color=vec3(0.88,0.91,0.89);
	float emission=0.0;
	if(family==0){
		vec2 d=normalize(flow);
		float x=dot(p,d),y=dot(p,vec2(-d.y,d.x));
		float tick=floor(age*24.0);
		float segment=(x+0.5)*5.0;
		float a=sin(floor(segment)*17.1+tick*2.3+phase);
		float b=sin((floor(segment)+1.0)*17.1+tick*2.3+phase);
		float bend=mix(a,b,fract(segment))*0.09;
		float line=exp(-pow((y-bend)/0.030,2.0));
		float halo=exp(-pow((y-bend)/0.065,2.0));
		float ends=1.0-smoothstep(0.36,0.47,abs(x));
		float pulse=0.78+sin(tick*2.1+phase)*0.18;
		alpha=ends*(line*0.94+halo*0.14)*pulse;
		color=mix(vec3(0.86,0.81,0.36),vec3(1.0,0.98,0.83),line);
		emission=line*0.24;
	}else{
		// Open rotating ellipses widen towards the top of a transparent funnel.
		float h=1.0-UV.y;
		float axis=sin(h*5.0-age*7.0+phase)*0.018*h+flow.x*0.025*h*h;
		float x=p.x-axis;
		float cone=0.045+0.30*pow(h,1.25);
		float inside=1.0-smoothstep(cone*0.60,cone,abs(x));
		float fade=smoothstep(0.02,0.14,h)*(1.0-smoothstep(0.88,0.98,h));
		float mist=inside*fade*0.085;
		float bands=0.0;
		for(int i=0;i<5;i++){
			float u=0.15+float(i)*0.155;
			float r=0.045+0.30*pow(u,1.25);
			vec2 q=vec2(x/r,(h-u)/(0.018+r*0.22));
			float ring=exp(-pow((length(q)-1.0)/0.24,2.0));
			float angle=atan(q.y,q.x+0.00001);
			float arc=0.24+0.76*pow(0.5+0.5*sin(angle-age*19.0+float(i)*1.1+phase),2.0);
			bands+=ring*arc*(0.68+u*0.20);
		}
		float helix=sin(h*18.85-age*19.0+phase)*cone*0.9;
		float joining=exp(-pow((x-helix)/(0.013+cone*0.025),2.0))*fade*0.20;
		alpha=mist+bands+joining;
		color=mix(vec3(0.56,0.66,0.65),vec3(0.90,0.94,0.90),min(1.0,bands*1.6));
	}
	alpha*=strength;
	if(alpha<0.002){discard;}
	ALBEDO=color;
	EMISSION=color*emission;
	ALPHA=min(0.97,alpha);
}

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec2 flow=vec2(1.0,0.0);
uniform float age=0.0;
uniform float phase=0.0;
uniform int family=0;
uniform float strength=1.0;
uniform vec2 shape_aspect=vec2(1.0);
uniform float head_gain=1.0;
uniform float sheen_gain=1.0;
uniform bool compact_bolt=false;

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
		// The luminous head stays at the actual projectile centre. Only its
		// short wake bends, so the viewer can follow a moving packet of charge.
		float segment=(x+0.5)*6.0;
		float a=sin(floor(segment)*17.1+tick*2.3+phase);
		float b=sin((floor(segment)+1.0)*17.1+tick*2.3+phase);
		float rear=clamp(-x/0.43,0.0,1.0);
		float bend=mix(a,b,fract(segment))*0.065*rear;
		if(compact_bolt){
			// Two folds travel with the head. Their height flickers independently of flight.
			float fold=1.0-4.0*abs(fract(-x*4.0+0.25)-0.5);
			bend=fold*smoothstep(0.045,0.19,-x)*(0.095+0.017*sin(tick+phase));
		}
		float wake=exp(-pow((y-bend)/(0.019+0.012*(1.0-rear)),2.0));
		float wake_halo=exp(-pow((y-bend)/0.065,2.0));
		float tail=smoothstep(-0.48,-0.40,x)*(1.0-smoothstep(-0.055,0.0,x))*pow(1.0-rear,0.40);
		float pulse=0.80+sin(tick*2.1+phase)*0.16;
		vec2 head=vec2(x/0.135,y/0.105);
		if(compact_bolt){
			head=vec2(x/0.17,y/0.070);
		}
		float radius=length(head);
		float body=1.0-smoothstep(0.65,1.12,radius);
		float halo=exp(-dot(head,head)*1.65)*0.19;
		vec2 head_view=d*head.x+vec2(-d.y,d.x)*head.y;
		float top=clamp(0.64-head_view.x*0.14-head_view.y*0.28,0.0,1.0);
		float core=exp(-dot(head-vec2(0.12,0.0),head-vec2(0.12,0.0))*8.0);
		float surface=exp(-pow((head_view.y+0.42+head_view.x*0.35)/0.20,2.0))*body;
		vec3 head_color=mix(vec3(0.61,0.58,0.23),vec3(1.0,0.96,0.66),top);
		head_color=mix(head_color,vec3(1.0,0.995,0.89),clamp(core*0.9+surface*0.24*sheen_gain,0.0,1.0));
		float tail_alpha=tail*(wake*0.95+wake_halo*0.12)*pulse;
		float head_alpha=(body*0.94+halo)*head_gain;
		alpha=max(head_alpha,tail_alpha);
		vec3 tail_color=mix(vec3(0.80,0.77,0.34),vec3(1.0,0.98,0.82),wake);
		color=mix(tail_color,head_color,smoothstep(0.015,0.14,head_alpha));
		emission=core*0.28*head_gain+tail*wake*0.10;
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
		float lit_bands=0.0;
		float sheen=0.0;
		for(int i=0;i<5;i++){
			float u=0.15+float(i)*0.155;
			float r=0.045+0.30*pow(u,1.25);
			vec2 q=vec2(x/r,(h-u)/(0.018+r*0.22));
			float ring=exp(-pow((length(q)-1.0)/0.24,2.0));
			float angle=atan(q.y,q.x+0.00001);
			float arc=0.24+0.76*pow(0.5+0.5*sin(angle-age*19.0+float(i)*1.1+phase),2.0);
			float front=clamp(0.5-q.y*0.45,0.0,1.0);
			float band=ring*arc*(0.68+u*0.20)*(0.75+front*0.25);
			bands+=band;
			lit_bands+=band*clamp(0.62-q.x*0.18-q.y*0.20,0.25,0.98);
			sheen+=ring*pow(max(0.0,cos(angle-age*19.0+float(i)*1.1+phase)),10.0)*0.13;
		}
		float helix=sin(h*18.85-age*19.0+phase)*cone*0.9;
		float joining=exp(-pow((x-helix)/(0.013+cone*0.025),2.0))*fade*0.20;
		alpha=mist+bands+joining;
		float illumination=clamp(lit_bands/max(0.001,bands)*0.85+0.20,0.0,1.0);
		color=mix(vec3(0.60,0.69,0.68),vec3(0.98,0.99,0.96),illumination);
		color=mix(color,vec3(0.97,0.98,0.94),min(0.3,sheen*sheen_gain));
		emission=sheen*0.025;
	}
	alpha*=strength;
	if(alpha<0.002){discard;}
	ALBEDO=color;
	EMISSION=color*emission;
	ALPHA=min(0.97,alpha);
}

extends RefCounted
# Body-local pixels: x = screen right, y = up, z = toward camera.
# Shared geometry for flat and HD-2D views. Never consumes gameplay RNG.
# Purple ribbon hue references the verified SV Wrap still; motion is custom.
const SEGMENTS := 60
const WIND_TIME := 0.30
static func ribbon(age: float,radius: float,remaining: float,damage_phase: float) -> Array:
	var result: Array=[]
	var winding := smoothstep(0.0,1.0,clampf(age/WIND_TIME,0.0,1.0))
	var pulse := (1.0-clampf(damage_phase/0.20,0.0,1.0)) if age>WIND_TIME else 0.0
	var rx := maxf(5.0,radius*1.25)*(lerpf(1.28,1.0,winding)-pulse*0.10)
	var height := maxf(10.0,radius*1.8)
	var alpha := clampf(age/0.08,0.0,1.0)*clampf(remaining/0.18,0.0,1.0)
	var count := mini(SEGMENTS,ceili(float(SEGMENTS)*winding))
	for i in count:
		var start := float(i)/SEGMENTS
		var finish := minf(float(i+1)/SEGMENTS,winding)
		if finish<=start:continue
		var a := point(start,rx,height)
		var b := point(finish,rx,height)
		var front := (a.z+b.z)*0.5>0.0
		var color := Color(0.64,0.26,0.94,alpha*(0.94 if front else 0.65))
		color=color.lerp(Color(0.90,0.68,1.0,color.a),pulse*0.38)
		result.append({"a":a,"b":b,"width":maxf(1.8,radius*0.22)*(1.0+pulse*0.18),"color":color,"front":front})
	return result
static func point(t: float,radius: float,height: float) -> Vector3:
	var angle := -PI*0.5+t*TAU*2.5
	return Vector3(cos(angle)*radius,(t-0.5)*height,sin(angle)*radius*0.70)

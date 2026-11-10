extends RefCounted

# Cosmetic world-space samples, independent of camera and combat RNG.
const LIFE := 0.24
const STAR_LIFE := 0.23
const SAMPLE_TIME := 1.0/30.0
const STAR_TIME := 1.0/15.0
var history: Array=[]
var motes: Array=[]
var _sample_clock := 0.0
var _star_clock := STAR_TIME-SAMPLE_TIME
var _emissions := 0

func advance(dt: float, item: LootItem) -> void:
	for point in history: point.age+=dt
	for mote in motes: mote.age+=dt
	history=history.filter(func(p): return p.age<LIFE)
	motes=motes.filter(func(p): return p.age<STAR_LIFE)
	if not is_instance_valid(item) or item.done or item.merge_age>=0.0 or item.flight<0.0: return
	_sample_clock+=dt
	_star_clock+=dt
	if _sample_clock>=SAMPLE_TIME:
		_sample_clock=fmod(_sample_clock,SAMPLE_TIME)
		history.append({"at":item.draw_at,"height":item.height,"age":0.0})
		if history.size()>9: history.pop_front()
	if _star_clock>=STAR_TIME:
		_star_clock=fmod(_star_clock,STAR_TIME)
		motes.append({"at":item.draw_at,"height":item.height,"age":0.0,
			"side":1.0 if _emissions%2==0 else -1.0,"size":0.30 if _emissions%3==0 else 0.23})
		_emissions+=1

static func star_pulse(age: float) -> float:
	return clampf(age/0.035,0.0,1.0)*clampf((STAR_LIFE-age)/0.18,0.0,1.0)

func draw_flat(canvas: Node2D) -> void:
	for i in maxi(0,history.size()-1):
		var a: Vector2=history[i].at-Vector2(0,history[i].height)-canvas.position
		var b: Vector2=history[i+1].at-Vector2(0,history[i+1].height)-canvas.position
		var fade: float=pow(1.0-float(history[i].age)/LIFE,1.5)
		canvas.draw_line(a,b,Color(1.0,0.88,0.59,fade*0.25),3.0)
		canvas.draw_line(a,b,Color(1.0,0.98,0.83,fade*0.65),1.0)
	for mote in motes:
		var pulse := star_pulse(mote.age)
		var at: Vector2=(mote.at-Vector2(0,mote.height)-canvas.position+Vector2(mote.side, -1)).round()
		var radius := 2.0 if pulse>0.65 else 1.0
		var color := Color(1.0,0.94,0.74,pulse)
		canvas.draw_rect(Rect2(at-Vector2(radius,0),Vector2(radius*2+1,1)),color)
		canvas.draw_rect(Rect2(at-Vector2(0,radius),Vector2(1,radius*2+1)),color)

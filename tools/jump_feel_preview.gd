extends SceneTree

# Before/application comparison. The right-hand sample uses the runtime helpers.
const OUT := "res://docs/jump_feel_preview/"
const NEW_TICKS := MonSprite.HOP_VISUAL_TICKS
const ORIGINAL_LANDING_DURATION := 0.16

func remap_hop(time: float, anim: Dictionary) -> float:
	return MonSprite.hop_sheet_time(anim,time)

func squash(time: float, revised: bool) -> Vector2:
	if time<0.0: return Vector2.ONE
	if not revised:
		if time>=ORIGINAL_LANDING_DURATION: return Vector2.ONE
		var pulse:=sin(PI*time/ORIGINAL_LANDING_DURATION)
		return Vector2(1.0+0.055*pulse,1.0-0.075*pulse)
	return Mon.landing_scale_at(time)

func _init() -> void:
	var mon:=Mon.new()
	mon.setup("charmander",5,Mon.TEAM_PLAYER)
	mon.facing=Vector2.RIGHT
	var hop: Dictionary=mon._sprites.Hop
	assert(hop.durations.size()==NEW_TICKS.size())
	assert(absf(MonSprite.anim_length(hop)-0.4)<0.00001)
	var total:=0.0
	for n in NEW_TICKS: total+=float(n)
	assert(absf(total*MonSprite.TICK-0.4)<0.00001)
	var rows: Array=[]
	for i in 80:
		var time:=float(i)*0.02-0.3
		var samples: Array=[]
		for revised in [false,true]:
			var jumping:=time>=0.0 and time<0.4
			var anim: Dictionary=hop if jumping else mon._sprites.Idle
			var sheet_time:=remap_hop(time,hop) if revised and jumping else time if jumping else 0.0
			var visual:=MonSprite.visual_frame(anim,2,sheet_time,false)
			var center:=MonSprite.anchor_of(mon._sprites,anim)
			var height:=0.0
			if jumping:
				var body: Vector2=visual.body_center if revised else anim.centers[2][MonSprite.frame_at(anim,sheet_time,false)]
				height=maxf(0.0,(anim.centers[2][0] as Vector2).y-body.y)
			var r: Rect2=visual.src
			var scale:=squash(time-0.4,revised)
			samples.append({"path":visual.tex.resource_path,"rect":[r.position.x,r.position.y,r.size.x,r.size.y],"anchor":[center.x,center.y],"scale":[scale.x,scale.y],"height":height,"travel":clampf(time/0.4,0.0,1.0)*Player.JUMP_DISTANCE,"feet":float(mon._sprites.feet_dy)-1.0,"jumping":jumping})
		rows.append(samples)
	DirAccess.make_dir_recursive_absolute(OUT)
	var file:=FileAccess.open(OUT+"selections.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows))
	mon.free()
	print("Applied jump comparison: both flights 0.4 s / ",Player.JUMP_DISTANCE," px")
	quit()

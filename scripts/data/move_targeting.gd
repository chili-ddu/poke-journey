extends RefCounted

const FAN_DEGREES := 54.0
const FRONT_DEGREES := 50.0
const TARGETS_PATH := "res://assets/data/move_targets.json"
static var ids: Dictionary

static func configure(move: Dictionary) -> void:
	if ids.is_empty():
		ids=JSON.parse_string(FileAccess.get_file_as_string(TARGETS_PATH))
	if move.id=="none":
		move.target_pattern="unused"
		return
	var target:=int(ids[move.id])
	move.original_target=target
	match target:
		8,10: move.target_pattern="front"
		11: move.target_pattern="fan"
		9: move.target_pattern="around"
		7: move.target_pattern="self"
		3,4,5,13,15: move.target_pattern="friendly"
		6,12,14: move.target_pattern="field"
		_: move.target_pattern="specific"
	if move.target_pattern=="around" and move.cat!="status":
		move.shape="arc"
		move.arc_deg=360.0
		move.lunge=false
		move.erase("glide")
		if not move.has("fx"):
			move.area_wave=true
		return
	if move.shape in ["projectile","cone","burst"]:
		if move.target_pattern=="fan":
			var lanes:=maxi(7,ceili(deg_to_rad(FAN_DEGREES)*float(move.range)/(2.0*move.radius))+1)
			if move.shape=="burst":
				move.interval=float(move.interval)*(int(move.count)-1)/(lanes-1)
				move.volley=true
			else:
				move.shape="cone"
			move.count=lanes
			move.spread_deg=FAN_DEGREES
		if move.target_pattern in ["front","fan"]:
			move.pierce=true
			if move.id=="water_gun":
				move.spread_deg=0.0
				move.vary=false
		return
	if move.shape=="arc" and move.target_pattern=="fan":
		move.arc_deg=FAN_DEGREES
	if move.shape=="arc" and move.target_pattern=="front" and not MoveShapes.SHAPES.has(move.id):
		move.arc_deg=FRONT_DEGREES
	if move.id in ["flatter","swagger"]:
		move.shape="status_cone"
		move.stat={move.stat:move.stages}
		move.range=2*MoveShapes.T
	if move.shape=="status_cone":
		match move.target_pattern:
			"front": move.arc_deg=FRONT_DEGREES
			"fan": move.arc_deg=maxf(FAN_DEGREES,float(move.arc_deg))
			"around","field","self","friendly": move.arc_deg=360.0

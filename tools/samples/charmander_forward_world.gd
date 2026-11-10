extends "res://tools/samples/charmander_target_world.gd"

signal release(move: String, direction: Vector2, landing: Vector2, timing: float)
var quiet_impact := false
var smoke_time := 0.0
var smoke_land := Vector2.ZERO

# These cached move dictionaries exist only in the isolated review process.
func configure(move: String) -> void:
	var m := MoveDB.get_move(move)
	match move:
		"scratch","slash": m.fx = "forward_only"
		"fire_fang":
			m.erase("glide")
			m.step = 24.0
		"dragon_breath","flamethrower":
			m.merge({"fx":"forward_only","pierce":true,"volley":true,"spread_deg":0.0}, true)
		"inferno":
			m.merge({"shape":"ring","radius":18.0,"lifetime":0.24,"tick":1.0,"cast_delay":0.20,"anim":"Charge"},true)
		"fire_spin": m.radius = 23.0
		"flare_blitz":
			m.merge({"shape":"dash","distance":66.0,"duration":0.32,"anim":"Attack","lunge":false},true)

func cast(mon: Mon, move: String, dir: Vector2, aim: Vector2, opts: Dictionary = {}) -> void:
	var zone_count := zones.size()
	super.cast(mon,move,dir,aim,opts)
	if mon != player: return
	var landing := mon.position+(aim-mon.position).limit_length(3.0*Arena.TILE)
	var timing := 0.0
	if move in ["scratch","slash","fire_fang"] and not pending_melee.is_empty():
		timing = pending_melee.back().duration
	if move == "smoke_screen":
		timing = smoke_time
		landing = smoke_land
	if zones.size() > zone_count and move in ["fire_spin","inferno"]:
		var zone: Zone = zones.back()
		zone.follow = null
		zone.position = landing
		zone.hide()
	release.emit(move,dir.normalized(),landing,timing)

func _smoke_lob_custom(mon: Mon, m: Dictionary, _mouth: Vector2, land: Vector2, travel: float, radius: float) -> void:
	smoke_time = travel
	smoke_land = land
	var apply := func():
		# Same visual foot-plane offset as the projectile and its shadow.
		_smoke_cloud_custom(land+Vector2(0,mon.feet_offset()),radius*.90,mon.radius)
		_smoke_land_for_team(mon.team,m.stat,land,radius,mon==player)
	pending_calls.append({"t":travel,"call":apply})

func _fire_fang_cast_custom(mon: Mon, dir: Vector2, close: float) -> void:
	super._fire_fang_cast_custom(mon,dir,close)
	var jaws: Fx = fxs.back()
	jaws.offset -= dir * 6.0
	jaws.position = mon.position+jaws.offset
	jaws.size *= .84

func _fire_fang_hit_custom(_target: Mon, _forward: Vector2) -> void:
	pass # The jaws are already drawn in the lunge direction.

func apply_hit(target: Mon, hit: Dictionary, from_pos: Vector2) -> bool:
	quiet_impact = hit.get("src") == player
	var landed := super.apply_hit(target,hit,from_pos)
	quiet_impact = false
	return landed

func add_fx(kind: String, pos: Vector2, opts: Dictionary = {}) -> Fx:
	var f := super.add_fx(kind,pos,opts)
	if quiet_impact and kind == "impact": f.dead = true
	return f

# Keep moving through contacts in this sample; terrain still ends the charge.
func _step_dash(mon: Mon, dt: float) -> void:
	var dash := mon.dash
	if dash.get("move") != "flare_blitz":
		super._step_dash(mon,dt)
		return
	var start := mon.position
	var dt_left := minf(dt,float(dash.t))
	var wanted := start+Vector2(dash.dir)*float(dash.speed)*dt_left
	mon.position = resolve_mon(mon,wanted)
	mon.facing = dash.dir
	for foe: Mon in opponents(mon.team):
		var id := foe.get_instance_id()
		if dash.hit_ids.has(id): continue
		var nearest := start if start.is_equal_approx(mon.position) else Geometry2D.get_closest_point_to_segment(foe.position,start,mon.position)
		if nearest.distance_to(foe.position) < mon.radius+foe.radius:
			dash.hit_ids[id] = true
			apply_hit(foe,dash.hit,start)
	dash.t -= dt
	if dash.t <= 0 or mon.position.distance_to(wanted)>0.5:
		mon.dash = {}
		if mon == player: _player_recover("flare_blitz")

extends RefCounted

const BOUNCE_SPEED := 112.0

## A straight attacking advance, clipped before walls and the first body.
## Shared by melee, actual dashes and their read-only HUD prediction.
static func forward_sweep(world, mon: Mon, start: Vector2, direction: Vector2, distance: float, seen: Dictionary={}) -> Dictionary:
	var dir:=direction.normalized()
	var travel:=maxf(0.0,distance)
	var safe:=0.0
	var wall:=false
	while safe<travel:
		var next:=minf(travel,safe+2.0)
		var wanted:=start+dir*next
		if world.resolve_mon(mon,wanted).distance_to(wanted)>.001:
			var low:=safe;var high:=next
			for _index in 8:
				var mid: float=(low+high)*.5
				var point:=start+dir*mid
				if world.resolve_mon(mon,point).distance_to(point)>.001:high=mid
				else:low=mid
			travel=low;wall=true;break
		safe=next
	var first: Mon
	for foe: Mon in world.opponents(mon.team):
		if foe.dead or seen.has(foe.get_instance_id()):continue
		var offset:=foe.position-start
		var along:=offset.dot(dir)
		# Existing rear overlaps must be escapable; moving away increases the
		# separation immediately. A front body still clips this same sweep.
		if along<=0.0:continue
		var radius:=foe.radius+mon.radius
		var lateral:=maxf(0.0,offset.length_squared()-along*along)
		if lateral>=radius*radius:continue
		var chord:=sqrt(radius*radius-lateral)
		if along+chord<0.0:continue
		var entry:=maxf(0.0,along-chord-.01)
		if entry<=travel:
			travel=entry;first=foe
	return {"point":start+dir*travel,"distance":travel,"blocked":wall or first!=null,"target":first}

# Earliest circle entry along a swept segment, regardless of enemy array order.
static func first_contact(world, start: Vector2,end: Vector2,team: int,width: float,seen: Dictionary) -> Mon:
	var delta:=end-start
	var length:=delta.length()
	var dir:=delta.normalized()
	var first: Mon
	var nearest:=INF
	for foe: Mon in world.opponents(team):
		if foe.dead or seen.has(foe.get_instance_id()): continue
		var offset:=foe.position-start
		var along:=offset.dot(dir)
		var radius:=foe.radius+width
		var lateral_sq:=maxf(0,offset.length_squared()-along*along)
		if lateral_sq>radius*radius: continue
		var chord:=sqrt(radius*radius-lateral_sq)
		var entry:=maxf(0,along-chord)
		if along+chord>=0 and entry<=length and entry<nearest:
			nearest=entry
			first=foe
	return first

static func pay_recoil(world, hit: Dictionary, lost: int) -> void:
	var attacker=hit.get("src")
	if lost<=0 or not is_instance_valid(attacker) or attacker.dead: return
	var state: Dictionary=hit.recoil_state
	state.total+=lost
	var due:=maxi(1,roundi(attacker.max_hp*.25)) if hit.move=="struggle" else maxi(1,roundi(state.total*float(hit.recoil)))
	var amount:=due-int(state.paid)
	if amount>0:
		state.paid=due
		world.damage(attacker,amount)
		world.float_text(attacker.position+Vector2.UP*(attacker.radius+4),str(amount),Color("ff9a9a"),7)
	if not state.bounced and not attacker.dead:
		state.bounced=true
		var forward: Vector2=state.direction
		attacker.attack_lunge=false
		attacker.glide={}
		attacker.knock=-forward.normalized()*BOUNCE_SPEED

static func step_recoil_dash(world, mon: Mon, dt: float) -> void:
	step_attack_dash(world,mon,dt)

## One swept contact ends an attacking dash even when the hit is protected/misses.
static func step_attack_dash(world, mon: Mon, dt: float) -> void:
	var dash:=mon.dash
	var dir: Vector2=dash.dir
	var remaining:=minf(dt,float(dash.t))*float(dash.speed)
	mon.facing=dir
	var sweep:=forward_sweep(world,mon,mon.position,dir,remaining,dash.hit_ids)
	mon.position=sweep.point
	var target: Mon=sweep.target
	if target!=null:
		dash.hit_ids[target.get_instance_id()]=true
		if world.apply_hit(target,dash.hit,mon.position) and world.last_damage>0:
			world._dash_hit_fx(target,String(MoveDB.get_move(dash.move).get("fx","")),dir)
		# Neighbours at the same contact share the original hit/recoil packet.
		if not mon.dead:
			for foe: Mon in world.opponents(mon.team):
				if foe.dead or dash.hit_ids.has(foe.get_instance_id()):continue
				if mon.position.distance_to(foe.position)<=mon.radius+foe.radius+.02:
					dash.hit_ids[foe.get_instance_id()]=true
					world.apply_hit(foe,dash.hit,mon.position)
					if mon.dead:break
	dash.t-=dt
	if sweep.blocked or dash.t<=0:
		mon.dash={}
		mon.trail.clear()
		if not mon.dead:
			if mon==world.player: world._player_recover(dash.move,0.0)
			else: mon.recover_t=Mon.RECOVER_DURATION

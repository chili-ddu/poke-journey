extends "res://tools/samples/projectile_clash_world.gd"
## Isolated simultaneous-contact timing study.
const HOLD:=2.0/30.0
var rebound_study:=false
var forward_cuts:=false
var remaining_cut_scale: Dictionary={}
var residual_knock:=false
var full_knock_distance:=0.0
var release: Array[Dictionary]=[]
var separation: Array[Dictionary]=[]
var sim_time:=0.0
var held_projectile_steps:=0
var held_melee_steps:=0

func step(dt: float) -> void:
	super.step(dt)
	sim_time+=dt

func match_power(a: Dictionary,b: Dictionary) -> void:
	super.match_power(a,b)
	for packet in [a,b]: packet["resume_at"]=sim_time+HOLD

func _step_bursts(dt: float) -> void:
	var held:=bursts.filter(func(b):return float(b.hit.get("resume_at",0))>sim_time)
	if held.is_empty():
		super._step_bursts(dt)
		return
	bursts=bursts.filter(func(b):return float(b.hit.get("resume_at",0))<=sim_time)
	super._step_bursts(dt)
	bursts.append_array(held)

func _advance_projectile(p: Projectile,dt: float,attempted: Dictionary,targets: Array,record_trail:=true) -> void:
	if float(p.hit.get("resume_at",0))>sim_time:
		held_projectile_steps+=1
		return
	super._advance_projectile(p,dt,attempted,targets,record_trail)

func faces_target(attack: Dictionary,target: Mon) -> bool:
	var actor: Mon=attack.mon
	var gap:=target.position-actor.position
	var m:=MoveDB.get_move(attack.move)
	return gap.length()<=actor.radius+target.radius+float(m.range) and absf(Vector2(attack.dir).angle_to(gap))<=deg_to_rad(float(m.arc_deg)*.5)

func _step_pending_melee(dt: float) -> void:
	# One preview duel. Only simultaneous, mutually facing active strikes qualify.
	if pending_melee.size()==2:
		var a: Dictionary=pending_melee[0]
		var b: Dictionary=pending_melee[1]
		if not a.get("cancel",false) and not b.get("cancel",false) and a.mon.team!=b.mon.team and minf(a.t,b.t)<=dt and maxf(a.t,b.t)<=dt+.004 and faces_target(a,b.mon) and faces_target(b,a.mon):
			match_power(a.hit,b.hit)
			incoming=[{"type":a.hit.type,"dir":a.dir,"broken":a.hit.power<=0},
				{"type":b.hit.type,"dir":b.dir,"broken":b.hit.power<=0}]
			if rebound_study:
				var axis: Vector2=a.mon.position.direction_to(b.mon.position)
				if axis==Vector2.ZERO: axis=a.dir
				for strike in [a,b]:
					var distance:=12.0
					if a.hit.power!=b.hit.power: distance=8.0 if strike.hit.power>0 else 16.0
					release.append({"actor":strike.mon,"axis":-axis if strike==a else axis,"distance":distance,
						"use_hit_knock":residual_knock and a.hit.power!=b.hit.power})
			for strike in [a,b]:
				var actor: Mon=strike.mon
				remaining_cut_scale[actor]=float(strike.hit.power)/float(strike.hit.original_power)
				actor.hitstop_t=maxf(actor.hitstop_t,HOLD)
				actor.glide.clear()
				if strike.hit.power<=0:
					strike.cancel=true
				else:
					strike.t=HOLD+dt
					strike.hit["held_contact"]=true
			var at: Vector2=(a.mon.position+b.mon.position)*.5
			contacts.append(at)
			if not rebound_study:
				for angle in [-.75,.52]:
					add_fx("sprite",at+Vector2.UP*4,{"text":"g4_streak","size":6.5,"stretch":1.8,"rot":angle,"color":Color(1,.88,.62,.8),"lifetime":.12,"fade_out":.65})
	if not contacts.is_empty() and player.hitstop_t>0: held_melee_steps+=1
	super._step_pending_melee(dt)
	# Let the surviving attack resolve at contact, then apply one impulse per body.
	if not release.is_empty() and pending_melee.is_empty() and release[0].actor.hitstop_t<=0:
		for push in release:
			var actor: Mon=push.actor
			# The strike normally advances its owner on the final lunge frame.
			# A clash ends that forward motion as the bodies peel apart.
			actor.attack_lunge=false
			if push.use_hit_knock:
				push.distance=actor.knock.length_squared()/(2.0*Mon.KNOCK_DECEL)
			else:
				actor.knock=push.axis*knock_speed(push.distance)
			separation.append({"actor":actor,"axis":push.axis,"start":actor.position,"distance":push.distance})
		release.clear()

func _melee_arc(mon: Mon, move: Dictionary, hit: Dictionary, dir: Vector2) -> void:
	if forward_cuts and hit.get("held_contact",false) and hit.move in ["scratch","slash"]:
		# The two cuts have already played in front of their owners.
		move=move.duplicate()
		move.fx=""
	super._melee_arc(mon,move,hit,dir)

func _hitstop(target: Mon,hit: Dictionary,dmg: int,crit: bool) -> void:
	if not hit.get("held_contact",false):
		super._hitstop(target,hit,dmg,crit)
	elif residual_knock:
		# The common hit path already supplied this move's full impulse against
		# this target. Distance under constant deceleration is proportional to v².
		full_knock_distance=target.knock.length_squared()/(2.0*Mon.KNOCK_DECEL)
		var fraction:=clampf(float(hit.power)/float(hit.original_power),0.0,1.0)
		target.knock*=sqrt(fraction)
		if target.dead and target.dying_t>0.0:
			target.dying_t=target.knock.length()/Mon.KNOCK_DECEL

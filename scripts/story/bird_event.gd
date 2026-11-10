extends RefCounted
const Flight=preload("res://scripts/data/pokemon_flight.gd")

# The same second airborne Space discovers the friend, then calls for a ride.
const ID := "pidgeotto_nest"
const ARENA := "arena_bird_nest"
const WON := "bird_nest_battle_won"
const FRIEND := "friend_bird_fly"
const COUNT := 12
const INTERVAL := 1.8
const CHICK_LEVEL := 16
const BOSS_LEVEL := 25
const DIVE_TIME := 0.40
const DIVE_HEIGHT := 70.0
const GRIP_TIME := 0.07
const PULL_TIME := 0.24
const FLYBY_DEPART_TIME := 0.36
const ARRIVE_TIME := 1.2
const RELEASE_TIME := 0.12
const LEAVE_TIME := 0.8
const NEST_PASS_TIME := 0.24
const NEST_THROW_TIME := 0.44
const NEST_SETTLE_TIME := 0.16
const NEST_THROW_HEIGHT := 54.0
const NEST_THROW_DISTANCE := 72.0
const SELF_READY_TIME := 0.20
const SELF_DEPART_TIME := 0.44
const OPEN_MAPS := ["kanto_south","kanto_north","kanto_east","cerulean_north","viridian_forest","kanto_rock_pass","saffron_city","route11","kanto_world","safari_zone_center","safari_zone_east","safari_zone_north","safari_zone_west"]
var game: Node
var helper: Mon
var phase := "idle"
var elapsed := 0.0
var focus := Vector2.ZERO
var origin := Vector2.ZERO
var safe_at := Vector2.ZERO
var entry := Vector2.ZERO
var direction := Vector2.UP
var spawned := 0
var pidgey_defeated := 0
var boss_spawned := false
var spawn_t := 0.2
var pickup_at := Vector2.ZERO
var pickup_lift := 0.0
var contact_lift := 0.0
var carry_lift := 0.0
var carry_gap := 18.0
var gripped := false
var talons_ready := false
var pull_started := false
var dive_traced := false
var pickup_stage := "idle"
var travel_target: Dictionary={}
var leave_lift := 0.0
var camera_locked := false
var camera_at := Vector2.ZERO
var camera_zoom := 1.0
var flyby_speed := 0.0
var arrival_height := 160.0
var nest_from := Vector2.ZERO
var nest_released := false
var nest_landed := false
var nest_stage := "idle"
var self_flight := false
var landing_grip := Vector2.ZERO
var landing_overlap := 0.0
var nest_chick_feet_offset := 0.0
var learned_pages: Array=[]

func setup(owner: Node) -> void:
	game=owner

func arrive(fly_to: String="", back: Dictionary={}) -> void:
	camera_locked=false
	self_flight=false
	if fly_to!="":
		_arrive_flight(fly_to,back)
	elif DungeonDB.current==ARENA:
		game.total_enemies=COUNT+1;game.defeated=0
		game.world.start_battle(nest_center(),0.0)
		game.world.arena_cam=false
		origin=game.world.player.position;focus=origin
		direction=Vector2(1,-0.08).normalized()
		nest_from=origin-direction*NEST_THROW_DISTANCE
		var p: Player=game.world.player
		p.position=nest_from-direction*(NEST_THROW_DISTANCE/NEST_THROW_TIME)*NEST_PASS_TIME
		p.lift=NEST_THROW_HEIGHT;p.hop_t=0.0;p.dash={};p.facing=Vector2.DOWN
		p.set_meta("screen_facing",true)
		_spawn_helper("pidgeotto",p.position);_attach()
		entry=helper.position
		nest_released=false;nest_landed=false;nest_stage="carried"
		phase="drop";elapsed=0.0;game.state="bird_event"
		for i in 6:
			var chick:=_actor("pidgey",_nest_feet("roosts",i))
			nest_chick_feet_offset=chick.feet_offset()
			chick.position.y-=nest_chick_feet_offset
			chick.facing=(origin-chick.position).normalized()
			chick.set_meta("nest_spectator",true)
	elif game.events.has(WON) and not game.events.has(FRIEND) and DungeonDB.current in OPEN_MAPS:
		# WON is saved at the source before returning; interrupted rewards resume here.
		origin=game.world.player.position;safe_at=origin;focus=origin
		_spawn_helper("pidgeotto",origin)
		game.world.player.lift=48.0
		game.world.player.set_meta("carried",true)
		phase="returning";elapsed=0.0;game.state="bird_event"
		_attach()

func press_space() -> bool:
	if phase!="idle" or game.state not in ["fight","town"] or game.mode!="overworld" or not game.battle.is_empty():return false
	var p: Player=game.world.player
	if p.dead or p.travel_terrain!=0 or p.hop_t<=0.0 or not bool(p.dash.get("hop",false)) or DungeonDB.current not in OPEN_MAPS:return false
	origin=p.dash.get("from",p.position)
	if not can_land(origin):return false
	game.learn_field_hms()
	if game.events.has(FRIEND) or game.FieldHMs.can_use(p,"fly"):
		safe_at=origin;phase="selecting"
		game._record_area_visit()
		game._menu_open("fly")
		game.fly_screen.open(Arena.area_at(p.position),game.events)
	elif game.events.has("visited_area_saffron_city"):_begin_pickup()
	else:return false
	return true

func choose_destination(id: String) -> void:
	if phase!="selecting" or game.state!="menu" or game.menu!="fly":return
	var target:=FlyDestinations.find(id)
	if not FlyDestinations.can_fly(id,game.events):return
	travel_target=target.duplicate(true)
	game._close_menu()
	_begin_pickup()

func cancel_destination() -> void:
	if phase!="selecting":return
	game._close_menu();phase="idle";travel_target={}

func _begin_pickup() -> void:
	var p: Player=game.world.player
	safe_at=origin;focus=p.position
	pickup_at=p.position
	pickup_lift=p.visual_shadow_height()
	contact_lift=maxf(6.0,pickup_lift*0.45)
	game.learn_field_hms()
	var friendly: bool=game.events.has(FRIEND) or game.FieldHMs.can_use(p,"fly")
	if friendly and game.FieldHMs.can_use(p,"fly"):
		_begin_self_flight()
		return
	direction=Vector2(1,-0.65).normalized() if friendly else Vector2(1,0.18).normalized()
	if friendly and is_instance_valid(game.view3d) and game.view3d.visible:
		direction=game.view3d.screen_move_world(direction).normalized()
	var approach:=maxf(240.0,game.game_view_size().length()*0.65)
	flyby_speed=approach/DIVE_TIME
	camera_locked=friendly
	camera_at=game.world.cam.position;camera_zoom=game.world.cam.zoom.x
	gripped=false;talons_ready=false;pull_started=false;dive_traced=false;pickup_stage="dive"
	game.world.field_water.cancel(game.world,false)
	game.world.scatter_enemies()
	if p.controller.has_method("stop_move"):p.controller.stop_move()
	p.dash={};p.trail.clear();p.hop_t=0.0;p.knock=Vector2.ZERO;p.vel=Vector2.ZERO
	p.lift=pickup_lift
	p.attack_anim_t=0.0;p.set_meta("screen_facing",true);p.set_meta("carried",false)
	var from:=pickup_at-direction*approach if friendly else pickup_at-direction*142.0-direction.orthogonal()*18.0
	_spawn_helper(carrier(p) if friendly else "pidgeotto",from)
	carry_gap=_grip_gap(p,helper,direction if friendly else -direction)
	_flight_pose("Charge")
	if friendly:
		helper.position+=Vector2(0,p.feet_offset()-helper.feet_offset())
		helper.lift=p.lift+carry_gap
		helper.facing=direction
	else:helper.lift=DIVE_HEIGHT
	entry=helper.position
	phase="calling" if friendly else "swoop"
	elapsed=0.0;game.state="bird_event"
	Sfx.cry(helper.species_id)
	if phase=="calling":Sfx.cry(p.species_id)

func _begin_self_flight() -> void:
	var p: Player=game.world.player
	self_flight=true;_remove_helper()
	direction=Vector2(1,-0.65).normalized()
	if is_instance_valid(game.view3d) and game.view3d.visible:
		direction=game.view3d.screen_move_world(direction).normalized()
	flyby_speed=maxf(240.0,game.game_view_size().length()*0.65)/DIVE_TIME
	camera_locked=true;camera_at=game.world.cam.position;camera_zoom=game.world.cam.zoom.x
	game.world.field_water.cancel(game.world,false);game.world.scatter_enemies()
	if p.controller.has_method("stop_move"):p.controller.stop_move()
	p.dash={};p.trail.clear();p.hop_t=0.0;p.knock=Vector2.ZERO;p.vel=Vector2.ZERO;p.hurt_t=0.0
	p.lift=pickup_lift;p.facing=direction
	p.set_meta("screen_facing",true);p.set_meta("carried",false)
	_self_pose(p)
	phase="self_ready";elapsed=0.0;game.state="bird_event"
	Sfx.cry(p.species_id)

func _self_pose(p: Player) -> void:
	p.attack_full_recovery=false;p.attack_lunge=false;p.attack_contact_hold=0.0;p.attack_contact_time=0.0
	var pose:=Flight.prepare_animation(p)
	if pose!="":
		p.play_attack(pose,9999.0,false)
		if pose!="Walk":p.set_meta("loop_animation",pose)
	p.set_meta("self_flight_pose",true);p.queue_redraw()

func _clear_self_pose(p: Player) -> void:
	if not p.get_meta("self_flight_pose",false):return
	p.remove_meta("self_flight_pose")
	if p.has_meta("loop_animation"):p.remove_meta("loop_animation")
	p.attack_anim_t=0.0;p.attack_lunge=false;p.queue_redraw()

func _finish_self_landing() -> void:
	var p: Player=game.world.player
	_clear_self_pose(p)
	p.lift=0.0;p.set_meta("screen_facing",false);p.set_meta("carried",false)
	self_flight=false;phase="idle";game.state="fight";game.world.no_skills=false
	if p.controller.has_method("stop_move"):p.controller.stop_move()
	game._save_here()

static func carrier(p: Mon) -> String:
	return PokemonSize.carrier_for(p.size_tier)

func _actor(species: String, at: Vector2) -> Mon:
	var mon:=Mon.new();mon.setup(species,CHICK_LEVEL if species=="pidgey" else BOSS_LEVEL,Mon.TEAM_ENEMY)
	mon.position=at;mon.set_meta("screen_facing",true)
	game.world.add_child(mon);game.world.bystanders.append(mon)
	return mon

func _spawn_helper(species: String, at: Vector2) -> void:
	_remove_helper()
	helper=_actor(species,at)
	_flight_pose("Double")
	helper.lift=70.0
	carry_gap=_grip_gap(game.world.player,helper,game.world.player.facing)

func _remove_helper() -> void:
	if is_instance_valid(helper):
		game.world.bystanders.erase(helper);helper.queue_free()
	helper=null

func _page(key: String, speaker: Mon) -> Dictionary:
	return {"text":speaker.display_name()+": "+Lang.t(key),"speaker":weakref(speaker)}

func _flight_pose(animation: String) -> void:
	if animation=="Double":
		var pose:=Flight.prepare_animation(helper)
		if pose=="Flight":
			# The carrier uses intact Shoot wing strokes, aligned by native markers.
			helper._sprites[pose]["native_frames"]=true
			helper._sprites["Double"]=helper._sprites[pose]
	helper.set_meta("loop_animation",animation)
	helper.play_attack(animation,0.0,false)
	helper.attack_anim_t=9999.0

func _talons_out() -> void:
	talons_ready=true
	_flight_pose("Attack")
	var anim: Dictionary=helper._sprites[helper.attack_anim]
	var contact_time:=MonSprite.frame_start(anim,int(anim.get("hit_frame",0)))
	# Align the native talon strike with physical contact, rather than looping
	# flapping wings while the bird slides to a stop over the passenger.
	helper._attack_start=helper.anim_t-maxf(0.0,contact_time-maxf(0.0,DIVE_TIME-elapsed))

func _grip() -> void:
	gripped=true
	_talons_out()
	var p: Player=game.world.player
	p.set_meta("carried",true)
	p.facing=direction if phase=="calling" else -direction
	if phase=="swoop":p.hurt_t=maxf(0.0,0.13-(elapsed-DIVE_TIME))
	var offset:=Vector2(0,-p.radius*1.25)
	var contact: Fx=game.world.add_fx("sprite",p.position+offset,{"text":"g4_spark","follow":p,"offset":offset,
		"body_impact":true,"size":5.0,"grow":1.4,"lifetime":0.13,"fade_out":0.8,"color":Color(1,0.98,0.85,0.8)})
	contact.set_meta("bird_snatch_contact",true)
	game.world.add_fx("sprite",p.position+offset,{"text":"g4_ring","follow":p,"offset":offset,
		"body_impact":true,"size":10.0,"grow":1.8,"lifetime":0.16,"fade_out":0.8,"color":Color(1,1,1,0.65)})
	Sfx.move("tackle",0.12,-10.0)

func _step_pickup() -> void:
	if phase=="calling":
		_step_flyby_pickup()
		return
	var p: Player=game.world.player
	if elapsed<DIVE_TIME:
		pickup_stage="dive"
		var t:=clampf(elapsed/DIVE_TIME,0.0,1.0)
		var u:=t*t
		var a:=entry+direction*30.0-direction.orthogonal()*24.0
		var catch_at:=pickup_at+Vector2(0,p.feet_offset()-helper.feet_offset())
		var b:=catch_at-direction*28.0
		p.lift=lerpf(pickup_lift,contact_lift,t)
		helper.position=entry.bezier_interpolate(a,b,catch_at,u)
		var tangent:=3.0*(a-entry)*(1.0-u)*(1.0-u)+6.0*(b-a)*(1.0-u)*u+3.0*(catch_at-b)*u*u
		helper.facing=tangent.normalized()
		helper.lift=lerpf(DIVE_HEIGHT,p.lift+carry_gap,u)
		if t>=0.5 and not talons_ready:_talons_out()
		if t>=0.6 and not dive_traced:
			dive_traced=true
			Sfx.move("tail_whip",0.2,-12.0)
			for side in [-1,1]:
				var offset:=Vector2(-9,float(side)*4.0)
				game.world.add_fx("sprite",helper.position+offset,{"text":"g4_streak","follow":helper,"offset":offset,
					"body_impact":true,"size":1.4,"stretch":10.0,"rot":PI/2.0,"lifetime":0.12,"fade_out":0.8,"color":Color(1,1,1,0.6)})
	else:
		if not gripped:_grip()
		if elapsed<DIVE_TIME+GRIP_TIME:
			pickup_stage="grip"
			var t:=clampf((elapsed-DIVE_TIME)/GRIP_TIME,0.0,1.0)
			p.position=pickup_at+direction*4.0*smoothstep(0.0,1.0,t)
			p.lift=contact_lift+4.0*t
			_attach()
		else:
			pickup_stage="pull"
			if not pull_started:
				pull_started=true;_flight_pose("Double")
			var t:=clampf((elapsed-DIVE_TIME-GRIP_TIME)/PULL_TIME,0.0,1.0)
			p.position=pickup_at+direction*(4.0+30.0*t)
			p.lift=contact_lift+4.0+30.0*(1.0-pow(1.0-t,2.0))
			_attach()
			# A short lag makes the passenger's weight follow the talons' pull.
			helper.position+=direction*2.5*sin(PI*t)
			if t>=1.0:
				pickup_stage="carried"
				if phase=="calling":
					carry_lift=p.lift;origin=p.position
					phase="fly_depart";elapsed=0.0
				else:
					phase="caught"
					game._say_pages([_page("bird_caught",p)],_carry_away)
	focus=p.position

# A friendly ride crosses the frame at cruising speed. Contact changes who is
# attached to the talons, rather than braking the bird into a vertical hoist.
func _step_flyby_pickup() -> void:
	var p: Player=game.world.player
	if elapsed<DIVE_TIME:
		pickup_stage="dive"
		var t:=clampf(elapsed/DIVE_TIME,0.0,1.0)
		p.lift=lerpf(pickup_lift,contact_lift,t)
		helper.position=entry+direction*flyby_speed*elapsed
		helper.lift=p.lift+carry_gap
		helper.facing=direction
		if t>=0.5 and not talons_ready:_talons_out()
		if t>=0.6 and not dive_traced:
			dive_traced=true
			Sfx.move("tail_whip",0.2,-12.0)
			for side in [-1,1]:
				var offset: Vector2=-direction*9.0+direction.orthogonal()*float(side)*4.0
				game.world.add_fx("sprite",helper.position+offset,{"text":"g4_streak","follow":helper,"offset":offset,
					"body_impact":true,"size":1.4,"stretch":13.0,"rot":Vector2(1,-0.65).angle()+PI/2.0,
					"lifetime":0.13,"fade_out":0.8,"color":Color(1,1,1,0.6)})
	else:
		if not gripped:_grip()
		var since_contact:=elapsed-DIVE_TIME
		pickup_stage="grip" if since_contact<GRIP_TIME else "pull"
		if since_contact>=GRIP_TIME and not pull_started:
			pull_started=true;_flight_pose("Double")
		var t:=clampf(since_contact/(GRIP_TIME+PULL_TIME),0.0,1.0)
		p.position=pickup_at+direction*flyby_speed*since_contact
		p.lift=contact_lift+34.0*smoothstep(0.0,1.0,t)
		_attach()
		if t>=1.0:
			pickup_stage="carried";carry_lift=p.lift;origin=p.position
			phase="fly_depart";elapsed=0.0
	focus=pickup_at

func step(dt: float) -> void:
	elapsed+=dt
	game.world.step_fx(dt)
	var p: Player=game.world.player
	p.anim_t+=dt
	p.hurt_t=maxf(0.0,p.hurt_t-dt)
	p.vel=Vector2.ZERO
	if camera_locked:game._set_cam(camera_at,camera_zoom)
	elif landing_camera_active():game._set_cam(safe_at,World.CAM_ZOOM)
	elif nest_camera_active():game._set_cam(nest_center(),World.CAM_ZOOM)
	else:game._set_cam(focus-Vector2(0,p.lift),World.CAM_ZOOM)
	match phase:
		"self_ready":
			var t:=clampf(elapsed/SELF_READY_TIME,0.0,1.0)
			p.position=pickup_at;p.lift=lerpf(pickup_lift,maxf(12.0,pickup_lift)+5.0,smoothstep(0.0,1.0,t))
			if t>=1.0:
				carry_lift=p.lift;origin=p.position;phase="self_depart";elapsed=0.0
				Sfx.move("tail_whip",0.2,-10.0)
				for side in [-1,1]:
					var offset: Vector2=-direction*9.0+direction.orthogonal()*float(side)*4.0
					game.world.add_fx("sprite",p.position+offset,{"text":"g4_streak","follow":p,"offset":offset,
						"body_impact":true,"size":1.4,"stretch":13.0,"rot":Vector2(1,-0.65).angle()+PI/2.0,
						"lifetime":0.15,"fade_out":0.8,"color":Color(1,1,1,0.6)})
		"self_depart":
			var t:=clampf(elapsed/SELF_DEPART_TIME,0.0,1.0)
			p.position=origin+direction*flyby_speed*elapsed*(0.6+0.8*t)
			p.lift=carry_lift+28.0*t
			if t>=1.0:_travel()
		"swoop","calling":
			_step_pickup()
		"fly_depart":
			var t:=clampf(elapsed/FLYBY_DEPART_TIME,0.0,1.0)
			p.position=origin+direction*flyby_speed*elapsed
			p.lift=carry_lift+14.0*t
			_attach()
			if t>=1.0:_travel()
		"carry_out","take_home":
			var t:=clampf(elapsed/1.1,0.0,1.0)
			p.lift=lerpf(carry_lift,125.0,t*t)
			p.position=origin+direction*65.0*t
			_attach();focus=p.position
			if t>=1.0:
				if phase=="take_home":game._leave_arena();phase="transition"
				else:_enter_nest()
		"drop":
			_step_nest_throw()
		"boss_arrival":
			var t:=clampf(elapsed/0.8,0.0,1.0)
			helper.position=entry.lerp(Arena.center()+Vector2(0,-Arena.TILE*3.0),t)
			helper.lift=65.0*(1.0-t)
			focus=p.position.lerp(helper.position,0.35)
			if t>=1.0:
				phase="boss_dialogue"
				game._say_pages([_page("bird_angry",helper),_page("bird_explain",p)],_boss_fight)
		"returning":
			var t:=clampf(elapsed/1.0,0.0,1.0)
			p.lift=48.0*(1.0-t)*(1.0-t)
			_attach()
			if t>=1.0:
				p.set_meta("carried",false)
				_stand_beside()
				phase="promise"
				game._say_pages([_page("bird_home",helper),_page("bird_dream",p),_page("bird_fan",helper),_page("bird_promise",helper)],_befriend)
		"farewell","flight_leave":
			var t:=clampf(elapsed/LEAVE_TIME,0.0,1.0)
			helper.position=entry+Vector2(-95,-70)*t
			helper.lift=leave_lift+70.0*t
			helper.facing=Vector2(-1,-1).normalized();helper.modulate.a=1.0-t*t
			if t>=1.0:
				var reward:=phase=="farewell"
				_remove_helper();phase="idle";p.lift=0.0;p.set_meta("screen_facing",false);p.set_meta("carried",false)
				game.state="fight";game.world.no_skills=false
				if p.controller.has_method("stop_move"):p.controller.stop_move()
				game._save_here()
				if reward:
					game._say_pages([Lang.t("bird_friend_gained")]+learned_pages+[Lang.t("bird_friend_hint")])
					learned_pages=[]
		"fly_arrive":
			var t:=clampf(elapsed/ARRIVE_TIME,0.0,1.0)
			p.position=safe_at;p.lift=arrival_height*pow(1.0-t,2.0)
			if not self_flight:_attach()
			focus=p.position
			if t>=1.0:
				# Keep supporting the passenger briefly after their feet touch down.
				phase="landing_release";elapsed=0.0
				if self_flight:_clear_self_pose(p)
		"landing_release":
			p.position=safe_at;p.lift=0.0
			if not self_flight:_attach()
			if elapsed>=RELEASE_TIME:
				if self_flight:_finish_self_landing()
				else:
					p.set_meta("carried",false)
					leave_lift=helper.lift
					phase="flight_leave";elapsed=0.0;entry=helper.position

func landing_camera_active() -> bool:
	return phase in ["fly_arrive","landing_release","flight_leave"]

func nest_camera_active() -> bool:
	return phase in ["drop","nest_intro"]

# Arena.center() is the player's landing point, south of the actual bowl.
# Layout coordinates denote feet, so sprite size cannot push roosts over the lip.
func nest_center() -> Vector2:
	var center: Array=Arena.map.arena.nest.center
	return Vector2(float(center[0]),float(center[1]))*Arena.TILE

func _nest_feet(kind: String, index: int) -> Vector2:
	var points: Array=Arena.map.arena.nest[kind]
	var point: Array=points[index%points.size()]
	return Vector2(float(point[0]),float(point[1]))*Arena.TILE

# The first visit is a delivery of prey: fly over the nest, fling the passenger
# forward, and peel away while the passenger completes a separate ballistic arc.
func _step_nest_throw() -> void:
	var p: Player=game.world.player
	var speed:=NEST_THROW_DISTANCE/NEST_THROW_TIME
	if elapsed<NEST_PASS_TIME:
		p.position=nest_from-direction*speed*(NEST_PASS_TIME-elapsed)
		p.lift=NEST_THROW_HEIGHT
		_attach()
		return
	var after_release:=elapsed-NEST_PASS_TIME
	if not nest_released:
		nest_released=true;nest_stage="thrown"
		p.set_meta("carried",false)
		_flight_pose("Attack")
		Sfx.move("tail_whip",0.15,-12.0)
	if after_release>=0.10 and helper.attack_anim!="Double":_flight_pose("Double")
	helper.position=entry+direction*(speed*elapsed+160.0*after_release*after_release)
	helper.lift=NEST_THROW_HEIGHT+carry_gap+190.0*after_release
	helper.facing=direction
	helper.modulate.a=1.0-smoothstep(NEST_THROW_TIME*0.72,NEST_THROW_TIME+NEST_SETTLE_TIME,after_release)
	var t:=clampf(after_release/NEST_THROW_TIME,0.0,1.0)
	p.position=nest_from.lerp(origin,t)
	p.lift=NEST_THROW_HEIGHT*(1.0-t)+32.0*4.0*t*(1.0-t)
	p.hurt_t=maxf(0.0,0.14-after_release)
	if t>=1.0:
		p.position=origin;p.lift=0.0
		p.set_meta("screen_facing",false)
		if not nest_landed:
			nest_landed=true;nest_stage="impact"
			game.world._hop_land_fx(p)
			Sfx.move("tackle",0.12,-14.0)
		p.landing_t=maxf(0.0,Mon.LANDING_DURATION-(after_release-NEST_THROW_TIME))
		if after_release>=NEST_THROW_TIME+NEST_SETTLE_TIME:
			_remove_helper();nest_stage="settled";p.landing_t=0.0
			phase="nest_intro"
			game._say_pages([Lang.t("bird_nest_drop"),Lang.t("bird_chicks_hungry"),_page("bird_defend",p)],_fight)

func _attach() -> void:
	var p: Player=game.world.player
	p.set_meta("carried",true)
	helper.position=p.position+Vector2(0,p.feet_offset()-helper.feet_offset())
	if phase in ["fly_arrive","landing_release"]:carry_gap=_landing_carry_gap(p)
	helper.lift=p.lift+carry_gap
	helper.facing=direction

# Grip the passenger's head/shoulder region using the scaled native pixels.
# Collision radius is a ground footprint and no longer describes body height.
func _grip_gap(passenger: Mon, bird: Mon, facing: Vector2) -> float:
	var heights:=_grip_heights(passenger,bird,facing)
	return maxf(12.0,heights.x-heights.y)

func _grip_heights(passenger: Mon, bird: Mon, facing: Vector2) -> Vector2:
	if not passenger._sprites.has("Walk"):return Vector2(passenger.display_span*0.65+6.0,0.0)
	var head_anim: Dictionary=passenger._sprites.get("Idle",passenger._sprites.Walk)
	var head:=MonSprite.visual_frame(head_anim,MonSprite.row_for(head_anim,facing),0.0)
	var head_top:=_central_edge(head,(head.body_center as Vector2).x,true)
	var head_height: float=(float(passenger._sprites.feet_dy)-1.0+(head.body_center as Vector2).y-head_top)*passenger.sprite_scale
	var wing_anim: Dictionary=bird._sprites.get("Double",bird._sprites.Walk)
	var row:=MonSprite.row_for(wing_anim,direction)
	var wing:=MonSprite.visual_frame(wing_anim,row,0.0)
	var torso:=MonSprite.flight_anchor(wing_anim,row,0.0,wing)
	var claw:=_central_edge(wing,torso.x,false)
	var claw_height: float=(float(bird._sprites.feet_dy)-1.0+torso.y-claw)*bird.sprite_scale
	return Vector2(head_height,claw_height)

func _landing_carry_gap(passenger: Mon) -> float:
	var gap:=landing_grip.x-landing_grip.y-landing_overlap
	var view=game.view3d
	if not is_instance_valid(view) or not view.visible or not view._cam_ready:return maxf(4.0,gap)
	# Solve contact in the camera plane: perspective otherwise opens an air gap
	# between two billboards even when their 2D pixel heights meet exactly.
	var up: Vector3=view.cam.global_basis.y
	var back: Vector3=view.cam.global_basis.z
	var feet:=passenger.position+Vector2(0,passenger.feet_offset())
	var relative: Vector3=view.to3d(feet,passenger.lift/Arena.TILE*view.bill)-view.cam.global_position
	var head:=relative+up*((landing_grip.x-landing_overlap)/Arena.TILE)
	var claw:=relative+up*(landing_grip.y/Arena.TILE)
	var lift: Vector3=Vector3.UP*(view.bill/Arena.TILE)
	if view.cam.projection==Camera3D.PROJECTION_ORTHOGONAL:return maxf(4.0,gap/(view.bill*up.y))
	var ratio:=head.dot(up)/maxf(0.001,-head.dot(back))
	var denominator: float=lift.dot(up)+ratio*lift.dot(back)
	if absf(denominator)<0.001:return maxf(4.0,gap)
	return maxf(4.0,(-ratio*claw.dot(back)-claw.dot(up))/denominator)

func _central_edge(visual: Dictionary, x: float, top: bool) -> float:
	var image: Image=visual.tex.get_image()
	if image.is_compressed():image.decompress()
	var rect:=Rect2i(visual.src)
	for step in rect.size.y:
		var y:=step if top else rect.size.y-1-step
		for column in range(maxi(0,int(x)-4),mini(rect.size.x,int(x)+5)):
			if image.get_pixel(rect.position.x+column,rect.position.y+y).a>0.5:return float(y)
	return float(rect.size.y)*0.5

func _stand_beside() -> void:
	var p: Player=game.world.player
	var landed:=false
	for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
		var at: Vector2=p.position+d*Arena.TILE*1.5
		if can_land(at):
			helper.position=at;landed=true;break
	helper.lift=0.0 if landed else 32.0
	helper.attack_anim_t=0.0 if landed else 9999.0
	helper.facing=(p.position-helper.position).normalized();p.facing=-helper.facing

func _carry_away() -> void:
	carry_lift=game.world.player.lift
	phase="carry_out";elapsed=0.0;origin=game.world.player.position

func _enter_nest() -> void:
	game.arena_trip={"event":ID,"arena":ARENA,"back":{"map":DungeonDB.current,"pos":safe_at,"layout":int(DungeonDB.LAYOUTS.get(DungeonDB.current,1)),"pursuit_visit":game.road_pursuit.snapshot()}}
	# Save the source through _save_here(), while leaving the airborne actors
	# untouched until the fade finishes. Resetting them here caused a ground snap.
	game._carry_out();game._save_here()
	game.destination={"map":ARENA};game.state="warp";phase="transition"
	var tw:=game.create_tween();tw.tween_property(game.fader,"color:a",1.0,0.25)
	tw.tween_callback(func():game.get_tree().reload_current_scene())

func _fight() -> void:
	phase="battle";game.state="fight";game.world.no_skills=false
	Bgm.play("seq_ba_train")

func step_battle(dt: float) -> void:
	if phase!="battle" or game.world.player.dead:return
	spawn_t-=dt
	if spawned<COUNT and spawn_t<=0.0:
		_queue_chick();spawned+=1;spawn_t=INTERVAL
	elif pidgey_defeated==COUNT and not boss_spawned and game.world.remaining()==0:
		boss_spawned=true;phase="boss_arrival";elapsed=0.0
		entry=nest_center()+Vector2(90,-85)
		_spawn_helper("pidgeotto",entry);game.state="bird_event"
		Sfx.cry("pidgeotto")
	elif boss_spawned and game.defeated==COUNT+1 and game.world.remaining()==0:
		game.world.clear_enemy_projectiles();game.world.no_skills=true
		# Finish the parent's fall before replacing it with the speaking actor.
		for enemy in game.world.enemies:
			if enemy.species_id=="pidgeotto" and enemy.dead and enemy.faint_t>0.0:return
		phase="apology";game.world.end_battle();game.world.clear_enemy_projectiles()
		_spawn_helper("pidgeotto",game.world.player.position+Vector2(Arena.TILE*1.5,0))
		_stand_beside()
		game.world.no_skills=true
		_flag(WON);game._save_here()
		game._say_pages([_page("bird_strong",helper),_page("bird_sorry",helper)],_take_home)

func _queue_chick() -> void:
	var at:=_nest_feet("entries",spawned)+Vector2(0,-nest_chick_feet_offset)
	var delay:=0.6
	var from_roost:=false
	# The birds seen in the introduction join the fight one at a time.
	# Keep the others waiting on the rim instead of making the flock disappear.
	for mon in game.world.bystanders:
		if mon.get_meta("nest_spectator",false):
			at=mon.position;delay=0.05;from_roost=true
			game.world.bystanders.erase(mon);mon.queue_free();break
	if not from_roost and at.distance_to(game.world.player.position)<Arena.TILE*3.0:
		var feet:=at+Vector2(0,nest_chick_feet_offset)
		at=nest_center()*2.0-feet-Vector2(0,nest_chick_feet_offset)
	game.world.pending_spawns.append({"species":"pidgey","level":CHICK_LEVEL,"pos":at,"t":delay,"no_exp":true,"moves":["peck"]})
	game.world.add_fx("spawn",at,{"lifetime":0.6,"size":8.0,"color":Color("f6deb0")})

func _boss_fight() -> void:
	var at:=helper.position
	_remove_helper()
	game.world.pending_spawns.append({"species":"pidgeotto","level":BOSS_LEVEL,"pos":at,"t":0.3,"no_exp":true})
	phase="battle";game.state="fight"

func _take_home() -> void:
	helper.play_attack("Double",0.0,false);helper.attack_anim_t=9999.0
	carry_gap=_grip_gap(game.world.player,helper,game.world.player.facing)
	carry_lift=game.world.player.lift
	origin=game.world.player.position;focus=origin;phase="take_home";elapsed=0.0
	game.state="bird_event"

func _befriend() -> void:
	_flag(FRIEND);learned_pages=game.learn_field_hms();game._save_here();Bgm.fanfare(Bgm.ITEM)
	helper.play_attack("Double",0.0,false);helper.attack_anim_t=9999.0
	leave_lift=helper.lift
	phase="farewell";elapsed=0.0;entry=helper.position;focus=game.world.player.position
	game.state="bird_event"

func _flag(id: String) -> void:
	if not game.events.has(id):game.events.append(id)
	if not game.bot:SaveData.store_progress("events",id)

func defeated_enemy(enemy: Enemy) -> void:
	if enemy.species_id=="pidgey":pidgey_defeated+=1

func enemies_left() -> int:
	return COUNT-spawned+game.world.remaining()+(0 if boss_spawned else 1)

func boss() -> Enemy:
	for enemy in game.world.enemies:
		if enemy.species_id=="pidgeotto" and not enemy.dead:return enemy
	return null

func can_land(at: Vector2) -> bool:
	if not Arena.bounds().grow(-game.world.player.radius).has_point(at):return false
	if Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1 or Arena.is_water(Arena.tile_of(at)):return false
	if not Arena.warp_at(at).is_empty():return false
	for npc in game.world.npcs:
		if is_instance_valid(npc) and npc.position.distance_to(at)<game.world.player.radius+10.0:return false
	return true

func _travel() -> void:
	if travel_target.is_empty():return
	var back: Dictionary={"map":DungeonDB.current,"pos":safe_at,"layout":int(DungeonDB.LAYOUTS.get(DungeonDB.current,1))}
	game._carry_out();game._save_here()
	game.destination={"map":String(travel_target.map),"pos":FlyDestinations.position_of(travel_target),
		"layout":int(DungeonDB.LAYOUTS.get(String(travel_target.map),1)),"fly_arrival":String(travel_target.id),"fly_back":back}
	phase="transition";game.state="warp"
	var tw:=game.create_tween();tw.tween_property(game.fader,"color:a",1.0,0.25)
	tw.tween_callback(func():game.get_tree().reload_current_scene())

func arrival_point(id: String) -> Vector2:
	var target:=FlyDestinations.find(id)
	if target.is_empty() or not target.get("enabled",false):return Vector2.INF
	var area:=String(target.get("area",id))
	var source_fixture: bool=String(target.map)==KantoWorldTravel.ID and DungeonDB.KantoWorld.LEGACY_OFFSETS.has(DungeonDB.current)
	if String(target.map)!=DungeonDB.current and not source_fixture:return Vector2.INF
	var preferred:=Arena.tile_of(FlyDestinations.position_of(target))
	if source_fixture:
		var bounds:=Arena.area_rect(area)
		if bounds.size==Vector2i.ZERO:return Vector2.INF
		var local: Array=target.get("local_tile",[])
		if local.size()==2:preferred=bounds.position+Vector2i(int(local[0]),int(local[1]))
	# Recheck live collision patches, doors, cut trees and NPCs after loading.
	for radius in 9:
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				if maxi(absi(x),absi(y))!=radius:continue
				var at:=Arena.tile_center(preferred+Vector2i(x,y))
				if Arena.area_at(at)==area and can_land(at):return at
	return Vector2.INF

func _arrive_flight(id: String, back: Dictionary) -> void:
	var at:=arrival_point(id)
	if at==Vector2.INF:
		# A changed map must not strand the player in a wall or overwrite the source save.
		game._carry_out();game.destination=back.duplicate(true)
		game.state="warp"
		game.call_deferred("_reload_after_flight_failure")
		return
	safe_at=at;origin=at;focus=at;direction=Vector2.DOWN
	var p: Player=game.world.player
	arrival_height=maxf(160.0,game.game_view_size().y*0.75)
	# Perspective brings elevated actors above the top edge much sooner than 2D.
	# Start just outside the frame so most of the descent remains visible.
	if is_instance_valid(game.view3d) and game.view3d.visible:arrival_height=96.0
	p.position=at;p.travel_terrain=0;p.lift=arrival_height;p.hop_t=0.0;p.dash={};p.vel=Vector2.ZERO
	p.facing=Vector2.DOWN;p.set_meta("screen_facing",true)
	game.learn_field_hms()
	self_flight=game.FieldHMs.can_use(p,"fly")
	phase="fly_arrive";elapsed=0.0;game.state="bird_event"
	if self_flight:
		_remove_helper();p.set_meta("carried",false);_self_pose(p)
	else:
		_spawn_helper(carrier(p),at)
		landing_grip=_grip_heights(p,helper,Vector2.DOWN)
		landing_overlap=2.0*minf(p.sprite_scale,helper.sprite_scale)
		_attach()
	game.warp_armed=true;game._save_here()
	Sfx.cry(p.species_id if self_flight else helper.species_id)

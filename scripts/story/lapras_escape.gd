extends RefCounted

# Legacy filename/flag retained for saves; only Surf support remains here.
const Data=preload("res://scripts/data/lapras_escape.gd")
const Ride=preload("res://scripts/view/lapras_ride.gd")
const FRIEND=Data.FRIEND
const CALL_TIME:=0.35
const SWIM_TIME:=0.65
const RIDE_LIFT:=11.0
const SELF_SURF_TIME:=0.45
var game: Node
var helper: Mon
var phase:="idle"
var elapsed:=0.0
var focus:=Vector2.ZERO
var safe_at:=Vector2.ZERO
var call_from:=Vector2.ZERO
var call_to:=Vector2.ZERO
var call_path: Array[Vector2]=[]
var mounted:=false
var departing:=false
var departure_t:=0.0
var ride: RefCounted

func setup(owner: Node) -> void:game=owner

func text(_key: String) -> String:
	return "물 위를 건너려면\n도와줄 친구가 필요하다." if Lang.is_ko() else "You'll need a friend's help\nto travel across the water."

func _actor(at: Vector2,water: bool) -> Mon:
	var mon:=Mon.new();mon.setup("lapras",25,Mon.TEAM_PLAYER)
	mon.position=at-Vector2(0,mon.feet_offset());mon.facing=Vector2.DOWN
	mon.travel_terrain=1 if water else 0
	mon.set_meta("screen_facing",true)
	game.world.add_child(mon);game.world.bystanders.append(mon)
	return mon

func step(dt: float) -> void:
	elapsed+=dt
	game.world.step_fx(dt);game.world._step_bystanders(dt)
	if phase=="calling":
		if elapsed>=CALL_TIME:
			phase="boarding";elapsed=0.0
			helper=_actor(call_from,true)
			Sfx.cry("lapras")
	elif phase=="boarding":
		var k:=smoothstep(0,1,clampf(elapsed/SWIM_TIME,0,1))
		var before:=helper.position
		helper.position=_swim_point(k)-Vector2(0,helper.feet_offset())
		helper.vel=(helper.position-before)/maxf(dt,0.001)
		if helper.vel.length()>0.1:helper.facing=helper.vel.normalized()
		if k>=1.0:
			if game.world.field_water.surf(game.world):
				mounted=true;_sync_mount(0.0)
			else:_remove_helper()
			phase="idle";game.state="fight"
	elif phase=="self_surf":
		game.world.player.anim_t+=dt;game.world.player.attack_anim_t=maxf(0.0,game.world.player.attack_anim_t-dt)
		var k:=clampf(elapsed/SELF_SURF_TIME,0.0,1.0)
		game.world.player.position=safe_at.lerp(call_to,smoothstep(0.0,1.0,k))
		game.world.player.lift=sin(PI*k)*Arena.TILE*0.35
		if k>=1.0:
			game.world.player.position=call_to;game.world.player.lift=0.0;game.world.player.attack_anim_t=0.0
			phase="idle";game.state="fight";game._save_here()
func can_call() -> bool:
	return (game.events.has(FRIEND) or game.FieldHMs.can_use(game.world.player,"surf")) and game.mode=="overworld" and game.state=="fight" and phase=="idle" and game.battle.is_empty() and not game.world.player.dead and game.world.player.travel_terrain==0 and game.world.field_water.target(game.world)!=Vector2i(-1,-1) and not game.world.player.is_dashing()

func try_call() -> bool:
	game.learn_field_hms()
	if not can_call():return false
	var w: World=game.world
	var tile:=w.field_water.target(w)
	call_to=Arena.tile_center(tile)
	if Arena.resolve(call_to,w.player.radius,false,2).distance_to(call_to)>0.1:return false
	if game.FieldHMs.can_use(w.player,"surf"):
		safe_at=w.player.position;focus=safe_at.lerp(call_to,0.5)
		if not w.field_water.surf(w):return false
		_remove_helper();mounted=false
		w.player.position=safe_at;w.player.vel=Vector2.ZERO;w.player.set_meta("self_surf",true)
		if w.player.controller.has_method("stop_move"):w.player.controller.stop_move()
		w.player.play_attack("Hop");phase="self_surf";elapsed=0.0;game.state="lapras_event"
		return true
	# Approach through connected water only, never through an island or bank.
	var queue: Array[Vector2i]=[tile];var seen={tile:true};var parents: Dictionary={};var cursor:=0;var farthest:=tile
	while cursor<queue.size() and cursor<100:
		var at:=queue[cursor];cursor+=1
		if at.distance_to(tile)>farthest.distance_to(tile):farthest=at
		for direction in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var other: Vector2i=at+direction
			if seen.has(other) or not Arena.is_water(other) or other.distance_to(tile)>6.0:continue
			seen[other]=true;parents[other]=at;queue.append(other)
	call_from=Arena.tile_center(farthest)
	call_path.clear()
	var cursor_tile:=farthest
	call_path.append(Arena.tile_center(cursor_tile))
	while cursor_tile!=tile:
		cursor_tile=parents[cursor_tile];call_path.append(Arena.tile_center(cursor_tile))
	phase="calling";elapsed=0.0;safe_at=w.player.position;focus=safe_at.lerp(call_to,0.5)
	w.field_water.cancel(w,false);w.player.vel=Vector2.ZERO
	if w.player.controller.has_method("stop_move"):w.player.controller.stop_move()
	w.player.play_attack("Charge");Sfx.cry(w.player.species_id)
	game.state="lapras_event"
	return true

func _swim_point(progress: float) -> Vector2:
	if call_path.size()<2:return call_to
	var distance:=clampf(progress,0,1)*float(call_path.size()-1)
	var index:=mini(call_path.size()-2,int(distance))
	return call_path[index].lerp(call_path[index+1],clampf(distance-float(index),0,1))

func follow(dt: float) -> void:
	if game.mode!="overworld":return
	var p: Player=game.world.player
	if game.FieldHMs.can_use(p,"surf"):
		if is_instance_valid(helper) or ride!=null:_remove_helper()
		if mounted:p.lift=0.0
		mounted=false
		if p.travel_terrain==2:p.set_meta("self_surf",true)
		elif p.has_meta("self_surf"):p.remove_meta("self_surf")
		return
	if not game.events.has(FRIEND):return
	if p.get_meta("carried",false) or game.state=="bird_event":
		_remove_helper();mounted=false;return
	if p.travel_terrain==2 and Arena.is_water(Arena.tile_of(p.position)) and phase=="idle":
		if not is_instance_valid(helper):helper=_actor(p.position,true)
		mounted=true;_sync_mount(dt)
	elif mounted:
		mounted=false;p.lift=0.0
		_release_ride()
		if is_instance_valid(helper):departing=true;departure_t=0.0
	if departing and is_instance_valid(helper):
		departure_t+=dt;helper.modulate.a=1.0-clampf(departure_t/0.35,0,1)
		if departure_t>=0.35:_remove_helper()

func _sync_mount(_dt: float) -> void:
	if not is_instance_valid(helper):return
	var p: Player=game.world.player
	helper.position=p.position+Vector2(0,p.feet_offset()-helper.feet_offset())
	helper.vel=p.vel;helper.facing=p.facing
	p.lift=RIDE_LIFT
	if ride==null:ride=Ride.new();ride.setup(p,helper)
	ride.step()
	departing=false;helper.modulate.a=1.0

func _release_ride() -> void:
	if ride!=null:ride.detach();ride=null

func _remove_helper() -> void:
	_release_ride()
	if is_instance_valid(helper):game.world.bystanders.erase(helper);helper.queue_free()
	helper=null;departing=false

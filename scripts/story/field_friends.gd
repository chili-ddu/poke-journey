extends RefCounted

const Rescue=preload("res://scripts/story/forest_rescue.gd")
const TREE_DATA="res://assets/data/field_cut_trees.json"
const CALL_TIME:=0.55
const FLY_HEIGHT:=1.5*Arena.TILE
const ARRIVE_TIME:=0.18
const WALK_TIME:=0.9
const READY_TIME:=0.38
const CONTACT_HOLD:=0.1
const RECOVER_TIME:=0.22
const LOOK_TIME:=0.4
const LEAVE_TIME:=0.65
class CutTree:
	extends Npc
	func can_talk(pos: Vector2) -> bool:
		return talk!="" and pos.distance_to(position)<=Arena.TILE*1.5

var game: Node
var trees: Array[Npc]=[]
var helper: Mon
var target: Npc
var phase:="idle"
var elapsed:=0.0
var focus:=Vector2.ZERO
var work_at:=Vector2.ZERO
var entry_at:=Vector2.ZERO
var caller_at:=Vector2.ZERO
var tree_at:=Vector2.ZERO
var curve_a:=Vector2.ZERO
var curve_b:=Vector2.ZERO
var exit_at:=Vector2.ZERO
var gaze_at:=0.0
var camera_zoom:=1.0
var eye_glinted:=false
var cut_at:=0.0
var leave_at:=0.0
var sliced:=false
var cut:=false
var self_duration:=0.0

func setup(owner: Node) -> void:
	game=owner
	if game.mode!="overworld":return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(TREE_DATA))
	for area in data:
		var region:=Arena.area_rect(area)
		if region.size==Vector2i.ZERO:continue
		for point in data[area]:
			var local:=Vector2i(int(point[0]),int(point[1]))
			if not Rect2i(Vector2i.ZERO,region.size).has_point(local):continue
			var id:="cut_tree_%s_%d_%d"%[area,local.x,local.y]
			var tile: Vector2i=region.position+local
			if game.events.has(id):
				Arena.set_solid(tile,false)
				continue
			var tree:=CutTree.new()
			tree.setup({"id":id,"sprite":"cut_tree","talk":"friend_cut","tile":tile})
			game.world.add_child(tree);game.world.npcs.append(tree);trees.append(tree)
			Arena.set_solid(tile,true)

func talk(tree: Npc) -> void:
	if phase!="idle" or not is_instance_valid(tree):return
	game.learn_field_hms()
	if game.FieldHMs.can_use(game.world.player,"cut"):
		_self_cut(tree);return
	if not game.events.has(Rescue.FRIEND):
		game._say_pages([Lang.t("friend_cut_needed")])
		return
	call_friend(tree)

func _self_cut(tree: Npc) -> bool:
	if game.state not in ["fight","town"] or game.world.player.dead or not game.battle.is_empty():return false
	if game.mode!="overworld" or not trees.has(tree) or not tree.can_talk(game.world.player.position):return false
	target=tree;tree_at=tree.position;focus=tree_at
	var p: Player=game.world.player
	caller_at=p.position;p.vel=Vector2.ZERO
	game.world.field_water.cancel(game.world,false)
	if p.controller.has_method("stop_move"):p.controller.stop_move()
	p.facing=(tree_at-p.position).normalized()
	p.attack_contact_hold=0.0;p.attack_full_recovery=false
	p.play_attack("Slice",0.0,false)
	var anim: Dictionary=p._sprites.get(p.attack_anim,{})
	cut_at=MonSprite.frame_start(anim,int(anim.get("hit_frame",3))) if not anim.is_empty() else 0.15
	p.attack_contact_time=cut_at;p.attack_contact_hold=CONTACT_HOLD;p.attack_anim_t+=CONTACT_HOLD
	self_duration=p.attack_anim_t+RECOVER_TIME
	phase="self_cut";elapsed=0.0;cut=false;game.state="field_cut"
	return true

func call_friend(tree: Npc) -> bool:
	if phase!="idle" or game.state not in ["fight","town"] or game.world.player.dead:return false
	if game.mode!="overworld" or not game.battle.is_empty() or not game.events.has(Rescue.FRIEND):return false
	if not is_instance_valid(tree) or not trees.has(tree) or not tree.can_talk(game.world.player.position):return false
	target=tree
	var player: Player=game.world.player
	caller_at=player.position
	tree_at=tree.position
	camera_zoom=1.0
	game.world.field_water.cancel(game.world,false)
	player.vel=Vector2.ZERO
	if player.controller.has_method("stop_move"):player.controller.stop_move()
	player.play_attack("Charge",CALL_TIME,false)
	Sfx.cry(player.species_id)
	focus=player.position
	for pulse in 3:
		game.world.add_fx("sprite",player.position,{"text":"g4_ring","follow":player,"body_impact":true,
			"size":14.0,"grow":5.0,"lifetime":0.5+float(pulse)*0.08,"delay":float(pulse)*0.08,
			"color":Color(0.94,0.97,1.0,0.8),"fade_out":0.65})
	phase="calling";elapsed=0.0
	game.state="field_cut"
	return true

func _begin_cut() -> void:
	if not is_instance_valid(target):return
	phase="arriving";elapsed=0.0;sliced=false;cut=false;eye_glinted=false
	game.state="field_cut"
	helper=Mon.new();helper.setup("scyther",8,Mon.TEAM_PLAYER)
	helper.set_meta("screen_facing",true)
	work_at=target.position
	var best:=-INF
	var opposite: Vector2=(target.position-caller_at).normalized()
	# Land across the object; diagonal floor cells cover narrow native paths.
	for d in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
		var candidate:=Arena.tile_center(target.tile+d)
		if candidate.distance_to(caller_at)<Arena.TILE*0.8 or not _clear(candidate,helper.radius):continue
		var score:=Vector2(d).normalized().dot(opposite)*4.0-Vector2(d).length()*0.15
		if score>best:work_at=candidate;best=score
	if best==-INF:
		helper.free();helper=null;phase="idle";game.state="fight"
		return
	var away: Vector2=(work_at-target.position).normalized()
	var side:=away.orthogonal()
	entry_at=work_at+side*Arena.TILE*10.0+away*Arena.TILE*3.0
	curve_a=tree_at+side*Arena.TILE*5.0+away*Arena.TILE*6.0
	curve_b=work_at-side*Arena.TILE*2.0+away*Arena.TILE*2.5
	exit_at=work_at+Vector2(-9,-7)*Arena.TILE
	helper.position=entry_at-Vector2(0,helper.feet_offset())
	helper.facing=(work_at-entry_at).normalized()
	helper.lift=FLY_HEIGHT
	helper.modulate.a=0.0
	game.world.add_child(helper);game.world.bystanders.append(helper)
	game.world.player.vel=Vector2.ZERO
	game.world.player.facing=(target.position-caller_at).normalized()
	focus=tree_at
	var anim: Dictionary=helper._sprites["Slice"]
	cut_at=ARRIVE_TIME+WALK_TIME+READY_TIME+MonSprite.frame_start(anim,int(anim.get("hit_frame",3)))
	gaze_at=ARRIVE_TIME+WALK_TIME+READY_TIME+MonSprite.anim_length(anim)+CONTACT_HOLD+RECOVER_TIME
	leave_at=gaze_at+LOOK_TIME
	Sfx.cry("scyther")

func _clear(at: Vector2,radius: float) -> bool:
	return not Arena.is_water(Arena.tile_of(at)) and Arena.resolve(at,radius).distance_to(at)<0.1

func flight_point(progress: float) -> Vector2:
	var t:=clampf(progress,0.0,1.0)
	var u:=1.0-t
	return entry_at*u*u*u+curve_a*3.0*u*u*t+curve_b*3.0*u*t*t+work_at*t*t*t

func _eye_glint() -> void:
	eye_glinted=true
	helper.facing=Vector2.DOWN
	var anim: Dictionary=helper._sprites["Idle"]
	# Front Idle eye pixels sit at (12..13,13) and (18..19,13), above the
	# authored head marker (16,18). Match the body's source-frame anchor.
	var eye: Vector2=(Vector2(15.5,13)-MonSprite.anchor_of(helper._sprites,anim))*helper.sprite_scale+Vector2(0,helper.radius*Mon.GROUND_RATIO)
	for side in [-1,1]:
		var offset:=eye+Vector2(float(side)*3.0*helper.sprite_scale,0)
		var flash: Fx=game.world.add_fx("sprite",helper.position+offset,{"text":"g4_spark","follow":helper,"offset":offset,
			"body_impact":true,"size":7.0,"lifetime":0.2,"grow":0.45,"fade_in":0.04,"fade_out":0.7,"color":Color("fff9cb")})
		flash.set_meta("field_eye_glint",true)
	game.world.add_fx("sprite",helper.position+eye,{"text":"g4_streak","follow":helper,"offset":eye,"body_impact":true,
		"size":2.0,"stretch":9.0,"rot":PI/2.0,"lifetime":0.17,"grow":1.3,"fade_out":0.7,"color":Color.WHITE})
	Sfx.play("pinpon",1.35,-12.0)

func step(dt: float) -> void:
	if phase=="idle":return
	elapsed+=dt
	game.world.step_fx(dt)
	game.world.player.anim_t+=dt
	game.world.player.attack_anim_t=maxf(0.0,game.world.player.attack_anim_t-dt)
	if phase=="self_cut":
		game.world.player.vel=Vector2.ZERO
		if not cut and elapsed>=cut_at:_cut_tree()
		if elapsed>=self_duration:
			game.world.player.attack_contact_hold=0.0;game.world.player.attack_contact_time=0.0;game.world.player.attack_anim_t=0.0
			phase="idle";game.state="fight"
			game._say(Lang.t("field_cut_self_done",[game.world.player.display_name()]))
		game._set_cam(focus,World.CAM_ZOOM)
		return
	if phase=="calling":
		if elapsed>=CALL_TIME:
			if is_instance_valid(target):_begin_cut()
			else:
				phase="idle";game.state="fight"
		return
	# step_fx already advances bystander animation clocks once.
	helper.attack_anim_t=maxf(0.0,helper.attack_anim_t-dt)
	game.world.player.vel=Vector2.ZERO
	focus=tree_at
	camera_zoom=1.0
	helper.modulate.a=clampf(elapsed/ARRIVE_TIME,0.0,1.0)
	var foot:=Vector2(0,helper.feet_offset())
	if elapsed<ARRIVE_TIME:
		phase="arriving";helper.vel=Vector2.ZERO
	elif elapsed<ARRIVE_TIME+WALK_TIME:
		phase="approaching"
		var flight:=smoothstep(ARRIVE_TIME,ARRIVE_TIME+WALK_TIME,elapsed)
		var ahead: Vector2=flight_point(minf(1.0,flight+0.015))-flight_point(maxf(0.0,flight-0.015))
		helper.position=flight_point(flight)-foot
		helper.lift=FLY_HEIGHT*(1.0-flight)+sin(PI*flight)*Arena.TILE*0.75
		helper.vel=ahead/maxf(dt,0.0001)
		helper.facing=ahead.normalized()
	else:
		helper.position=work_at-foot;helper.vel=Vector2.ZERO;helper.lift=0.0
		var landing:=ARRIVE_TIME+WALK_TIME
		var windup:=smoothstep(landing,landing+READY_TIME*0.6,elapsed)
		camera_zoom=1.0+0.14*windup
		focus=tree_at.lerp(work_at,0.25*windup)
		helper.facing=Vector2.DOWN if elapsed<landing+READY_TIME-0.1 else (tree_at-work_at).normalized()
		phase="ready"
		if not eye_glinted and elapsed>=landing+0.08:_eye_glint()
		if elapsed>=ARRIVE_TIME+WALK_TIME+READY_TIME:
			phase="cutting"
			if not sliced:
				sliced=true
				helper.attack_contact_time=cut_at-(ARRIVE_TIME+WALK_TIME+READY_TIME)
				helper.attack_contact_hold=CONTACT_HOLD
				helper.play_attack("Slice",0.0,false)
		if not cut and elapsed>=cut_at:_cut_tree()
		if elapsed>=gaze_at:
			phase="looking"
			var look:=smoothstep(gaze_at,leave_at,elapsed)
			helper.facing=Vector2(-1,-1).normalized()
			camera_zoom=lerpf(1.14,1.2,look)
			focus=tree_at.lerp(work_at+Vector2(-0.3,-0.3)*Arena.TILE,look*0.55)
		if elapsed>=leave_at:
			phase="leaving"
			var progress:=clampf((elapsed-leave_at)/LEAVE_TIME,0.0,1.0)
			var control:=work_at+Vector2(-0.5,-4.0)*Arena.TILE
			var p0:=work_at.lerp(control,progress)
			var p1:=control.lerp(exit_at,progress)
			helper.position=p0.lerp(p1,progress)-foot
			helper.vel=(p1-p0)/LEAVE_TIME
			helper.facing=Vector2(-1,-1).normalized()
			helper.lift=FLY_HEIGHT*progress+sin(PI*progress)*Arena.TILE*0.5
			helper.modulate.a=clampf((1.0-progress)/0.3,0.0,1.0)
			camera_zoom=lerpf(1.2,1.0,smoothstep(0.0,1.0,progress))
			focus=tree_at.lerp(work_at+Vector2(-0.3,-0.3)*Arena.TILE,0.55*(1.0-progress))
		if elapsed>=leave_at+LEAVE_TIME:
			game.world.bystanders.erase(helper);helper.queue_free();helper=null
			game.world.player.vel=Vector2.ZERO
			phase="idle";game.state="fight"
			camera_zoom=1.0
			game._say(Lang.t("friend_cut_done"))
	game._set_cam(focus,World.CAM_ZOOM*camera_zoom)

func _cut_tree() -> void:
	cut=true
	var at:=target.position
	game.world.add_fx("sprite",at+Vector2(0,-5),{"text":"field_cut_crescent","size":43.0,"lifetime":0.28,
		"rot":-0.45,"spin":3.0,"grow":1.2,"fade_in":0.05,"fade_out":0.6})
	game.world.add_fx("sprite",at,{"text":"g4_claw3","size":25.0,"lifetime":0.16,"color":Color("f2ffe7")})
	for i in 10:
		game.world.add_fx("sprite",at,{"text":"g4_leaf" if i%2==0 else "g4_leaf_b","size":6.5+float(i%3),"lifetime":0.65,"dir":Vector2.from_angle(TAU*i/10.0),
			"speed":28.0+float(i%3)*7.0,"arc_h":10.0,"spin":4.0,"grow":0.5,"color":Color(0.92,1.0,0.85,0.95)})
	Sfx.move("slash")
	Arena.set_solid(target.tile,false)
	var id:=target.id
	game.world.npcs.erase(target);trees.erase(target);target.queue_free();target=null
	if not game.events.has(id):game.events.append(id)
	if not game.bot:SaveData.store_progress("events",id)
	game._save_here()

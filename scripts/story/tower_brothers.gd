extends RefCounted

const Data=preload("res://scripts/data/tower_brothers.gd")
const ID := "pokemon_tower_brothers"
const ENTRY_DELAY := 0.35
const APPEAR_TIME := 0.4
const BEFORE_DOUBLE := 0.25
const SPREAD_TIME := 0.85
const BROTHER_GAP := 0.45
const FORMATION_HOLD := 0.6
const AFTER_TIME := 0.8
const ATTACK_GAP := 0.28
const JOIN_LINES := {
	"third":["이번에는 나도 간다!\n내 열 분신까지 상대해 봐!","My turn to join in!\nFace my ten doubles too!"],
	"second":["이제 나까지 합세하겠다!\n끝까지 버틸 수 있겠어?","Now I'm joining my brothers!\nCan you last until the end?"]}
const INTRO := {
	2:[
		["youngest","히히! 여긴 우리 네 형제의 탑이야!\n막내인 내가 먼저 상대해 주지!","Hee hee! This tower belongs to us four\nbrothers! The youngest goes first!"],
		["youngest","내가 다섯이 되면 어떨까?\n어디 한번 전부 잡아 봐!","What if there were five of me?\nTry catching every one!"]],
	3:[
		["youngest","셋째 형! 바로 저 녀석이야!\n내 분신을 전부 없애 버렸어!","Brother! That's the one!\nIt got rid of all my doubles!"],
		["third","우리 막내를 울렸다고?\n형인 내가 가만둘 수 없지!","You made our little brother cry?\nI'm not letting that slide!"],
		["third","다섯은 너무 적었나 보네.\n열 명의 나를 상대해 봐!","Five wasn't enough, was it?\nTry taking on ten of me!"]],
	4:[
		["youngest","이번엔 혼자가 아니라고!\n형, 내가 먼저 상대할게!","I'm not alone this time!\nBrother, let me go first!"],
		["third","좋아. 먼저 해 봐.\n조금 뒤에 나도 합세하겠다!","All right, you go first.\nI'll join you shortly!"],
		["youngest","큰형한테는 못 가게 할 거야!","We won't let you reach our big brother!"]],
	5:[
		["third","둘째 형! 우리 둘이 힘을 합쳤는데도\n저 녀석이 다 이겨 버렸어!","Brother! We teamed up,\nbut it still beat both of us!"],
		["youngest","맞아! 열다섯이나 됐는데도!\n형이 우리 대신 혼내 줘!","Yeah! All fifteen of us!\nGet it back for us!"],
		["second","너희 둘은 뒤로 물러서 있어.\n이제부터는 내가 상대한다.","You two stand back.\nI'll handle this from here."],
		["second","고오스와 고우스트는 다르지.\n내 열 분신을 넘을 수 있겠어?","HAUNTER plays a different game.\nCan you get past my ten doubles?"]],
	6:[
		["youngest","둘째 형까지 졌어?!\n이러다 큰형한테 혼나겠어!","Even you lost?!\nOur big brother's going to be mad!"],
		["third","막내, 네가 먼저 상대해!\n곧 내 열 분신도 합세할 거야!","Little brother, you go first!\nMy ten doubles will join you soon!"],
		["second","나도 오래 기다려 주진 않겠다.\n셋이 합치면 스물다섯이다!","I won't wait long either.\nTogether, we make twenty-five!"],
		["youngest","여기서 끝이야!\n큰형한테는 절대 못 가!","This is as far as you go!\nYou won't get to our big brother!"]],
	7:[
		["youngest","큰형! 저 녀석이 우리를...!","Big brother! It beat us...!"],
		["third","셋이 같이 덤볐는데도 졌어...","Even all three of us lost together..."],
		["eldest","다 들었다. 너희가 시비를 걸어 놓고\n또 나한테 일러바치러 온 거냐?","I heard it all. You picked the fights,\nthen came running to tell on someone?"],
		["second","...그래도 여기까지 온 실력은\n형이 직접 확인해 봐야겠지?","...Still, you ought to see\nwhat it took to get this far."],
		["eldest","좋아. 동생들 몫까지 내가 상대하지.\n내 열 그림자를 모두 넘어 봐!","All right. I'll fight for my brothers.\nOvercome all ten of my shadows!"]]
}
const OUTRO := {
	2:[["youngest","으아! 내 분신을 전부 없애다니!\n셋째 형한테 다 일러바칠 거야!","Aah! You got every double!\nI'm telling my older brother!"],
		["youngest","내 형은 나보다 훨씬 강하다고!\n따라올 테면 따라와!","My brother is much stronger than me!\nFollow me if you dare!"]],
	3:[["third","열 분신까지 전부... 말도 안 돼!","All ten doubles... Impossible!"],
		["youngest","형도 졌잖아!\n다음 층에선 나랑 같이 싸워!","You lost too!\nFight with me on the next floor!"],
		["third","좋아. 큰형한테는 못 가게 하자!","Fine. We won't let anyone reach him!"]],
	4:[["youngest","둘이 같이했는데도 졌어...!","We lost even together...!"],
		["third","둘째 형! 도와줘!\n엄청 강한 녀석이 올라오고 있어!","Brother! Help us!\nSomeone really strong is coming!"]],
	5:[["second","내 분신까지 전부 걷어 냈군...\n하지만 아직 끝난 건 아니야!","You dispersed my doubles too...\nBut we aren't finished yet!"],
		["third","이번엔 우리 셋이 같이 막자!","Then the three of us stop it together!"],
		["youngest","맞아! 큰형한테는 절대로 못 가!","Yeah! You can't reach our big brother!"]],
	6:[["youngest","스물다섯인데도 졌어...\n이제 어떡하지, 형...?","All twenty-five of us lost...\nWhat do we do now...?"],
		["second","큰형을 불러야겠어.\n이 녀석은 우리 힘으로 못 막아.","We need our big brother.\nWe can't stop this one ourselves."],
		["third","큰형! 큰형!\n우리 대신 좀 싸워 줘!","Big brother! Big brother!\nFight for us!"]],
	7:[["eldest","내 열 그림자마저 모두 넘었구나.\n너, 정말 대단한 녀석이었군!","You overcame all ten of my shadows.\nYou really are something!"],
		["youngest","큰형까지 이기다니...\n그럼 우리보다 형인 거야?","You even beat our big brother...\nDoes that make you older than us?"],
		["third","그건 나이랑은 상관없잖아!","That's not how age works!"],
		["second","장난은 여기까지 하자.\n우리가 먼저 시비 걸어서 미안해.","That's enough mischief.\nSorry we started all this."],
		["eldest","우리 네 형제가 네 실력을 인정하마.\n다음엔 친구로 찾아와!","All four of us recognize your strength.\nCome visit as a friend next time!"]]
}

class Brother:
	extends Mon
	var brother_id := "youngest"
	func display_name() -> String:return Data.brother_name(brother_id)

class Double:
	extends Enemy
	var brother_id := "youngest"
	var unfolding := false
	func think(dt: float,world) -> void:
		if unfolding:
			vel=Vector2.ZERO;return
		super.think(dt,world)
	func display_name() -> String:
		return Data.brother_name(brother_id)+("의 분신" if Lang.is_ko() else "'s double")
	func _begin_windup(move_id: String,dir: Vector2,world) -> void:
		var event=world.get_parent().tower_brothers
		if event==null or not event.request_attack():return
		super._begin_windup(move_id,dir,world)

var game: Node
var floor_number := 0
var actors: Dictionary={}
var phase := "idle"
var elapsed := 0.0
var attack_t := 0.0
var spawned := false
var arrived := false
var focus := Vector2.ZERO
var doubles: Array[Enemy]=[]
var summon_step := "idle"
var summon_t := 0.0
var summon_index := -1
var active_brother := ""
var double_duration := 0.0
var released: Dictionary={}
var flights: Array=[]
var camera_wide := 0.0
var summon_log: Array=[]
var created := 0
var peak_active := 0
var battle_elapsed := 0.0
var intervention_pages: Array[String]=[]
var intervention_t := 0.0

func setup(owner: Node) -> void:
	game=owner
	floor_number=int(game.arena_trip.get("tower_floor",2)) if DungeonDB.current==Data.ARENA else Data.floor_number(DungeonDB.current)

func arrive() -> void:
	if arrived:return
	arrived=true
	if DungeonDB.current==Data.ARENA:
		floor_number=clampi(floor_number,2,7)
		game.total_enemies=Data.count(floor_number);game.defeated=0
		game.world.start_battle(Arena.center(),0.0);game.world.arena_cam=false
		game.world.no_skills=true
		_setup_actors(true)
		phase="ready"
		_begin_split()
	elif floor_number==1 and game.events.has(Data.COMPLETE) and not game.events.has("tower_brothers_rewarded") and game.events.has("visited_area_saffron_city"):
		game._say_pages(["네 형제는 네 실력을 인정하며 고마움의 선물을 남겼다." if Lang.is_ko() else "The four brothers left a gift in recognition of your strength."],_award_completion)
	elif floor_number>=2:
		if not game.events.has("visited_area_saffron_city"):return
		var next:=Data.next_floor(game.events)
		if next!=floor_number:
			_travel(next if next<=7 else 1);return
		_setup_actors(false)
		phase="intro"
		game._say_pages(_pages(INTRO[floor_number]),_enter_arena)

func _setup_actors(arena: bool) -> void:
	if not actors.is_empty():return
	if arena:
		game.world.player.position=Arena.tile_center(Vector2i(12,17))
	else:
		game.world.player.position=Arena.tile_center(Data.PLAYER_TILES[floor_number])
	game.world.player.vel=Vector2.ZERO;game.world.player.facing=Vector2.UP
	if game.world.player.controller.has_method("stop_move"):game.world.player.controller.stop_move()
	var speakers: Array=Data.SPEAKERS[floor_number]
	for i in speakers.size():
		var id: String=speakers[i];var cfg: Dictionary=Data.BROTHERS[id]
		var mon:=Brother.new();mon.brother_id=id;mon.setup(cfg.species,int(cfg.level),Mon.TEAM_PLAYER)
		var at:=Data.brother_position(i,speakers.size()) if arena else Arena.tile_center(Data.SPEAKER_TILES[floor_number][i])
		mon.position=at-Vector2(0,mon.feet_offset())
		mon.facing=Vector2.DOWN;mon.set_meta("screen_facing",true)
		mon.visible=not arena
		game.world.add_child(mon);game.world.bystanders.append(mon);actors[id]=mon
	focus=game.world.player.position.lerp((actors[speakers[-1]] as Mon).position,0.55)
	game._set_cam(focus,World.CAM_ZOOM)

func _pages(lines: Array) -> Array:
	var result: Array=[]
	for line in lines:
		var speaker: Mon=actors[line[0]]
		var text:=speaker.display_name()+": "+String(line[1 if Lang.is_ko() else 2])
		var width: float=game.hud.size.x-40.0
		for page in PixelUi.dialogue_pages(text,width):
			result.append({"text":page,"speaker":weakref(speaker)})
	return result

func _enter_arena() -> void:
	if phase!="intro":return
	var snap: Texture2D=null
	if DisplayServer.get_name()!="headless":
		var img:=game.get_viewport().get_texture().get_image()
		if img!=null and not img.is_empty():snap=ImageTexture.create_from_image(img)
	var layer:=CanvasLayer.new();layer.layer=90;game.add_child(layer)
	game.encounter=EncounterFx.new();game.encounter.setup("low",snap,{})
	game.encounter.size=game.get_viewport().get_visible_rect().size;layer.add_child(game.encounter)
	game.arena_trip={"event":ID,"tower_floor":floor_number,"arena":Data.ARENA,
		"back":{"map":Data.floor_id(floor_number),"pos":Arena.tile_center(Data.PLAYER_TILES[floor_number]),"layout":1}}
	phase="encounter";game.state="encounter";game.world.player.vel=Vector2.ZERO
	Bgm.play("seq_ba_train")

func _begin_split() -> void:
	if phase!="ready":return
	phase="cloning";elapsed=0.0;game.state="tower_event"
	summon_step="gap";summon_t=0.0
	Bgm.play("seq_ba_train")

func _next_brother() -> void:
	summon_index+=1
	active_brother=Data.STAGES[floor_number][summon_index]
	var actor: Mon=actors[active_brother]
	var at:=_safe_entry_position(game.world.player.position+Vector2.UP*Arena.TILE*3.0) if phase=="battle" else Data.brother_position(0,1)
	actor.position=at-Vector2(0,actor.feet_offset())
	actor.appear=0.0;actor.visible=true;actor.attack_anim_t=0.0
	summon_step="entry";summon_t=0.0
	summon_log.append({"brother":active_brother,"event":"entry","time":elapsed,"battle_time":battle_elapsed,"during_battle":phase=="battle","alive":game.world.remaining()})
	game.world.add_fx("spawn",actor.position,{"size":actor.radius,"lifetime":APPEAR_TIME,"color":Color("ce9bff")})
	Sfx.cry(actor.species_id,1.0,-5.0)

func _play_double() -> void:
	var actor: Mon=actors[active_brother]
	actor.play_attack("Double")
	double_duration=actor.attack_anim_t
	summon_step="double";summon_t=0.0
	summon_log.append({"brother":active_brother,"event":"double","time":elapsed,"duration":double_duration})

func _release_copies(id: String) -> void:
	if released.has(id) or id!=active_brother or summon_step!="double":return
	released[id]=true
	var actor: Mon=actors[id]
	var cfg: Dictionary=Data.BROTHERS[id]
	var destinations:=Data.formation(int(cfg.copies))
	var claimed: Array[Vector2]=[]
	flights.clear()
	for i in int(cfg.copies):
		var destination: Vector2=destinations[i]
		if phase=="battle":destination=_projection_target(destination,claimed)
		claimed.append(destination)
		var enemy:=_create_copy(id,actor.position)
		enemy.unfolding=true;enemy.appear=0.0
		if phase=="battle":enemy.invuln_t=SPREAD_TIME+0.2
		flights.append({"mon":enemy,"from":actor.position,"to":destination,"delay":float(i)*0.018})
	actor.visible=false;actor.attack_anim_t=0.0
	summon_step="spread";summon_t=0.0
	summon_log.append({"brother":id,"event":"spread","time":elapsed,"battle_time":battle_elapsed,"count":int(cfg.copies),"alive":game.world.remaining()})

func _create_copy(id: String,at: Vector2) -> Double:
	var cfg: Dictionary=Data.BROTHERS[id]
	var enemy:=Double.new();enemy.brother_id=id
	enemy.setup_trainer_mon(cfg.species,int(cfg.level),cfg.moves,game.world.rng)
	enemy.set_meta("no_exp",true);enemy.set_meta("tower_double",id)
	enemy.position=at;enemy.facing=Vector2.DOWN
	enemy.anim_t=float(created)*0.17
	for move_id in enemy.cds:enemy.cds[move_id]=1.0+float(created%7)*0.21
	game.world.add_child(enemy);game.world.enemies.append(enemy);doubles.append(enemy)
	created+=1;spawned=created==Data.count(floor_number)
	peak_active=maxi(peak_active,game.world.remaining())
	return enemy

func _safe_entry_position(preferred: Vector2) -> Vector2:
	var options: Array[Vector2]=[preferred]
	for direction in [Vector2.UP,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2.LEFT,Vector2.RIGHT,Vector2.DOWN]:
		options.append(game.world.player.position+direction*Arena.TILE*3.0)
	options.append_array(Data.formation(Data.count(floor_number)))
	var best:=Arena.resolve(preferred,10.0)
	var best_score:=-INF
	for point in options:
		var at:=Arena.resolve(point,10.0)
		var distance:=at.distance_to(game.world.player.position)
		var clearance:=distance
		for enemy in game.world.alive_enemies():clearance=minf(clearance,at.distance_to(enemy.position))
		var score:=minf(distance,Arena.TILE*3.0)+minf(clearance,Arena.TILE)-at.distance_to(preferred)*0.1
		if score>best_score:best=at;best_score=score
		if distance>=Arena.TILE*2.5 and clearance>=Arena.TILE*1.3:return at
	return best

func _projection_target(preferred: Vector2,claimed: Array[Vector2]) -> Vector2:
	var options: Array[Vector2]=[preferred]
	options.append_array(Data.formation(Data.count(floor_number)))
	options.sort_custom(func(a,b):return a.distance_squared_to(preferred)<b.distance_squared_to(preferred))
	for point in options:
		if point.distance_to(game.world.player.position)<Arena.TILE*2.0:continue
		if claimed.any(func(p):return p.distance_to(point)<Arena.TILE):continue
		if game.world.alive_enemies().any(func(e):return e.position.distance_to(point)<Arena.TILE):continue
		return point
	for point in options:
		if not claimed.any(func(p):return p.distance_to(point)<Arena.TILE*0.75):return point
	return Arena.resolve(preferred,10.0)

func _begin_intervention() -> void:
	var next: String=Data.STAGES[floor_number][summon_index+1]
	var line: Array=JOIN_LINES[next]
	intervention_pages=PixelUi.dialogue_pages(Data.brother_name(next)+": "+String(line[0 if Lang.is_ko() else 1]),Hud.MSG_W-30.0)
	intervention_t=float(intervention_pages.size())*1.8
	summon_step="gap";summon_t=0.0
	summon_log.append({"brother":next,"event":"intervention","time":elapsed,"battle_time":battle_elapsed,"scheduled":Data.INTERVENTION_INTERVAL*float(summon_index+1),"alive":game.world.remaining(),"defeated":game.defeated})

func _step_summoning(dt: float,during_battle: bool=false) -> void:
	summon_t+=dt
	for actor in actors.values():actor.attack_anim_t=maxf(0.0,actor.attack_anim_t-dt)
	if not during_battle:
		for enemy in game.world.alive_enemies():enemy.anim_t+=dt
	match summon_step:
		"gap":
			if summon_t>=(ENTRY_DELAY if summon_index<0 else BROTHER_GAP):_next_brother()
		"entry":
			var actor: Mon=actors[active_brother]
			actor.appear=clampf(summon_t/APPEAR_TIME,0.0,1.0)
			if summon_t>=APPEAR_TIME:
				actor.appear=1.0;summon_step="pause";summon_t=0.0
		"pause":
			if summon_t>=BEFORE_DOUBLE:_play_double()
		"double":
			if summon_t>=double_duration:_release_copies(active_brother)
		"spread":
			for flight in flights:
				if not is_instance_valid(flight.mon):continue
				var k:=clampf((summon_t-float(flight.delay))/(SPREAD_TIME-float(flight.delay)),0.0,1.0)
				var ease:=1.0-pow(1.0-k,3.0)
				var enemy: Enemy=flight.mon
				if not is_instance_valid(enemy) or enemy.dead:continue
				enemy.position=Vector2(flight.from).lerp(flight.to,ease)+Vector2(0,-sin(PI*k)*Arena.TILE*0.35)
				enemy.appear=clampf(k/0.18,0.0,1.0)
			if summon_t>=SPREAD_TIME:
				for flight in flights:
					if not is_instance_valid(flight.mon) or flight.mon.dead:continue
					flight.mon.position=flight.to;flight.mon.appear=1.0;flight.mon.unfolding=false
				flights.clear()
				summon_log.append({"brother":active_brother,"event":"settled","time":elapsed})
				summon_step="done" if during_battle else "hold"
				summon_t=0.0
		"hold":
			if summon_t>=FORMATION_HOLD:
				phase="battle";summon_step="done";game.state="fight";game.world.no_skills=false
				summon_log.append({"event":"battle","time":elapsed})
	if during_battle:return
	var wide:=1.0 if summon_step in ["spread","hold"] or (summon_step=="gap" and summon_index>=0) else 0.0
	camera_wide=move_toward(camera_wide,wide,dt*2.5)
	var target:=Arena.tile_center(Vector2i(12,12))
	if active_brother!="" and summon_step in ["entry","pause","double"]:
		target=game.world.player.position.lerp((actors[active_brother] as Mon).position,0.7)
	focus=focus.lerp(target,1.0-exp(-6.0*dt))
	game._set_cam(focus,World.CAM_ZOOM*lerpf(1.0,0.75,camera_wide))

func _restore_speakers() -> void:
	var speakers: Array=Data.SPEAKERS[floor_number]
	for i in speakers.size():
		var actor: Mon=actors[speakers[i]]
		actor.position=Data.brother_position(i,speakers.size())-Vector2(0,actor.feet_offset())
		actor.visible=true;actor.appear=1.0;actor.attack_anim_t=0.0

func step(dt: float) -> void:
	elapsed+=dt
	intervention_t=maxf(0.0,intervention_t-dt)
	game.world.step_visual(dt)
	game._set_cam(focus,World.CAM_ZOOM)
	if phase=="cloning":
		_step_summoning(dt)
	elif phase=="aftermath" and elapsed>=AFTER_TIME:
		_restore_speakers()
		phase="won"
		game._say_pages(_pages(OUTRO[floor_number]),_finish_outro)

func _finish_outro() -> void:
	# Recognition and its reward belong after the brothers' apology, not a KO.
	if floor_number==7:_award_completion()
	game._leave_arena()

func _award_completion() -> void:
	if game.events.has("tower_brothers_rewarded"):return
	if game.get("quests")!=null:
		game.quests.grant_reward({"id":"tower_brothers", "reward":{"oran_berry":3,"leppa_berry":2},
			"xp_levels":0.4, "ng_plus_xp_levels":1.0})
	else:
		game.world.award_berries({"oran_berry":3,"leppa_berry":2},game.world.player.position)
	_flag("tower_brothers_rewarded")
	game._save_here()

func request_attack() -> bool:
	if phase!="battle" or attack_t>0.0:return false
	attack_t=ATTACK_GAP
	return true

func step_battle(dt: float) -> void:
	if phase!="battle" or game.world.player.dead:return
	elapsed+=dt
	battle_elapsed+=dt
	intervention_t=maxf(0.0,intervention_t-dt)
	attack_t=maxf(0.0,attack_t-dt)
	if summon_step!="done":
		_step_summoning(dt,true)
	elif summon_index+1<Data.STAGES[floor_number].size() and battle_elapsed>=Data.INTERVENTION_INTERVAL*float(summon_index+1):
		_begin_intervention()
	peak_active=maxi(peak_active,game.world.remaining())
	if spawned and summon_step=="done" and game.defeated>=Data.count(floor_number) and game.world.remaining()==0:
		phase="aftermath";elapsed=0.0
		game.world.end_battle();game.world.clear_enemy_projectiles();game.world.no_skills=true
		game.world.player.vel=Vector2.ZERO
		_flag(Data.flag(floor_number))
		if floor_number==7:_flag(Data.COMPLETE)
		var next:=floor_number+1 if floor_number<7 else 1
		game.arena_trip.back={"map":Data.floor_id(next),"pos":_arrival_position(next),"layout":1}
		game._save_here()
		game.state="tower_event"

func _arrival_position(number: int) -> Vector2:
	return Arena.tile_center(Data.PLAYER_TILES[number] if number>=2 else Vector2i(11,15))

func _travel(number: int) -> void:
	phase="redirect";game.world.player.vel=Vector2.ZERO
	game._carry_out();game.arena_trip={}
	game.destination={"map":Data.floor_id(number),"pos":_arrival_position(number),"from_arena":true}
	game.state="warp"
	var tween:=game.create_tween()
	tween.tween_property(game.fader,"color:a",1.0,0.25)
	tween.tween_callback(func():game.get_tree().reload_current_scene())

func block_completed_stairs(warp: Dictionary) -> bool:
	if floor_number!=1 or not game.events.has(Data.COMPLETE) or String(warp.get("to",""))!=Data.floor_id(2):return false
	game.warp_armed=false
	game._say_pages(["네 형제는 위층에서 쉬고 있다.\n다음에 다시 인사하러 오자." if Lang.is_ko() else "The four brothers are resting upstairs.\nCome visit them again another time."])
	return true

func _flag(id: String) -> void:
	if not game.events.has(id):game.events.append(id)
	if not game.bot:SaveData.store_progress("events",id)

func defeated_enemy(_enemy: Enemy) -> void:pass
func enemies_left() -> int:return maxi(0,Data.count(floor_number)-game.defeated)
func progress_text() -> String:
	var text:="전투 중 %d · 남은 분신 %d"%[game.world.remaining(),enemies_left()] if Lang.is_ko() else "Active %d · Remaining %d"%[game.world.remaining(),enemies_left()]
	if summon_index+1<Data.STAGES[floor_number].size():
		var seconds:=maxi(0,ceili(Data.INTERVENTION_INTERVAL*float(summon_index+1)-battle_elapsed))
		text+=(" · 합류 %d초"%seconds if Lang.is_ko() else " · Join %ds"%seconds)
	return text
func overlay_message() -> String:
	if intervention_t<=0.0 or intervention_pages.is_empty():return ""
	var index:=clampi(int((float(intervention_pages.size())*1.8-intervention_t)/1.8),0,intervention_pages.size()-1)
	return intervention_pages[index]
func boss() -> Enemy:return null

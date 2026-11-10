extends RefCounted

# Clefairy's one-way shortcut uses the original western entrance and eastern exit.
const PLACE := "mt_moon_1f"
const CROSSED := "mt_moon_clefairy_passage"
const ENTRANCE := Vector2i(18,37)
const WAGGLE_TIME := 1.2
const DEPART_TIME := 1.95
const LINES := {
	"danger":["잠깐! 지금 동굴 안은 위험해!\nR이 적힌 옷을 입은 사람들이 있어.","It's dangerous here!\nPeople wearing an R are inside."],
	"offer":["반대편으로 가야 하는 거야?\n그럼 내가 보내 줄게!","Need to cross?\nI'll send you to the far exit!"],
	"repeat":["또 반대편으로 가려는 거야?\n내가 다시 보내 줄게!","Crossing again?\nI'll send you to the far exit!"],
	"move":["삐삐가 손가락흔들기를 썼다!","CLEFAIRY used METRONOME!"],
	"arrived":["달맞이산 반대편 출구에 도착했다!","You arrived at MT. MOON's far exit!"],
	"blocked":["동굴 입구가 막혀 있다.\n이쪽으로는 돌아갈 수 없다.","The cave entrance is blocked.\nYou can't return this way."]
}

var game: Node
var actor: Mon
var phase := "idle"
var elapsed := 0.0
var pulses := 0
var released := false
var goal := Vector2.ZERO
var blocked_tile := Vector2i(-1,-1)

func text(key: String) -> String:
	return LINES[key][0 if Lang.is_ko() else 1]

func setup(owner: Node) -> void:
	game=owner
	if DungeonDB.current!=PLACE:return
	actor=Mon.new();actor.setup("clefairy",8,Mon.TEAM_PLAYER)
	actor.position=Arena.tile_center(Vector2i(18,33))-Vector2(0,actor.feet_offset())
	actor.facing=Vector2.DOWN;actor.visible=false
	actor.set_meta("screen_facing",true)
	game.world.add_child(actor);game.world.bystanders.append(actor)

func arrive(teleported: bool=false) -> void:
	if teleported:
		game._say(text("arrived"))
	elif DungeonDB.current==PLACE and game._arrival_door==ENTRANCE:
		_begin()

func check_discovery() -> bool:
	if DungeonDB.current!=PLACE or phase!="idle" or game.world.player.dead:return false
	if game.world.player.position.distance_to(Arena.tile_center(ENTRANCE))>Arena.TILE*3.0:return false
	_begin();return true

func _begin() -> void:
	phase="approach";elapsed=0.0;actor.visible=true
	var p: Player=game.world.player
	goal=Arena.tile_center(Arena.tile_of(p.position)+Vector2i.UP*2)-Vector2(0,actor.feet_offset())
	actor.position=goal+Vector2.UP*Arena.TILE*2.0
	# Stop commands and wild AI before the greeting; the shortcut never starts a battle.
	game.world.scatter_enemies();p.vel=Vector2.ZERO;p.knock=Vector2.ZERO
	if p.controller.has_method("stop_move"):p.controller.stop_move()
	p.attack_anim_t=0.0;p.facing=Vector2.UP
	game.world.hold_cam=true;game.cinematic=true;game.state="moon_event"
	Sfx.cry("clefairy")

func step(dt: float) -> void:
	elapsed+=dt
	game.world.step_fx(dt)
	if phase=="approach":
		var before:=actor.position
		actor.position=actor.position.move_toward(goal,48.0*dt)
		actor.vel=(actor.position-before)/maxf(dt,0.0001)
		actor._walk_visual_time+=dt
		if actor.position.distance_to(goal)<0.1:
			actor.vel=Vector2.ZERO;phase="greeting"
			var pages: Array=[]
			for key in (["repeat"] if game.events.has(CROSSED) else ["danger","offer"]):
				pages.append({"text":actor.display_name()+": "+text(key),"speaker":weakref(actor)})
			pages.append(text("move"))
			game._say_pages(pages,_cast)
	elif phase=="casting":
		actor.attack_anim_t=maxf(0.0,actor.attack_anim_t-dt)
		# Existing Dance frames raise and waggle the hands; no source sprite is edited.
		while pulses<3 and elapsed>=0.18+float(pulses)*0.32:
			var side:= -1.0 if pulses%2==0 else 1.0
			_sparkle(actor,Vector2(side*9.0,-10.0),18.0,0.5)
			pulses+=1
		if elapsed>=WAGGLE_TIME and not released:
			released=true;Sfx.move("teleport")
			_sparkle(game.world.player,Vector2(0,-8),36.0,0.65)
			game.world.add_fx("sprite",game.world.player.position,{"text":"g4_ring","follow":game.world.player,
				"offset":Vector2(0,-5),"body_impact":true,"body_depth":0.6,"size":20.0,"grow":2.4,
				"lifetime":0.6,"fade_out":0.65,"color":Color("ffe8f5")})
		if released:
			game.fader.color=Color(1,1,1,clampf((elapsed-WAGGLE_TIME-0.15)/0.45,0.0,1.0))
		if elapsed>=DEPART_TIME:_depart()

func _cast() -> void:
	phase="casting";elapsed=0.0;pulses=0;released=false
	game.state="moon_event";actor.play_attack("Dance",WAGGLE_TIME,false)
	Sfx.move("metronome")

func _sparkle(mon: Mon,offset: Vector2,size: float,duration: float) -> void:
	game.world.add_fx("sprite",mon.position+offset,{"text":"metronome_star",
		"follow":mon,"offset":offset,"body_impact":true,"body_depth":0.5,
		"size":size,"lifetime":duration,"grow":0.25,"fade_in":0.08,"fade_out":0.5,"color":Color.WHITE})

func _depart() -> void:
	if phase!="casting":return
	phase="departed";game.state="warp"
	if not game.events.has(CROSSED):game.events.append(CROSSED)
	if not game.bot:SaveData.store_progress("events",CROSSED)
	game._carry_out()
	game.destination={"map":DungeonDB.WARP_MAPS["route4"],"warp":{"map":"route4","index":1},"moon_arrival":true}
	# The normal doorway loader promotes Route 4 into the continuous mainland map.
	game.get_tree().reload_current_scene()

func check_blocked_entry(warp: Dictionary) -> bool:
	if warp.is_empty():
		blocked_tile=Vector2i(-1,-1);return false
	if not game.events.has(CROSSED) or String(warp.get("map",""))!="route4":return false
	if String(warp.get("to",""))!="mt_moon_b1f" or int(warp.get("to_warp",-1))!=7:return false
	var tile:=Arena.tile_of(game.world.player.position)
	game.warp_armed=false
	if tile!=blocked_tile:
		blocked_tile=tile;game.world.player.vel=Vector2.ZERO
		game._say_pages([text("blocked")])
	return true

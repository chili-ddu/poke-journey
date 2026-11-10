extends RefCounted

# Persistent stage flags make each conversation/battle resumable independently.
const Regional=preload("res://scripts/story/regional_quests.gd")
const Campaign=preload("res://scripts/story/campaign_director.gd")
const ARENA := "arena_forest_rescue"
const BATTLE_ID := "quest_battle"
class QuestNpc:
	extends Npc
	func can_talk(at: Vector2) -> bool:
		return at.distance_to(position)<=Arena.TILE*1.6

var game: Node
var campaign: RefCounted
var catalog: Array=[]
var actors: Array=[]
var visuals: Array=[]
var people: Array=[]
var follower: Mon
var _refresh_signature := ""
var _refresh_t := 0.0
var _battle_index := 0
var _active_enemy: Enemy
var _battle_finished := false
var _cost_pending := {}
var journal_page := 0
var journal_ids: Array=[]
var phase := "idle"

func setup(owner: Node) -> void:
	game=owner
	campaign=Campaign.new()
	campaign.setup(game,self)
	catalog=Regional.quests(game.starter)
	catalog.append_array(campaign.quests())
	if not is_battle():refresh_actors()

func has(id: String) -> bool:
	return game.events.has(id)

func flag(id: String) -> void:
	if id.is_empty() or has(id):return
	game.events.append(id)
	if not game.bot:SaveData.store_progress("events",id)

static func stage_flag(id: String,index: int) -> String:
	return "quest_%s_stage_%d"%[id,index]

func stage_done(id: String,index: int) -> bool:
	return has(stage_flag(id,index))

func find_quest(id: String) -> Dictionary:
	for quest in catalog:
		if String(quest.id)==id:return quest
	return {}

func all_flags(flags: Array) -> bool:
	for id in flags:
		if not has(String(id)):return false
	return true

func current_stage(quest: Dictionary) -> int:
	for i in quest.stages.size():
		if not stage_done(quest.id,i):return i
	return quest.stages.size()

func available(quest: Dictionary) -> bool:
	if not all_flags(quest.get("requires",[])):return false
	for id in quest.get("unless",[]):
		if has(String(id)):return false
	return true

func completed(quest: Dictionary) -> bool:
	return has("quest_%s_complete"%quest.id)

func _at_location(stage: Dictionary) -> bool:
	if stage.has("map"):
		if DungeonDB.current==String(stage.map):return true
		return game.mode=="overworld" and Arena.area_rect(String(stage.map)).size!=Vector2i.ZERO
	return stage.has("area") and Arena.area_rect(String(stage.area)).size!=Vector2i.ZERO

func _stage_tile(stage: Dictionary) -> Vector2i:
	var at: Vector2i=stage.get("tile",Vector2i(5,5))
	if stage.has("area"):at+=Arena.area_rect(String(stage.area)).position
	elif stage.has("map") and DungeonDB.current!=String(stage.map):at+=Arena.area_rect(String(stage.map)).position
	# Never put a new interaction behind a wall or on a warp.
	var queue: Array[Vector2i]=[at]
	var seen: Dictionary={at:true}
	var cursor := 0
	while cursor<queue.size() and cursor<300:
		var cell:=queue[cursor];cursor+=1
		if not Arena.solid_at(cell.x,cell.y) and Arena.warp_at(Arena.tile_center(cell)).is_empty():
			var occupied:=false
			for npc in game.world.npcs:
				if npc.visible and npc.position.distance_to(Arena.tile_center(cell))<Arena.TILE*0.6:occupied=true;break
			if not occupied:return cell
		for direction in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
			var next: Vector2i=cell+direction
			if seen.has(next):continue
			seen[next]=true;queue.append(next)
	return at

func refresh_actors() -> void:
	for actor in actors:
		game.world.npcs.erase(actor)
		if is_instance_valid(actor):actor.queue_free()
	for mon in visuals:
		game.world.bystanders.erase(mon)
		if is_instance_valid(mon):mon.queue_free()
	for actor in people:
		game.world.npcs.erase(actor)
		if is_instance_valid(actor):actor.queue_free()
	actors.clear();visuals.clear();people.clear()
	if is_battle():return
	for quest in catalog:
		if not available(quest):continue
		var index:=current_stage(quest)
		var done:=completed(quest)
		if done and quest.get("hide_on_complete",false):continue
		if index>=quest.stages.size():
			if not done:continue
			index=quest.stages.size()-1
		var stage: Dictionary=quest.stages[index]
		if not all_flags(stage.get("requires",[])) or not _at_location(stage):continue
		if stage.get("hidden",false):continue
		var cell:=_stage_tile(stage)
		var actor:=QuestNpc.new()
		actor.setup({"id":"quest_actor_%s"%quest.id,"talk":"quest","sprite":String(stage.get("sprite","youngster")),"tile":cell})
		actor.set_meta("roaming_trainer",true)
		actor.set_meta("quest_id",String(quest.id));actor.set_meta("quest_index",index)
		actor.set_meta("quest_done",done)
		game.world.add_child(actor);game.world.npcs.append(actor);actors.append(actor)
		if stage.has("species"):
			actor.visible=false
			var species:=String(stage.species)
			if species=="starter":species=game.starter
			if stage.get("appearance","")=="player":species=game.world.player.appearance_id()
			var mon:=Mon.new();mon.setup(species,game.world.player.level,Mon.TEAM_PLAYER)
			mon.position=actor.position-Vector2(0,mon.feet_offset())
			mon.set_meta("screen_facing",true)
			if stage.get("opposite_sex",false):
				var player_female: bool=(game.world.player.pid & 255)<31
				mon.pid=(game.world.player.pid & 0xffffff00) | (255 if player_female else 0)
				mon.set_meta("gender","male" if player_female else "female")
			game.world.add_child(mon);game.world.bystanders.append(mon);visuals.append(mon)
			actor.set_meta("quest_visual",weakref(mon))
		var companions: Array=(stage.get("companions",[]) as Array).duplicate(true)
		if done:companions.append_array(quest.get("completed_companions",[]))
		for companion in companions:
			var companion_stage: Dictionary=stage.duplicate();companion_stage["tile"]=companion.tile
			if companion.has("species"):
				var mon:=Mon.new();mon.setup(String(companion.species),game.world.player.level,Mon.TEAM_PLAYER)
				mon.position=Arena.tile_center(_stage_tile(companion_stage))-Vector2(0,mon.feet_offset())
				mon.set_meta("screen_facing",true)
				game.world.add_child(mon);game.world.bystanders.append(mon);visuals.append(mon)
			elif companion.has("sprite"):
				var person:=Npc.new();person.setup({"id":"quest_companion_%s"%quest.id,"sprite":String(companion.sprite),"tile":_stage_tile(companion_stage)})
				person.set_meta("roaming_trainer",true)
				game.world.add_child(person);game.world.npcs.append(person);people.append(person)
	_refresh_signature=str(game.events)
	_sync_follower()

func _sync_follower() -> void:
	var follows:=has("eevee_following") and not has("eevee_research_assistant")
	if not follows or game.mode=="arena":
		if is_instance_valid(follower):
			game.world.bystanders.erase(follower);follower.queue_free();follower=null
		return
	if not is_instance_valid(follower):
		follower=Mon.new();follower.setup("eevee",game.world.player.level,Mon.TEAM_PLAYER)
		follower.position=_safe_follower_position()
		follower.set_meta("screen_facing",true)
		game.world.add_child(follower);game.world.bystanders.append(follower)

func _safe_follower_position() -> Vector2:
	var tile:=Arena.tile_of(game.world.player.position)
	for direction in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.ZERO]:
		var at: Vector2i=tile+direction
		if not Arena.solid_at(at.x,at.y) and Arena.warp_at(Arena.tile_center(at)).is_empty():
			return game.world.resolve_mon(follower,Arena.tile_center(at))
	return game.world.player.position

func arrive() -> void:
	if is_battle():
		phase="battle";game.total_enemies=(game.arena_trip.get("quest_stage",{}).get("battle",[]) as Array).size()
		game.defeated=0;game.world.start_battle(Arena.center(),0.0);game.world.arena_cam=false
		game.world.no_skills=false;game.state="fight"
		return
	campaign.arrive()
	if game.state not in ["fight","town"]:return
	for quest in catalog:
		var index:=current_stage(quest)
		if index<quest.stages.size() and has(_won_flag(quest.id,index)):
			_finish_stage(quest,index)
			return

func step(dt: float) -> void:
	if is_battle():return
	_refresh_t-=dt
	if _refresh_t<=0.0 and game.state in ["fight","town"]:
		_refresh_t=0.5
		if _refresh_signature!=str(game.events):refresh_actors()
	if is_instance_valid(follower):
		var player: Player=game.world.player
		var distance:=follower.position.distance_to(player.position)
		if distance>Arena.TILE*8.0 or player.get_meta("carried",false) or player.travel_terrain==2 or not game.battle.is_empty():
			follower.visible=false;follower.vel=Vector2.ZERO
			if distance>Arena.TILE*8.0:follower.position=_safe_follower_position()
		else:
			follower.visible=true
			var dir: Vector2=(player.position-follower.position).normalized()
			var speed:=90.0 if distance>Arena.TILE*1.2 and game.state in ["fight","town"] else 0.0
			follower.vel=dir*speed
			if speed>0.0:follower.facing=dir
			follower.position=game.world.resolve_mon(follower,follower.position+follower.vel*dt)
			follower.anim_t+=dt;follower.queue_redraw()
	campaign.step(dt)

func check_discovery() -> bool:
	if is_battle() or game.state not in ["fight","town"] or not game.battle.is_empty():return false
	if campaign.has_method("check_discovery"):return campaign.check_discovery()
	return false

func talk(actor: Npc) -> bool:
	if actor.talk!="quest":return false
	var quest:=find_quest(String(actor.get_meta("quest_id","")))
	if quest.is_empty():return true
	var index:=current_stage(quest)
	if completed(quest):
		game._say_pages(quest.get("repeat",["이 일은 잘 해결됐어. 도와줘서 고마워!" if Lang.is_ko() else "Everything is settled. Thank you for helping!"]))
		return true
	if index>=quest.stages.size():return true
	var stage: Dictionary=quest.stages[index]
	if not all_flags(stage.get("requires",[])):return true
	var cost: Dictionary=stage.get("cost",{})
	for item in cost:
		if int(game.world.player.bag.get(item,0))<int(cost[item]):
			game._say_pages(["%s %d개를 준비해서 다시 와 줘."%[ItemDB.name_of(item),int(cost[item])]])
			return true
	if not cost.is_empty():
		_cost_pending={"id":quest.id,"index":index}
		game._menu_open("quest_cost")
		var parts: Array=[]
		for item in cost:parts.append("%s ×%d"%[ItemDB.name_of(item),int(cost[item])])
		game.panel.show_items(", ".join(parts)+(" 건넬까?" if Lang.is_ko() else " — offer these?"),[{"name":"건네기" if Lang.is_ko() else "Give"},{"name":"다음에" if Lang.is_ko() else "Later"}],2,1)
		return true
	_begin_stage(quest,index)
	return true

func choose_cost(index: int) -> void:
	game._close_menu()
	if index!=0 or _cost_pending.is_empty():_cost_pending={};return
	var quest:=find_quest(_cost_pending.id)
	var stage_index:=int(_cost_pending.index)
	_cost_pending={}
	_begin_stage(quest,stage_index)

func _begin_stage(quest: Dictionary,index: int) -> void:
	flag("quest_%s_started"%quest.id)
	var stage: Dictionary=quest.stages[index]
	game.world.scatter_enemies();game.world.player.vel=Vector2.ZERO
	var after:=start_quest_battle.bind(quest,stage,index) if not (stage.get("battle",[]) as Array).is_empty() and not has(_won_flag(quest.id,index)) else _finish_stage.bind(quest,index)
	var intro: Array=stage.get("intro",[])
	if intro.is_empty():after.call()
	else:game._say_pages(intro,after)

func _finish_stage(quest: Dictionary,index: int) -> void:
	var stage: Dictionary=quest.stages[index]
	var lines: Array=stage.get("outro",[])
	if lines.is_empty():_commit_stage(quest,index)
	else:game._say_pages(lines,_commit_stage.bind(quest,index))

func _commit_stage(quest: Dictionary,index: int) -> void:
	if stage_done(quest.id,index):return
	var stage: Dictionary=quest.stages[index]
	var cost: Dictionary=stage.get("cost",{})
	for item in cost:
		if int(game.world.player.bag.get(item,0))<int(cost[item]):return
	for item in cost:game.world.player.take_item(item,int(cost[item]))
	flag(stage_flag(quest.id,index));flag(String(stage.get("flag","")))
	match String(stage.get("action","")):
		"snorlax_wake":
			if game.road_gates!=null:game.road_gates.complete_snorlax_event()
		"eevee_follow_start":flag("eevee_following")
		"eevee_follow_end":flag("eevee_research_assistant")
	if index==quest.stages.size()-1:
		flag("quest_%s_complete"%quest.id);flag(String(quest.get("completion_flag","")))
		grant_reward(quest)
	game._save_here()
	refresh_actors()
	campaign.on_commit(String(quest.id),index)

func grant_reward(quest: Dictionary) -> void:
	var reward: Dictionary=quest.get("reward",{})
	if not reward.is_empty():game.world.award_berries(reward,game.world.player.position)
	var xp_fraction:=float(quest.get("xp_levels",0.0))
	if has("campaign_cycle_2"):xp_fraction=maxf(xp_fraction,float(quest.get("ng_plus_xp_levels",0.75)))
	var p: Player=game.world.player
	var growth:=SpeciesDB.growth_of(p.species_id)
	var whole:=floori(xp_fraction)
	var after:=mini(100,p.level+whole)
	var delta:=SpeciesDB.exp_for_level(after,growth)-SpeciesDB.exp_for_level(p.level,growth)
	var fractional:=xp_fraction-whole
	delta+=roundi((SpeciesDB.exp_for_level(mini(100,after+1),growth)-SpeciesDB.exp_for_level(after,growth))*fractional)
	if xp_fraction>0.0 and delta>0:grant_exp(delta)
	var lines: Array=World.loot_summary_pages(reward)
	if xp_fraction>0.0:lines.append("이야기를 마치며 경험을 쌓았다!" if Lang.is_ko() else "You gained experience through this story!")
	if not lines.is_empty():
		Bgm.fanfare(Bgm.ITEM)
		for line in lines:game._toast(String(line))

func grant_exp(amount: int) -> void:
	var p: Player=game.world.player
	var before_level:=p.level
	var before_progress:=p.exp_progress()
	var gained:=p.gain_exp(amount)
	for _i in gained:
		var before:=p.stats.duplicate();p.set_level(p.level+1)
		var delta: Dictionary={}
		for key in p.stats:delta[key]=int(p.stats[key])-int(before[key])
		# Quest rewards can transition scenes immediately (gym returns / endings).
		# Persist move knowledge with the gained levels instead of leaving it only
		# in the departing scene's UI queue. Equipped combat slots stay unchanged.
		for move_id in SpeciesDB.moves_at_level(p.species_id,p.level):
			if not p.known_moves().has(move_id):
				p.add_learned(move_id)
				game._toast(Lang.t("learned",[p.display_name(),MoveDB.move_name(move_id)]))
		game.stat_queue.append({"delta":delta,"after":p.stats.duplicate(),"level":p.level,"learns":[],"exp_ready":false})
	if not game.exp_display_pending():game.exp_display_level=before_level;game.exp_display_progress=before_progress
	for level in range(before_level,p.level):game.exp_segments.append({"level":level,"from":before_progress if level==before_level else 0.0,"to":1.0,"level_up":true})
	if p.level<100:game.exp_segments.append({"level":p.level,"from":before_progress if gained==0 else 0.0,"to":p.exp_progress(),"level_up":false})

static func _won_flag(id: String,index: int) -> String:
	return "quest_%s_battle_%d_won"%[id,index]

func start_quest_battle(quest: Dictionary,stage: Dictionary,index: int) -> void:
	var player: Player=game.world.player
	var snapshot: Dictionary={"species":player.species_id,"form_species":player.form_species_id,"level":player.level,"ivs":player.ivs.duplicate(),"pid":player.pid,"stats":player.stats.duplicate(),"max_hp":player.max_hp,"slots":player.slots.duplicate(),"shiny":player.shiny}
	game.arena_trip={"event":BATTLE_ID,"arena":ARENA,"quest_id":quest.id,"quest_index":index,"quest_stage":stage.duplicate(true),"snapshot":snapshot,
		"back":{"map":DungeonDB.current,"pos":player.position,"layout":int(DungeonDB.LAYOUTS.get(DungeonDB.current,1)),"pursuit_visit":game.road_pursuit.snapshot()}}
	var layer:=CanvasLayer.new();layer.layer=90;game.add_child(layer)
	game.encounter=EncounterFx.new();game.encounter.setup("low",null,{})
	game.encounter.size=game.get_viewport().get_visible_rect().size;layer.add_child(game.encounter)
	game.state="encounter";player.vel=Vector2.ZERO
	Bgm.play("seq_ba_train")

func is_battle() -> bool:
	return game!=null and game.mode=="arena" and String(game.arena_trip.get("event",""))==BATTLE_ID

func step_battle(_dt: float) -> void:
	if _battle_finished or game.world.player.dead:return
	if is_instance_valid(_active_enemy) and not _active_enemy.dead:return
	if game.world.remaining()>0:return
	var roster: Array=game.arena_trip.quest_stage.get("battle",[])
	if _battle_index>=roster.size():
		_battle_finished=true;phase="won"
		game.world.end_battle();game.world.clear_enemy_projectiles();game.world.no_skills=true
		flag(_won_flag(String(game.arena_trip.quest_id),int(game.arena_trip.quest_index)))
		game._save_here()
		game._say_pages(["勝った！" if Lang.code=="ja" else ("승리했다!" if Lang.is_ko() else "You won!")],game._leave_arena)
		return
	var cfg: Dictionary=roster[_battle_index];_battle_index+=1
	_active_enemy=spawn_opponent(cfg,game.arena_trip.snapshot)

func spawn_opponent(cfg: Dictionary,snapshot: Dictionary) -> Enemy:
	var level:=int(cfg.get("level",clampi(int(snapshot.level)+int(cfg.get("offset",0)),int(cfg.get("min",1)),int(cfg.get("max",100)))))
	var species:=String(cfg.get("species","rattata"))
	var mirror:=bool(cfg.get("mirror",false))
	if mirror:species=String(snapshot.species);level=int(snapshot.level)
	var moves: Array=cfg.get("moves",[])
	if mirror:moves=(snapshot.slots as Array).filter(func(id):return String(id)!="")
	var direction: Vector2=(Arena.center()-game.world.player.position).normalized()
	if direction==Vector2.ZERO:direction=Vector2.UP
	var at: Vector2=game.world.player.position+direction*Arena.TILE*4.0
	var enemy: Enemy=game.world.send_out(species,level,moves,at)
	enemy.set_meta("no_exp",true);enemy.set_meta("quest_opponent",true)
	var individual: Dictionary=cfg.get("individual",{})
	if mirror:
		enemy.cds.clear()
		for move_id in moves:enemy.cds[move_id]=0.6
		enemy.ai="wild"
	if mirror or not individual.is_empty():
		var source:=snapshot if mirror else individual
		enemy.ivs=(source.get("ivs",{}) as Dictionary).duplicate();enemy.pid=int(source.get("pid",0))
		enemy.stats=SpeciesDB.stats_at(species,level,enemy.ivs);enemy.max_hp=int(enemy.stats.hp);enemy.hp=enemy.max_hp
		if mirror:
			enemy.stats=(snapshot.stats as Dictionary).duplicate();enemy.max_hp=int(snapshot.max_hp);enemy.hp=enemy.max_hp
			enemy.shiny=bool(snapshot.get("shiny",false))
			enemy._sprites=MonSprite.load_set(int(SpeciesDB.get_species(species).dex),enemy.shiny)
			var form:=String(snapshot.get("form_species",""))
			if not form.is_empty():
				enemy.form_species_id=form
				enemy._sprites=MonSprite.load_set(int(SpeciesDB.get_species(form).dex),enemy.shiny)
				enemy._apply_species_size(SpeciesDB.get_species(form))
	return enemy

func defeated_enemy(_enemy: Enemy) -> void:
	pass # World retains the fainting animation; the next opponent waits for its removal.

func enemies_left() -> int:
	return maxi(0,game.total_enemies-game.defeated)

func boss() -> Enemy:
	return _active_enemy if is_instance_valid(_active_enemy) and not _active_enemy.dead else null

func handle_loss() -> void:
	# Never persist a win or consume a quest cost when the player loses.
	game.world.full_restore(false)
	game.world.player.dead=false;game.world.player.dying_t=0.0
	game.world.player.vel=Vector2.ZERO
	game.world.end_battle();game.world.scatter_enemies();game.world.clear_enemy_projectiles();game.world.no_skills=true
	game.pending_battle_end=""
	game._say_pages(["무리하지 말자. 준비를 갖추고 다시 도전하자." if Lang.is_ko() else "Rest and prepare before trying again."],game._leave_arena)

func _map_name(place: String) -> String:
	var data: Dictionary=DungeonDB.DUNGEONS.get(place,{})
	return String(data.get("name_ko",data.get("name",place))) if Lang.is_ko() else String(data.get("name",place))

func recorded(quest: Dictionary) -> bool:
	if has("quest_%s_started"%quest.id) or completed(quest) or quest.get("auto_record",false):return true
	var discovery: Array=quest.get("discover_requires",[])
	if not discovery.is_empty() and all_flags(discovery):return true
	for index in quest.stages.size():
		if stage_done(quest.id,index) or has(_won_flag(quest.id,index)):return true
	return false

func journal_entries() -> Array:
	var out: Array=[]
	for quest in catalog:
		if not available(quest) or not recorded(quest):continue
		var index:=current_stage(quest)
		var done:=completed(quest)
		var stage: Dictionary=quest.stages[mini(index,quest.stages.size()-1)]
		var place:=String(stage.get("area",stage.get("map","")))
		var label:=String(stage.get("place",DungeonDB.area_name(place) if stage.has("area") else _map_name(place)))
		out.append({"id":quest.id,"name":String(quest.name),"place":label,"done":done,"objective":String(stage.get("objective",stage.get("intro",[""])[0]))})
	if campaign.has_method("journal_entries"):
		for entry in campaign.journal_entries():
			entry["id"]="@campaign_"+str(out.size());entry["done"]=entry.get("status","")=="complete"
			out.append(entry)
	return out

func journal_card(entry: Dictionary) -> Dictionary:
	var title:=String(entry.name)
	# The compact card is one line; its detail view retains the full title,
	# destination and objective. Branch subtitles distinguish the bird stories.
	if title.contains(" · "):title=title.get_slice(" · ",1)
	if PixelUi.text_width(title)>100.0:
		while not title.is_empty() and PixelUi.text_width(title+"…")>100.0:title=title.substr(0,title.length()-1)
		title+="…"
	return {"name":title,"sub":("완료" if entry.done else "진행 중") if Lang.is_ko() else ("Complete" if entry.done else "In progress"),"accent":Color("80b890") if entry.done else Color("e8bf55")}

func open_journal(page: int=0) -> void:
	game._menu_open("quest_journal")
	var entries:=journal_entries();journal_page=clampi(page,0,maxi(0,(entries.size()-1)/4))
	journal_ids=[]
	var cards: Array=[]
	for index in range(journal_page*4,mini(entries.size(),journal_page*4+4)):
		var entry: Dictionary=entries[index]
		journal_ids.append(entry.id)
		cards.append(journal_card(entry))
	if entries.is_empty():cards.append({"name":"아직 기록이 없다" if Lang.is_ko() else "No stories yet","enabled":false});journal_ids.append("")
	cards.append({"name":"이전" if Lang.is_ko() else "Previous","enabled":journal_page>0});journal_ids.append("@prev")
	cards.append({"name":"다음" if Lang.is_ko() else "Next","enabled":(journal_page+1)*4<entries.size()});journal_ids.append("@next")
	cards.append({"name":"닫기" if Lang.is_ko() else "Close"});journal_ids.append("@close")
	game.panel.show_items(("이야기 수첩" if Lang.is_ko() else "Story journal")+" %d/%d"%[journal_page+1,maxi(1,ceili(entries.size()/4.0))],cards,2,cards.size()-1)

func choose_journal(index: int) -> void:
	if index<0 or index>=journal_ids.size():game._close_menu();return
	var id:=String(journal_ids[index])
	match id:
		"@prev":open_journal(journal_page-1)
		"@next":open_journal(journal_page+1)
		"@close":game._close_menu()
		_:
			game._close_menu()
			for entry in journal_entries():
				if entry.id==id:
					game._say_pages([entry.name+" — "+entry.place,entry.objective],func():open_journal(journal_page))
					break

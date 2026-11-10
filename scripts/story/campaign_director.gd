extends RefCounted

const Catalog = preload("res://scripts/story/campaign_quests.gd")
const GYMS := ["leader_brock","leader_misty","leader_lt_surge","leader_erika","leader_koga","leader_sabrina","leader_blaine"]
const CLUES := ["quest_moon_mining_complete","quest_silph_theft_complete","quest_hideout_complete","quest_cinnabar_records_complete"]
const EGG_MOVES := {"charmander":"dragon_dance","bulbasaur":"power_whip","squirtle":"mirror_coat"}
const CYCLE := "campaign_cycle_2"
const HO_OH := "campaign_hooh_sighted"
const SUPPLY := "campaign_supply_chain_connected"
const TARGET := "campaign_mewtwo_identified"
static var bot_campaign: Dictionary = {}

var game: Node
var _runtime_ref: WeakRef
var runtime: RefCounted:
	get:return _runtime_ref.get_ref() if _runtime_ref != null else null
	set(value):_runtime_ref = weakref(value)
var data: Dictionary = {}
var sky_bird: Mon
var sky_time := 0.0
var sky_from := Vector2.ZERO
var sky_to := Vector2.ZERO
var ending_active := false
var _connections_announced := false

func setup(owner: Node, quests_runtime: RefCounted) -> void:
	game = owner
	runtime = quests_runtime
	data = bot_campaign.duplicate(true) if game.bot else SaveData.load_campaign()
	if data.is_empty():data = {"cycle":2 if game.events.has(CYCLE) else 1,"current_challenges":[],"parent":{},"parent_challenges":[],"pending_capture":false}
	_connect_evidence(false)

func cycle() -> int:
	return 2 if game.events.has(CYCLE) else int(data.get("cycle",1))

func quests(_starter: String = "charmander") -> Array:
	var result: Array = []
	for quest in Catalog.quests():
		if cycle() == 2 and quest.id in ["moon_mining","silph_theft","hideout","cinnabar_records","mysterious_bird_clue"]:continue
		if cycle() == 1 and quest.id == "mewtwo_final":continue
		result.append(quest)
	return result

func _save() -> void:
	if game.bot:bot_campaign = data.duplicate(true)
	else:SaveData.store_campaign(data)

func _flag(id: String) -> void:
	if game.events.has(id):return
	game.events.append(id)
	if not game.bot:SaveData.store_progress("events",id)

func _connect_evidence(announce: bool) -> void:
	var messages: Array = []
	if game.events.has(CLUES[0]) and game.events.has(CLUES[1]) and not game.events.has(SUPPLY):
		_flag(SUPPLY)
		messages.append("광석과 도난 기술의 운송 기록이 이어졌다!\n게임코너 지하의 제작 계획을 추적하자.")
	if game.events.has(CLUES[2]) and game.events.has(CLUES[3]) and not game.events.has(TARGET):
		_flag(TARGET)
		messages.append("포획 대상 M2의 정체는 뮤츠다!\n로켓단은 최강의 포켓몬을 노리고 있다.")
	if game.events.has(SUPPLY) and game.events.has(TARGET) and not game.events.has("campaign_giovanni_ready"):
		_flag("campaign_giovanni_ready")
		messages.append("두 조사 흐름이 하나로 모였다.\n상록시티 체육관에서 비주기를 찾아가자.")
	if announce:
		for line in messages:game._toast(line)

func arrive() -> void:
	# Removed from the actual scene, so an absent leader cannot still be talked to.
	if cycle() == 1 and not game.events.has(CLUES[0]):
		for trainer in game.trainers.duplicate():
			if trainer.trainer_id == "leader_misty":
				game.trainers.erase(trainer)
				game.world.npcs.erase(trainer)
				trainer.queue_free()
	_connect_evidence(false)

func step(dt: float) -> void:
	if is_instance_valid(sky_bird):
		sky_time += dt
		sky_bird.anim_t += dt
		var t := clampf(sky_time / 3.2,0.0,1.0)
		sky_bird.position = sky_from.lerp(sky_to,t)
		sky_bird.vel = (sky_to-sky_from)/3.2
		if t >= 1.0:
			game.world.bystanders.erase(sky_bird)
			sky_bird.queue_free()
			sky_bird = null
	if not ending_active and game.mode != "arena" and (bool(data.get("pending_capture",false)) or bool(data.get("bad_ending",false))) and game.state in ["fight","town"] and game.dialog_text.is_empty():
		_capture_ending()

func check_discovery() -> bool:
	if cycle() != 1 or game.events.has(HO_OH) or game.mode != "overworld":return false
	if game.state not in ["fight","town"] or not game.battle.is_empty() or not game.dialog_text.is_empty() or game.world.player.dead:return false
	if Arena.area_at(game.world.player.position) != "route1":return false
	_flag(HO_OH)
	sky_bird = Mon.new()
	sky_bird.setup("ho_oh",50,Mon.TEAM_PLAYER)
	sky_bird.lift = 28.0
	sky_bird.facing = Vector2.RIGHT
	sky_bird.set_meta("screen_facing",true)
	sky_from = game.world.player.position + Vector2(-120,-26)
	sky_to = game.world.player.position + Vector2(150,-68)
	sky_bird.position = sky_from
	sky_time = 0.0
	game.world.add_child(sky_bird)
	game.world.bystanders.append(sky_bird)
	game._save_here()
	game._say_pages(["空を横切る、虹色の大きな翼……。" if Lang.code == "ja" else ("하늘을 가로지르는 커다란 날개.\n무지갯빛 새가 멀리 날아간다…!" if Lang.is_ko() else "A great rainbow-colored bird\nglides across the sky..."),"이야기 시작 — 신비로운 새를 찾아서\n1번도로의 구구에게 목격담을 물어보자.","메뉴의 이야기 기록에서\n현재 목표와 단서를 확인할 수 있다."],runtime.refresh_actors)
	return true

func on_commit(quest_id: String, _stage_index: int) -> void:
	_connect_evidence(true)
	if quest_id == "mewtwo_final" and game.events.has("quest_mewtwo_final_complete"):
		_flag("campaign_true_ending")
		_save()
		game._save_here()
	if quest_id == "daycare_courtship" and game.events.has("daycare_egg_left"):
		data["egg_move"] = EGG_MOVES.get(SpeciesDB.base_form(game.world.player.species_id),"dragon_dance")
		_save()

func can_challenge(trainer_id: String) -> bool:
	if trainer_id == "leader_misty" and cycle() == 1:return game.events.has(CLUES[0])
	if trainer_id != "leader_giovanni":return true
	if cycle() == 1:return game.events.has(SUPPLY) and game.events.has(TARGET) and not bool(data.get("pending_capture",false))
	for id in GYMS:
		if not game.events.has("campaign_child_won_"+id):return false
	return not game.events.has("campaign_father_rescued")

func challenge_pages(trainer_id: String) -> Array:
	if trainer_id == "leader_misty" and cycle() == 1 and not game.events.has(CLUES[0]):return ["이슬 관장은 달맞이산을 조사 중이다.\n체육관 밖 안내인에게 행방을 물어보자."]
	if trainer_id == "leader_giovanni":
		if cycle() == 1:return ["아직 비주기에게 따질 증거가 부족하다.\n광석·실프 기술과 포획 대상의 단서를 모으자."]
		var remaining: Array = []
		for id in GYMS:
			if not game.events.has("campaign_child_won_"+id):remaining.append(TrainerDB.short_name(id))
		return ["비주기: 다른 일곱 관장에게 먼저 승리해라.\n남은 관장: "+", ".join(remaining)]
	return []

func on_gym_challenged(trainer_id: String) -> void:
	if not GYMS.has(trainer_id):return
	var faced: Array = data.get("current_challenges",[])
	if not faced.has(trainer_id):
		faced.append(trainer_id)
		data["current_challenges"] = faced
		_save()

func flashback_pages(trainer_id: String) -> Array:
	if cycle() != 2 or not GYMS.has(trainer_id):return []
	if not (data.get("parent_challenges",[]) as Array).has(trainer_id):return []
	if game.events.has("campaign_memory_"+trainer_id):return []
	_flag("campaign_memory_"+trainer_id)
	var memory: Dictionary = {
		"leader_brock":"네 아버지도 혼자 찾아왔지.\n돌처럼 흔들리지 않는 눈빛이었어.",
		"leader_misty":"네 아버지는 달맞이산에서\n도움이 필요한 포켓몬을 외면하지 않았어.",
		"leader_lt_surge":"네 아버지는 명령 없이 싸우더군.\n용기란 스스로 선택하는 것임을 배웠지.",
		"leader_erika":"그 아이는 강함을 꿈꾸면서도\n작은 생명의 목소리에 귀 기울였어요.",
		"leader_koga":"상처를 입어도 일어서는 모습을 봤다.\n그 의지가 네게도 이어져 있군.",
		"leader_sabrina":"네 아버지의 마음에는\n언제나 자유롭게 여행할 꿈이 있었어.",
		"leader_blaine":"내가 기억하는 그 아이는\n누구의 도구도 될 포켓몬이 아니었다!"}
	return ["아버지의 기억 — "+TrainerDB.short_name(trainer_id),memory[trainer_id]]

func on_trainer_defeated(trainer_id: String) -> Array:
	var pages: Array = []
	if cycle() == 2 and GYMS.has(trainer_id):
		var won := "campaign_child_won_"+trainer_id
		if not game.events.has(won):
			_flag(won)
			runtime.grant_reward({"id":"child_gym_"+trainer_id,"reward":{},"xp_levels":5.0})
			pages.append("新たな勝利が力になった！" if Lang.code == "ja" else "새로운 승리로 크게 성장했다!")
			if can_challenge("leader_giovanni"):pages.append("일곱 관장에게 모두 승리했다!\n상록시티에서 아버지를 되찾자.")
		_save()
	if trainer_id != "leader_giovanni":return pages
	if cycle() == 1:
		data["parent"] = snapshot(game.world.player)
		data["parent_challenges"] = (data.get("current_challenges",[]) as Array).duplicate()
		for id in GYMS:
			if game.beaten.has(id) and not data.parent_challenges.has(id):data.parent_challenges.append(id)
		data["pending_capture"] = true
		_save()
		pages.append_array(["비주기: 이 나를 이기다니…\n최강을 향한 네 의지는 여전하군.","비주기: 뮤츠를 쫓기 전에\n마스터볼로 너라도 잡아야겠다!", "마스터볼이 날아왔다!\n빛에 휩싸인 몸이 볼 안으로 빨려 들어간다…"])
	else:
		if game.events.has("campaign_father_rescued"):return pages
		_flag("campaign_father_rescued")
		runtime.grant_reward({"id":"father_rescued","reward":{"sitrus_berry":5,"leppa_berry":5},"xp_levels":3.0})
		pages.append_array(["비주기: 내가… 또 졌다고?!\n이제는 너희를 붙잡아 둘 수 없겠군.","아버지는 힘겹게 일어나 네 곁으로 왔다.\n포획 장치의 빛이 꺼졌다.","아버지: 나를 찾아와 주었구나.\n네가 스스로 고른 길을 잊지 마라.","아버지: 블루시티 깊은 동굴에 뮤츠가 있다.\n쓰러뜨리고 최강의 포켓몬이 되어라!"])
		_save()
	return pages

static func snapshot(player: Player) -> Dictionary:
	var moves: Array = []
	for move in player.slots:
		if String(move) != "":moves.append(String(move))
	return {"species":player.species_id,"form_species_id":player.form_species_id,"level":player.level,"pid":player.pid,"ivs":player.ivs.duplicate(),"stats":player.stats.duplicate(),"max_hp":player.max_hp,"moves":moves,"shiny":player.shiny}

func trainer_roster(trainer_id: String, base: Dictionary) -> Dictionary:
	var roster := base.duplicate(true)
	if cycle() != 2 or trainer_id != "leader_giovanni":return roster
	var father: Dictionary = data.get("parent",{})
	if father.is_empty():return roster
	var party: Array = roster.get("party",[])
	party.append([father.species,int(father.level),(father.get("moves",[]) as Array).duplicate()])
	roster["party"] = party
	if roster.has("ivs"):
		var ivs: Array = roster.ivs
		ivs.append(0)
		roster["ivs"] = ivs
	roster["campaign_father"] = father.duplicate(true)
	return roster

func _capture_ending() -> void:
	ending_active = true
	if game.events.has("daycare_egg_left"):
		game._say_pages(["비주기에게 붙잡힌 뒤, 시간이 흘렀다…", "5번도로 교배집.\n네가 남긴 알에 작은 금이 갔다.","이어받은 기술과 함께 눈을 뜬 아이.\n아버지의 자유를 되찾을 두 번째 여행이 시작된다."],_begin_second_cycle)
	else:
		game._say_pages(["비주기는 붙잡은 포켓몬을 앞세워\n곳곳에서 새로운 힘과 승리를 빼앗았다.","오랜 싸움 끝에 최강이라는 이름을 얻었다.\n그러나 가는 곳마다 두려움만 남았다.","자유롭게 여행하던 꿈은 볼 안에 갇혔다.\n배드엔딩 — 빼앗긴 의지", "교배집에서 이야기를 끝내고 알을 남겼다면\n다른 세대가 이 여정을 이어 갈 수 있었을 것이다."],_finish_bad_ending)

func _finish_bad_ending() -> void:
	_flag("campaign_bad_ending")
	data["pending_capture"] = false
	data["bad_ending"] = true
	_save()
	game._save_here()
	game.get_tree().change_scene_to_file("res://scenes/title.tscn")

# Preserve access and friendships, but let the child solve regional stories anew.
# The new journey therefore never repeats the Saffron tutorial lock.
func child_events(parent_events: Array) -> Array:
	var keep: Array = []
	for value in parent_events:
		var event := String(value)
		if event.begins_with("visited_area_") or event.begins_with("friend_") or event in ["giovanni_everstone",HO_OH,SUPPLY,TARGET,"campaign_giovanni_ready"] or event == "campaign_parent_forest_truce" or CLUES.has(event):keep.append(event)
	if parent_events.has("quest_forest_truce_complete") and not keep.has("campaign_parent_forest_truce"):keep.append("campaign_parent_forest_truce")
	for flag in [CYCLE,"visited_area_saffron_city","giovanni_everstone"]:
		if not keep.has(flag):keep.append(flag)
	return keep

func child_snapshot() -> Dictionary:
	var parent: Dictionary = data.get("parent",{})
	if parent.is_empty():parent = snapshot(game.world.player)
	var base := SpeciesDB.base_form(String(parent.get("species",game.starter)))
	var inherited := String(EGG_MOVES.get(base,"dragon_dance"))
	var moves: Array = SpeciesDB.learnable(base,10)
	moves.erase(inherited)
	moves.push_front(inherited)
	var slots: Array = moves.slice(0,Player.SLOT_COUNT)
	while slots.size()<Player.SLOT_COUNT:slots.append("")
	var ind := Individual.method1(int(parent.get("pid",0)) ^ 0xC11D2026)
	var exp := SpeciesDB.exp_for_level(10,SpeciesDB.growth_of(base))
	var pp: Array = []
	for move in slots:pp.append(MoveDB.pp_of(String(move)) if move != "" else 0)
	return {"species":base,"level":10,"exp":exp,"evolution_declined_level":0,"slots":slots,"learned":moves,"pid":ind.pid,"ivs":ind.ivs,"cleared":[],"bag":{"oran_berry":8,"leppa_berry":4},"reward_reserve":{},"hold":"","hotbar":["oran_berry","leppa_berry","",""],"pp_focus_slot":0,"trainers":[],"events":child_events(game.events),"hp":int(SpeciesDB.stats_at(base,10,ind.ivs).hp),"pp":pp,"status":"","field_puzzles":{}}

func _begin_second_cycle() -> void:
	data["cycle"] = 2
	data["pending_capture"] = false
	data["current_challenges"] = []
	data["bad_ending"] = false
	var child := child_snapshot()
	data["egg_move"] = EGG_MOVES.get(child.species,"dragon_dance")
	_save()
	game.carry = child
	game.destination = {"map":"route5_pokemon_day_care","pos":Vector2(-1,-1)}
	game.arena_trip = {}
	game.skip_opening = true
	if game.bot:
		game.bot_events = child.events.duplicate()
		game.bot_beaten = []
	else:
		SaveData.store_cycle(child,String(game.destination.map))
	game.state = "warp"
	game.get_tree().reload_current_scene()

func journal_entries() -> Array:
	var entries: Array = []
	if game.events.has(HO_OH):entries.append({"name":"신비로운 새를 찾아서","objective":"무지갯빛 새의 목격담을 찾아 여행하기","place":"관동 각지","status":"추적 중"})
	if cycle() == 1 and game.events.has(SUPPLY) and game.events.has(TARGET):entries.append({"name":"로켓단의 포획 계획","objective":"상록시티 체육관에서 비주기와 결전하기","place":"상록시티 체육관","status":"증거 확보"})
	if cycle() == 2 and not game.events.has("campaign_father_rescued"):
		var count := 0
		for id in GYMS:
			if game.events.has("campaign_child_won_"+id):count += 1
		entries.append({"name":"아버지를 찾아서","objective":"일곱 관장에게 승리하고 비주기에게 도전하기 (%d/7)"%count,"place":"관동의 체육관","status":"진행 중"})
	return entries

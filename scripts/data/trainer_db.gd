class_name TrainerDB
extends RefCounted

# 트레이너(사용자 결정 2026-10-29: 체육관 배틀도 일반 트레이너 배틀 위에, 체육관일 때만 배지 같은 부가 요소).
# 지도와 일반 트레이너는 pret/pokefirered 기반이다. 관장은 GymRosters의 작성 파티와 GymGrowth의 성장 규칙을 사용한다.
# 원작 파티(src/data/trainer_parties.h: 종족·레벨·기술·고정 개체값),
# 대사(data/maps/<지도>/text.inc, 쪽 나눔 \p 를 배열로). 한국어는 파이어레드 한국어판이 없어 옮긴 말. 자리·시야는 DungeonDB 의 "trainers".
# party: [[종족, 레벨], …] 또는 [[종족, 레벨, [기술 …]], …](CUSTOM_MOVES 트레이너). 기술을 안 적으면 그 레벨의 자력기(원작 DEFAULT_MOVES).
# gym: 체육관 관장 — 관장 곡·컷인, 이기면 같은 체육관의 트레이너도 모두 이긴 것으로 친다(원작 set_gym_trainers).
#      배지는 주지 않는다. 승리 보상은 berry_rewards의 전투용 열매다.

const BASE_CLASSES := {
	"gamer": {"en":"GAMER","ko":"갬블러","sprite":"old_man_1","eye":"seq_eye_boy"},
	"engineer": {"en":"ENGINEER","ko":"엔지니어","sprite":"balding_man","eye":"seq_eye_boy"},
	"researcher": {"en":"RESEARCHER","ko":"연구가","sprite":"bill"},
	"swimmer": {"en":"SWIMMER","ko":"수영팬티소년","sprite":"swimmer_m_water","eye":"seq_eye_boy"},
	"super_nerd": {"en":"SUPER NERD","ko":"이과계의남자","sprite":"scientist","eye":"seq_eye_boy"},
	"rocket": {"en":"TEAM ROCKET","ko":"로켓단","sprite":"rocket_m","eye":"seq_eye_boy"},
	"youngster": {"en":"YOUNGSTER","ko":"반바지꼬마","sprite":"youngster","eye":"seq_eye_boy"},
	"lass": {"en":"LASS","ko":"짧은치마","sprite":"lass","eye":"seq_eye_boy"},
	"camper": {"en":"CAMPER","ko":"캠프보이","sprite":"camper","eye":"seq_eye_boy"},
	"picnicker": {"en":"PICNICKER","ko":"피크닉걸","sprite":"picnicker","eye":"seq_eye_boy"},
	"hiker": {"en":"HIKER","ko":"등산가","sprite":"hiker","eye":"seq_eye_boy"},
	"bug_catcher": {"en": "BUG CATCHER", "ko": "곤충채집소년", "sprite": "bug_catcher", "eye": "seq_eye_boy"},
	"leader": {"en": "LEADER", "ko": "관장", "sprite": "brock"},
	# 라이벌 그린(사용자 요청 2026-10-30): 파이어레드 라이벌 그림(BLUE), 플래티넘 라이벌 곡 — 등장 SEQ_THE_RIV, 배틀 SEQ_BA_RIVAL.
	"rival": {"en": "RIVAL", "ko": "라이벌", "sprite": "blue", "eye": "seq_the_riv", "battle": "seq_ba_rival"},
}

const RIVAL_GREEN := {"class": "rival", "name": "GREEN", "name_ko": "그린", "arena": "arena_route1",
	"berry_reward": {"oran_berry":2,"leppa_berry":1},
	"intro": {"en": ["Huff… huff…\nFinally caught up!", "So you're the one who busted\nout of Gramps's lab, huh?", "Truth is, I was gonna pick YOU.",
			"Then you went and ran off!", "So I brought three friends\nto help me find you.", "Together, we're gonna\ncatch you!",
			"I'll wear you down, then\ninto a POKé BALL you go! Go!"],
		"ko": ["헉… 헉… 드디어 따라잡았다!", "할아버지 연구소에서 볼을 박차고\n나간 게 바로 너지?", "사실 난 원래 너를 고르려고 했다고.\n그런데 네가 먼저 도망쳐 버렸잖아!",
			"그래서 세 녀석과 함께 쫓아왔지.\n이번엔 꼭 너를 잡고 말겠어!", "실컷 약하게 만든 다음\n몬스터볼에 넣어 주마! 가라!"]},
	# 진 뒤에는 열매를 주고 떠난다.
	"defeat": {"en": ["WHAT? Unbelievable!\nI lost?!", "Hmph! I'm letting you off today.", "Next time, you're mine!",
			"Take this. Keep yourself safe\ntill I come back stronger to catch you!"],
		"ko": ["뭐야!? 말도 안 돼!\n내가 지다니!", "흥, 오늘은 봐주는 거야.\n다음엔 꼭 잡고 말 테니까!", "이거나 받아 둬. 내가 더 강해져서\n다시 잡으러 올 때까지 몸 잘 지키고 있으라고!"]},
	"farewell": {"en": ["Smell you later!"], "ko": ["그럼 이만!"]},
	"after": {"en": ["Smell you later!"], "ko": ["그럼 이만!"]}}

# 내 스타팅 → 그린이 고른 스타팅(원작: 상성이 강한 쪽).
const RIVAL_FOR := {"charmander": "rival_green_squirtle", "squirtle": "rival_green_bulbasaur", "bulbasaur": "rival_green_charmander"}

# Authored research battle: EEVEE, an advantageous evolution, then KADABRA.
const BILL := {"class":"researcher","name":"BILL","name_ko":"이수재","sprite":"bill","arena":"arena_route1","berry_reward":{},
	"intro":{"ko": ["나는 이수재! 내가 좋아하는\n포켓몬들을 모으고 있지.", "혼자 여행하는 포켓몬이라니!\n너도 내 최애 목록에 넣고 싶어!", "너를 잡아서 네 타입의 특징을\n가까이에서 연구해 보고 싶어.", "그 특징이 이브이의 진화와\n어떤 관련이 있는지 궁금하거든!", "좋아, 집 앞에서 승부다!\n너를 내 컬렉션에 추가하겠어!"], "en": ["I'm BILL! I collect\nmy favorite POKéMON.", "A POKéMON traveling alone!\nYou belong on my favorites list!", "I want to catch you and study\nthe traits of your type.", "Could those traits tell us\nhow EEVEE evolves?", "Let's battle outside!\nI'll add you to my collection!"]},
	"defeat":{"ko": ["앗, 졌다! 널 잡는 건\n생각보다 훨씬 어렵구나.", "그래도 네 타입과 싸움 방식은\n이브이 연구에 큰 도움이 됐어!"], "en": ["I lost! Catching you is\nharder than I thought.", "Your type and battle style\ntaught me a lot about EEVEE!"]},
	"after":{"ko": ["넌 여전히 내 최애 목록에 있어.\n이번엔 관찰한 걸로 만족할게!"], "en": ["You're still a favorite of mine!\nI'll settle for my notes today."]}}

const BILL_EVOLUTION := {"charmander":"vaporeon","squirtle":"jolteon","bulbasaur":"flareon"}

const BASE_TRAINERS := {
	"bill_vaporeon":{"base":BILL,"party":[["eevee",17,["tackle","sand_attack","quick_attack"]],["vaporeon",18,["water_gun","sand_attack","quick_attack"]],["kadabra",18,["confusion","recover","teleport"]]]},
	"bill_jolteon":{"base":BILL,"party":[["eevee",17,["tackle","sand_attack","quick_attack"]],["jolteon",18,["thunder_shock","sand_attack","quick_attack"]],["kadabra",18,["confusion","recover","teleport"]]]},
	"bill_flareon":{"base":BILL,"party":[["eevee",17,["tackle","sand_attack","quick_attack"]],["flareon",18,["ember","sand_attack","quick_attack"]],["kadabra",18,["confusion","recover","teleport"]]]},
	"mt_moon_jessie_james": {"class":"rocket", "name":"JESSIE & JAMES", "name_ko":"로사·로이", "sprite":"rocket_f", "partner_sprite":"rocket_m", "arena":"arena_mt_moon",
		"party":[["ekans",14],["koffing",14],["meowth",14]], "senders":["jessie","james","self"],
		"berry_reward":{"sitrus_berry":2,"leppa_berry":2,"lum_berry":1},
		"intro":{"ko":["로사: 잠깐! 이 동굴을\n그냥 나갈 생각은 아니겠지?", "로이: 트레이너도 없이 여기까지?\n제법인데, 우리와도 겨뤄 보자!", "나옹: 마지막 상대는 우리다옹!"],
			"en":["JESSIE: Hold it! Leaving\nthis cave already?", "JAMES: You made it alone?\nThen take on our team!", "MEOWTH: We're your last test!"]},
		"defeat":{"ko":["로사: 우리가 지다니!\n이 포켓몬, 보통이 아니야!", "로이: 달맞이산을 넘어갈\n실력은 확실히 있네.", "나옹: 다음엔 우리가 이긴다옹!"],
			"en":["JESSIE: We lost?\nThis POKéMON is tough!", "JAMES: You've earned your\nway out of MT MOON.", "MEOWTH: We'll win next time!"]},
		"after":{"ko":["달맞이산 출구가 열렸다!"],"en":["The way out of MT MOON is clear!"]}},
	# ── 1번도로 라이벌 그린(사용자 요청·승인 대사 2026-10-30) ──
	# 늦게 출발한 오박사의 손자. 원작처럼 내 스타팅에 상성이 강한 스타팅(원작 연구소 배틀 TRAINER_RIVAL_OAKS_LAB_* : Lv5, 그 레벨 기술)을
	# 데리고 1번도로 북쪽 끝에서 따라잡는다(Game._check_rival). 경기장은 1번도로 타일로 짠 arena_route1.
	"rival_green_squirtle": {"base": RIVAL_GREEN, "party": [["squirtle", 5, ["tackle", "tail_whip"]], ["pidgey", 5, ["tackle", "sand_attack"]], ["rattata", 5, ["tackle", "tail_whip", "quick_attack"]]]},
	"rival_green_bulbasaur": {"base": RIVAL_GREEN, "party": [["bulbasaur", 5, ["tackle", "growl"]], ["pidgey", 5, ["tackle", "sand_attack"]], ["rattata", 5, ["tackle", "tail_whip", "quick_attack"]]]},
	"rival_green_charmander": {"base": RIVAL_GREEN, "party": [["charmander", 5, ["scratch", "growl"]], ["pidgey", 5, ["tackle", "sand_attack"]], ["rattata", 5, ["tackle", "tail_whip", "quick_attack"]]]},
	# ── 회색체육관(관장만 배틀 — 캠프보이 리암은 대화 NPC) ──
	# 관장 컷인(EncounterFx "leader", 플래티넘 구조): 얼굴은 파이어레드 웅 그림 상반신 2배, 띠는 같은 바위 타입 관장 강석의 띠(tools/plat_encounter.py).
	"leader_brock": {"class": "leader", "name": "BROCK", "name_ko": "웅", "gym": {},
		"berry_reward": {"sitrus_berry":2,"leppa_berry":1,"lum_berry":1},
		"cutin": {"mugshot": "plat/enc_mugshot_brock", "banner": "plat/enc_leader_banner_rock"},
		# Training-return party; these ranks become player +3,+4,+5,+7.
		"party": [["geodude", 12, ["tackle", "defense_curl"]], ["kabuto", 13, ["absorb", "harden", "scratch"]],
			["onix", 14, ["tackle", "bind", "rock_tomb"]], ["aerodactyl", 16, ["bite", "supersonic", "wing_attack"]]],
		# 웅은 혼자 온 포켓몬의 승부를 받아 주고, 승리 후 열매를 준다.
		"intro": {"en": ["…A POKéMON, alone?\nYou came to challenge my GYM?", "Without a TRAINER, even.\nNormally I'd turn you away…",
				"But that look in your eyes…\nSteady as stone. Fine, I accept!", "I've returned from training.\nI met two new partners there.",
				"KABUTO and AERODACTYL!\nThey've trained beside us.", "I'm BROCK. My POKéMON are\nall hard as rock. Show me!"],
			"ko": ["…포켓몬 혼자서 체육관에\n도전하러 온 건가?", "트레이너도 없이, 라니.\n보통은 돌려보내겠지만…",
				"그 눈빛. 돌처럼 흔들림이 없군.\n좋다, 이 승부 받아 주마!", "수련을 마치고 돌아왔다.\n새로운 동료들도 함께 왔지.",
				"투구와 프테라다.\n함께 단련한 힘을 보여 주마!", "나는 웅. 바위처럼 단단한\n포켓몬들로 상대해 주지!"]},
		"defeat": {"en": ["…I lost. To fight like that\nwithout a TRAINER… Impressive.", "With your skill, you can\nhandle something like this."],
			"ko": ["…졌군. 트레이너 없이\n이만큼 싸우다니, 훌륭하다.", "네 실력이라면\n이런 것도 할 수 있을 거다."]},
		"after": {"en": ["I won't forget those eyes.\nGo find stronger foes."], "ko": ["그 눈빛, 잊지 않으마.\n더 강한 상대를 찾아 떠나거라."]}},
}

const CeruleanData = preload("res://scripts/data/cerulean_progression.gd")
const RoadData = preload("res://scripts/data/road_trainer_db.gd")
const GymData = preload("res://scripts/data/gym_leaders.gd")
const RivalData = preload("res://scripts/data/rival_progression.gd")
const GymGrowth = preload("res://scripts/data/gym_growth.gd")
const GymRosters = preload("res://scripts/data/gym_rosters.gd")
static var CLASSES: Dictionary = BASE_CLASSES.merged(RoadData.CLASSES)
static var TRAINERS: Dictionary = _with_pursuit_trainers()

static func _with_pursuit_trainers() -> Dictionary:
	var result := BASE_TRAINERS.merged(CeruleanData.TRAINERS).merged(GymData.TRAINERS).merged(RivalData.TRAINERS).duplicate(true)
	for id in RoadData.TRAINERS:
		var entry: Dictionary = RoadData.TRAINERS[id]
		if result.has(id):
			# Existing story trainers keep their authored party, dialogue and rewards.
			entry = (result[id] as Dictionary).merged(entry)
			entry["name_ko"] = result[id]["name_ko"]
		result[id] = entry
	for id in GymRosters.PARTIES:
		result[id]=(result[id] as Dictionary).merged(GymRosters.PARTIES[id],true)
	return result

static func has_trainer(id: String) -> bool:
	return TRAINERS.has(id)

static func get_trainer(id: String) -> Dictionary:
	return _t(id)

# A challenge owns its snapshot; level-ups and later challenges cannot mutate it.
static func for_battle(id: String,player_level: int,context: Dictionary={}) -> Dictionary:
	var source:=GymGrowth.configure(id,_t(id),player_level)
	if context.is_empty() or not RoadData.TRAINERS.has(id):return source
	return LevelProgression.trainer(source,String(context.get("area","")),player_level,context.get("events",[]))

# "base" 가 있으면 그 위에 덮어쓴 것(라이벌 그린: 대사는 같고 파티만 스타팅마다 다르다).
static func _t(id: String) -> Dictionary:
	var t: Dictionary = TRAINERS[id]
	if t.has("base"):
		return (t["base"] as Dictionary).merged(t, true)
	return t

# "BUG CATCHER RICK" / "곤충채집소년 릭"
static func display_name(id: String) -> String:
	var t: Dictionary = _t(id)
	var c: Dictionary = CLASSES[t["class"]]
	if Lang.is_ko():
		return "%s %s" % [c["ko"], t["name_ko"]]
	return "%s %s" % [c["en"], t["name"]]

# 대사 쪽 배열(intro / defeat / after).
static func pages(id: String, key: String) -> Array:
	var d: Dictionary = _t(id)[key]
	return d.get(Lang.code, d["en"])

static func sprite(id: String) -> String:
	var t: Dictionary = _t(id)
	return String(t.get("sprite", CLASSES[t["class"]]["sprite"]))

# 이름만(관장 컷인의 이름 칸: "BROCK" / "웅").
static func short_name(id: String) -> String:
	var t: Dictionary = _t(id)
	return String(t["name_ko"] if Lang.is_ko() else t["name"])

# 플래티넘 곡(Bgm): 눈이 마주쳤을 때(곤충채집소년·캠프보이 SEQ_EYE_BOY — 관장은 없음, 컷인과 함께 배틀 곡),
# 배틀(SEQ_BA_TRAIN / 관장 SEQ_BA_GYM), 이긴 뒤(SEQ_WINTRAIN / SEQ_WINTGYM).
static func eye_music(id: String) -> String:
	return String(CLASSES[_t(id)["class"]].get("eye", ""))

static func battle_music(id: String) -> String:
	var c: Dictionary = CLASSES[_t(id)["class"]]
	if c.has("battle"):
		return String(c["battle"])
	return "seq_ba_gym" if _t(id).has("gym") else "seq_ba_train"

# 배틀 경기장: 트레이너가 따로 정해 두었으면 그것(바깥 세계 한 장 안의 1번도로 라이벌), 아니면 그 장소의 경기장.
static func arena_of(id: String) -> String:
	return String(_t(id).get("arena", DungeonDB.arena_of()))

static func cerulean_rival_for(starter: String) -> String:
	return rival_for(starter).replace("rival_green_","rival_cerulean_")

static func bill_for(starter: String) -> String:
	return "bill_"+String(BILL_EVOLUTION.get(SpeciesDB.base_form(starter),"vaporeon"))

static func rival_for(starter: String) -> String:
	return String(RIVAL_FOR.get(starter, RIVAL_FOR["charmander"]))

static func victory_music(id: String) -> String:
	return "seq_wintgym" if _t(id).has("gym") else "seq_wintrain"

# 예전 진단 도구 호환 조회. 현재 보상 데이터에는 tm이 없어 빈 문자열을 반환한다.
static func tm_for(id: String, starter: String) -> String:
	var t: Dictionary = _t(id).get("tm", {})
	return String(t.get(starter, ""))

# "TM28 구멍파기" / "TM28 DIG"
static func tm_label(move_id: String) -> String:
	return "%s %s" % [String(MoveDB.get_move(move_id).get("tm", "TM")), MoveDB.move_name(move_id)]


# Battle rewards are berries; existing learned moves remain untouched.
static func berry_rewards(id: String,roster: Dictionary={}) -> Dictionary:
	var t := get_trainer(id) if roster.is_empty() else roster
	if t.has("berry_reward") and t.berry_reward.is_empty():return {}
	var highest := 0
	for member in t.party: highest=maxi(highest,int(member[1]))
	# One extra effort tier per five levels above Lv10; explicit story rewards stay authored.
	var effort: int = t.party.size()+maxi(0,int(floor((highest-10)/5.0)))
	var regular := {"oran_berry":clampi(effort,1,2)}
	if effort>=3: regular["leppa_berry"]=1
	var reward: Dictionary = t.get("berry_reward",regular).duplicate()
	for member in t.party:
		var moves: Array=member[2] if member.size()>2 else SpeciesDB.enemy_moves(member[0],member[1])
		for berry in BerryLoot.status_berries(moves):
			reward[berry]=maxi(1,int(reward.get(berry,0)))
	return reward

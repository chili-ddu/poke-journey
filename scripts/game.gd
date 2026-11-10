extends Node2D

# 한 판의 흐름: 던전에 들어가면 적이 끊김 없이 이어서 나오고, 다 쓰러뜨리면 끝. 그 사이사이 기술 습득·진화.
# 웨이브 구분·중간 회복은 없다(사용자 결정). 던전 데이터의 "웨이브"는 출현 순서를 적는 단위일 뿐이다.
#
# 상태
#   fight    적이 나오고 싸운다.
#   choose   "어느 기술을 잊게 할까?" 창(월드 정지)
#   evolve   진화 화면(EvolutionScreen — 플래티넘 진화 장면, 월드 정지)
#   gameover, victory
#
# 기술은 원작처럼 종족의 습득 레벨에 자동으로 배운다. 빈 칸이 있으면 바로 배우고 대사만 띄우며,
# 4칸이 차 있으면 잊을 기술을 고르는 창을 연다. 창을 닫으면 원래 상태(resume_state)로 돌아간다.

const RegionTravel = preload("res://scripts/johto/region_travel.gd")
var region_travel: RegionTravel
const QuestRuntime = preload("res://scripts/story/quest_runtime.gd")
var quests: RefCounted = null
const BillEvent = preload("res://scripts/story/bill_event.gd")
const RoadGates = preload("res://scripts/story/road_gates.gd")
var road_gates: RefCounted = null
const MoonPassage = preload("res://scripts/story/moon_passage.gd")
var moon_passage: RefCounted = null
var player_cursor: PlayerCursor
var bill_event: RefCounted = null
const ForestRescue = preload("res://scripts/story/forest_rescue.gd")
const FieldFriends = preload("res://scripts/story/field_friends.gd")
const FieldHMs = preload("res://scripts/data/field_hms.gd")
const GYM_FIELD_SOURCES={"leader_misty":"friend_lapras_surf","leader_lt_surge":"friend_pikachu_flash"}
const GymFieldFriends = preload("res://scripts/story/gym_field_friends.gd")
const BirdEvent = preload("res://scripts/story/bird_event.gd")
const PikachuRescue = preload("res://scripts/story/pikachu_rescue.gd")
const TowerBrothers = preload("res://scripts/story/tower_brothers.gd")
const LaprasEscape = preload("res://scripts/story/lapras_escape.gd")
const SeafoamPuzzle = preload("res://scripts/story/seafoam_puzzle.gd")
var seafoam: RefCounted = null
var puzzles: Dictionary={}
static var bot_puzzles: Dictionary={}
var lapras_escape: RefCounted = null
var tower_brothers: RefCounted = null
var pikachu_rescue: RefCounted = null
var bird_event: RefCounted = null
var forest_rescue: RefCounted = null
var field_friends: RefCounted = null
const START_LEVEL := 5
# 스타팅(사용자 결정 2026-10-28): 시작 화면(PC 박스)에서 고른다. 시작 기술은 플래티넘 습득표의 Lv5 까지(모양 있는 것):
# 이상해씨 몸통박치기·울음소리 / 파이리 할퀴기·울음소리 / 꼬북이 몸통박치기·꼬리흔들기.
const DEFAULT_STARTER := "charmander"
const TITLE_SCENE := "res://scenes/title.tscn"
static var starter := ""          # 시작 화면이 정한다. 비었으면(도구·봇·main.tscn 바로 실행) STARTER 환경변수 또는 파이리
# 한 번에 한 마리씩, 많아야 네 마리. 적은 수를 신중하게 상대하는 게임(사용자 결정).
const SPAWN_INTERVAL := 3.0
const SPAWN_GROUP := 1          # 한 번에 나오는 마리 수
const MAX_ALIVE := 3            # 동시에 살아 있는 최대 마리 수(사용자 결정: 셋)
const TOAST_TIME := 2.6
const SAY_TIME := 2.8
const COMBAT_MESSAGE_TIME := 2.8
const COMBAT_MESSAGE_MEDIUM_TIME := 1.2
const COMBAT_MESSAGE_MEDIUM_THRESHOLD := 4
const COMBAT_MESSAGE_FAST_TIME := 0.6
const COMBAT_MESSAGE_FAST_THRESHOLD := 7
const COMBAT_MESSAGE_STALE_AFTER := 3.0
const STAT_PHASE := 1.5           # 능력치 창 한 단계 길이(오른 만큼 → 새 능력치)
# UI(HUD·기술 잊기 창) 비율(사용자 결정 2026-10-28: 3/4). 늘리기 모드가 canvas_items(정수 배 k)라 UI 레이어를 m/k 배로 그리면
# UI 1px = 창 m px 로 여전히 또렷하다. m = round(k × UI_RATIO): 기본 창(448×252 ×4) 에선 3/4, ×3 창(512·576 시야·전체화면)에선 2/3.
const UI_RATIO := 0.75

var world: World
var hud: Hud
const ScreenControls = preload("res://scripts/ui/touch_controls.gd")
var touch_controls: Control
var look_layer: CanvasLayer        # HD-2D 느낌 후처리(Look): 월드 위·UI 아래 층
var look_rect: ColorRect
var look_ambient: CanvasModulate   # 장소마다 깔리는 밝기(조명이 둘레를 밝힐 바탕)
var view3d: View3D                 # HD-2D 2단계 시제품: 3D 로 세운 지도(층 1, 후처리 층 아래)
var ui_layer: CanvasLayer
var ui_root: Control
var ui_scale := 1.0               # UI 레이어 배율(m/k). HUD 는 화면을 뷰포트 ÷ 이 값 크기로 본다
var panel: ChoicePanel
var state := "fight"
var resume_state := "fight"
var stream: Array = []            # 아직 안 나온 적. { species, level }
const RoadPursuit = preload("res://scripts/battle/trainer_exposure.gd")
const RivalProgression = preload("res://scripts/story/rival_progression.gd")
var rival_progression: RefCounted
var road_pursuit = RoadPursuit.new()

var spawn_t := 0.0
var total_enemies := 0
var defeated := 0

var pending_learns: Array = []    # 배울 차례인 기술 id
var growth_learns: Array = []
var stat_queue: Array = []        # 보여 줄 레벨업 { delta, after }
var exp_segments: Array = []
var exp_segment := {}
var exp_display_level := 0
var exp_display_progress := -1.0
const EXP_FILL_SECONDS := 0.8

var stat_box := {}                # 지금 떠 있는 능력치 창
var stat_t := 0.0
# 가방·상점 창(state "menu"). menu: bag / shop / shop_confirm / game(Esc 게임 메뉴). 창이 열린 동안 세계는 멈춘다(원작 가방처럼).
var menu := ""
var bag_screen: BagScreen
var summary_screen: SummaryScreen
var fly_screen: FlyMapScreen
var menu_resume := "fight"
var menu_ids: Array = []
var shop_pick := ""
var shop_pay := {}
var _wild_tile := Vector2i(-999, -999)   # 스프레이 걸음 세기용 직전 칸
# 트레이너 배틀(사용자 결정 2026-10-29): 그 자리에서 울타리 안에서 싸운다. 상대 포켓몬은 한 마리씩 차례로, 지면 포켓몬센터.
# 체육관 배틀은 같은 흐름 위에 배지·체육관 트레이너 정리만 더한다(TrainerDB 의 gym).
#   spotted  트레이너가 플레이어를 보았다: "!" 뒤 다가온다(세계 정지)
#   talk     대사 쪽을 E·Enter·Space·클릭으로 넘긴다(세계 정지). 다 넘기면 talk_after
const BATTLE_RADIUS := 5.5 * 24.0
const SEND_NEXT_DELAY := 0.6       # "쓰러졌다!" 를 넘긴 뒤 다음 포켓몬까지
const WIN_TEXT_DELAY := 0.6
const FAINT_TEXT_DELAY := Mon.FAINT_TIME   # 쓰러지는 동작이 끝나면 "상대 X는 쓰러졌다!"
# 트레이너가 포켓몬을 내보낼 때(원작 배틀의 볼 던지기): 카메라가 2배로 다가가 비추고, 볼이 날아가 터지면 흰 실루엣으로 나온다.
const SEND_ZOOM := 2.0
const SEND_PAN := 0.35
const SEND_THROW_AT := 0.2
const SEND_THROW := 0.45
const SEND_ARC := 1.2               # 칸. 볼이 그리는 포물선 높이
const SEND_READY := 0.95            # 이때부터 대사를 넘길 수 있다(나온 포켓몬을 보고 나서)
const ARENA_SEND_BACK := 0.7       # Rise into the real-time battle view after the reveal.
const SEND_BACK := 0.3              # 넘긴 뒤 내 포켓몬 쪽 1배로 돌아오는 시간
const BACK_OFF_TILES := 2
const FIRST_SEND_DELAY := 0.6     # 내 포켓몬이 물러나 자리 잡는 시간
const KNOCK_DECEL := 900.0
var trainers: Array = []          # 이 장소의 트레이너(Npc)
var rival := {}                   # 1번도로 라이벌 등장 {npc, path, t}
var rival_exit := {}              # 떠나는 사람(진 라이벌·달아나는 새미) {npc, path}
var sendout := {}                 # 상대가 포켓몬을 내보내는 연출 {mon, ball, t, phase, from_pos, from_zoom, focus}
var battle := {}                  # {trainer: Npc, idx: 다음에 낼 순번, mon: Enemy, next_t, done_t, resume: 배틀 전 상태}
var beaten: Array = []            # 이긴 트레이너 id(저장)
var spot := {}                    # {trainer: Npc, walked: bool}
var talk_pages: Array = []
var talk_focus: WeakRef
var talk_after := Callable()
var page_fanfare := {}            # 대사 쪽 글 → 그 쪽이 뜰 때 울릴 팡파르(배지)
var evolve_bgm := ""              # 진화 전 배경 곡(진화가 끝나면 다시)
var talk_resume := "fight"
var _bot_talk_t := 0.0
static var bot_beaten: Array = [] # 봇·도구는 저장하지 않으니 실행 동안만
static var bot_events: Array = []
var events: Array = []            # 한 번만 일어나는 이벤트 id([progress] events): 상록시티 비주기 등
# 경기장 왕복(사용자 결정 2026-10-29: 원작처럼 컷신 뒤 경기장으로). arena_trip = {trainer, back: {map, pos, layout}} — 경기장에서 싸울 트레이너와
# 돌아갈 자리. carry = 장면을 넘어 들고 가는 내 포켓몬 상태(성장·HP·PP·가방 — 문으로 지날 땐 HP 가 차지만 배틀 왕복은 그대로 이어진다).
static var arena_trip := {}
static var rival_leaving := ""        # 경기장에서 이긴 라이벌이 원래 지도에 돌아온 뒤 떠난다.
static var carry := {}
var encounter: EncounterFx = null
var arena_trainer: Npc = null
var rocket_james: Npc = null
var rocket_meowth: Enemy = null
const MEOWTH_WALK_SPEED := 72.0
var _returned_from_arena := false
var _returned_from_fly := false
var _arrival_door := Vector2i(-1, -1)     # 문으로 왔으면 그 문 칸
# 새 게임 시작 연출(사용자 요청 2026-10-29): 오박사 연구소 탁자 위 볼 세 개 중 내 스타팅의 볼이 흔들리다 튀어나와 열리고 내 포켓몬이 나온다.
var balls: StarterBalls = null
var opening := {}
var _opening_pending := false
var cinematic := false            # 시작 연출 동안: HUD 는 글상자만(줌인한 화면을 가리지 않게)
var monologue := false            # 검은 화면 독백(HUD 가 화면 가운데에 흰 글씨로)
static var opening_outside := false   # 연구소에서 도망쳐 나온 직후 — 태초마을 연구소 문 앞 장면
static var skip_opening := false      # 시험 도구: 시작 연출 없이
var lure_t := 0.0                 # 달콤한향기: 남은 동안 야생 출현 확률 LURE_MULT 배
const LURE_TIME := 10.0
const LURE_MULT := 2.0
var sparkle_pending := false
var evolve_to := ""
var evolution_screen: EvolutionScreen

var banner_text := ""
var banner_sub := ""
var banner_t := 0.0
var status_messages: Array[String] = []
var status_message_times: Array[float] = []
var last_small_message := ""
var _fear_area := ""
var _fear_active := false
const WILD_FEAR_LEVEL_GAP := 10

var combat_message_clock := 0.0
var active_message_created_at := 0.0
var pending_battle_end := ""
var dialog_text := ""
var status_message_active := false
var timed_dialog_pages: Array[String] = []
var dialog_t := 0.0               # 0 이면 시간으로 닫히지 않는다(진화 연출이 직접 닫음)
var toasts: Array = []

var bot := false              # 봇이 조종하고 선택지도 자동으로 고른다(스모크 테스트·스크린샷)
var seed_value := 0
var mode := "dungeon"         # dungeon(적이 줄지어 나오는 던전) / overworld(바깥 세계: 구역별 야생) / indoor(건물 안: 적 없음)
var hub := false              # mode != dungeon
var cleared: Array = []       # 클리어한 던전 id(저장됨)
var wild_since := 0.0         # 바깥 세계: 마지막 야생 출현 뒤 지난 시간(초 = 걸음)
var wild_buff := 0.0          # 허탕 보정(원작 encounterRateBuff: 허탕 1걸음마다 출현율만큼 쌓임)
var despawn_t := 1.0
var warp_armed := false       # 문 칸에서 내려선 뒤에야 다음 문이 열린다(도착한 문으로 되돌아가지 않게)
var fader: ColorRect          # 문 전환 암전
# 장면을 다시 열 때 갈 곳(문·비행·복귀). {map: 장소 id, pos: 월드 px | warp: {map, index} | home: true}. 비어 있으면 저장/환경변수/기본.
static var destination := {}
var _carried_arrival := false
static var came_from_faint := false
static var _player_sparkled := false   # 내 이로치의 반짝임은 실행마다 처음 한 번만(문을 지날 때마다 다시 하지 않게)

func _ready() -> void:
	Controllers.ensure_input_map()
	# 픽셀 글꼴을 창 배율로 다시 래스터하지 않게. 글자 픽셀이 도트 픽셀과 같은 크기여야 한다.
	get_viewport().oversampling = false
	bot = OS.get_environment("BOT") == "1"
	Lang.load_saved()
	# 시야 크기 옵션(ViewScale). 봇·헤드리스(도구)는 건드리지 않는다 — 캡처 크기를 도구가 정한다.
	ViewScale.use_game(get_tree())     # 시작 화면이 바꿔 둔 배율(박스를 창에 꽉 채움)을 원래대로
	if not bot:
		ViewScale.init_window(get_tree())
	seed_value = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else randi()
	# 스타팅과 세이브 칸. 시험 도구가 SaveData.path 를 바꿔 뒀으면 그 파일을 그대로 쓴다.
	if starter == "":
		starter = OS.get_environment("STARTER") if SaveData.STARTERS.has(OS.get_environment("STARTER")) else DEFAULT_STARTER
	if not bot and SaveData.path == SaveData.PATH:
		SaveData.use_slot(starter)
	# 저장된 성장이 있으면 그걸로(봇은 늘 Lv5 스타팅).
	var saved := {} if bot else SaveData.load_saved()
	# 경기장 왕복이면 들고 온 상태가 저장보다 앞선다(봇도 같은 포켓몬으로 이어서 싸운다).
	var carried := carry.duplicate()
	_carried_arrival = not carried.is_empty()
	carry = {}
	if not carried.is_empty():
		var keep_map := String(saved.get("map", ""))
		saved = carried.duplicate()
		saved["map"] = keep_map
	# 갈 곳: 환경변수(도구) > 문·비행·복귀로 정한 곳 > 봇은 기본 던전, 사람은 저장된 자리(없으면 오박사 연구소).
	var dest := destination.duplicate()
	destination = {}
	var where := OS.get_environment("DUNGEON")
	if where == "":
		if dest.has("map"):
			where = String(dest["map"])
		elif bot:
			where = DungeonDB.DEFAULT
		elif not saved.is_empty() and DungeonDB.has_location(String(saved["map"])) and DungeonDB.is_hub(String(saved["map"])):
			where = String(saved["map"])
			dest = {"map": where, "pos": saved["pos"], "layout": int(saved.get("layout", 1))}
		else:
			where = DungeonDB.HOME
	# Explicit developer fixtures keep their source coordinates. Normal travel
	# and legacy saves enter the continuous mainland field exactly once.
	if OS.get_environment("DUNGEON")=="" and not dest.get("source_region",false):
		var mainland:=KantoWorldTravel.promote(where,dest)
		where=mainland.map;dest=mainland.destination
	DungeonDB.set_current(where)
	mode = "arena" if DungeonDB.is_arena() else ("overworld" if DungeonDB.is_overworld() else ("indoor" if DungeonDB.is_indoor() else "dungeon"))
	_returned_from_arena = dest.has("from_arena")
	_returned_from_fly = dest.has("fly_arrival")
	if mode != "arena" and not _returned_from_arena:
		arena_trip = {}
	hub = mode != "dungeon"
	puzzles=(bot_puzzles if bot else saved.get("field_puzzles",{})).duplicate(true)
	if carried.has("field_puzzles"):puzzles=carried.field_puzzles.duplicate(true)
	Arena.configure(SeafoamPuzzle.Data.theme(DungeonDB.theme(),where,puzzles))
	world = World.new()
	add_child(world)
	var species := starter
	var level := START_LEVEL
	var moves: Array = SpeciesDB.learnable(starter, START_LEVEL)
	# 개체 정보(원작 그대로, Individual): 트레이너 ID·비밀 ID 는 저장에서(없으면 새로), 내 포켓몬의 PID·개체값도 저장에서 —
	# 새 게임(또는 개체값이 없던 예전 저장)이면 스타팅처럼 한 번 뽑는다. 봇은 SEED 로 정해진다.
	var id_rng := RandomNumberGenerator.new()
	id_rng.seed = seed_value ^ 0x5EED
	var ids: Array = Individual.new_trainer(id_rng) if bot else SaveData.trainer(id_rng)
	Individual.tid = int(ids[0])
	Individual.sid = int(ids[1])
	Individual.force_shiny = OS.get_environment("SHINY") == "1"
	var ind := Individual.roll(id_rng)
	if not saved.is_empty() and SpeciesDB.has_species(String(saved["species"])) and int(saved["level"]) > 0:
		species = String(saved["species"])
		level = int(saved["level"])
		moves = []
		cleared = saved["cleared"]
		if int(saved.get("pid", -1)) >= 0 and (saved.get("ivs", {}) as Dictionary).size() == 6:
			ind = {"pid": int(saved["pid"]), "ivs": saved["ivs"]}
	world.setup(seed_value, species, level, moves, Controllers.Bot.new() if bot else Controllers.Human.new(), ind)
	if not bot and ViewScale.mobile_mode(get_tree()) and Input.is_action_pressed("move_click"):
		world.player.controller.hold = true
	if not saved.is_empty() and moves.is_empty():
		# 배운 기술: 저장된 목록(예전 저장이면 예전 칸들 + 지금 레벨까지의 자력기). 끼운 칸: 저장된 칸의 앞 두 기술.
		var p0 := world.player
		var old: Array = []
		for m in saved["slots"]:
			if String(m) != "" and MoveDB.has_move(String(m)):
				old.append(String(m))
		var pool: Array = saved.get("learned", [])
		if pool.is_empty():
			pool = old + SpeciesDB.learnable(species, level)
		for m in pool:
			if MoveDB.has_move(String(m)):
				p0.add_learned(String(m))
		for i in mini(old.size(), Player.SLOT_COUNT):
			p0.equip(i, old[i])
		# 빈 칸은 끼우지 않은 배운 기술로 채운다(배운 순서) — 두 칸이던 예전 저장도 W·E·R 이 비지 않게(2026-11-02).
		for i in Player.SLOT_COUNT:
			var combat_spares: Array=p0.spare_moves().filter(func(move):return not FieldHMs.MACHINES.has(move))
			if p0.slots[i] == "" and not combat_spares.is_empty():
				p0.equip(i, combat_spares[0])
		var shb: Array = saved.get("hotbar", [])
		if not shb.is_empty():
			for i in mini(shb.size(), Player.HOTBAR):
				p0.hotbar[i] = String(shb[i]) if ItemDB.has_item(String(shb[i])) else ""
		world.player.exp_total = maxi(int(saved["exp"]), world.player.exp_total)
		world.player.evolution_declined_level = int(saved.get("evolution_declined_level", 0))
		world.player.reward_reserve=(saved.get("reward_reserve",{}) as Dictionary).duplicate()
		world.player.select_skill(int(saved.get("pp_focus_slot",0)))
		var sbag: Dictionary = saved.get("bag", {})
		for id in sbag:
			if ItemDB.has_item(String(id)):
				world.player.add_item(String(id), int(sbag[id]))
		if world.player.bag.has(String(saved.get("hold", ""))):
			world.player.hold = String(saved["hold"])
		world.player.set_status(String(saved.get("status", "")))      # 마비 같은 상태이상은 고칠 때까지(저장에도) 남는다
		# 개체 정보가 없던 예전 저장: 방금 뽑은 PID·개체값·트레이너 ID 를 바로 적어 둔다(다음에 켜도 같게).
		if not bot and int(saved.get("pid", -1)) < 0:
			SaveData.store(world.player, cleared)
	# 내 이로치: 첫 프레임에 반짝(자리가 다 정해진 뒤 — 시험 도구가 옮겨 세워도 그 자리에서).
	sparkle_pending = world.player.shiny and not _player_sparkled
	if not carried.is_empty():
		world.player.hp = clampi(int(carried.get("hp", world.player.max_hp)), 1, world.player.max_hp)
		world.player.set_status(String(carried.get("status", "")))
		world.player.hold = String(carried.get("hold", ""))
		world.player.select_skill(int(carried.get("pp_focus_slot",0)))
		var chb: Array = carried.get("hotbar", [])
		for i in mini(chb.size(), Player.HOTBAR):
			world.player.hotbar[i] = String(chb[i])
		var cpp: Array = carried.get("pp", [])
		for i in mini(cpp.size(), world.player.pp.size()):
			world.player.pp[i] = int(cpp[i])
	world.no_skills = mode == "indoor"
	world.hub = hub
	world.overworld = mode == "overworld"
	# 자리: 문으로 왔으면 그 문 칸, 좌표가 있으면 거기, 아니면 지도의 시작 자리.
	if dest.has("warp"):
		var wt := Arena.warp_tile(String(dest["warp"]["map"]), int(dest["warp"]["index"]))
		if Arena.has_warp(String(dest.warp.map),int(dest.warp.index)):
			_arrival_door = wt
			# 바깥 세계로 나오면 문 칸이 아니라 문 앞 한 칸에 선다(사용자 결정 2026-10-29: 문 칸에 서면 바로 옆으로 못 걸어 불편).
			# Native caves use overworld controls for surf/save, but their warp
			# anchors already sit inside the cave. Do not step outside the model.
			var native_cave := Arena.is_native() and preload("res://scripts/johto/visual_style_rules.gd").game_profile(where)=="cave"
			var out := _door_out_dir(wt) if mode == "overworld" and not native_cave else Vector2i.ZERO
			world.player.position = Arena.tile_center(wt + out)
			world.player.facing = Vector2(out) if out != Vector2i.ZERO else Vector2.DOWN
	elif dest.has("pos") and dest.pos != Vector2(-1,-1):
		var at: Vector2 = dest["pos"]
		# 예전 판 지도에서 저장한 자리면 바뀐 원점만큼 옮긴다(DungeonDB.LAYOUT_SHIFT).
		var lv := int(dest.get("layout", DungeonDB.LAYOUTS.get(where, 1)))
		var shifts: Dictionary = DungeonDB.LAYOUT_SHIFT.get(where, {})
		while lv < int(DungeonDB.LAYOUTS.get(where, 1)):
			at += Vector2(shifts.get(lv, Vector2i.ZERO)) * Arena.TILE
			lv += 1
		world.player.travel_terrain=2 if Arena.is_water(Arena.tile_of(at)) else 0
		# Restoring a saved position is placement, not movement across the map.
		world.player.position = Arena.resolve(at,world.player.radius,false,world.player.travel_terrain)
	warp_armed = Arena.warp_at(world.player.position).is_empty()
	# 문으로 왔으면 도착한 장소·자리를 저장한다(사용자 결정 2026-10-28). 예전엔 문을 지나는 순간 '떠나는 장소의 문 칸'을 적어서,
	# 껐다 켜면 이미 떠난 건물의 출구 매트 위에서 시작했다.
	if (dest.has("warp") or dest.has("region_arrival") or _returned_from_arena) and not bot:
		SaveData.store(world.player, cleared, DungeonDB.current, world.player.position)
	world.god = OS.get_environment("GOD") == "1"
	world.status_message.connect(_queue_status_message)
	world.inventory_changed.connect(_save_here)
	world.enemy_defeated.connect(_on_enemy_defeated)
	world.hotbar_used.connect(_on_hotbar_used)
	world.player_fainted.connect(_on_player_fainted)
	world.player_move_used.connect(_on_pursuit_move_used)
	world.player_grass_rustled.connect(_on_pursuit_grass_rustled)
	world.lured.connect(_on_lured)
	# 지도 위 사람(간호순·점원)과 트레이너.
	for cfg in DungeonDB.DUNGEONS.get(DungeonDB.current, {}).get("npcs", []):
		var n := Npc.new()
		n.setup(cfg)
		world.add_child(n)
		world.npcs.append(n)
	if DungeonDB.current == DungeonDB.HOME:
		balls = StarterBalls.new()
		balls.setup(starter)
		world.add_child(balls)
		_opening_pending = ((not bot and saved.is_empty() and dest.is_empty() and not came_from_faint) or OS.get_environment("OPENING") == "1") \
			and not skip_opening
	if opening_outside:
		_opening_pending = true
	beaten = bot_beaten if bot else Array(saved.get("trainers", []))
	events = bot_events if bot else Array(saved.get("events", []))
	world.progression_enabled=true;world.progression_events=events
	var restored_gym_help:=_restore_gym_field_help()
	var migrated_hms:=FieldHMs.sync(world.player,events)
	rival_progression=RivalProgression.new();rival_progression.setup(self)
	if DungeonDB.current==BillEvent.PLACE:
		bill_event=BillEvent.new()
		bill_event.setup(self)
	if DungeonDB.current==MoonPassage.PLACE or Arena.area_rect("route4").size!=Vector2i.ZERO:
		moon_passage=MoonPassage.new();moon_passage.setup(self)
	if String(arena_trip.get("event",""))!="quest_battle" and (DungeonDB.current in [ForestRescue.PLACE,ForestRescue.ARENA] or (DungeonDB.current==ForestRescue.LEGACY_PLACE and events.has(ForestRescue.WON) and not events.has(ForestRescue.FRIEND))):
		forest_rescue=ForestRescue.new()
		forest_rescue.setup(self)
	bird_event=BirdEvent.new()
	bird_event.setup(self)
	field_friends=FieldFriends.new()
	field_friends.setup(self)
	road_gates=RoadGates.new();road_gates.setup(self)
	region_travel=RegionTravel.new();region_travel.setup(self)
	if DungeonDB.current in PikachuRescue.CAVES:
		pikachu_rescue=PikachuRescue.new()
		pikachu_rescue.setup(self)
	if TowerBrothers.Data.floor_number(DungeonDB.current)>0 or DungeonDB.current==TowerBrothers.Data.ARENA:
		tower_brothers=TowerBrothers.new()
		tower_brothers.setup(self)
	if mode=="overworld":
		lapras_escape=LaprasEscape.new()
		lapras_escape.setup(self)
	if SeafoamPuzzle.Data.is_floor(DungeonDB.current):
		seafoam=SeafoamPuzzle.new();seafoam.setup(self)
	quests=QuestRuntime.new();quests.setup(self)
	_lock_doors()
	if mode == "arena" and not arena_trip.is_empty() and not is_event_battle():
		var at: Dictionary = Arena.map.get("arena", {})
		var tt: Array = at.get("trainer", [int(Arena.map["width"]) / 2, 3])
		arena_trainer = Npc.new()
		arena_trainer.setup({"id": String(arena_trip["trainer"]), "trainer": String(arena_trip["trainer"]), "tile": Vector2i(int(tt[0]), int(tt[1])), "face": "down"})
		world.add_child(arena_trainer)
		world.npcs.append(arena_trainer)
		# 필드는 폭이 짝수(10칸)라 가운데가 칸 경계다 — 칸 가운데에 세우면 반 칸 오른쪽으로 치우친다. 나와 트레이너를 필드 정가운데 세로줄에.
		var fd: Array = at.get("field", [])
		if fd.size() == 4:
			var cx := (Arena.tile_center(Vector2i(int(fd[0]), 0)).x + Arena.tile_center(Vector2i(int(fd[0]) + int(fd[2]) - 1, 0)).x) * 0.5
			world.player.position.x = cx
			arena_trainer.position.x = cx
		arena_trainer.face_toward(world.player.position)
		_add_trainer_partner(arena_trainer)
		world.player.facing = Vector2.UP
		world.arena_cam = true
		world.cam_pos = world.player.position
	for cfg in DungeonDB.DUNGEONS.get(DungeonDB.current, {}).get("trainers", []):
		var c: Dictionary = cfg.duplicate()
		if bool(c.get("pursuit_only", false)): continue
		c["id"] = c["trainer"]
		var n := Npc.new()
		n.setup(c)
		world.add_child(n)
		world.npcs.append(n)
		trainers.append(n)

	for cfg in TrainerDB.CeruleanData.FIELD_TRAINERS:
		var region:=Arena.area_rect(cfg.area)
		if region.size==Vector2i.ZERO:continue
		var c: Dictionary=cfg.duplicate()
		c["id"]=c["trainer"]
		c["tile"]=region.position+c["tile"]
		var n:=Npc.new()
		n.setup(c)
		world.add_child(n)
		world.npcs.append(n)
		trainers.append(n)

	ui_layer = CanvasLayer.new()
	if not bot:
		player_cursor=PlayerCursor.new()
		add_child(player_cursor)
		player_cursor.setup(world.player)
	ui_layer.layer = 4                      # 3D 지도(1)·HD-2D 후처리(2)·3D 화면 글자(3) 위에 — UI 는 흐려지거나 물들지 않는다
	add_child(ui_layer)
	if dest.has("pursuit_visit"): road_pursuit.restore_visit(world,dest["pursuit_visit"])
	_setup_look()
	ui_root = Control.new()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UiFont.make_theme()
	ui_layer.add_child(ui_root)
	hud = Hud.new()
	hud.game = self
	ui_root.add_child(hud)
	panel = ChoicePanel.new()
	panel.chosen.connect(_on_chosen)
	ui_root.add_child(panel)
	bag_screen = BagScreen.new()
	bag_screen.used.connect(_on_bag_used)
	bag_screen.hotbar_set.connect(_on_hotbar_set)
	bag_screen.closed.connect(_close_menu)
	ui_root.add_child(bag_screen)
	summary_screen = SummaryScreen.new()
	summary_screen.closed.connect(_close_menu)
	ui_root.add_child(summary_screen)
	fly_screen=FlyMapScreen.new()
	fly_screen.chosen.connect(bird_event.choose_destination)
	fly_screen.closed.connect(_close_travel_map)
	ui_root.add_child(fly_screen)
	evolution_screen = EvolutionScreen.new()
	evolution_screen.evolved.connect(_on_evolved)
	evolution_screen.finished.connect(_on_evolve_finished)
	ui_root.add_child(evolution_screen)
	fader = ColorRect.new()
	fader.color = Color(0, 0, 0, 1.0 if hub else 0.0)
	if dest.get("moon_arrival",false):fader.color=Color.WHITE
	if mode == "arena" and bool(arena_trip.get("white", false)):
		fader.color = Color(1, 1, 1, 1)          # 관장 컷인은 하얗게 끝난다 → 하얀 화면에서 밝아짐
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(fader)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 5
	add_child(touch_layer)
	touch_controls = ScreenControls.new()
	touch_controls.game = self
	touch_layer.add_child(touch_controls)
	_fit_ui()
	get_window().size_changed.connect(_fit_ui)
	_enter_dungeon()
	_record_area_visit()
	if _opening_pending:
		if opening_outside:
			_begin_opening_outside()
		else:
			_begin_opening()
	_update_bgm()
	if fader.color.a > 0.0:
		create_tween().tween_property(fader, "color:a", 0.0, 0.3)
	# 경기장: 화면이 밝아지면 원작처럼 "○○{이/가} 승부를 걸어왔다!" 와 함께 바로 배틀.
	if arena_trainer != null:
		_begin_battle(arena_trainer)
	if bill_event!=null:
		bill_event.arrive()
	if moon_passage!=null:moon_passage.arrive(bool(dest.get("moon_arrival",false)))
	if forest_rescue!=null:
		forest_rescue.arrive()
	if pikachu_rescue!=null:
		pikachu_rescue.arrive()
	if tower_brothers!=null:
		tower_brothers.arrive()
	bird_event.arrive(String(dest.get("fly_arrival","")),dest.get("fly_back",{}))
	if rival_leaving != "":
		if rival_progression.owns(rival_leaving):
			rival_progression.depart(rival_leaving)
		elif TrainerDB.has_trainer(rival_leaving) and TrainerDB.get_trainer(rival_leaving)["class"]=="rival" and DungeonDB.current in [DungeonDB.OVERWORLD,KantoWorldTravel.ID]:
			_rival_exit(rival_leaving)
		rival_leaving = ""
	quests.arrive()
	if restored_gym_help or not migrated_hms.is_empty():_save_here()

# Recover confirmed gym travel assistance before cave/sea helper arrival hooks.
# Legacy standalone battle flags are intentionally not a source of assistance.
func _restore_gym_field_help() -> bool:
	var restored:=false
	for leader in GYM_FIELD_SOURCES:
		var source: String=GYM_FIELD_SOURCES[leader]
		if not beaten.has(leader) or events.has(source):continue
		events.append(source)
		if not bot:SaveData.store_progress("events",source)
		restored=true
	return restored

func _gym_field_help_pages(leader: String) -> Array:
	if not GYM_FIELD_SOURCES.has(leader):return []
	var source: String=GYM_FIELD_SOURCES[leader]
	if events.has(source):return []
	quests.flag(source)
	var pages: Array=[]
	if leader=="leader_misty":
		pages.append("이슬이: 내 라프라스에게 부탁해 둘게. 바다에서는 라프라스가 널 도와줄 거야!" if Lang.is_ko() else "MISTY: My LAPRAS will help you travel across the sea!")
	else:
		pages.append(GymFieldFriends.REWARDS["leader_lt_surge"].intro[0 if Lang.is_ko() else 1])
	pages.append_array(learn_field_hms())
	return pages

func learn_field_hms() -> Array:
	return FieldHMs.pages(world.player,FieldHMs.sync(world.player,events))

# HD-2D 느낌(Look, 사용자 요청 2026-11-02): 화면을 덮는 후처리 사각형(틸트시프트·블룸·색보정·비네팅)과 장소 밝기.
func _setup_look() -> void:
	var map_dir := String(Arena.theme.get("native_map", Arena.theme.get("map", "")))
	if DisplayServer.get_name() != "headless" and View3D.supported(map_dir):
		# 바닥 오버레이가 2D 세계의 바닥 표시 노드를 그리려면 그 부모(Game·World)도 같은 레이어 비트를 가져야 한다.
		visibility_layer |= Look.GROUND_LAYER
		world.visibility_layer |= Look.GROUND_LAYER       # World 가 직접 그리는 배틀 울타리·떨어진 도구 점도 바닥에
		view3d = View3D.new()
		view3d.layer = 1
		add_child(view3d)
		view3d.build(world, map_dir)
	look_layer = CanvasLayer.new()
	look_layer.layer = 2
	add_child(look_layer)
	look_rect = ColorRect.new()
	look_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	look_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/hd2d_post.gdshader")
	look_rect.material = mat
	look_layer.add_child(look_rect)
	look_ambient = CanvasModulate.new()
	world.add_child(look_ambient)
	_apply_look()

# 대화 상대 주변만 틸트시프트를 해제한다. 약한 참조로 지도 이동/퇴장 후에도 안전하다.
func _update_dialogue_focus() -> void:
	if look_rect == null:
		return
	var mat := look_rect.material as ShaderMaterial
	var target = talk_focus.get_ref() if talk_focus != null else null
	var active := state == "talk" and is_instance_valid(target) and view3d != null and view3d.visible
	mat.set_shader_parameter("dialogue_focus_enabled", false)
	if not active:
		if state != "talk":
			talk_focus = null
		return
	var focus: Rect2 = view3d.mon_focus_bounds(target) if target is Mon else view3d.npc_focus_bounds(target)
	if focus.size == Vector2.ZERO:
		return
	mat.set_shader_parameter("dialogue_focus_center", focus.position)
	mat.set_shader_parameter("dialogue_focus_radius", focus.size)
	mat.set_shader_parameter("dialogue_focus_enabled", true)

# Keep visible Pokemon sharp while preserving blur in the surrounding scenery.
func _update_combat_focus() -> void:
	if look_rect==null: return
	var material := look_rect.material as ShaderMaterial
	material.set_shader_parameter("combat_focus_count",0)
	if view3d==null or not view3d.visible: return
	var masks := PackedVector4Array()
	masks.resize(8)
	var count := 0
	var mons: Array=[world.player]
	mons.append_array(world.enemies)
	for mon in mons:
		var bounds := view3d.mon_focus_bounds(mon)
		if bounds.size==Vector2.ZERO: continue
		masks[count]=Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y)
		count+=1
		if count==8: break
	material.set_shader_parameter("combat_focus",masks)
	material.set_shader_parameter("combat_focus_count",count)

func _apply_look() -> void:
	if look_rect != null:
		look_rect.visible = Look.hd2d()
		var battle_3d := view3d != null and Look.view3d and mode=="arena"
		var post := look_rect.material as ShaderMaterial
		# Samples and actual play now read the same approved region profiles.
		preload("res://scripts/johto/visual_style_rules.gd").apply_game(post, DungeonDB.current, battle_3d)
	if view3d != null:
		view3d.visible = Look.view3d or Arena.is_native() or Arena.is_continent()
		if not view3d.visible:
			world.aim_override = Callable()
		else:
			world.aim_override = view3d.mouse_world
	Look.ambient_now = Look.ambient(DungeonDB.current)
	if look_ambient != null:
		look_ambient.color = Look.ambient_now

# UI 레이어 배율과 UI 컨트롤 크기를 창에 맞춘다. 창 크기·시야 옵션·전체화면이 바뀔 때마다.
func game_view_size() -> Vector2:
	return Vector2(ViewScale.size()) if ViewScale.mobile_mode(get_tree()) else get_viewport().get_visible_rect().size

func _fit_ui() -> void:
	var win := get_window()
	var cs := Vector2(win.content_scale_size)
	var k := maxi(1, int(floor(minf(win.size.x / cs.x, win.size.y / cs.y))))
	if get_viewport().has_meta("mobile_display_scale"):
		cs = get_viewport().get_visible_rect().size
		k = maxi(1,int(floor(float(get_viewport().get_meta("mobile_display_scale")))))
	var ratio := UI_RATIO
	if OS.get_environment("UI_RATIO") != "":      # 도구·비교용 강제값
		ratio = float(OS.get_environment("UI_RATIO"))
	var m := maxi(1, int(round(k * ratio)))
	ui_scale = float(m) / float(k)
	ui_layer.scale = Vector2(ui_scale, ui_scale)
	var logical := (cs / ui_scale).floor()
	for c in [ui_root, hud, panel, fader]:
		if c != null:
			c.position = Vector2.ZERO
			c.size = logical
	# 가방·상태창은 UI 배율(m/k)을 되돌려 원본 1px = 게임 화면 1px(창 k 배, 정수라 또렷) — HUD 보다 4/3 쯤 크게(사용자 요청 2026-10-28).
	var zoom := 1.0 / ui_scale
	for c in [bag_screen, summary_screen, evolution_screen, fly_screen]:
		if c != null:
			c.position = Vector2.ZERO
			c.scale = Vector2(zoom, zoom)
			c.size = (logical / zoom).floor()

func _process(dt: float) -> void:
	_update_dialogue_focus()
	advance(dt)
	if pikachu_rescue!=null:pikachu_rescue.update_light()
	if quests!=null:quests.step(dt)

func _unhandled_input(event: InputEvent) -> void:
	# Spoken dialogue is manual; narration also accepts Space before its timer ends.
	if state == "talk":
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			if can_advance(): _talk_next()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_SPACE and bird_event!=null and bird_event.press_space():
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_SPACE and dialog_t > 0.0 and not dialog_text.is_empty() and state in ["fight", "town"]:
		get_viewport().set_input_as_handled()
		_advance_timed_message()
		return
	# 진화 화면: B(원작 B 버튼)·Esc 로 진화를 멈춘다(교대하는 동안만 받음).
	if state == "evolve":
		if event.physical_keycode in [KEY_B, KEY_ESCAPE]:
			get_viewport().set_input_as_handled()
			evolution_screen.request_cancel()
		return
	if state in ["fight","town"] and world.player.controller is Controllers.Human and not world.no_skills and not world.player.dead:
		var skill := Controllers.SKILL_KEYS.find(event.physical_keycode)
		if skill>=0:world.player.controller.record_skill_event(skill,world)
	if event.physical_keycode == KEY_R and state in ["gameover", "victory"]:
		# 결과 뒤 R: 봇은 같은 곳 다시. 사람은 쓰러졌으면 오박사 연구소(성장은 유지, HP 가득), 클리어했으면 날아온 자리로.
		if bot:
			destination = {}
		elif state == "gameover":
			# 쓰러지면 마지막으로 회복한 포켓몬센터(사용자 결정 2026-10-28: 원작처럼), 들른 적이 없으면 오박사 연구소.
			var sv := SaveData.load_saved()
			var rmap := String(sv.get("respawn_map", ""))
			if rmap != "" and DungeonDB.has_location(rmap) and DungeonDB.is_hub(rmap):
				destination = {"map": rmap, "pos": sv["respawn_pos"], "layout": int(DungeonDB.LAYOUTS.get(rmap, 1))}
				SaveData.store(world.player, cleared, rmap, sv["respawn_pos"])
			else:
				destination = {"map": DungeonDB.HOME}
				SaveData.store(world.player, cleared, DungeonDB.HOME)
			came_from_faint = true
		else:
			var saved := SaveData.load_saved()
			if not saved.is_empty() and DungeonDB.has_location(String(saved["map"])) and DungeonDB.is_hub(String(saved["map"])):
				destination = {"map": saved["map"], "pos": saved["pos"], "layout": int(saved.get("layout", 1))}
			else:
				destination = {"map": DungeonDB.OVERWORLD}
		get_tree().reload_current_scene()
	elif event.physical_keycode == KEY_M:
		_open_town_map()
		get_viewport().set_input_as_handled()
	# F8: 화면 느낌 HD-2D ↔ 평평한 2D(비교용, Look).
	elif event.physical_keycode == KEY_F8:
		Look.toggle()
		_apply_look()
	# F9: 3D 로 세운 지도 ↔ 2D 지도(HD-2D 2단계 시제품, View3D).
	elif event.physical_keycode == KEY_F9:
		Look.view3d = not Look.view3d
		_apply_look()
	# F11: 창(기본) ↔ 전체화면. 사용자는 창 모드를 원하므로 기본은 창.
	elif event.physical_keycode == KEY_F11:
		var win := get_window()
		if win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			win.mode = Window.MODE_WINDOWED
			ViewScale.apply(get_tree(), ViewScale.index, false, true)
		else:
			win.mode = Window.MODE_FULLSCREEN
	# E: 건물 안 사람에게 말 걸기(카운터 앞 칸에서). 간호순은 회복 + 부활 자리, 점원은 물물교환.
	# Space: 앞에 있는 사람에게 말 걸기·오브젝트(사용자 결정 2026-11-02 — 처음엔 E). 아무도 없으면 점프(Controllers.Human.want_jump).
	elif event.physical_keycode == KEY_SPACE and not event.echo and state in ["town", "fight"] and hub:
		var n: Npc = npc_in_reach()
		if n != null:
			_talk(n)
			get_viewport().set_input_as_handled()
		elif lapras_escape!=null and lapras_escape.try_call():
			get_viewport().set_input_as_handled()
		elif mode=="overworld" and battle.is_empty() and world.field_water.fishing.is_empty() and world.field_water.can_use(world):
			_open_water_menu()
			get_viewport().set_input_as_handled()
	# C: 상태창(플래티넘 포켓몬 상세창, 어디서나). 다시 누르거나 Esc 로 닫는다(열린 동안은 창이 키를 먼저 받는다).
	elif event.physical_keycode == KEY_F and state in ["town", "fight"] and mode=="overworld" and battle.is_empty():
		if not world.field_water.fishing.is_empty(): world.field_water.cancel(world)
		else: _open_water_menu()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_C and state in ["town", "fight"]:
		_menu_open("summary")
		summary_screen.open(world.player)
		Sfx.cry(world.player.species_id)        # 원작 상태창을 열면 울음소리
	# B: 가방(어디서나). 다시 누르거나 Esc 로 닫는다.
	elif event.physical_keycode == KEY_B:
		if state == "menu" and menu == "bag":
			_close_menu()
		elif state in ["town", "fight"]:
			_open_bag()
	# - / = : 시야 크기(상자·글자가 화면에서 차지하는 비율) 줄이기 / 넓히기. 저장된다.
	elif event.physical_keycode == KEY_MINUS:
		ViewScale.cycle(get_tree(), -1)
		_toast(Lang.t("view", [ViewScale.NAMES[ViewScale.index]]))
	elif event.physical_keycode == KEY_EQUAL:
		ViewScale.cycle(get_tree(), 1)
		_toast(Lang.t("view", [ViewScale.NAMES[ViewScale.index]]))
	# L: 언어(영어 ↔ 한국어). 글꼴도 바뀌므로 테마를 다시 씌운다. 저장된다.
	elif event.physical_keycode == KEY_L:
		_toggle_lang()
	# Esc: 게임 메뉴(저장하고 시작 화면으로 · 언어 · 닫기). 열린 동안은 ChoicePanel 이 Esc 를 먼저 받아 닫는다.
	elif event.physical_keycode == KEY_ESCAPE and state in ["town", "fight"] and not bot:
		_open_game_menu()

# 한 프레임 진행. 스모크 테스트는 이걸 고정 dt 로 직접 부른다.
func advance(dt: float) -> void:
	combat_message_clock += dt
	if world != null:
		world.talk_ready = hub and state in ["town", "fight"] and (npc_in_reach() != null or (lapras_escape!=null and lapras_escape.can_call()))
	if sparkle_pending:
		sparkle_pending = false
		_player_sparkled = true
		world.shiny_fx(world.player)
	banner_t = maxf(0.0, banner_t - dt)
	for t in toasts:
		t["t"] -= dt
	toasts = toasts.filter(func(t): return t["t"] > 0.0)
	if dialog_t > 0.0:
		dialog_t -= dt
		if dialog_t <= 0.0:
			if state == "talk":
				if can_advance(): _talk_next()
				else: dialog_t = 0.05
			else:
				_advance_timed_message()
	_step_exp_display(dt)
	# 능력치 창은 전투를 멈추지 않고 한 레벨씩 차례로 보여 준다.
	if stat_t > 0.0:
		stat_t -= dt
		if stat_t <= 0.0:
			stat_box = {}
	if growth_learns.is_empty() and dialog_text.is_empty() and status_messages.is_empty() and not world.player.dead and stat_box.is_empty() and not stat_queue.is_empty() and bool(stat_queue[0].get("exp_ready",true)) and state in ["fight","town"] and float(battle.get("faint_t", 0.0)) <= 0.0:
		stat_box = stat_queue.pop_front()
		if exp_display_level > 0:
			exp_display_level = int(stat_box.level)
			exp_display_progress = 0.0
		for move_id in stat_box.get("learns", []):
			if not world.player.known_moves().has(move_id) and not growth_learns.has(move_id):
				growth_learns.append(move_id)
		stat_t = STAT_PHASE * 2.0
		# 원작: 왼쪽 글상자에 "X grew to / LV. n!", 오른쪽 아래에 능력치 창. 창이 떠 있는 동안 대사도 유지.
		_say(Lang.t("grew", [world.player.display_name(), int(stat_box["level"])]))
		dialog_t = stat_t
		Bgm.fanfare(Bgm.LEVEL_UP)
	_show_next_status_message()
	if not pending_battle_end.is_empty():
		world.step_visual(dt)
		if state == "evolve":
			_step_evolve(dt)
		elif pending_battle_end == "victory":
			_open_next_menu()
		_finish_pending_battle_end()
		return
	if state in ["fight", "town"]:
		# Arrival is already a visit even if a discovery scene pauses this frame.
		_record_area_visit()
		_update_bgm()
		if mode == "overworld" and location_name() != _banner_area:
			_banner(location_name(), "")

	match state:
		"fight":
			if bot:
				_bot_maintain(dt)
			if quests!=null and quests.check_discovery():return
			if battle.is_empty() and moon_passage!=null and moon_passage.check_discovery():return
			if mode=="overworld" and battle.is_empty() and forest_rescue!=null and forest_rescue.check_discovery():
				return
			if is_event_battle():
				event_battle().step_battle(dt)
				if state!="fight":return
			# 트레이너 배틀의 사이사이(사용자 결정 2026-10-30): 상대가 쓰러진 직후부터 다음 포켓몬이 볼에서 나올 때까지는 플레이가 멈춘다 —
			# 세계는 그림만 움직인다(쓰러지는 동작·연출). 내보내기 연출 자체는 대화 상태라 이미 멈춰 있다.
			if _battle_paused():
				_step_battle(dt)
				_open_next_menu()
				world.step_visual(dt)
				return
			if mode == "dungeon":
				_step_spawning(dt)
			elif mode == "overworld" and battle.is_empty():
				_step_wild(dt)
			_step_battle(dt)
			world.step(dt)
			_record_area_visit()
			if seafoam!=null and battle.is_empty() and seafoam.check_environment():return
			if mode == "overworld" and battle.is_empty() and state=="fight" and not world.player.dead:
				var caught: Npc = road_pursuit.step(world,view3d,dt,beaten,dialog_text.is_empty() and not exp_display_pending() and Arena.warp_at(world.player.position).is_empty())
				if caught != null:
					world.player.vel = Vector2.ZERO
					_start_intro(caught)
			if mode == "dungeon" and state == "fight" and stream.is_empty() and world.remaining() == 0:
				_win()
			elif mode != "dungeon" and battle.is_empty():
				_check_warp()
				_check_trainers()
				_check_rival()
			_step_rival_exit()
		"town":
			if quests!=null and quests.check_discovery():return
			world.step(dt)
			_record_area_visit()
			_check_warp()
			_check_trainers()
			_check_rival()
		"opening":
			_step_opening(dt)
		"spotted":
			_step_spotted(dt)
		"rival":
			_step_rival(dt)
		"bill_arrival":
			bill_event.step(dt)
		"moon_event":
			moon_passage.step(dt)
		"forest_event":
			forest_rescue.step(dt)
		"tower_event":
			tower_brothers.step(dt)
		"lapras_event":
			lapras_escape.step(dt)
		"seafoam_event":
			seafoam.step(dt)
		"field_cut":
			field_friends.step(dt)
		"bird_event":
			bird_event.step(dt)
		"giovanni":
			_step_giovanni(dt)
		"leave":
			# 떠나는 사람(진 그린)이 지도에서 사라질 때까지 세계는 멈추고 그림만 움직인다. 비주기만은 4칸 지나가면 풀린다(GIO_PASS).
			world.step_visual(dt)
			_step_rival_exit()
			if rival_exit.is_empty():
				state = "town" if mode=="indoor" else "fight"
		"encounter":
			_step_encounter(dt)
		"heal":
			_step_heal(dt)
		"talk":
			if sendout.is_empty():
				world.step_loot_visual(dt)
				world._step_bystanders(dt)
			if not sendout.is_empty():
				_step_sendout(dt)
			if bot:
				_bot_talk_t += dt
				if _bot_talk_t >= 0.4 and can_advance():
					_bot_talk_t = 0.0
					_talk_next()
		"sendout":
			_step_sendout(dt)
		"warp", "menu":
			world.step_loot_visual(dt)
		"evolve":
			_step_evolve(dt)
		"gameover", "victory":
			world.step(dt)
	# 습득·진화는 월드가 도는 상태에서만, 그리고 원작 순서대로 능력치 창이 다 지나간 뒤에 처리한다(죽은 뒤에는 안 한다).
	if pending_battle_end.is_empty() and state == "fight" and not world.player.dead and stat_box.is_empty():
		_open_next_menu()
	if pikachu_rescue!=null:pikachu_rescue.follow(dt)
	if lapras_escape!=null:lapras_escape.follow(dt)

# ── 던전 흐름 ──

# 던전의 출현 순서를 한 줄로 편다.
#   출현표 던전: 원작 확률대로 count 마리를 뽑는다.
#   waves 던전: 적어 둔 순서대로. 보스는 없다(사용자 결정 2026-10-28) — 다 쓰러뜨리면 끝.
func _enter_dungeon() -> void:
	stream.clear()
	if hub:
		# 바깥 세계·건물 안: 적이 줄지어 나오지 않는다. 처음 시작하거나 쓰러진 뒤 돌아오면 HP 를 채운다.
		total_enemies = 0
		defeated = 0
		state = "town" if mode == "indoor" else "fight"
		if (came_from_faint or not SaveData.exists() or bot) and mode != "arena" and not _returned_from_arena and not _returned_from_fly and not _carried_arrival:
			world.player.hp = world.player.max_hp
			if not _opening_pending:
				_say(Lang.t("welcome", [world.player.display_name()]))
			came_from_faint = false
		# 시작 연출 땐 큰 장소 배너가 탁자 위 볼을 가린다. 경기장에서 돌아올 때도 띄우지 않는다 — 떠났던 그 자리이고,
		# 진 라이벌이 뛰어가는 모습을 가린다(위쪽 장소 이름은 그대로).
		if not _opening_pending and not _returned_from_arena and mode != "arena":
			_banner(location_name(), "")
		else:
			_banner_area = location_name()      # 띄우지 않은 채 지금 구역으로(구역이 바뀌면 그때 띄운다)
		return
	if DungeonDB.has_encounters():
		for i in DungeonDB.enemy_count():
			stream.append(DungeonDB.roll_encounter(world.rng))
	else:
		for i in DungeonDB.count():
			stream.append_array(DungeonDB.spawn_list(i))
	total_enemies = stream.size()
	defeated = 0
	spawn_t = 1.0
	state = "fight"
	_banner(DungeonDB.display_name(), "")

func _step_spawning(dt: float) -> void:
	spawn_t -= dt
	if spawn_t > 0.0 or stream.is_empty():
		return
	spawn_t = SPAWN_INTERVAL
	var n := mini(SPAWN_GROUP, MAX_ALIVE - world.remaining())
	for k in maxi(0, n):
		if stream.is_empty():
			break
		var s: Dictionary = stream.pop_front()
		world.queue_spawn(s["species"], s["level"])

func enemies_left() -> int:
	if is_event_battle():return event_battle().enemies_left()
	return stream.size() + world.remaining()

func is_forest_rescue_battle() -> bool:
	return mode=="arena" and DungeonDB.current==ForestRescue.ARENA and forest_rescue!=null

func is_event_battle() -> bool:
	return (quests!=null and quests.is_battle()) or is_forest_rescue_battle() or (mode=="arena" and DungeonDB.current==BirdEvent.ARENA and bird_event!=null) or (mode=="arena" and DungeonDB.current==TowerBrothers.Data.ARENA and tower_brothers!=null)

func event_battle() -> RefCounted:
	if quests!=null and quests.is_battle():return quests
	if mode=="arena" and DungeonDB.current==TowerBrothers.Data.ARENA:return tower_brothers
	return forest_rescue if is_forest_rescue_battle() else bird_event

# 화면 위 이름표: 던전 이름, 바깥 세계에선 서 있는 구역 이름.
# Unlock only the region under the player, never every region in a shared field.
# Reuse persistent event flags so visits also survive battles and save-slot changes.
func _record_area_visit() -> void:
	if mode!="overworld" or state not in ["fight","town"] or world.player.dead:return
	if world.player.get_meta("carried",false):return
	var area:=Arena.area_at(world.player.position)
	area=String(KantoWorldTravel.AREA_ALIASES.get(area,area))
	var entry:=FlyDestinations.find(area)
	if entry.is_empty() or not entry.get("enabled",false):return
	var flag:=FlyDestinations.visit_flag(area)
	if events.has(flag):return
	events.append(flag)
	if not bot:SaveData.store_progress("events",flag)

func location_name() -> String:
	if quests!=null and quests.is_battle():
		var quest: Dictionary=quests.find_quest(String(arena_trip.get("quest_id","")))
		return String(quest.get("name","이야기 속 승부" if Lang.is_ko() else "Story battle"))
	if mode=="arena" and tower_brothers!=null:
		return "포켓몬타워 %d층"%tower_brothers.floor_number if Lang.is_ko() else "POKéMON TOWER %dF"%tower_brothers.floor_number
	if mode == "overworld":
		return DungeonDB.area_name(Arena.area_at(world.player.position))
	return DungeonDB.display_name()

# ── 바깥 세계: 구역별 야생 출현과 문 ──

# 서 있는 구역의 출현표대로 풀숲에서 한 마리씩(도로는 동시에 한 마리, 사용자 결정). 멀어진 녀석은 사라진다.
func _step_wild(dt: float) -> void:
	if not world.field_water.fishing.is_empty(): return
	lure_t = maxf(0.0, lure_t - dt)
	despawn_t -= dt
	if despawn_t <= 0.0:
		despawn_t = 1.0
		world.despawn_far(world.player.position, 520.0)
	# 스프레이: 한 칸 걸을 때마다 1걸음. 남아 있는 동안 야생이 안 나온다.
	var pt := Arena.tile_of(world.player.position)
	if pt != _wild_tile:
		if _wild_tile.x != -999 and world.player.repel_steps > 0:
			world.player.repel_steps -= 1
			if world.player.repel_steps == 0:
				_toast(Lang.t("repel_off"))
		_wild_tile = pt
	var cfg := world.wild_cfg()
	if _update_wild_fear(cfg): return
	if world.player.repel_steps > 0:
		return
	wild_since += dt
	if cfg.get("encounters", []).is_empty():
		# 마을(출현표 없는 구역)로 들어서면 쫓아오던 야생은 도망친다(사용자 결정 2026-10-28). 경험치는 없다.
		if world.remaining() > 0:
			var before := world.remaining()
			world.scatter_enemies(not cfg.get("fishing",{}).is_empty() and world.field_water.can_use(world))
			if world.remaining()<before: _toast(Lang.t("fled"))
		return
	var rate := float(cfg.get("encounter_rate", 21))
	# 한 걸음(WILD_STEP 초)에 한 번 굴리는 것과 같은 확률을 매 프레임 나눠 굴린다(걸음 단위로 툭툭 나오지 않게). 부하는 난수 하나.
	var per_step := DungeonDB.wild_chance(rate, wild_since, wild_buff, world.remaining())
	if lure_t > 0.0:
		per_step = minf(1.0, per_step * LURE_MULT)
	if world.rng.randf() < 1.0 - pow(1.0 - per_step, dt / DungeonDB.WILD_STEP):
		var pick := DungeonDB.roll_table(cfg["encounters"], world.rng)
		if world.queue_spawn(pick["species"], pick["level"]):
			wild_since = 0.0
			wild_buff = 0.0
	else:
		wild_buff += rate * dt / DungeonDB.WILD_STEP


# Empty tables and trainer battles never use the intimidation rule.
func wild_fear_suppressed(cfg: Dictionary) -> bool:
	if not battle.is_empty(): return false
	var maximum := 0
	for entry in cfg.get("encounters",[]):
		if int(entry[2])>0: maximum = maxi(maximum,int(entry[3]) if entry.size()>3 else int(entry[1]))
	if world.progression_enabled and maximum>0:
		maximum=LevelProgression.encounter_window(Arena.area_at(world.player.position),maximum,world.player.level,events).y
	return maximum>0 and world.player.level>=maximum+WILD_FEAR_LEVEL_GAP

func _update_wild_fear(cfg: Dictionary) -> bool:
	var area := Arena.area_at(world.player.position)
	if area!=_fear_area:
		_fear_area=area
		_fear_active=false
	if not wild_fear_suppressed(cfg):
		_fear_active=false
		return false
	if not _fear_active:
		_fear_active=true
		_queue_status_message(Lang.t("wild_afraid",[world.player.display_name()]))
	if world.remaining()>0: world.scatter_enemies()
	wild_since=0.0
	wild_buff=0.0
	return true

# 달콤한향기(사용자 결정 2026-10-29): 출현표가 있는 바깥 구역에서 쓰면 LURE_TIME 초 동안 출현 확률 LURE_MULT 배(다시 쓰면 10초로 되감김),
# 야생이 하나도 없으면 원작 필드 효과처럼 바로 한 마리를 불러낸다. 스프레이 중엔 안 나온다(배율도 스프레이가 이긴다).
func _on_lured() -> void:
	if mode != "overworld":
		return
	var cfg := world.wild_cfg()
	if _update_wild_fear(cfg) or cfg.get("encounters",[]).is_empty():
		return
	lure_t = LURE_TIME
	if world.remaining() > 0 or world.player.repel_steps > 0:
		return
	var pick := DungeonDB.roll_table(cfg["encounters"], world.rng)
	if world.queue_spawn(pick["species"], pick["level"]):
		wild_since = 0.0
		wild_buff = 0.0

# 문 칸에 서면 암전 뒤 반대편으로. 도착한 문에서 내려선 뒤에야 다시 열린다.
# 단, 문 칸 위에서 막힌 쪽(벽·지도 밖)으로 방향키를 누르면 바로 열린다 — 원작 출구 매트(화살표 워프)처럼(사용자 결정 2026-10-28).
# 그래서 건물에 막 들어와 매트 위에 선 채로도 아래(벽 쪽)를 누르면 나가고, 바깥 문 칸에선 위(건물 쪽)를 누르면 들어간다.
func _check_warp() -> void:
	var wp := Arena.warp_at(world.player.position)
	if moon_passage!=null and moon_passage.check_blocked_entry(wp):return
	if wp.is_empty():
		warp_armed = true
		return
	if not warp_armed and not _pushing_wall_on_warp():
		return
	var gym_target:=DungeonDB.warp_destination(wp)
	if DungeonDB.GymLeaders.GYMS.has(gym_target) and not LevelProgression.unlocked(events):
		warp_armed=false
		world.player.vel=Vector2.ZERO
		_say_pages([Lang.t("gym_tutorial_locked")])
		return
	if String(wp["to"]) == GIO_DOOR and mode == "overworld" and not events.has(GIO_EVENT):
		_begin_giovanni(Arena.tile_of(world.player.position))
		return
	if _check_moon_graduation(wp): return
	if tower_brothers!=null and tower_brothers.block_completed_stairs(wp):return
	if seafoam!=null and seafoam.check_fall(wp):return
	var target: String = DungeonDB.warp_destination(wp)
	if target == "":
		warp_armed = false
		_toast(Lang.t("door_locked"))
		return
	state = "warp"
	world.player.vel = Vector2.ZERO
	if not wp.get("edge_transition", false):
		Sfx.play("door")
	destination = {"map": target, "warp": {"map": String(wp["to"]), "index": int(wp["to_warp"])}}
	if wp.get("edge_transition",false):destination.source_region=true
	if Arena.native_at(Arena.tile_of(world.player.position)) or target==DungeonDB.Johto.LEGACY_GATE: _carry_out()
	# 성장만 저장(자리는 도착한 뒤 새 장면이 저장한다).
	if not bot:
		SaveData.store(world.player, cleared)
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.25)
	tw.tween_callback(func(): get_tree().reload_current_scene())

# 문 칸에서 바깥쪽: 그쪽은 걸을 수 있고 반대쪽(건물)은 막힌 방향. 아래를 먼저 본다. 없으면 제자리.
func _door_out_dir(t: Vector2i) -> Vector2i:
	var warp := Arena.warp_at(Arena.tile_center(t))
	if warp.has("arrival_dir"):
		var hint: Array = warp["arrival_dir"]
		return Vector2i(int(hint[0]), int(hint[1]))
	for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		var n: Vector2i = t + d
		if not Arena.solid_at(n.x, n.y) and Arena.warp_at(Arena.tile_center(n)).is_empty() and Arena.solid_at(t.x - d.x, t.y - d.y):
			return d
	return Vector2i.ZERO

# 문 칸 위에서 막힌 칸 쪽으로 누르고 있나(네 방향 중 누르는 쪽과 45° 이내). 그 방향은 '막혔고 반대쪽은 걸을 수 있는' 쪽만 —
# 바깥 문 칸은 양옆도 건물 벽이라, 이걸 빼면 건물에서 나오자마자 옆으로 걸을 때 다시 들어가 버린다.
func _pushing_wall_on_warp() -> bool:
	var p := world.player
	if p.controller == null:
		return false
	var mv: Vector2 = p.controller.move_dir(world)
	if mv.length_squared() < 0.25:
		return false
	mv = mv.normalized()
	var t := Arena.tile_of(p.position)
	for d in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if mv.dot(Vector2(d)) > 0.7 and Arena.solid_at(t.x + d.x, t.y + d.y) and not Arena.solid_at(t.x - d.x, t.y - d.y):
			return true
	return false

# The eastern exit is a one-time graduation battle; victory is saved in beaten.
const MOON_GRADUATION := "mt_moon_jessie_james"

func _add_trainer_partner(lead: Npc) -> Npc:
	var sprite := String(TrainerDB.get_trainer(lead.trainer_id).get("partner_sprite", ""))
	if sprite == "": return null
	var partner := Npc.new()
	partner.setup({"id":lead.id+"_partner", "sprite":sprite, "tile":Arena.tile_of(lead.position), "face":"down"})
	partner.position=lead.position+Vector2.RIGHT*Arena.TILE*1.5
	partner.face_toward(world.player.position)
	world.add_child(partner)
	world.npcs.append(partner)
	lead.set_meta("trainer_partner",weakref(partner))
	if lead.trainer_id==MOON_GRADUATION:
		_setup_rocket_formation(lead,partner)
	return partner

func _setup_rocket_formation(jessie: Npc, james: Npc) -> void:
	rocket_james=james
	var center:=jessie.position
	var spacing:=Arena.TILE*1.5
	if mode!="arena":
		center-=Vector2.RIGHT*Arena.TILE
		spacing=Arena.TILE
	jessie.set_meta("formation_center",center)
	jessie.position=center-Vector2.RIGHT*spacing
	james.position=center+Vector2.RIGHT*spacing
	jessie.face_toward(world.player.position)
	james.face_toward(world.player.position)
	var entry: Array=TrainerDB.get_trainer(MOON_GRADUATION).party[2]
	rocket_meowth=Enemy.new()
	rocket_meowth.setup_trainer_mon(entry[0],entry[1],[],world.rng)
	# Align feet with the two humans while keeping the same actor for its battle turn.
	rocket_meowth.position=center-Vector2(0,rocket_meowth.feet_offset())
	rocket_meowth.facing=(world.player.position-rocket_meowth.position).normalized()
	world.add_child(rocket_meowth)
	world.bystanders.append(rocket_meowth)

func _check_moon_graduation(warp: Dictionary) -> bool:
	if mode!="overworld" or DungeonDB.current!="mt_moon_b1f" or String(warp.get("to",""))!="route4":return false
	if beaten.has(MOON_GRADUATION) or world.player.dead:return false
	var n:=Npc.new()
	n.setup({"id":MOON_GRADUATION, "trainer":MOON_GRADUATION, "tile":Arena.tile_of(world.player.position), "face":"down"})
	n.position=Arena.resolve(world.player.position+Vector2.DOWN*Arena.TILE,Npc.BODY_R)
	world.add_child(n)
	world.npcs.append(n)
	_add_trainer_partner(n)
	n.face_toward(world.player.position)
	world.player.vel=Vector2.ZERO
	_start_intro(n)
	return true

func progress() -> float:
	return 0.0 if total_enemies == 0 else float(defeated) / float(total_enemies)

func _win() -> void:
	if world.player.dead or pending_battle_end == "gameover": return
	pending_battle_end = "victory"

func _finish_pending_battle_end() -> void:
	if state not in ["fight", "town"] or pending_battle_end.is_empty() or not status_messages.is_empty() or not dialog_text.is_empty() or not stat_box.is_empty():
		return
	if pending_battle_end == "victory" and (exp_display_pending() or not stat_queue.is_empty() or not growth_learns.is_empty() or not pending_learns.is_empty()):
		return
	world.stop_battle_audio()
	var result := pending_battle_end
	pending_battle_end = ""
	if result == "gameover":
		if quests!=null and quests.is_battle():
			quests.handle_loss()
			return
		if RoadPursuit.Data.TRAINERS.has(String(arena_trip.get("trainer", ""))):
			_road_blackout()
			return
		state = "gameover"
		Bgm.stop()
		panel.close()
	else:
		_finish_win()

func _finish_win() -> void:
	state = "victory"
	world.clear_enemy_projectiles()
	panel.close()
	# 클리어한 성장은 여기서 저장된다(봇은 저장 안 함).
	if not bot:
		if not cleared.has(DungeonDB.current):
			cleared.append(DungeonDB.current)
		SaveData.store(world.player, cleared)
		_toast(Lang.t("saved"))

func _on_player_fainted() -> void:
	pending_battle_end = "gameover"
	if RoadPursuit.Data.TRAINERS.has(String(arena_trip.get("trainer", ""))):
		_queue_status_message("目の前が真っ暗になった！" if Lang.code=="ja" else ("눈앞이 캄캄해졌다!" if Lang.is_ko() else "Everything went black!"))

# Pursuit defeat returns automatically to the last healing center after blackout.
func _road_blackout() -> void:
	var saved := SaveData.load_saved()
	var place := String(saved.get("respawn_map","pewter_center"))
	if not DungeonDB.has_location(place) or not DungeonDB.is_indoor(place): place = "pewter_center"
	var at: Vector2 = saved.get("respawn_pos",Vector2(7.5,5.5)*Arena.TILE)
	arena_trip = {}
	world.full_restore(false)
	_carry_out()
	destination = {"map":place,"pos":at,"layout":int(DungeonDB.LAYOUTS.get(place,1))}
	came_from_faint = true
	state = "warp"
	if not bot: SaveData.store(world.player,cleared,place,at)
	var fade := create_tween()
	fade.tween_property(fader,"color:a",1.0,0.3)
	fade.tween_callback(func(): get_tree().reload_current_scene())

# ── 경험치·레벨업·기술 습득 ──

func _on_pursuit_grass_rustled() -> void:
	if mode=="overworld" and state=="fight" and battle.is_empty() and not world.player.dead:
		road_pursuit.notice(Arena.area_at(world.player.position),RoadPursuit.GRASS_GAIN)

func _on_pursuit_move_used(_move_id: String) -> void:
	if mode=="overworld" and state=="fight" and battle.is_empty() and not world.player.dead:
		road_pursuit.notice(Arena.area_at(world.player.position),RoadPursuit.MOVE_ATTENTION,true)

func _on_enemy_defeated(e: Enemy, exp: int) -> void:
	defeated += 1
	if is_event_battle():
		event_battle().defeated_enemy(e)
		return # Story combat grants no EXP, level-ups, move learns or evolutions.
	if battle.is_empty() or e != battle.get("mon"):
		_queue_status_message(Lang.t("fainted", [world._battle_name(e)]))
	var p := world.player
	if p.dead:
		return
	# 트레이너의 포켓몬은 경험치 1.5배(원작 4세대·파이어레드 공통).
	if e.trainer_owned:
		exp = int(floor(exp * 1.5))
	if not battle.is_empty() and e == battle["mon"]:
		var party: Array = battle_trainer()["party"]
		# 원작 순서: 쓰러지는 동작 → "상대 X는 쓰러졌다!" → 경험치·레벨업 → 다음 포켓몬(또는 승리).
		battle["faint_t"] = FAINT_TEXT_DELAY + e.dying_t     # 밀려나거나 굳어 있는 시간만큼 더 기다린다
		battle["faint_name"] = e.display_name()
		battle["then"] = "next" if int(battle["idx"]) < party.size() else "done"
	# Gym challenges still advance fainting, reserves and victory, without growth.
	if not battle.is_empty() and battle.has("trainer") and TrainerDB.get_trainer(battle["trainer"].trainer_id).has("gym"):
		return
	var old_level := p.level
	var old_progress := p.exp_progress()
	if not exp_display_pending():
		exp_display_level = old_level
		exp_display_progress = old_progress
	var gained := p.gain_exp(exp)
	for k in gained:
		var before: Dictionary = p.stats.duplicate()
		p.set_level(p.level + 1)
		var delta := {}
		for key in p.stats:
			delta[key] = int(p.stats[key]) - int(before[key])
		stat_queue.append({"delta": delta, "after": p.stats.duplicate(), "level": p.level,
			"learns": SpeciesDB.moves_at_level(p.species_id, p.level), "exp_ready": false})

	for level in range(old_level,p.level):
		exp_segments.append({"level":level,"from":old_progress if level==old_level else 0.0,"to":1.0,"level_up":true})
	if p.level < 100:
		exp_segments.append({"level":p.level,"from":old_progress if p.level==old_level else 0.0,"to":p.exp_progress(),"level_up":false})
	elif gained == 0:
		exp_display_level = 0
		exp_display_progress = -1.0

func exp_display_pending() -> bool:
	return not exp_segment.is_empty() or not exp_segments.is_empty()

func displayed_level() -> int:
	return exp_display_level if exp_display_level > 0 else world.player.level

func displayed_exp_progress() -> float:
	return exp_display_progress if exp_display_progress >= 0.0 else world.player.exp_progress()

func _step_exp_display(dt: float) -> void:
	if state not in ["fight","town"] or world.player.dead or not growth_learns.is_empty() or not stat_box.is_empty() or not dialog_text.is_empty() or float(battle.get("faint_t",0.0)) > 0.0:
		return
	if exp_segment.is_empty():
		if not stat_queue.is_empty() and bool(stat_queue[0].get("exp_ready",true)): return
		if exp_segments.is_empty():
			exp_display_level = 0
			exp_display_progress = -1.0
			return
		exp_segment = exp_segments.pop_front()
		exp_segment["elapsed"] = 0.0
		exp_display_level = int(exp_segment.level)
	exp_segment.elapsed += dt
	var progress := clampf(float(exp_segment.elapsed)/EXP_FILL_SECONDS,0.0,1.0)
	exp_display_progress = lerpf(float(exp_segment.from),float(exp_segment.to),progress)
	if float(exp_segment.elapsed) >= EXP_FILL_SECONDS + (0.12 if bool(exp_segment.level_up) else 0.0):
		if bool(exp_segment.level_up):
			for entry in stat_queue:
				if int(entry.level)==int(exp_segment.level)+1:
					entry["exp_ready"] = true
					break
		exp_segment = {}

# 그 레벨에 배우는 기술을 차례에 넣는다. 이미 아는 것은 건너뛴다.
func _queue_learns(species_id: String, level: int) -> void:
	for move_id in SpeciesDB.moves_at_level(species_id, level):
		if not world.player.known_moves().has(move_id) and not pending_learns.has(move_id):
			pending_learns.append(move_id)

func _open_next_menu() -> void:
	if exp_display_pending() and growth_learns.is_empty(): return
	if state != "fight" or world.player.dead or not dialog_text.is_empty() or not status_messages.is_empty() or not stat_box.is_empty() or (not stat_queue.is_empty() and growth_learns.is_empty()) or float(battle.get("faint_t", 0.0)) > 0.0:
		return
	var p := world.player
	for queue in [growth_learns, pending_learns]:
		while not queue.is_empty() and p.known_moves().has(queue[0]):
			queue.pop_front()
	if not stat_queue.is_empty() and growth_learns.is_empty():
		return
	if not growth_learns.is_empty() or not pending_learns.is_empty():
		# 새 기술은 배운 기술 목록에 쌓인다(사용자 결정 2026-10-28: '잊게 할까' 창 없음). 빈 칸이 있으면 바로 끼운다.
		var move_id: String = growth_learns.pop_front() if not growth_learns.is_empty() else pending_learns.pop_front()
		p.add_learned(move_id)
		var slot := p.first_empty_slot()
		if slot >= 0:
			p.learn(move_id, slot)
			_say(Lang.t("learned", [p.display_name(), MoveDB.move_name(move_id)]))
			return
		_say(Lang.t("learned", [p.display_name(), MoveDB.move_name(move_id)]))
		return
	var target := p.evolution_target()
	if target != "" and not evolve_held(p):
		resume_state = state
		state = "evolve"
		evolve_to = target
		evolve_bgm = Bgm.now()
		p.vel = Vector2.ZERO
		evolution_screen.open(p, target)

# 봇: 배운 기술 중 더 센 것이 있으면 약한 칸(변화기는 위력 0)에 끼운다. PP 가 가득인 칸만 바꿀 수 있어 1초마다 다시 본다
# — 흐름 시험용(사람은 상태창에서 고른다).
var _bot_equip_t := 0.0
func _bot_maintain(dt: float) -> void:
	_bot_equip_t -= dt
	if _bot_equip_t > 0.0:
		return
	_bot_equip_t = 1.0
	var p := world.player
	var best := ""
	var best_pow := -1
	for m in p.spare_moves():
		var pw := int(MoveDB.get_move(m).get("power", 0))
		if pw > best_pow:
			best_pow = pw
			best = m
	if best == "":
		return
	var weakest := -1
	var weakest_pow := 1 << 30
	for i in Player.SLOT_COUNT:
		var pw := int(MoveDB.get_move(p.slots[i]).get("power", 0)) if p.slots[i] != "" else -1
		if pw < weakest_pow:
			weakest_pow = pw
			weakest = i
	if weakest >= 0 and best_pow > weakest_pow:
		if p.can_swap(weakest):
			p.equip(weakest, best)
			p.set_meta("bot_hold_slot", -1)
		else:
			p.set_meta("bot_hold_slot", weakest)   # 그 칸은 PP 가 찰 때까지 안 쓴다(Controllers.Bot)
	else:
		p.set_meta("bot_hold_slot", -1)

func _on_chosen(index: int) -> void:
	if state == "menu":
		_resolve_menu(index)

# ── 진화 ──

# 진화 화면(EvolutionScreen)이 원작 순서대로 진행하고, 종족을 바꿀 때(evolved)와 필드로 돌아올 때(finished) 알린다.
func _step_evolve(dt: float) -> void:
	evolution_screen.step(dt)

# B 로 멈춘 그 종족·레벨이면 다시 묻지 않는다(레벨이 오르면 다시).
static func evolve_held(p: Player) -> bool:
	return p.evolution_declined_level > 0 and p.level <= p.evolution_declined_level

func _on_evolved() -> void:
	var p := world.player
	p.evolve_to(evolve_to)
	Sfx.cry(p.species_id)                   # 진화한 모습의 울음소리
	# 원작처럼 진화한 종족이 지금 레벨에 배우는 기술이 있으면 필드로 돌아와 이어서 배운다.
	_queue_learns(p.species_id, p.level)

func _on_evolve_finished(did_evolve: bool) -> void:
	if not did_evolve:
		world.player.evolution_declined_level = world.player.level
	state = resume_state
	Bgm.play(evolve_bgm)          # 진화 전 곡을 다시
	if did_evolve:
		var pages:=learn_field_hms()
		_save_here()
		if not pages.is_empty():_say_pages(pages)

# ── 포켓몬센터 회복 연출(사용자 아이디어 2026-10-29 — 원작엔 없음) ──
# 간호순에게 말을 걸면 내 포켓몬이 카운터 위 회복 기계로 뛰어올라(Hop) 잠들고(Sleep 동작), 회복한 뒤 다시 뛰어내린다.
# 그동안 세계는 멈추고 그림만 움직인다(World.step_visual). 잠든 동안은 원작 회복 기계(field_effect.c FldEff_PokecenterHeal)의
# 박자 그대로(사용자 결정 2026-10-29): 볼을 올려놓은 뒤처럼 32프레임 쉬고 → 회복 곡(플래티넘 SEQ_ASA 팡파르 — 장소 곡은 잠깐 멈춤)과 함께
# 몬스터볼 깜빡임 대신 몸에 빛이 위에서 아래로 세 번 흐르고 한 번 번쩍임(StatOverlay 회복 빛, 120프레임) → 30프레임 쉼(그리고 BGM 끝까지)
# → 회복(원작도 연출이 끝난 뒤 HealPlayerParty).
const HEAL_HOP := 0.4
const HEAL_PRE := 32.0 / 60.0
const HEAL_POST := 30.0 / 60.0
var heal := {}
var heal_sleep := 3.0             # 이번 회복에서 잠든 시간(빛 + BGM 길이로 정해짐)

func _start_heal(n: Npc) -> void:
	var p := world.player
	heal = {"t": 0.0, "from": p.position, "spot": n.heal_spot, "nurse": n, "slept": false, "glow": false, "healed": false, "back": false}
	var bgm_len := Bgm.length(Bgm.HEAL)
	heal_sleep = HEAL_PRE + maxf(StatOverlay.HEAL_STEP * (StatOverlay.HEAL_SWEEPS * 4 + 3) + HEAL_POST, bgm_len)
	state = "heal"
	p.vel = Vector2.ZERO
	p.facing = (n.heal_spot - p.position).normalized()
	p.play_hop()

func _step_heal(dt: float) -> void:
	var p := world.player
	heal["t"] = float(heal["t"]) + dt
	var t: float = heal["t"]
	var from: Vector2 = heal["from"]
	var spot: Vector2 = heal["spot"]
	if t < HEAL_HOP:
		p.position = from.lerp(spot, t / HEAL_HOP)
	elif t < HEAL_HOP + heal_sleep:
		p.position = spot
		if not bool(heal["slept"]):
			heal["slept"] = true
			p.facing = Vector2.DOWN
			p.sleep_t = heal_sleep          # Sleep 동작만(Z 표시는 없음 — 사용자 결정 2026-10-29)
		if t >= HEAL_HOP + HEAL_PRE and not bool(heal["glow"]):
			heal["glow"] = true
			p.play_heal_glow()
			Bgm.fanfare(Bgm.HEAL)
		if t >= HEAL_HOP + heal_sleep - 1.0 / 60.0 and not bool(heal["healed"]):
			heal["healed"] = true
			world.full_restore(false)
	elif t < HEAL_HOP * 2.0 + heal_sleep:
		if not bool(heal["back"]):
			heal["back"] = true
			p.sleep_t = 0.0
			p.facing = (from - spot).normalized()
			p.play_hop()
		if not bool(heal["healed"]):
			heal["healed"] = true
			world.full_restore(false)
		p.position = spot.lerp(from, (t - HEAL_HOP - heal_sleep) / HEAL_HOP)
	else:
		p.position = from
		var n: Npc = heal["nurse"]
		p.facing = (n.position - p.position).normalized()
		heal = {}
		state = "town"
		_finish_heal(n)
	world.step_visual(dt)

# 장소 곡(Bgm.PLACE): 관동 남부처럼 여러 구역을 이은 지도는 서 있는 구역의 곡. 트레이너 배틀·경기장 동안은 배틀 쪽 곡을 그대로 둔다.
func _update_bgm() -> void:
	if mode == "arena" or not battle.is_empty():
		return
	var song := Bgm.place(Arena.area_at(world.player.position))
	if song == "":
		song = Bgm.place(DungeonDB.current)
	Bgm.play(song, true)

func _finish_heal(n: Npc) -> void:
	world.full_restore(false)
	SaveData.store_respawn(DungeonDB.current, Arena.tile_center(n.talk_tile))
	if not bot:
		SaveData.store(world.player, cleared, DungeonDB.current, world.player.position)
	_say_pages(_pages([Lang.t("nurse_done"), Lang.t("nurse_bye")], n))

# 대사 목록을 쪽으로 편다: 한 대사 안의 "|" 는 쪽 나눔(글상자 두 줄에 안 들어가는 영어).
func _pages(lines: Array, speaker: Npc = null) -> Array:
	var out: Array = []
	for l in lines:
		for text in String(l).split("|"):
			out.append({"text": text, "speaker": weakref(speaker)} if speaker != null else text)
	return out

# ── 새 게임 시작 연출 ──
# 이야기(사용자 결정 2026-10-29): 볼 안에만 갇혀 있을 수 없는 내 포켓몬이 최강이 되려고 탈출하고, 오박사가 "어디 가냐"며 쫓아와
# 오박사 연구소 문 앞에서 게임이 시작된다. 대사는 사용자 승인(Lang intro_* / oak_*).
#   1 검은 화면 독백: 자기소개(종마다) → 바깥세상의 소리 → 결심
#   2 내 볼에 2배로 다가간 채 밝아짐 + 해설 "조용한 연구소… 그런데 탁자 위 몬스터볼 하나가…"
#   3 볼이 버둥대듯 세 번 흔들림(볼 밑동 축, 20°·28°·36°), 흔들릴 때마다 카메라가 한 단계씩 더 다가감(3·4·5배)
#   4 마지막 흔들림 끝에 터지듯 열림(하얀 빛) → 하얀 실루엣으로 커지며 튀어나와 Hop 으로 뛰어 탁자 앞 바닥에 착지,
#     카메라는 빛과 함께 1배로 빠짐. 오박사(원작 자리 6,3)가 "!" 로 놀라 돌아봄
#   5 오박사 "아니!? 볼에서 혼자 나오다니…!" → 내 포켓몬이 오박사를 한 번 보고 출구로 달아남 → 오박사 "!" + "어디 가는 게냐!?"(멈추지
#     않는 글) 하며 뒤쫓음(원작 걷기 속도라 느림) → 출구에 닿으면 태초마을로
#   6 연구소 문 앞: 문에서 두 칸 앞에 선 내 포켓몬, 오박사가 문에서 나와 한 칸 걸어와 헉헉 → 대사 세 쪽 → 내 포켓몬은 정면으로 돌아서고
#     오박사는 연구소로 돌아감 → 조작 시작·저장
# 그동안 세계는 멈추고 그림만 움직인다(World.step_visual).
const OPENING_WAIT := 0.5
const WOBBLE_TIMES := [0.5, 0.42, 0.34]      # 흔들림 한 번(좌 → 우) 길이 — 점점 빨라진다
const WOBBLE_ANGLES := [20.0, 28.0, 36.0]    # 도 — 점점 세진다
const WOBBLE_GAP := 0.22
const ZOOM_START := 2.0
const ZOOMS := [3.0, 4.0, 5.0]               # 흔들림마다 카메라 배율(정수 — 도트가 번지지 않게)
const ZOOM_STEP := 0.12
const ZOOM_OUT := 0.4
const APPEAR_TIME := 0.18
const ESCAPE_JUMP := 0.55                    # 볼 자리 → 바닥까지
const ESCAPE_HEIGHT := 0.9                   # 칸. 꼭대기 높이
const LANDED_HOLD := 0.45
const LOOK_BACK := 0.4                       # 달아나기 전 오박사를 한 번 보는 시간
const RUN_SPEED := 100.0                     # px/s(오박사 걷기 90 보다 조금 빠르다 — 오박사는 늦게 출발)
const OAK_CALL_AT := 0.45                    # 달리기 시작하고 이만큼 뒤 오박사가 놀라 소리치며 쫓는다
const LAB_EXIT := Vector2i(6, 12)            # 연구소 출구 칸(원작 지도 warp 0)
const OUTSIDE_OAK_AT := 0.6
const OAK_BERRIES := 3                       # 오박사가 문 앞에서 주는 오랭열매(사용자 결정 2026-10-30)

func _begin_opening() -> void:
	_opening_pending = false
	var p := world.player
	p.position = StarterBalls.ball_of(starter)
	p.facing = Vector2.DOWN
	p.vel = Vector2.ZERO
	p.appear = 0.0
	balls.intro = true
	cinematic = true
	monologue = true
	sparkle_pending = false          # 이로치 반짝임은 나온 뒤에
	if world.cam != null:
		world.cam.zoom = Vector2(ZOOM_START, ZOOM_START)
		world.cam.position = p.position.round()
	opening = {"phase": "monologue", "t": 0.0}
	state = "opening"
	var pages := [Lang.t("intro_self_" + starter if Lang.S.has("intro_self_" + starter) else "intro_self_charmander"),
		Lang.t("intro_world"), Lang.t("intro_resolve")]
	_say_pages(pages, _opening_lab_lights)

# 독백이 끝나면: 검은 화면에서 볼에 다가간 연구소가 밝아지며 해설.
func _opening_lab_lights() -> void:
	monologue = false
	fader.color.a = 1.0
	create_tween().tween_property(fader, "color:a", 0.0, 0.5)
	state = "opening"
	opening = {"phase": "lights", "t": 0.0}
	_say_pages(_pages([Lang.t("intro_lab")]), _opening_wobble)

func _opening_wobble() -> void:
	state = "opening"
	opening = {"phase": "wobble", "t": 0.0, "open": false, "shown": false}

func _npc(id: String) -> Npc:
	for n in world.npcs:
		if (n as Npc).id == id:
			return n
	return null

func _opening_open_at() -> float:
	var t := OPENING_WAIT
	for d in WOBBLE_TIMES:
		t += float(d) + WOBBLE_GAP
	return t - WOBBLE_GAP            # 마지막 흔들림이 끝나자마자 열린다

# 시작 연출의 카메라 배율: 연출 시간(t)으로 정한다 — 흔들림 i 가 시작되면 ZOOM_STEP 동안 ZOOMS[i] 로, 열리면 ZOOM_OUT 동안 1배로(ease out).
func _opening_zoom(t: float, open_at: float) -> float:
	var z := ZOOM_START
	var w0 := OPENING_WAIT
	for i in WOBBLE_TIMES.size():
		if t >= w0:
			var k := clampf((t - w0) / ZOOM_STEP, 0.0, 1.0)
			z = lerpf(z, float(ZOOMS[i]), 1.0 - (1.0 - k) * (1.0 - k))
		w0 += float(WOBBLE_TIMES[i]) + WOBBLE_GAP
	if t >= open_at:
		var k := clampf((t - open_at) / ZOOM_OUT, 0.0, 1.0)
		z = lerpf(z, 1.0, 1.0 - (1.0 - k) * (1.0 - k))
	return z

func _step_opening(dt: float) -> void:
	opening["t"] = float(opening["t"]) + dt
	match String(opening.get("phase", "")):
		"wobble":
			_step_opening_wobble()
		"run":
			_step_opening_run(dt)
		"outside":
			_step_opening_outside()
	if balls != null:
		balls.queue_redraw()
	world.step_visual(dt)
	# 탈출해 뛰어오르는 동안은 카메라가 떠오른 몸을 따라간다(다가간 화면 위쪽에 걸리지 않게).
	if world.cam != null and world.player.lift > 0.0:
		world.cam.position = (world.player.position - Vector2(0, world.player.lift)).round()

func _step_opening_wobble() -> void:
	var p := world.player
	var t: float = opening["t"]
	var open_at := _opening_open_at()
	balls.wobble = 0.0
	var w0 := OPENING_WAIT
	for i in WOBBLE_TIMES.size():
		var d: float = WOBBLE_TIMES[i]
		if t >= w0 and t < w0 + d:
			balls.wobble = deg_to_rad(float(WOBBLE_ANGLES[i])) * sin(TAU * (t - w0) / d)
		w0 += d + WOBBLE_GAP
	if world.cam != null:
		var z := _opening_zoom(t, open_at)
		world.cam.zoom = Vector2(z, z)
	var from := StarterBalls.ball_of(starter)
	var to := StarterBalls.floor_of(starter)
	if t >= open_at and not bool(opening["open"]):
		opening["open"] = true
		balls.taken = true
		world.ball_open_fx(from, p.radius, true)
		Sfx.play("bowa")
		Sfx.cry(p.species_id)
		world.add_fx("sprite", from + Vector2(0, -p.radius * 0.5), {"starter_table": true, "text": "g4_shiny", "color": Color(1.0, 0.95, 0.7, 0.9),
			"size": p.radius * 3.0, "grow": 1.4, "lifetime": 0.4})
		p.play_hop()
		var oak := _npc("prof_oak")
		if oak != null:
			oak.emote_t = Npc.EMOTE_TIME
			oak.face_toward(from)
	if bool(opening["open"]):
		var e := t - open_at
		p.appear = clampf(e / APPEAR_TIME, 0.0, 1.0)
		if p.appear >= 1.0 and not bool(opening["shown"]):
			opening["shown"] = true
			p.flash_t = 0.15            # 하얀 실루엣이 제 색으로
		var u := clampf(e / ESCAPE_JUMP, 0.0, 1.0)
		p.position = from.lerp(to, u)
		p.lift = Arena.TILE * ESCAPE_HEIGHT * sin(PI * u)
		if e >= ESCAPE_JUMP + LANDED_HOLD:
			p.appear = 1.0
			p.lift = 0.0
			p.position = to
			if p.shiny and not _player_sparkled:
				sparkle_pending = true
			cinematic = false
			opening = {"phase": "o1", "t": 0.0}
			_say_pages(_pages([Lang.t("oak_escape")], _npc("prof_oak")), _opening_run)

# 오박사를 한 번 보고 출구로 달아난다. 길: 탁자 앞 → 아래로 한 줄 → 출구 칸 줄(6열) → 출구.
func _opening_run() -> void:
	state = "opening"
	var bx: int = (StarterBalls.TILES.get(starter, StarterBalls.TILES["charmander"]) as Vector2i).x
	var path := [Arena.tile_center(Vector2i(bx, 7)), Arena.tile_center(Vector2i(LAB_EXIT.x, 7)), Arena.tile_center(LAB_EXIT)]
	var oak := _npc("prof_oak")
	if oak != null:
		world.player.facing = (oak.position - world.player.position).normalized()
	opening = {"phase": "run", "t": 0.0, "path": path, "called": false, "shouted": false,
		"oak_path": [Arena.tile_center(Vector2i(LAB_EXIT.x, 4)), Arena.tile_center(Vector2i(LAB_EXIT.x, 11))]}

func _step_opening_run(dt: float) -> void:
	var p := world.player
	var t: float = opening["t"]
	if t < LOOK_BACK:
		return
	var path: Array = opening["path"]
	if not path.is_empty():
		var to: Vector2 = path[0]
		var d := to - p.position
		var stepd := RUN_SPEED * dt
		if d.length() <= stepd:
			p.position = to
			path.pop_front()
		else:
			p.position += d.normalized() * stepd
			p.vel = d.normalized() * RUN_SPEED       # 걷기 동작·방향(위치는 여기서 옮긴다)
			p.facing = d.normalized()
	var oak := _npc("prof_oak")
	if t >= LOOK_BACK + OAK_CALL_AT and not bool(opening["called"]):
		opening["called"] = true
		if oak != null:
			oak.emote_t = Npc.EMOTE_TIME
			oak.face_toward(p.position)
	# "!" 가 끝나면 큰 대화창으로 소리친다(사용자 결정 2026-10-30: 대사이니 작은 말풍선이 아니라 대화창, 쫓아오기 전에).
	# 그동안 내 포켓몬은 멈춰 오박사를 돌아보고, 창을 닫으면 다시 달린다(talk_resume = "opening").
	if bool(opening["called"]) and not bool(opening["shouted"]) and (oak == null or oak.emote_t <= 0.0):
		opening["shouted"] = true
		p.vel = Vector2.ZERO
		if oak != null:
			p.facing = (oak.position - p.position).normalized()
		_say_pages(_pages([Lang.t("oak_wait")], oak))
		return
	if oak != null and bool(opening["shouted"]) and not oak.walking():
		var op: Array = opening["oak_path"]
		if not op.is_empty():
			oak.walk_target = op.pop_front()
			oak.face_toward(oak.walk_target)
	if path.is_empty():
		p.vel = Vector2.ZERO
		_opening_leave_lab()

# 출구에 닿았다: 태초마을의 연구소 문 앞으로(문을 지날 때와 같은 암전).
func _opening_leave_lab() -> void:
	state = "warp"
	opening = {}
	opening_outside = true
	var wp := Arena.warp_at(world.player.position)
	var to_map := String(wp.get("to", "pallet_town"))
	destination = {"map": DungeonDB.WARP_MAPS.get(to_map, "kanto_south"), "warp": {"map": to_map, "index": int(wp.get("to_warp", 2))}}
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.3)
	tw.tween_callback(func(): get_tree().reload_current_scene())

# 연구소 문 앞: 문(도착한 칸)에서 두 칸 아래에 서 있고, 잠시 뒤 오박사가 문에서 나와 한 칸 걸어와 말한다.
func _begin_opening_outside() -> void:
	_opening_pending = false
	opening_outside = false
	var p := world.player
	var door := _arrival_door if _arrival_door!=Vector2i(-1,-1) else Arena.tile_of(p.position)
	p.position = Arena.tile_center(door + Vector2i(0, 2))
	p.facing = Vector2.DOWN
	if world.cam != null:
		world.cam.position = p.position.round()
	opening = {"phase": "outside", "t": 0.0, "door": door, "oak": null, "step": "wait"}
	state = "opening"

func _step_opening_outside() -> void:
	var p := world.player
	var t: float = opening["t"]
	var door: Vector2i = opening["door"]
	match String(opening["step"]):
		"wait":
			if t >= OUTSIDE_OAK_AT:
				var oak := Npc.new()
				oak.setup({"id": "prof_oak_out", "sprite": "prof_oak", "tile": door, "face": "down"})
				world.add_child(oak)
				world.npcs.append(oak)
				oak.walk_target = Arena.tile_center(door + Vector2i.DOWN)
				opening["oak"] = oak
				opening["step"] = "come"
		"come":
			var oak: Npc = opening["oak"]
			if not oak.walking():
				oak.face = "down"
				p.facing = Vector2.UP
				opening["step"] = "talk"
				# 오박사의 오랭열매 3개(사용자 결정 2026-10-30): 마지막 당부 뒤에 건넨다(받는 글에 도구 팡파르). 가방에 바로.
				var pl := world.player
				var got_oran := Lang.t("got_oran", [pl.display_name(), Lang.t("oak_name"), OAK_BERRIES])
				page_fanfare[got_oran] = Bgm.ITEM
				pl.add_item("oran_berry", OAK_BERRIES)
				_say_pages(_pages([Lang.t("oak_huff"), Lang.t("oak_eyes"), Lang.t("oak_go"), Lang.t("oak_berry")], oak) + _pages([got_oran]), _opening_oak_back)
		"back":
			var oak: Npc = opening["oak"]
			if not oak.walking():
				world.npcs.erase(oak)
				oak.queue_free()
				_opening_done()

func _opening_oak_back() -> void:
	state = "opening"
	world.player.facing = Vector2.DOWN      # 대화가 끝나면 정면을 보며 시작(사용자 결정 2026-10-29)
	var oak: Npc = opening["oak"]
	oak.walk_target = Arena.tile_center(opening["door"])
	oak.face = "up"
	opening["step"] = "back"

# 조작 시작: 장소 배너(연구소 안에선 아꼈던 것)를 띄우고 이 자리를 저장한다.
func _opening_done() -> void:
	opening = {}
	cinematic = false
	state = "town" if mode == "indoor" else "fight"
	_banner(location_name(), "")
	if not bot:
		SaveData.store(world.player, cleared, DungeonDB.current, world.player.position)

# ── 트레이너 배틀 ──

# 아직 이기지 않은 트레이너의 시야에 들어갔나.
# ── 1번도로 라이벌 그린(사용자 요청·승인 2026-10-30) ──
# 1번도로 북쪽 끝(상록시티 남쪽 입구 통로의 첫 두 줄)에 들어서면 한 번: 내 포켓몬 머리 위 "!" → 라이벌 곡 → 뒤늦게 출발한 그린이
# 남쪽(뒤, 화면 밖)에서 뛰어와 바로 뒤에 선다 → 대사 → 인카운트 연출 → 1번도로 경기장. 지면 다른 트레이너처럼 다시(이길 때까지).
# 길: 통로 바로 아래 풀숲 오른쪽 열(31) — 왼쪽(22~27)은 언덕(165줄)이 가로막는다 — 을 따라 163줄까지 올라와 내 열로, 그리고 내 뒤 칸으로.
const RIVAL_ZONE := Rect2i(22, 180, 4, 2)
const RIVAL_FROM := Vector2i(31, 188)
const RIVAL_TURN_ROW := 183
const RIVAL_RUN := 150.0                     # px/s(걷기 90 — 원작 라이벌처럼 달려온다)

func _south_field_shift() -> Vector2i:
	var region:=Arena.area_rect("route1")
	return region.position-Vector2i(12,180) if region.size!=Vector2i.ZERO else Vector2i.ZERO

func _check_rival() -> void:
	if rival_progression!=null and rival_progression.check():return
	if _check_cerulean_rival(): return
	if mode != "overworld" or DungeonDB.current not in [DungeonDB.OVERWORLD, "kanto_north",KantoWorldTravel.ID] or not battle.is_empty() or state != "fight":
		return
	if world.player.dead or world.player.hop_t > 0.0 or beaten.has(TrainerDB.rival_for(starter)):
		return
	if RIVAL_ZONE.has_point(Arena.tile_of(world.player.position)-_south_field_shift()):
		_begin_rival(TrainerDB.rival_for(starter))

func _check_cerulean_rival() -> bool:
	if mode!="overworld" or not battle.is_empty() or state!="fight" or world.player.dead or world.player.hop_t>0.0:return false
	var region:=Arena.area_rect("cerulean_city")
	if region.size==Vector2i.ZERO:return false
	var local:=Arena.tile_of(world.player.position)-region.position
	if not Rect2i(22,6,3,1).has_point(local):return false
	var id:=TrainerDB.cerulean_rival_for(starter)
	if beaten.has(id):return false
	var n:=Npc.new()
	n.setup({"id":"cerulean_green","trainer":id,"tile":region.position+Vector2i(local.x,1),"face":"down"})
	n.speed=RIVAL_RUN
	world.add_child(n)
	world.npcs.append(n)
	_spotted(n)
	return true

func _begin_rival(id: String) -> void:
	var p := world.player
	p.vel = Vector2.ZERO
	p.facing = Vector2.DOWN
	p.emote_t = Npc.EMOTE_TIME
	Sfx.play("pinpon")
	var n := Npc.new()
	var shift:=_south_field_shift()
	var from:=RIVAL_FROM+shift
	var turn_row:=RIVAL_TURN_ROW+shift.y
	n.setup({"id": "rival_green", "trainer": id, "tile": from, "face": "up"})
	n.speed = RIVAL_RUN
	world.add_child(n)
	world.npcs.append(n)
	var path := [Arena.tile_center(Vector2i(from.x, turn_row)), Vector2(p.position.x, Arena.tile_center(Vector2i(0, turn_row)).y),
		p.position + Vector2(0, Arena.TILE)]
	rival = {"npc": n, "path": path, "t": 0.0}
	state = "rival"
	_eye_music(n)

func _step_rival(dt: float) -> void:
	rival["t"] = float(rival["t"]) + dt
	world.player.emote_t = maxf(0.0, world.player.emote_t - dt)
	var n: Npc = rival["npc"]
	if float(rival["t"]) >= Npc.EMOTE_TIME and not n.walking():
		var path: Array = rival["path"]
		if path.is_empty():
			n.face_toward(world.player.position)
			world.player.facing = (n.position - world.player.position).normalized()
			rival = {}
			state = "fight"
			_start_intro(n)
			return
		n.walk_target = path.pop_front()
		n.face_toward(n.walk_target)
	world.step_visual(dt)

# 경기장에서 진 그린: 돌아오면 내 뒤 칸에서 옆으로 한 칸 비켜 상록시티 쪽(북쪽)으로 뛰어가 화면 밖에서 사라진다.
func _rival_exit(id: String) -> void:
	var p := world.player
	var at := Arena.tile_of(p.position)
	var n := Npc.new()
	n.setup({"id": "rival_green", "trainer": id, "tile": at + Vector2i.DOWN, "face": "up"})
	n.speed = RIVAL_RUN
	world.add_child(n)
	world.npcs.append(n)
	var side := 1 if at.x < RIVAL_ZONE.end.x+_south_field_shift().x-1 else -1
	rival_exit = {"npc": n, "path": [Arena.tile_center(at + Vector2i(side, 1)), Arena.tile_center(at + Vector2i(side, -7))]}
	state = "leave"            # 다 뛰어가 사라질 때까지 내 포켓몬은 멈춘다(사용자 결정 2026-10-30: 떠나는 사람을 따라갈 수 있었다)

func _step_rival_exit() -> void:
	if rival_exit.is_empty():
		return
	var n: Npc = rival_exit["npc"]
	if n.walking():
		return
	var path: Array = rival_exit["path"]
	if path.is_empty() or n.position.distance_to(world.player.position) > EXIT_FAR:
		world.npcs.erase(n)
		n.queue_free()
		rival_exit = {}
		return
	n.walk_target = path.pop_front()
	n.face_toward(n.walk_target)

# ── 상록시티 체육관 앞 비주기(사용자 요청·승인 대사 A안 2026-10-30) ──
# 원작에서 상록체육관은 비주기가 자리를 비워 잠겨 있다 — 그 '자리를 비우는 순간'. 체육관 문 칸에 올라서면 한 번: 문에서 나온 비주기와
# 부딪힌다 — 내 포켓몬이 문에서 살짝 뒤(문 앞 칸)로 튕겨 나오고, 문에서 나온 비주기가 닿는 순간 옆(오른쪽 한 칸)으로 밀려난다
# (아래로 밀면 그 다음 줄이 언덕, 사용자 지적 2026-10-30). 밀려난 자리는 발끝을 비주기의 발(칸 아래 끝)에 맞춰 조금 위 —
# 포켓몬 도트는 칸 가운데에 서서 사람보다 낮아 보인다(사용자 지적 2026-10-30) — 밀릴 땐 비주기 쪽을 보며 뒤로 살짝 뛰어(Hop) 밀려난다 — 그 뒤 서로 마주 보며 둘 다 같은 높이의 "!"(원작 순서), 그리고 말을 건다 → 변함없는돌(가방에만 — 지니기는 가방에서)
# → 서쪽(22번도로 쪽)으로 걸어가 사라진다. 선물 이벤트 후 체육관 관장에게 도전할 수 있다. 기록은 [progress] events.
const GIO_EVENT := "giovanni_everstone"
const GIO_DOOR := "viridian_city_gym"            # 지도 warp 의 to(원작 지도 id)
const GIO_RECOIL := 0.15                         # 문에서 튕겨 나오는 시간(문 칸 → 문 앞 칸)
const GIO_BUMP := 0.25                           # 밀려나는 시간
const GIO_HOP := 2.0                             # 밀릴 때 더 띄우는 높이(px) — Hop 동작 자체가 뛰므로 조금만 — 비주기 쪽을 보며 뒤로 폴짝(사용자 결정 2026-10-30)
const GIO_PUSH := Vector2i.RIGHT                 # 문 앞 칸에서 밀려나는 쪽(한 칸, 사용자 결정 2026-10-30). 비주기는 서쪽으로 떠나니 반대쪽
const GIO_EXIT := [Vector2i(30, 151), Vector2i(30, 146), Vector2i(10, 146)]   # 왼쪽으로 가서 위로(아래 줄은 언덕 — 사용자 지적 2026-10-30), 멀어지면 치운다
const GIO_PASS := 4.0 * Arena.TILE           # 비주기가 이만큼 멀어지면 내 포켓몬이 움직일 수 있다(빠르게 지나간 뒤)
const EXIT_FAR := 12.0 * Arena.TILE              # 떠나는 사람은 이만큼 멀어지면 치운다(화면 밖)
var gio := {}

# 잠긴 건물(갈 곳이 없는 문, DungeonDB.WARP_MAPS 에 없음)은 문 칸 자체를 막는다 — "문이 잠겨 있다" 알림 대신(사용자 결정 2026-10-30).
# 상록시티 체육관은 선물 이벤트 전후 모두 출입 가능하며, 첫 방문 때만 문 앞 이벤트가 먼저 시작된다.
func _lock_doors() -> void:
	if not Arena.has_map():
		return
	for wv in Arena.warps():
		var to := String(wv["to"])
		if not DungeonDB.warp_destination(wv).is_empty():
			continue
		if to == GIO_DOOR and mode == "overworld" and not events.has(GIO_EVENT):
			continue
		Arena.set_solid(Vector2i(int(wv["x"]), int(wv["y"])), true)

func _begin_giovanni(door: Vector2i) -> void:
	var p := world.player
	p.vel = Vector2.ZERO
	p.facing = Vector2.UP
	warp_armed = false
	var n := Npc.new()
	n.setup({"id": "giovanni", "tile": door, "face": "down"})
	world.add_child(n)
	world.npcs.append(n)
	gio = {"npc": n, "door": door, "t": 0.0, "phase": "recoil", "from": p.position, "front": Arena.tile_center(door + Vector2i.DOWN)}
	state = "giovanni"

func _step_giovanni(dt: float) -> void:
	gio["t"] = float(gio["t"]) + dt
	var p := world.player
	var n: Npc = gio["npc"]
	p.emote_t = maxf(0.0, p.emote_t - dt)
	match String(gio["phase"]):
		"recoil":
			# 문에서 살짝 뒤로 튕겨 나온다. 그러고 나서 비주기가 문에서 나온다.
			var k := _ease_out(clampf(float(gio["t"]) / GIO_RECOIL, 0.0, 1.0))
			p.position = Vector2(gio["from"]).lerp(gio["front"], k)
			if k >= 1.0:
				gio["phase"] = "out"
				n.walk_target = gio["front"]
		"out":
			if n.position.distance_to(p.position) < Arena.TILE * 0.55:
				gio["phase"] = "shove"
				gio["t"] = 0.0
				gio["from"] = p.position
				p.facing = Vector2.LEFT          # 부딪힌 비주기 쪽을 보며 뒤로 폴짝 밀려난다
				p.play_hop()
		"shove":
			var k := _ease_out(clampf(float(gio["t"]) / GIO_BUMP, 0.0, 1.0))
			var stand := Vector2(gio["front"]) + Vector2(GIO_PUSH) * Arena.TILE + Vector2(0, Arena.TILE / 2.0 - p.feet_offset())
			var kl := clampf(float(gio["t"]) / GIO_BUMP, 0.0, 1.0)
			p.position = Vector2(gio["from"]).lerp(stand, k)
			p.lift = GIO_HOP * 4.0 * kl * (1.0 - kl)
			if k >= 1.0 and not n.walking():
				# 서로 마주 보고 "!"
				gio["phase"] = "notice"
				n.face_toward(p.position)
				p.facing = (n.position - p.position).normalized()
				n.emote_t = Npc.EMOTE_TIME
				p.emote_t = Npc.EMOTE_TIME
				Sfx.play("pinpon")
		"leave":
			_step_rival_exit()
			if rival_exit.is_empty() or n.position.distance_to(p.position) > GIO_PASS:
				gio = {}
				state = "fight"
		"notice":
			if n.emote_t <= 0.0 and p.emote_t <= 0.0:
				gio["phase"] = "talk"
				_say_pages(_pages([Lang.t("gio_1"), Lang.t("gio_2"), Lang.t("gio_3"), Lang.t("gio_4"), Lang.t("gio_5")], n), _gio_give)
	world.step_visual(dt)

# 변함없는돌을 가방에(지니지는 않는다). 받는 글에 원작 도구 팡파르.
func _gio_give() -> void:
	var p := world.player
	p.add_item("everstone")
	var got := Lang.t("got_from", [p.display_name(), Lang.t("giovanni"), ItemDB.name_of("everstone")])
	page_fanfare[got] = Bgm.ITEM
	state = "giovanni"
	_say_pages(_pages([got]) + _pages([Lang.t("gio_6"), Lang.t("gio_7"), Lang.t("gio_8")], gio["npc"]), _gio_leave)

func _gio_leave() -> void:
	var n: Npc = gio["npc"]
	Arena.set_solid(gio["door"], false)      # 선물 이벤트 후에도 관장에게 도전할 수 있다.
	events.append(GIO_EVENT)
	if not bot:
		SaveData.store_progress("events", GIO_EVENT)
		SaveData.store(world.player, cleared)
	var path: Array = []
	var map_shift:=Arena.area_rect("viridian_city").position-Vector2i(0,140)
	for t in GIO_EXIT:
		path.append(Arena.tile_center(t+map_shift))
	rival_exit = {"npc": n, "path": path}
	# 비주기가 빠르게 지나갈 때까지 내 포켓몬은 그대로(사용자 결정 2026-10-30) — 멀어지면 _step_giovanni 가 풀어 준다.
	gio = {"npc": n, "phase": "leave", "t": 0.0}
	state = "giovanni"

# 트레이너 대사 쪽: %s 는 내 포켓몬의 종족 이름(새미 "야생 파이리"). 한국어는 조사까지.
func _trainer_pages(id: String, key: String) -> Array:
	var out: Array = []
	for page in TrainerDB.pages(id, key):
		var p := String(page)
		if p.contains("%s"):
			p = p % [Lang.species_name(world.player.species_id)]
			if Lang.is_ko():
				p = Lang.josa(p)
		out.append(p)
	return out

# 기술을 바로 배운다(기술머신): 빈 칸이 있으면 끼우고 없으면 배운 기술 목록에. 글상자 쪽을 돌려준다.
func _learn_now(move_id: String) -> Array:
	var p := world.player
	p.add_learned(move_id)
	var slot := p.first_empty_slot()
	if slot >= 0:
		p.learn(move_id, slot)
		return [Lang.t("learned", [p.display_name(), MoveDB.move_name(move_id)])]
	return [Lang.t("learned_list", [p.display_name(), MoveDB.move_name(move_id)])]

func _check_trainers() -> void:
	if not battle.is_empty() or world.player.dead or world.player.hop_t > 0.0 or state not in ["fight", "town"]:
		return
	for n in trainers:
		if not beaten.has(n.trainer_id) and n.sees(world.player.position):
			_spotted(n)
			return

func _spotted(n: Npc) -> void:
	talk_resume = state
	state = "spotted"
	spot = {"trainer": n, "walked": false}
	n.emote_t = Npc.EMOTE_TIME
	Sfx.play("pinpon")                      # "!"
	_eye_music(n)
	n.face_toward(world.player.position)
	world.player.vel = Vector2.ZERO
	world.player.facing = (n.position - world.player.position).normalized()

# "!" 가 사라지면 플레이어 바로 앞(한 칸)까지 걸어와 말을 건다.
func _step_spotted(dt: float) -> void:
	var n: Npc = spot["trainer"]
	n.step(dt)
	if n.emote_t > 0.0 or n.walking():
		return
	if not bool(spot["walked"]):
		spot["walked"] = true
		var to := world.player.position - n.position
		if to.length() > Arena.TILE * 1.3:
			n.walk_target = world.player.position - to.normalized() * Arena.TILE
			return
	n.face_toward(world.player.position)
	world.player.facing = (n.position - world.player.position).normalized()
	spot = {}
	_start_intro(n)

# 말을 건 뒤: 경기장이 있는 장소면 컷신 → 경기장, 없으면 그 자리에서 울타리 배틀.
func _start_intro(n: Npc) -> void:
	if quests!=null and not quests.campaign.can_challenge(n.trainer_id):
		_say_pages(quests.campaign.challenge_pages(n.trainer_id));return
	_eye_music(n)
	var after := _to_arena.bind(n) if TrainerDB.arena_of(n.trainer_id) != "" else _begin_battle.bind(n)
	var pages:=_pages(_trainer_pages(n.trainer_id, "intro"), n)
	if quests!=null:pages=quests.campaign.flashback_pages(n.trainer_id)+pages
	_say_pages(pages,after)

# 눈이 마주친 곡(있는 트레이너만 — 관장은 말을 건 뒤 컷인과 함께 배틀 곡).
func _eye_music(n: Npc) -> void:
	var song := TrainerDB.eye_music(n.trainer_id)
	if song != "":
		Bgm.play(song)

# 플래티넘 인카운트 연출(EncounterFx): 상대 첫 포켓몬이 내 포켓몬보다 레벨이 낮으면 low, 아니면 high(원작 기준).
func _to_arena(n: Npc) -> void:
	var tr := _trainer_roster(n.trainer_id)
	var party: Array = tr["party"]
	var kind := "low" if int(party[0][1]) < world.player.level else "high"
	var opts := {}
	if tr.has("cutin"):
		# 관장: 플래티넘 관장 컷인(띠·VS·얼굴·이름). 끝나면 하얀 화면에서 경기장이 밝아진다.
		kind = "leader"
		opts = (tr["cutin"] as Dictionary).duplicate()
		opts["name"] = TrainerDB.short_name(n.trainer_id)
	var snap: Texture2D = null
	if DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			snap = ImageTexture.create_from_image(img)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	encounter = EncounterFx.new()
	encounter.setup(kind, snap, opts)
	encounter.position = Vector2.ZERO
	encounter.size = get_viewport().get_visible_rect().size
	layer.add_child(encounter)
	arena_trip = {"trainer": n.trainer_id, "arena": TrainerDB.arena_of(n.trainer_id), "white": kind == "leader", "back": {"map": DungeonDB.current, "pos": world.player.position,
		"layout": int(DungeonDB.LAYOUTS.get(DungeonDB.current, 1))}}
	arena_trip["back"]["pursuit_visit"] = road_pursuit.snapshot()
	arena_trip["roster"] = tr
	state = "encounter"
	world.player.vel = Vector2.ZERO
	Bgm.play(TrainerDB.battle_music(n.trainer_id))      # 원작처럼 연출과 함께 배틀 곡(경기장에서도 이어짐)

func _step_encounter(dt: float) -> void:
	encounter.step(dt)
	if encounter.done and state == "encounter":
		state = "warp"
		_carry_out()
		if not bot:
			# 경기장에서 껐다 켜도 원래 자리에서 이어지게: 지금 자리를 저장해 둔다.
			SaveData.store(world.player, cleared, DungeonDB.current, world.player.position)
		destination = {"map": String(arena_trip["arena"])}
		fader.color = Color.WHITE if encounter.kind == "leader" else Color.BLACK
		get_tree().reload_current_scene()

# 다음 장면으로 들고 갈 내 포켓몬 상태.
func _carry_out() -> void:
	var p := world.player
	carry = {"evolution_declined_level": p.evolution_declined_level, "species": p.species_id, "level": p.level, "exp": p.exp_total, "slots": p.slots.duplicate(), "hotbar": p.hotbar.duplicate(), "pp_focus_slot":p.pp_focus_slot, "learned": p.learned.duplicate(),
		"pid": p.pid, "ivs": p.ivs.duplicate(), "cleared": cleared.duplicate(), "bag": p.bag.duplicate(), "reward_reserve":p.reward_reserve.duplicate(), "hold": p.hold,
		"trainers": beaten.duplicate(), "events":events.duplicate(), "hp": p.hp, "pp": p.pp.duplicate(), "status": p.status_name()}
	carry["field_puzzles"]=puzzles.duplicate(true)

# 경기장에서 이긴 뒤: 암전하고 배틀이 걸린 자리로 돌아간다.
func _leave_arena() -> void:
	var back: Dictionary = arena_trip.get("back", {}).duplicate(true)
	var finished := String(arena_trip.get("trainer",""))
	if back.has("pursuit_visit"):
		var visit: Dictionary = back["pursuit_visit"]
		visit["actors"] = (visit.get("actors",[]) as Array).filter(func(record): return record.id!=finished)
		if (visit.get("deployed",[]) as Array).has(finished):visit["gauge"]=0.0
	arena_trip = {}
	_carry_out()
	destination = {"map": String(back.get("map", DungeonDB.HOME)), "pos": back.get("pos", Vector2(-1, -1)),
		"layout": int(back.get("layout", 1)), "from_arena": true}
	if back.has("pursuit_visit"): destination["pursuit_visit"]=back["pursuit_visit"]
	state = "warp"
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.3)
	tw.tween_callback(func(): get_tree().reload_current_scene())

# 지금 자리 저장. 경기장 안이면 돌아갈 자리(배틀이 걸린 곳)를 적는다.
func _save_here() -> void:
	if bot:
		return
	if mode == "arena":
		var back: Dictionary = arena_trip.get("back", {})
		SaveData.store(world.player, cleared, String(back.get("map", DungeonDB.HOME)), back.get("pos", Vector2(-1, -1)))
	else:
		var save_pos:=world.player.position
		if bird_event!=null and bird_event.phase!="idle":save_pos=bird_event.safe_at
		if lapras_escape!=null and lapras_escape.phase in ["calling","boarding","self_surf"]:save_pos=lapras_escape.safe_at
		if seafoam!=null and seafoam.phase!="idle":save_pos=seafoam.safe_at
		SaveData.store(world.player, cleared, DungeonDB.current, save_pos)

# 대사 여러 쪽을 띄우고 세계를 멈춘다. 다 넘기면 after.
func _say_pages(pages: Array, after: Callable = Callable()) -> void:
	if touch_controls != null:touch_controls.cancel_all()
	if status_message_active and not dialog_text.is_empty():
		for i in range(timed_dialog_pages.size() - 1, -1, -1):
			status_messages.push_front(timed_dialog_pages[i])
			status_message_times.push_front(active_message_created_at)
		status_messages.push_front(dialog_text)
		status_message_times.push_front(active_message_created_at)
	timed_dialog_pages.clear()
	status_message_active = false
	if state not in ["talk", "spotted"]:
		talk_resume = state
	if not battle.is_empty():
		talk_resume = "fight"
	state = "talk"
	world.player.vel = Vector2.ZERO
	world.player.attack_anim_t = 0.0        # 공격 동작 도중 멈추면 몸이 그림자 위에 떠 보인다(Strike 의 달려듦)
	talk_pages = pages.duplicate()
	talk_after = after
	_show_talk_page(talk_pages.pop_front())
	_page_fanfare()

# 문자열은 해설, Dictionary는 화자가 있는 대사. 쪽마다 초점을 새로 지정한다.
func _show_talk_page(page: Variant) -> void:
	talk_focus = page.get("speaker") if page is Dictionary else null
	dialog_text = String(page["text"] if page is Dictionary else page)
	dialog_t = 0.0 if talk_focus != null else SAY_TIME

func _page_fanfare() -> void:
	if page_fanfare.has(dialog_text):
		Bgm.fanfare(String(page_fanfare[dialog_text]))
		page_fanfare.erase(dialog_text)

func _talk_next() -> void:
	Sfx.play("select")                      # 글 넘김(원작 SEQ_SE_DP_SELECT)
	if not talk_pages.is_empty():
		_show_talk_page(talk_pages.pop_front())
		_page_fanfare()
		return
	dialog_text = ""
	dialog_t = 0.0
	talk_focus = null
	state = talk_resume
	if world.player.controller is Controllers.Human:
		world.player.controller.hold = true       # 넘기던 클릭으로 기술이 나가지 않게
	var after := talk_after
	talk_after = Callable()
	if after.is_valid():
		after.call()

# 배틀 시작: 내 포켓몬이 두 칸 뒤로 물러나 자리를 잡고(밀려나듯 미끄러짐, 벽이면 거기까지), 그 뒤 트레이너가 첫 포켓몬을
# 둘 사이에 내보낸다 — 말을 건 바로 옆 칸에서 시작하면 상대가 내 몸 위에 나와 버린다. 트레이너는 제자리(원작처럼 서 있는 그 칸).
func _begin_battle(n: Npc) -> void:
	if quests!=null:quests.campaign.on_gym_challenged(n.trainer_id)
	Bgm.play(TrainerDB.battle_music(n.trainer_id))
	world.scatter_enemies()          # 야생은 도망친다(배틀은 한 번에 하나)
	if mode == "arena":
		# 경기장: 벽이 가두니 울타리는 없다. 플레이어는 아래쪽 가운데, 트레이너는 위쪽 가운데에서 마주 본다.
		world.start_battle(world.player.position, 0.0)
		battle = {"trainer": n, "idx": 0, "mon": null, "next_t": FIRST_SEND_DELAY + 0.6, "done_t": 0.0, "resume": "fight"}
		battle["roster"]=arena_trip.get("roster",_trainer_roster(n.trainer_id)).duplicate(true)
		state = "fight"
		_say_pages([Lang.t("wants_battle", [TrainerDB.display_name(n.trainer_id)])])
		return
	var dir := (world.player.position - n.position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var gap := world.player.position.distance_to(n.position)
	var slide := maxf(0.0, BACK_OFF_TILES * Arena.TILE + Arena.TILE - gap)    # 트레이너와 세 칸이 되게
	world.player.knock = dir * sqrt(2.0 * KNOCK_DECEL * slide)                # knock 은 초당 900 씩 줄어든다(Mon.tick_status)
	world.start_battle(n.position + dir * Arena.TILE * 2.0, BATTLE_RADIUS)
	battle = {"trainer": n, "idx": 0, "mon": null, "next_t": FIRST_SEND_DELAY, "done_t": 0.0, "resume": talk_resume}
	battle["roster"]=_trainer_roster(n.trainer_id)
	# 건물 안(체육관)은 평소 기술을 못 쓰는 곳이라, 배틀 동안만 싸우는 상태로.
	state = "fight"
	world.no_skills = false

# Snapshot the source region before switching to a trainer arena.
func _trainer_roster(id: String) -> Dictionary:
	var area:=Arena.area_at(world.player.position)
	if mode=="arena" and arena_trip.has("roster"):return arena_trip.roster.duplicate(true)
	var roster:=TrainerDB.for_battle(id,world.player.level,{"area":area,"events":events})
	return quests.campaign.trainer_roster(id,roster) if quests!=null else roster

# Resolve once per battle, including direct fixtures and non-arena challenges.
func battle_trainer() -> Dictionary:
	if battle.is_empty():return {}
	if not battle.has("roster"):
		battle["roster"]=_trainer_roster(battle["trainer"].trainer_id)
	return battle["roster"]

func _send_next() -> void:
	var n: Npc = battle["trainer"]
	var trainer:=battle_trainer()
	var party: Array = trainer["party"]
	var index:=int(battle["idx"])
	var entry: Array = party[index]
	battle["idx"] = index + 1
	var owner: String=trainer.get("senders",[])[index] if trainer.has("senders") else ""
	var sender:=rocket_james if owner=="james" and is_instance_valid(rocket_james) else n
	if owner=="partner":
		var partner_ref: WeakRef=n.get_meta("trainer_partner",null)
		if partner_ref!=null and is_instance_valid(partner_ref.get_ref()):sender=partner_ref.get_ref()
	var spawn_origin := n.position
	if n.trainer_id==MOON_GRADUATION and is_instance_valid(rocket_james):
		spawn_origin.x=(n.position.x+rocket_james.position.x)*0.5
	if mode == "arena":
		var field: Array=Arena.map.get("arena",{}).get("field",[])
		if field.size()==4: spawn_origin.y=(float(field[1])-0.5)*Arena.TILE
	var dir := (world.player.position - spawn_origin).normalized()
	var reach := 2.5 if mode == "arena" else 1.5
	var target:=spawn_origin+dir*Arena.TILE*reach
	var cam_at := world.cam.position if world.cam != null else world.player.position
	var cam_z := world.cam.zoom.x if world.cam != null else 1.0
	if owner=="self" and is_instance_valid(rocket_meowth):
		var e:=rocket_meowth
		world.bystanders.erase(e)
		world.enemies.append(e)
		battle["mon"]=e
		var duration:=e.position.distance_to(target)/MEOWTH_WALK_SPEED
		sendout={"mon":e,"ball":null,"direct":true,"walk_from":e.position,"t":0.0,"phase":"show",
			"from_pos":cam_at,"from_zoom":cam_z,"trainer_at":e.position,"focus":target,"popped":true,"ready_at":SEND_PAN+duration}
		world.hold_cam=true
		Sfx.cry(e.species_id)
		_say_pages([Lang.t("meowth_steps_out")],_sendout_back)
		return
	var fixed_iv: int=int(trainer.ivs[index]) if trainer.has("ivs") else 0
	var e := world.send_out(String(entry[0]), int(entry[1]), entry[2] if entry.size() > 2 else [], target, true, fixed_iv)
	if trainer.has("gym"):e.set_meta("no_exp",true)
	if trainer.has("campaign_father") and index==party.size()-1:
		var father: Dictionary=trainer.campaign_father
		e.ivs=(father.get("ivs",{}) as Dictionary).duplicate();e.pid=int(father.get("pid",0))
		e.stats=(father.get("stats",SpeciesDB.stats_at(e.species_id,e.level,e.ivs)) as Dictionary).duplicate()
		e.max_hp=int(father.get("max_hp",e.stats.hp));e.hp=e.max_hp
		e.shiny=bool(father.get("shiny",false))
		e.form_species_id=String(father.get("form_species_id",""))
		e._sprites=MonSprite.load_set(int(SpeciesDB.get_species(e.appearance_id()).dex),e.shiny)
		e._apply_species_size(SpeciesDB.get_species(e.appearance_id()))
	battle["mon"] = e
	sender.face_toward(e.position)
	var ball := ThrownBall.new()
	ball.setup(sender.position + Vector2(0, -Arena.TILE * 0.4), e.position, SEND_ARC * Arena.TILE)
	ball.visible = false
	world.add_child(ball)
	sendout = {"mon": e, "ball": ball, "t": 0.0, "phase": "show", "from_pos": cam_at, "from_zoom": cam_z,
		"trainer_at": sender.position, "focus": e.position, "popped": false}
	world.hold_cam = true
	var sender_name:=Lang.t(owner) if owner in ["jessie","james"] else TrainerDB.display_name(n.trainer_id)
	_say_pages([Lang.t("sent_out", [sender_name, e.display_name()])], _sendout_back)

# 내보내는 연출을 다 보고 대사를 넘길 수 있나(볼이 터져 포켓몬이 다 나온 뒤).
func can_advance() -> bool:
	return sendout.is_empty() or String(sendout["phase"]) != "show" or float(sendout["t"]) >= float(sendout.get("ready_at",SEND_READY))

func _step_sendout(dt: float) -> void:
	sendout["t"] = float(sendout["t"]) + dt
	var t: float = sendout["t"]
	var e: Enemy = sendout["mon"]
	var ball = sendout["ball"]           # 터지면 null
	world.step_fx(dt)
	if String(sendout["phase"]) == "show":
		if bool(sendout.get("direct",false)):
			_step_meowth_entrance(e,t,dt)
			return
		# 카메라: 트레이너에게 다가갔다가 날아가는 볼을 따라 내보낼 자리로(넓은 경기장에선 2배 화면에 둘이 다 안 들어간다).
		# 아래 대화창에 가리지 않게 창 위쪽 빈 화면의 가운데에 둔다.
		var k := _ease_out(clampf(t / SEND_PAN, 0.0, 1.0))
		var bk := clampf((t - SEND_THROW_AT) / SEND_THROW, 0.0, 1.0)
		var z := lerpf(float(sendout["from_zoom"]), SEND_ZOOM, k)
		var aim := Vector2(sendout["trainer_at"]).lerp(sendout["focus"], _ease_out(bk)) + Vector2(0, _talk_box_lift(SEND_ZOOM))
		_set_cam(Vector2(sendout["from_pos"]).lerp(aim, k), z)
		if ball != null:
			ball.visible = t >= SEND_THROW_AT
			ball.k = bk
			ball.queue_redraw()
		if bk >= 1.0 and not bool(sendout["popped"]):
			sendout["popped"] = true
			_drop_ball()
			world.pop_out(e)
		if bool(sendout["popped"]):
			e.appear = clampf((t - SEND_THROW_AT - SEND_THROW) / APPEAR_TIME, 0.0, 1.0)
		return
	# 돌아오기: 내 포켓몬 쪽(경기장은 나와 상대 사이)으로 1배.
	var back := _fight_cam_target()
	var back_time := ARENA_SEND_BACK if mode == "arena" else SEND_BACK
	var k2 := _ease_out(clampf(t / back_time, 0.0, 1.0))
	var from := Vector2(sendout["focus"]) + Vector2(0, _talk_box_lift(SEND_ZOOM))
	_set_cam(from.lerp(back, k2), lerpf(SEND_ZOOM, World.CAM_ZOOM, k2))
	if t >= back_time:
		world.cam_pos = back
		world.hold_cam = false
		sendout = {}
		state = "fight"

func _step_meowth_entrance(e: Enemy, t: float, dt: float) -> void:
	var from: Vector2=sendout["walk_from"]
	var target: Vector2=sendout["focus"]
	var k:=clampf((t-SEND_PAN)/maxf(0.01,float(sendout["ready_at"])-SEND_PAN),0.0,1.0)
	e.position=from.lerp(target,k)
	e.vel=(target-from).normalized()*MEOWTH_WALK_SPEED if t>SEND_PAN and k<1.0 else Vector2.ZERO
	e.facing=(target-from).normalized()
	e.anim_t+=dt
	e.queue_redraw()
	var pan:=_ease_out(clampf(t/SEND_PAN,0.0,1.0))
	_set_cam(Vector2(sendout["from_pos"]).lerp(e.position+Vector2(0,_talk_box_lift(SEND_ZOOM)),pan),lerpf(float(sendout["from_zoom"]),SEND_ZOOM,pan))

# 대사를 넘기면: 볼이 아직 날고 있었더라도(봇) 다 나온 것으로 하고 카메라를 되돌린다.
func _sendout_back() -> void:
	var e: Enemy = sendout["mon"]
	_drop_ball()
	if bool(sendout.get("direct",false)):
		e.position=sendout["focus"]
		e.vel=Vector2.ZERO
	elif not bool(sendout["popped"]):
		world.pop_out(e)
	e.appear = 1.0
	sendout["phase"] = "back"
	sendout["t"] = 0.0
	state = "sendout"

func _drop_ball() -> void:
	if sendout["ball"] != null:
		(sendout["ball"] as Node).queue_free()
		sendout["ball"] = null

func _fight_cam_target() -> Vector2:
	var p := world.player.cam_anchor()
	if world.arena_cam and battle.has("mon") and is_instance_valid(battle["mon"]):
		return (p + (battle["mon"] as Mon).cam_anchor()) * 0.5
	return p

# 넘기는 대화창(화면 아래 전체 폭, Hud.msg_rect)만큼 카메라를 내려 볼 것을 창 위 빈 화면 가운데에 두는 거리(월드 px, 배율 z).
func _talk_box_lift(z: float) -> float:
	if hud == null:
		return 0.0
	var box := (Hud.MSG_H * 2.0 + 2.0) / hud.H
	return box * 0.5 * get_viewport().get_visible_rect().size.y / z

func _set_cam(at: Vector2, z: float) -> void:
	if world.cam == null:
		return
	world.cam.position = at.round()
	world.cam.zoom = Vector2(z, z)

static func _ease_out(k: float) -> float:
	return 1.0 - (1.0 - k) * (1.0 - k)

func _step_battle(dt: float) -> void:
	if battle.is_empty() or world.player.dead:
		return
	if float(battle.get("faint_t", 0.0)) > 0.0:
		if not status_messages.is_empty() or not dialog_text.is_empty():
			return
		battle["faint_t"] = float(battle["faint_t"]) - dt
		if float(battle["faint_t"]) <= 0.0:
			_say_pages([Lang.t("foe_fainted", [String(battle["faint_name"])])], _after_foe_fainted)
		return
	if not status_messages.is_empty() or not dialog_text.is_empty():
		return
	if exp_display_pending() or not stat_box.is_empty() or not stat_queue.is_empty() or not growth_learns.is_empty() or not pending_learns.is_empty():
		return
	if float(battle["next_t"]) > 0.0:
		battle["next_t"] = float(battle["next_t"]) - dt
		if float(battle["next_t"]) <= 0.0:
			_send_next()
	elif float(battle["done_t"]) > 0.0 and stat_box.is_empty() and stat_queue.is_empty():
		battle["done_t"] = float(battle["done_t"]) - dt
		if float(battle["done_t"]) <= 0.0:
			_trainer_defeated()

# 트레이너 배틀에서 플레이가 멈추는 틈: 다음 포켓몬을 기다리는 동안(next_t), 쓰러지는 동작 동안(faint_t), 승리 대사 전(done_t).
func _battle_paused() -> bool:
	if battle.is_empty() or world.player.dead:
		return false
	return float(battle.get("next_t", 0.0)) > 0.0 or float(battle.get("faint_t", 0.0)) > 0.0 or float(battle.get("done_t", 0.0)) > 0.0

func _after_foe_fainted() -> void:
	if battle.is_empty():
		return
	battle.erase("exp_text")
	if String(battle.get("then", "")) == "next":
		battle["next_t"] = SEND_NEXT_DELAY
	else:
		battle["done_t"] = WIN_TEXT_DELAY

# 마지막 포켓몬을 쓰러뜨렸다: 원작 순서대로 "이겼다!" → 트레이너의 진 대사 → 기술머신. 저장.
# 배지는 주지 않는다(사용자 결정 2026-10-30: 포켓몬 혼자라 — 관장은 기술머신만).
func _trainer_defeated() -> void:
	if battle.is_empty(): return
	var n: Npc = battle["trainer"]
	var id := n.trainer_id
	var roster:=battle_trainer()
	var resume: String = battle["resume"]
	battle = {}
	world.end_battle()
	world.no_skills = mode == "indoor"
	_mark_beaten(id)
	if TrainerDB.get_trainer(id)["class"] == "rival" and mode == "arena":
		rival_leaving = id
	Bgm.play(TrainerDB.victory_music(id))
	var pages: Array = [Lang.t("trainer_beaten", [TrainerDB.display_name(id)])]
	pages.append_array(_pages(_trainer_pages(id, "defeat"), n))
	var t := TrainerDB.get_trainer(id)
	if t.has("gym"):
		# 원작 set_gym_trainers: 관장을 이기면 그 체육관 트레이너도 모두 이긴 것으로(경기장에선 배틀이 걸린 체육관의 목록).
		var loc := String(arena_trip.get("back", {}).get("map", DungeonDB.current)) if mode == "arena" else DungeonDB.current
		for cfg in DungeonDB.DUNGEONS.get(loc, {}).get("trainers", []):
			_mark_beaten(String(cfg["trainer"]))
		# Field techniques now belong to story events; existing learned moves remain.
	pages.append_array(_gym_field_help_pages(id))
	if quests!=null:pages.append_array(quests.campaign.on_trainer_defeated(id))
	var reward := TrainerDB.berry_rewards(id,roster)
	var reserved := world.award_berries(reward,n.position)
	var reward_pages := World.loot_summary_pages(reward)
	if not reward_pages.is_empty():page_fanfare[reward_pages[0]]=Bgm.ITEM
	pages.append_array(reward_pages)
	if not reserved.is_empty(): pages.append(Lang.t("trainer_berry_reserve"))
	if t.has("farewell"):
		pages.append_array(_pages(_trainer_pages(id, "farewell"), n))
	_save_here()
	state = resume if resume in ["fight", "town"] else ("town" if mode == "indoor" else "fight")
	_say_pages(pages, _leave_arena if mode == "arena" else Callable())

func _mark_beaten(id: String) -> void:
	if beaten.has(id):
		return
	beaten.append(id)
	if not bot:
		SaveData.store_progress("trainers", id)

# ── 알림 ──

# 장소 이름 알림판(플래티넘 MapNamePopUp, 사용자 요청 2026-10-30): 왼쪽 위에서 4px/프레임으로 내려와(38px) 60프레임 머문 뒤
# 다시 올라간다. 그림은 장소 종류마다(DungeonDB.popup_kind). Hud._draw_banner 가 banner_t 로 자리를 정한다.
const BANNER_SLIDE := 10.0 / 60.0
const BANNER_WAIT := 60.0 / 60.0
const BANNER_TIME := BANNER_SLIDE * 2.0 + BANNER_WAIT
var banner_kind := "route"
var _banner_area := ""            # 바깥 세계에서 지금 알림판을 띄운 구역 이름(구역이 바뀌면 다시 띄운다 — 원작처럼)

func _banner(text: String, sub: String) -> void:
	banner_kind = DungeonDB.popup_kind(Arena.area_at(world.player.position) if mode == "overworld" else "")
	_banner_area = text
	banner_text = text
	banner_sub = sub
	banner_t = BANNER_TIME

# ── 건물 안 사람·가방·상점 ──

func npc_in_reach() -> Npc:
	if world == null or world.player == null:
		return null
	var nearest: Npc=null
	var distance:=INF
	for n in world.npcs:
		if (n as Npc).can_talk(world.player.position):
			var gap: float=n.position.distance_squared_to(world.player.position)
			if gap<distance:nearest=n;distance=gap
	return nearest

func _talk(n: Npc) -> void:
	if quests!=null and quests.talk(n):return
	if n.is_trainer() and TrainerDB.get_trainer(n.trainer_id).has("gym") and not LevelProgression.unlocked(events):
		_say_pages([Lang.t("gym_tutorial_locked")]);return
	match n.talk:
		"johto_ferry":
			region_travel.talk(n)
		"road_gate":
			road_gates.talk(n)
		"forest_scyther_rescue":
			if forest_rescue!=null:forest_rescue.talk()
		"friend_cut":
			field_friends.talk(n)
		"seafoam_boulder":
			if seafoam!=null:seafoam.push(n)
		"gym_surprised":
			n.face_toward(world.player.position)
			_say_pages(_pages([Lang.t(n.id)],n))
		"gym_member":
			n.face_toward(world.player.position)
			var lines: Array=TrainerDB.GymData.DIALOGUE.get(n.id,{}).get(Lang.code,[])
			_say_pages(_pages(lines,n))
		"bill_pc":
			if bill_event!=null:bill_event.talk(n)
		"nurse":
			# 맞이 → 살펴보기 → 기계로 안내(대사 세 쪽) 뒤 회복 연출, 끝나면 끝 인사 두 쪽(_finish_heal).
			var hello := _pages([Lang.t("nurse_hello"), Lang.t("nurse_check", [world.player.display_name()]), Lang.t("nurse_rest")], n)
			_say_pages(hello, _start_heal.bind(n) if n.heal_spot != Vector2.INF else _finish_heal.bind(n))
		"shop":
			_open_shop()
		"oak":
			# 연구소의 오박사(사용자 승인 대사 B1·B2).
			n.face_toward(world.player.position)
			_say_pages(_pages([Lang.t("oak_hello", [world.player.display_name()]), Lang.t("oak_grow")], n))
		"trainer":
			n.face_toward(world.player.position)
			if beaten.has(n.trainer_id):
				_say_pages(_pages(_trainer_pages(n.trainer_id, "after"), n))
			elif battle.is_empty():
				_start_intro(n)

func _menu_open(kind: String) -> void:
	if touch_controls != null:touch_controls.cancel_all()
	world.field_water.cancel(world,false)
	if state != "menu":
		menu_resume = state
	state = "menu"
	menu = kind
	world.player.vel = Vector2.ZERO

func _close_menu() -> void:
	# 창을 닫은 직후 누르고 있던 마우스로 기술이 나가지 않게: 버튼을 다 뗄 때까지 막는다(사용자 지적 2026-10-28).
	if world != null and world.player != null and world.player.controller is Controllers.Human:
		world.player.controller.hold = true
	panel.close()
	if bag_screen != null:
		bag_screen.close()
	if summary_screen != null:
		summary_screen.close()
	if fly_screen != null:fly_screen.close()
	menu = ""
	state = menu_resume

# 가방(플래티넘 가방 화면, BagScreen). 고르면 _on_bag_used, 닫으면 _close_menu.
func _open_bag() -> void:
	_menu_open("bag")
	bag_screen.hotbar = world.player.hotbar
	bag_screen.open(world.player.bag)

func _on_bag_used(id: String, pp_slot: int = -1) -> void:
	if menu!="": _close_menu()
	var r := world.use_item(id,pp_slot)
	if r == "hold":
		# 지니기 ↔ 돌려받기(사용자 결정 2026-10-30: 받아도 저절로 지니지 않는다 — 가방을 열어 고른다). 물건은 가방에 그대로.
		var p := world.player
		if p.hold == id:
			p.hold = ""
			_toast(Lang.t("hold_off", [p.display_name(), ItemDB.name_of(id)]))
		else:
			p.hold = id
			_toast(Lang.t("hold_on", [p.display_name(), ItemDB.name_of(id)]))
		if not bot:
			SaveData.store(p, cleared)
		return
	if r == "":
		_toast(Lang.t("item_used", [ItemDB.name_of(id)]))
	elif r == "escape":
		_toast(Lang.t("item_used", [ItemDB.name_of(id)]))
		_escape_dungeon()
	else:
		_toast(Lang.t(r))

# 도구 편성(1~4)으로 쓴 도구(오랭열매 말고): 가방에서 고른 것과 같게. 창이 열려 있지 않으니 창 닫기는 건너뛴다.
func _on_hotbar_used(id: String) -> void:
	if menu != "":
		return
	var resume := state
	menu_resume = resume
	_on_bag_used(id)

# 가방에서 도구를 고르고 숫자 키(1~4)를 누르면 그 칸에 편성(같은 칸에 같은 도구면 비움). 다른 칸에 있던 같은 도구는 옮긴다.
func _on_hotbar_set(slot: int, id: String) -> void:
	var hb: Array = world.player.hotbar
	if slot < 0 or slot >= hb.size() or not ItemDB.has_item(id) or ItemDB.pocket_of(id)=="key":
		return
	if hb[slot] == id:
		hb[slot] = ""
	else:
		for i in hb.size():
			if hb[i] == id:
				hb[i] = ""
		hb[slot] = id
	if not bot:
		SaveData.store(world.player, cleared)

func _open_shop() -> void:
	var ids := ItemDB.shop_items()
	var value := ItemDB.trade_value(world.player.bag)
	var entries: Array = []
	for id in ids:
		var ok := value >= ItemDB.price(id) and int(world.player.bag.get(id, 0)) < ItemDB.cap(id)
		entries.append({"name": ItemDB.name_of(id), "sub": Lang.t("worth", [ItemDB.price(id)]), "icon": ItemDB.icon(id), "enabled": ok})
	entries.append({"name": Lang.t("shop_leave"), "sub": "", "accent": PixelUi.INK_DIM})
	_menu_open("shop")
	menu_ids = ids
	panel.show_items(Lang.t("shop_title", [value]), entries, 4, ids.size())

func _resolve_menu(index: int) -> void:
	match menu:
		"quest_journal":
			quests.choose_journal(index)
		"quest_cost":
			quests.choose_cost(index)
		"johto_ferry":
			region_travel.choose(index)
		"water":
			_close_menu()
			if index>=0 and index<3:
				if not world.field_water.start_fishing(world,FieldWater.RODS[index]): _toast(Lang.t("field_busy"))
			elif index==3:
				if lapras_escape==null or not (events.has(LaprasEscape.FRIEND) or FieldHMs.can_use(world.player,"surf")):_say_pages([lapras_escape.text("needed") if lapras_escape!=null else Lang.t("field_no_water")])
				elif not lapras_escape.try_call():_toast(Lang.t("field_no_water"))
		"game":
			if index<0 or index>=menu_ids.size():_close_menu();return
			match String(menu_ids[index]):
				"save":_save_and_title()
				"lang":_toggle_lang();_open_game_menu()
				"journal":quests.open_journal()
				"reset":
					_close_menu()
					if seafoam!=null:seafoam.reset_floor()
				_:_close_menu()
		"shop":
			if index < 0 or index >= menu_ids.size():
				_close_menu()
				return
			var id: String = menu_ids[index]
			if int(world.player.bag.get(id, 0)) >= ItemDB.cap(id):
				_toast(Lang.t("shop_full"))
				return
			var pay := ItemDB.payment(world.player.bag, ItemDB.price(id))
			if pay.is_empty():
				_toast(Lang.t("shop_short"))
				return
			shop_pick = id
			shop_pay = pay
			var parts: Array = []
			for k in pay:
				parts.append("%s ×%d" % [ItemDB.name_of(k), int(pay[k])])
			menu = "shop_confirm"
			panel.show_items(Lang.t("shop_confirm", [", ".join(parts), ItemDB.name_of(id)]),
				[{"name": Lang.t("trade_yes"), "sub": "", "icon": ItemDB.icon(id)}, {"name": Lang.t("trade_no"), "sub": "", "accent": PixelUi.INK_DIM}], 2, 1)
		"shop_confirm":
			if index == 0:
				Sfx.play("regi")                  # 계산(원작 SEQ_SE_DP_REGI)
				for k in shop_pay:
					world.player.take_item(k, int(shop_pay[k]))
				world.player.add_item(shop_pick)
				if not bot:
					SaveData.store(world.player, cleared, DungeonDB.current, world.player.position)
				_toast(Lang.t("got_new", [ItemDB.name_of(shop_pick)]))
			_open_shop()

# Esc 게임 메뉴(사용자 요청 2026-10-29). 원작 X 메뉴의 '레포트'·'설정' 자리 — 저장하고 시작 화면(PC 박스)으로, 언어, 닫기.
func _open_game_menu() -> void:
	_menu_open("game")
	var entries: Array=[
		{"name": Lang.t("menu_save_title"), "sub": Lang.t("menu_save_title_sub"), "accent": Color("e06040")},
		{"name": Lang.t("lang_toast"), "sub": "L", "accent": Color("5890d8")}]
	menu_ids=["save","lang","journal"]
	entries.append({"name":"이야기 수첩" if Lang.is_ko() else "Story journal","sub":"진행 중인 단서와 목적지" if Lang.is_ko() else "Clues and destinations","accent":Color("e8bf55")})
	if seafoam!=null:menu_ids.append("reset")
	if seafoam!=null:entries.append({"name":"이 층의 바위 배치 되돌리기" if Lang.is_ko() else "Reset this floor's boulders","sub":"","enabled":battle.is_empty()})
	menu_ids.append("close")
	entries.append({"name": Lang.t("bag_close"), "sub": "Esc", "accent": PixelUi.INK_DIM})
	panel.show_items(Lang.t("menu_title"),entries,2,entries.size()-1)

func _toggle_lang() -> void:
	Lang.toggle()
	ui_root.theme = UiFont.make_theme()
	_toast(Lang.t("lang_toast"))

# 저장하고 시작 화면으로. 바깥 세계·건물 안은 지금 자리를, 던전 안은 성장만(자리는 날아온 바깥 자리 그대로 — 동굴탈출로프와 같다).
# 다음에 고르는 스타팅이 처음부터 다시 정해지도록 장면 사이에 남는 기록(스타팅·갈 곳·반짝임·세이브 파일)을 비운다.
func _save_and_title() -> void:
	Sfx.play("save")
	_close_menu()
	if not bot:
		if hub:
			_save_here()
		else:
			SaveData.store(world.player, cleared)
	state = "warp"
	starter = ""
	destination = {}
	came_from_faint = false
	_player_sparkled = false
	SaveData.path = SaveData.PATH
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.25)
	tw.tween_callback(func(): get_tree().change_scene_to_file(TITLE_SCENE))

# 동굴탈출로프: 던전에서 날아온 자리(저장된 바깥 세계 자리)로. 클리어는 아니다.
func _escape_dungeon() -> void:
	var saved := {} if bot else SaveData.load_saved()
	if not saved.is_empty() and DungeonDB.has_location(String(saved["map"])) and DungeonDB.is_hub(String(saved["map"])):
		destination = {"map": saved["map"], "pos": saved["pos"], "layout": int(saved.get("layout", 1))}
	else:
		destination = {"map": DungeonDB.OVERWORLD}
	if not bot:
		SaveData.store(world.player, cleared)
	state = "warp"
	var tw := create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.25)
	tw.tween_callback(func(): get_tree().reload_current_scene())

func _toast(text: String) -> void:
	toasts.append({"text": text, "t": TOAST_TIME})

# 대화창에 잠깐 띄우는 한마디(전투는 멈추지 않는다).
# Show the newest combat event immediately while preserving spoken dialogue.
func _queue_status_message(text: String) -> void:
	if text.is_empty(): return
	# Latest event takes priority; a spoken/story page still owns its callback.
	status_messages.clear()
	status_message_times.clear()
	status_messages.append(text)
	status_message_times.append(combat_message_clock)
	if state in ["fight","town"] and stat_box.is_empty():
		if status_message_active or dialog_t > 0.0:
			timed_dialog_pages.clear()
			dialog_text = ""
			dialog_t = 0.0
			status_message_active = false
		_show_next_status_message()

# Count displayed pages, including the current page, rather than merging targets.
func _combat_message_duration() -> float:
	if combat_message_clock - active_message_created_at >= COMBAT_MESSAGE_STALE_AFTER:
		return COMBAT_MESSAGE_FAST_TIME
	var remaining := 1 + timed_dialog_pages.size()
	for message in status_messages:
		remaining += PixelUi.dialogue_pages(message, Hud.MSG_W - 30.0).size()
		if remaining >= COMBAT_MESSAGE_FAST_THRESHOLD:
			return COMBAT_MESSAGE_FAST_TIME
	if remaining >= COMBAT_MESSAGE_FAST_THRESHOLD: return COMBAT_MESSAGE_FAST_TIME
	return COMBAT_MESSAGE_MEDIUM_TIME if remaining >= COMBAT_MESSAGE_MEDIUM_THRESHOLD else COMBAT_MESSAGE_TIME

func _show_next_status_message() -> void:
	if state not in ["fight","town"] or not dialog_text.is_empty() or not stat_box.is_empty(): return
	if not status_messages.is_empty():
		active_message_created_at = status_message_times.pop_front()
		_say(status_messages.pop_front())
		status_message_active = true
		dialog_t = _combat_message_duration()

func _advance_timed_message() -> void:
	if not timed_dialog_pages.is_empty():
		dialog_text = timed_dialog_pages.pop_front()
		last_small_message = dialog_text
		dialog_t = _combat_message_duration() if status_message_active else SAY_TIME
	else:
		dialog_text = ""
		dialog_t = 0.0
		status_message_active = false
		_show_next_status_message()

func _say(text: String) -> void:
	status_message_active = false
	timed_dialog_pages = PixelUi.dialogue_pages(text, Hud.MSG_W - 30.0)
	dialog_text = timed_dialog_pages.pop_front()
	last_small_message = dialog_text
	dialog_t = SAY_TIME

# The visible history does not keep dialogue callbacks, growth or battles waiting.
func displayed_message() -> String:
	if state=="fight" and is_event_battle() and event_battle().has_method("overlay_message"):
		var overlay: String=event_battle().overlay_message()
		if not overlay.is_empty():return overlay
	if not dialog_text.is_empty() or state=="talk": return dialog_text
	return last_small_message

func _open_water_menu() -> void:
	if not world.field_water.can_use(world):
		_toast(Lang.t("field_no_water"))
		return
	_menu_open("water")
	var entries: Array=[]
	for rod in FieldWater.RODS:
		entries.append({"name":Lang.t("field_"+rod),"sub":Lang.t("field_fishing"),"enabled":world.remaining()==0,"accent":Color("5890d8")})
	entries.append({"name":Lang.t("field_surf"),"enabled":world.player.travel_terrain==0 and (events.has(LaprasEscape.FRIEND) or FieldHMs.can_use(world.player,"surf")),"accent":Color("58b8d8")})
	entries.append({"name":Lang.t("bag_close"),"sub":"Esc","accent":PixelUi.INK_DIM})
	panel.show_items(Lang.t("field_water"),entries,2,4)

func _open_town_map() -> void:
	if state=="menu" and menu=="town_map":_close_menu();return
	if state not in ["fight","town"] or not battle.is_empty() or cinematic or encounter!=null or world.player.dead:return
	_menu_open("town_map")
	fly_screen.open(Arena.area_at(world.player.position),events,true)

func _close_travel_map() -> void:
	if state=="menu" and menu=="town_map":_close_menu()
	elif bird_event!=null:bird_event.cancel_destination()

# A failed landing returns through the preserved source destination.
func _reload_after_flight_failure() -> void:
	get_tree().reload_current_scene()

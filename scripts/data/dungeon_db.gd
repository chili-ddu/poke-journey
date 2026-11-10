class_name DungeonDB
extends RefCounted

# 장소 정의(던전·바깥 세계·건물 안) + 바닥 테마.
# 출현 포켓몬은 원작(FRLG) 출현표를 따른다. 보스는 없다(사용자 결정 2026-10-28) — 던전은 나온 적을 다 쓰러뜨리면 끝.
#
# waves 의 enemies: [종족, 마리 수, 레벨]. 종류가 섞여 나오도록 번갈아 끼운다.

const DEFAULT := "test_meadow"    # 봇·도구가 기본으로 들어가는 곳(던전 흐름 시험). 상록숲은 던전이 아니다(사용자 결정 2026-10-28)

const BASE_THEMES := {
	"vermilion_harbor": {"map": "res://assets/maps/vermilion_harbor", "tiles": {}},
	# 울타리 친 풀밭. 프로토타입 시절 아레나.
	"meadow": {"floor_a": Color("7fb35a"), "floor_b": Color("78ab54"), "grass": Color("5e9142"),
		"outside": Color("2b3a2a"), "border": "fence", "obstacle": "rock",
		"obstacles": [{"pos": Vector2(190, 120), "r": 14.0}, {"pos": Vector2(455, 115), "r": 12.0},
			{"pos": Vector2(170, 265), "r": 11.0}, {"pos": Vector2(470, 262), "r": 15.0}]},
	# 상록숲. 원작 지도(54×69칸)를 그대로 쓴다. tiles.tall 은 출현 때 흔들 풀숲 타일.
	"forest": {"map": "res://assets/maps/viridian_forest", "tiles": {"tall": 0x00D}},
	# 바깥 세계(태초마을·1번도로·상록시티를 연결 정보대로 한 장에, tools/frlg_map.py --region)와 건물 안.
	"kanto_south": {"map": "res://assets/maps/kanto_south", "tiles": {}},
	"oaks_lab": {"map": "res://assets/maps/oaks_lab", "tiles": {}},
	"players_house_1f": {"map": "res://assets/maps/players_house_1f", "tiles": {}},
	"players_house_2f": {"map": "res://assets/maps/players_house_2f", "tiles": {}},
	"rivals_house": {"map": "res://assets/maps/rivals_house", "tiles": {}},
	"viridian_center": {"map": "res://assets/maps/viridian_center", "tiles": {}},
	"forest_gate_south": {"map": "res://assets/maps/forest_gate_south", "tiles": {}},
	"forest_gate_north": {"map": "res://assets/maps/forest_gate_north", "tiles": {}},
	"viridian_mart": {"map": "res://assets/maps/viridian_mart", "tiles": {}},
	# 회색시티 건물(사용자 요청 2026-10-28). frlg_map.py PewterCity_<지도> pewter_<이름> 으로 구움.
	"pewter_center": {"map": "res://assets/maps/pewter_center", "tiles": {}},
	"pewter_mart": {"map": "res://assets/maps/pewter_mart", "tiles": {}},
	"pewter_gym": {"map": "res://assets/maps/pewter_gym", "tiles": {}},
	"pewter_museum_1f": {"map": "res://assets/maps/pewter_museum_1f", "tiles": {}},
	"pewter_museum_2f": {"map": "res://assets/maps/pewter_museum_2f", "tiles": {}},
	"pewter_house1": {"map": "res://assets/maps/pewter_house1", "tiles": {}},
	"pewter_house2": {"map": "res://assets/maps/pewter_house2", "tiles": {}},
	# 트레이너 배틀 경기장(사용자 결정 2026-10-29, tools/frlg_arena.py): 그 장소의 타일로 짠 직사각형 필드.
	"arena_viridian_forest": {"map": "res://assets/maps/arena_viridian_forest", "tiles": {}},
	"arena_bird_nest": {"map": "res://assets/maps/arena_bird_nest", "tiles": {}},
	"arena_forest_rescue": {"map": "res://assets/maps/arena_forest_rescue", "tiles": {}},
	"arena_pewter_gym": {"map": "res://assets/maps/arena_pewter_gym", "tiles": {}},
	"arena_mt_moon": {"map": "res://assets/maps/arena_mt_moon", "tiles": {}},
	"arena_route1": {"map": "res://assets/maps/arena_route1", "tiles": {}},
}

const HOME := "oaks_lab"            # 새 게임 시작·쓰러진 뒤 돌아오는 곳(사용자 결정 2026-10-28: 오박사 연구소 안에서 시작)
const OVERWORLD := "kanto_south"
# 원작 지도 id(pret 상수의 소문자) → 우리 장소 id. 문(워프)의 목적지를 찾는 데 쓴다. 없는 곳은 문이 열리지 않는다.
const BASE_WARP_MAPS := {"pallet_town": "kanto_south", "route1": "kanto_south", "viridian_city": "kanto_south",
	"ssanne_exterior": "vermilion_harbor",
	"pallet_town_professor_oaks_lab": "oaks_lab", "pallet_town_players_house_1f": "players_house_1f",
	"pallet_town_players_house_2f": "players_house_2f", "pallet_town_rivals_house": "rivals_house",
	"viridian_city_pokemon_center_1f": "viridian_center", "viridian_city_mart": "viridian_mart",
	"route2": "kanto_south", "pewter_city": "kanto_south",
	"route2_viridian_forest_south_entrance": "forest_gate_south", "route2_viridian_forest_north_entrance": "forest_gate_north",
	"viridian_forest": "viridian_forest",
	"pewter_city_pokemon_center_1f": "pewter_center", "pewter_city_mart": "pewter_mart", "pewter_city_gym": "pewter_gym",
	"pewter_city_museum_1f": "pewter_museum_1f", "pewter_city_museum_2f": "pewter_museum_2f",
	"pewter_city_house1": "pewter_house1", "pewter_city_house2": "pewter_house2"}
# 지도 판(版): 지도를 다시 구워 좌표가 바뀌면 올리고, 예전 저장 자리를 옮길 칸 수를 적는다(SaveData [where] layout).
#   kanto_south 3 / kanto_north 2 = 연속 필드 통합: 남부 +20행, 북부 +48열(2026-11-05)
#   kanto_south 2 = 2번도로·회색시티를 위에 붙여 기존 자리가 120칸 아래로(2026-10-28)
const LAYOUTS := {"kanto_south": 3, "kanto_north": 2}
const LAYOUT_SHIFT := {"kanto_south": {1: Vector2i(0, 120), 2: Vector2i(0, 20)}, "kanto_north": {1: Vector2i(48, 0)}}

const BASE_DUNGEONS := {
	"vermilion_harbor": {"name": "VERMILION HARBOR", "name_ko": "갈색시티 선착장", "theme": "vermilion_harbor", "overworld": true, "count": 0, "encounters": [],
		"areas": {"ssanne_exterior": {"name": "VERMILION HARBOR", "name_ko": "갈색시티 선착장", "encounter_rate": 0, "encounters": []}}},
	# 바깥 세계(사용자 결정 2026-10-28: 원작처럼 로딩 없이 걸어 다님). 구역마다 원작 출현표·출현율(0.5초 = 한 걸음, DungeonDB.wild_chance).
	"kanto_south": {"name": "KANTO", "name_ko": "관동", "theme": "kanto_south", "overworld": true, "count": 0, "encounters": [],
		"areas": {
			"pallet_town": {"name": "PALLET TOWN", "name_ko": "태초마을"},
			# 1번도로: 원작 파이어레드 출현표(12칸: 구구·꼬렛 Lv2~5)
			# encounter_rate: 원작 파이어레드 풀숲 출현율(wild_encounters.json land_mons). 출현 방식은 DungeonDB.wild_chance.
			"route1": {"name": "ROUTE 1", "name_ko": "1번도로", "encounter_rate": 21, "encounters": [
				["pidgey", 3, 20], ["rattata", 3, 20], ["pidgey", 3, 10], ["rattata", 3, 10], ["pidgey", 2, 10], ["rattata", 2, 10],
				["pidgey", 3, 5], ["rattata", 3, 5], ["pidgey", 4, 4], ["rattata", 4, 4], ["pidgey", 5, 1], ["rattata", 4, 1]]},
			"viridian_city": {"name": "VIRIDIAN CITY", "name_ko": "상록시티"},
			# 2번도로: 원작 파이어레드 출현표(꼬렛·구구 Lv2~5, 캐터피·뿔충이 Lv4~5). 가운데 서쪽 관문으로 상록숲.
			"route2": {"name": "ROUTE 2", "name_ko": "2번도로", "encounter_rate": 21, "encounters": [["rattata", 3, 20], ["pidgey", 3, 20], ["rattata", 4, 10], ["pidgey", 4, 10], ["rattata", 2, 10], ["pidgey", 2, 10], ["rattata", 5, 5], ["pidgey", 5, 5], ["caterpie", 4, 4], ["weedle", 4, 4], ["caterpie", 5, 1], ["weedle", 5, 1]]},
			"pewter_city": {"name": "PEWTER CITY", "name_ko": "회색시티"}}},
	# 건물 안: 적 없음, 기술도 안 쓴다. 문 칸에 서면 암전하고 바깥으로.
	# 오박사(사용자 요청 2026-10-29): 파이어레드 연구소 지도의 자리(6,3)·아래 보기. 말을 걸면 승인된 대사 B1·B2(Game._talk "oak").
	"oaks_lab": {"name": "OAK'S LAB", "name_ko": "오박사 연구소", "theme": "oaks_lab", "indoor": true, "count": 0, "encounters": [],
		"npcs": [{"id": "prof_oak", "sprite": "prof_oak", "tile": Vector2i(6, 3), "face": "down", "talk": "oak"}]},
	"players_house_1f": {"name": "PLAYER'S HOUSE", "name_ko": "주인공의 집", "theme": "players_house_1f", "indoor": true, "count": 0, "encounters": []},
	"players_house_2f": {"name": "PLAYER'S ROOM", "name_ko": "주인공의 방", "theme": "players_house_2f", "indoor": true, "count": 0, "encounters": []},
	"rivals_house": {"name": "RIVAL'S HOUSE", "name_ko": "라이벌의 집", "theme": "rivals_house", "indoor": true, "count": 0, "encounters": []},
	# 상록시티 포켓몬센터(1층)·프렌들리숍. 통신용 2층 계단은 제거.
	# npcs: 원작 지도의 object_events 중 일을 하는 사람만(간호순 7,2 아래 보기 / 점원 2,3 오른쪽 보기). talk_tile 은 카운터 앞 칸.
	# heal_spot: 간호순 왼쪽 회복 기계 위(칸 좌표, 원작 지도에서 기계가 5~6열·1~2행) — 회복 연출에서 내 포켓몬이 뛰어올라 잔다.
	"viridian_center": {"name": "POKéMON CENTER", "name_ko": "포켓몬센터", "theme": "viridian_center", "indoor": true, "count": 0, "encounters": [],
		"npcs": [{"id": "nurse", "sprite": "nurse", "tile": Vector2i(7, 2), "face": "down", "talk": "nurse", "talk_tile": Vector2i(7, 4), "heal_spot": Vector2(6.0, 1.7)}]},
	"viridian_mart": {"name": "POKé MART", "name_ko": "프렌들리숍", "theme": "viridian_mart", "indoor": true, "count": 0, "encounters": [],
		"npcs": [{"id": "clerk", "sprite": "clerk", "tile": Vector2i(2, 3), "face": "right", "talk": "shop", "talk_tile": Vector2i(4, 3)}]},
	# 회색시티(사용자 요청 2026-10-28). 센터·숍은 원작에서 상록시티와 같은 배치라 간호순·점원 자리도 같다. 파는 물건도 같은 목록(플래티넘 기준).
	# 체육관은 관장 웅과의 배틀(캠프보이 리암은 뺐다 — 사용자 결정 2026-10-30), 박물관·집은 아직 들어가 걷기만 한다(안내원·전시 설명은 없음).
	"pewter_center": {"name": "POKéMON CENTER", "name_ko": "포켓몬센터", "theme": "pewter_center", "indoor": true, "count": 0, "encounters": [],
		"npcs": [{"id": "nurse", "sprite": "nurse", "tile": Vector2i(7, 2), "face": "down", "talk": "nurse", "talk_tile": Vector2i(7, 4), "heal_spot": Vector2(6.0, 1.7)}]},
	"pewter_mart": {"name": "POKé MART", "name_ko": "프렌들리숍", "theme": "pewter_mart", "indoor": true, "count": 0, "encounters": [],
		"npcs": [{"id": "clerk", "sprite": "clerk", "tile": Vector2i(2, 3), "face": "right", "talk": "shop", "talk_tile": Vector2i(4, 3)}]},
	"pewter_gym": {"name": "PEWTER GYM", "name_ko": "회색체육관", "theme": "pewter_gym", "indoor": true, "count": 0, "encounters": [], "arena": "arena_pewter_gym",
		# 관장만 배틀. 원작 리암(3,8)은 야생 포켓몬을 보고 당황하는 대화 NPC.
		"npcs": [{"id":"gym_liam","sprite":"camper","talk":"gym_surprised","tile":Vector2i(3,8),"talk_tile":Vector2i(4,8),"face":"right"}],
		"trainers": [
			{"trainer": "leader_brock", "tile": Vector2i(6, 5), "face": "down", "sight": 0}]},
	"pewter_museum_1f": {"name": "PEWTER MUSEUM 1F", "name_ko": "회색시티 박물관 1층", "theme": "pewter_museum_1f", "indoor": true, "count": 0, "encounters": []},
	"pewter_museum_2f": {"name": "PEWTER MUSEUM 2F", "name_ko": "회색시티 박물관 2층", "theme": "pewter_museum_2f", "indoor": true, "count": 0, "encounters": []},
	"pewter_house1": {"name": "PEWTER CITY", "name_ko": "회색시티 민가", "theme": "pewter_house1", "indoor": true, "count": 0, "encounters": []},
	"pewter_house2": {"name": "PEWTER CITY", "name_ko": "회색시티 민가", "theme": "pewter_house2", "indoor": true, "count": 0, "encounters": []},
	# 상록숲. 적은 원작 파이어레드 야생 출현표(src/data/wild_encounters.json, 12칸 확률)에서 뽑는다 — 구구는 FRLG 상록숲에 없다.
	# 보스는 마지막에 독침붕(딱충이가 자란 "Lord of the Forest" 설정) 하나. 피카츄는 보스가 아니라 출현표의 5% 로만 나온다(사용자 결정).
	# count 는 원작 상록숲 통과(야생 10~15마리 + 벌레잡이 소년들 포켓몬 8마리)의 두 배쯤.
	# 상록숲: 던전이 아니라 도로와 같은 바깥 세계(사용자 결정 2026-10-28) — 2번도로 남·북 관문으로 드나들고, 원작 출현율 14·출현표대로
	# 걸음마다 나온다. 보스(독침붕)·30마리 줄·클리어는 없다(독침붕은 원작 상록숲 출현표에도 없다).
	"viridian_forest": {"name": "VIRIDIAN FOREST", "name_ko": "상록숲", "theme": "forest", "overworld": true, "count": 0, "encounters": [], "arena": "arena_viridian_forest",
		"areas": {"viridian_forest": {"name": "VIRIDIAN FOREST", "name_ko": "상록숲", "encounter_rate": 14, "encounters": [
			["caterpie", 4, 20], ["weedle", 4, 20], ["caterpie", 5, 10], ["weedle", 5, 10],
			["caterpie", 3, 10], ["weedle", 3, 10], ["metapod", 5, 5], ["kakuna", 5, 5],
			["kakuna", 4, 4], ["pikachu", 3, 4], ["kakuna", 6, 1], ["pikachu", 5, 1]]}},
		# 원작 다섯 명은 RoadData 출현 목록만 사용한다. 출구의 고정 이벤트는 없다.
		"trainers": []},
	# 트레이너 배틀 경기장(원작 배틀 화면). 이름표는 배틀이 걸린 장소 이름 그대로.
	"arena_viridian_forest": {"name": "VIRIDIAN FOREST", "name_ko": "상록숲", "theme": "arena_viridian_forest", "arena_field": true, "count": 0, "encounters": []},
	"arena_bird_nest": {"name": "PIDGEY NEST", "name_ko": "구구들의 둥지", "theme": "arena_bird_nest", "arena_field": true, "count": 0, "encounters": []},
	"arena_forest_rescue": {"name": "SCYTHER RESCUE", "name_ko": "스라크 구출", "theme": "arena_forest_rescue", "arena_field": true, "count": 0, "encounters": []},
	"arena_pewter_gym": {"name": "PEWTER GYM", "name_ko": "회색체육관", "theme": "arena_pewter_gym", "battle_style": "room", "arena_field": true, "count": 0, "encounters": []},
	"arena_mt_moon": {"name": "MT MOON", "name_ko": "달맞이산", "theme": "arena_mt_moon", "battle_style": "room", "arena_field": true, "count": 0, "encounters": []},
	"arena_route1": {"name": "ROUTE 1", "name_ko": "1번도로", "theme": "arena_route1", "arena_field": true, "count": 0, "encounters": []},
	"forest_gate_south": {"name": "VIRIDIAN FOREST", "name_ko": "상록숲 남쪽 관문", "theme": "forest_gate_south", "indoor": true, "count": 0, "encounters": []},
	"forest_gate_north": {"name": "VIRIDIAN FOREST", "name_ko": "상록숲 북쪽 관문", "theme": "forest_gate_north", "indoor": true, "count": 0, "encounters": []},
	# 시험용 풀밭 아레나(도감 캡처·확인용). 지도 없이 색칠 방식, 상록숲 종만 조금.
	"test_meadow": {"name": "Grass Arena", "name_ko": "풀밭 아레나", "theme": "meadow", "count": 10,
		"encounters": [["caterpie", 4, 40], ["weedle", 4, 40], ["metapod", 5, 10], ["kakuna", 5, 10]]},
}

const Expansion = preload("res://scripts/data/kanto_expansion.gd")
const Cerulean = preload("res://scripts/data/cerulean_progression.gd")
const RockPass = preload("res://scripts/data/rock_pass.gd")
const Saffron = preload("res://scripts/data/saffron_access.gd")
const DiglettRoute = preload("res://scripts/data/route11_diglett.gd")
const KantoWorld = preload("res://scripts/data/kanto_world.gd")
const TowerBrothers = preload("res://scripts/data/tower_brothers.gd")
const GymLeaders = preload("res://scripts/data/gym_leaders.gd")
const Johto = preload("res://scripts/data/johto_maps.gd")
const RivalProgression = preload("res://scripts/data/rival_progression.gd")
# Source regions stay editable; both legacy IDs now use one continuous field.
static func _field_themes() -> Dictionary:
	var themes := BASE_THEMES.merged(Expansion.THEMES).merged(Cerulean.THEMES).merged(RockPass.THEMES).merged(Saffron.THEMES).merged(DiglettRoute.THEMES).merged(KantoWorld.THEMES).merged(TowerBrothers.themes()).merged(GymLeaders.THEMES).merged(RivalProgression.THEMES)
	themes.erase("arena_pikachu_rescue")
	themes.merge(Johto.themes())
	for id in ["kanto_south", "kanto_north"]:
		themes[id] = {"map": "res://assets/maps/kanto_field", "tiles": {}}
	return themes

static func _field_warps() -> Dictionary:
	var warps := BASE_WARP_MAPS.merged(Expansion.WARP_MAPS).merged(Cerulean.WARP_MAPS).merged(RockPass.WARP_MAPS).merged(Saffron.WARP_MAPS).merged(DiglettRoute.WARP_MAPS)
	for id in ["route3", "route4", "cerulean_city", "route5"]:
		warps[id] = "kanto_south"
	warps.merge(KantoWorld.WARP_MAPS,true)
	return warps

static func _field_dungeons() -> Dictionary:
	var places := BASE_DUNGEONS.merged(Expansion.DUNGEONS).merged(Cerulean.DUNGEONS,true).merged(RockPass.DUNGEONS).merged(Saffron.DUNGEONS).merged(DiglettRoute.DUNGEONS).merged(KantoWorld.DUNGEONS)
	var areas: Dictionary = BASE_DUNGEONS.kanto_south.areas.merged(Expansion.DUNGEONS.kanto_north.areas)
	for id in ["kanto_south", "kanto_north"]:
		places[id] = places[id].duplicate(true)
		places[id].areas = areas
	# Keep established encounters and story data on the shared outdoor field.
	var whole: Dictionary=KantoWorld.DUNGEONS.kanto_world.duplicate(true)
	for source in [BASE_DUNGEONS.kanto_south,Expansion.DUNGEONS.kanto_north,Expansion.DUNGEONS.kanto_east,Cerulean.DUNGEONS.cerulean_north,RockPass.DUNGEONS.kanto_rock_pass,DiglettRoute.DUNGEONS.route11]:
		whole.areas.merge(source.get("areas",{}),true)
	places.kanto_world=whole
	# Story-only tower floors override the native random-encounter blockout.
	places.merge(TowerBrothers.places(),true)
	places.erase("arena_pikachu_rescue")
	for id in GymLeaders.PLACE_OVERRIDES:
		places[id]=(places.get(id,{}) as Dictionary).merged(GymLeaders.PLACE_OVERRIDES[id],true)
	places.merge(RivalProgression.PLACES,true)
	places.merge(Johto.places())
	return places

static var THEMES: Dictionary = _field_themes()
static var WARP_MAPS: Dictionary = _field_warps()
static var DUNGEONS: Dictionary = _field_dungeons()

static func warp_destination(warp: Dictionary) -> String:
	if Johto.has(String(warp.get("to", ""))): return String(warp.to)
	# Editable legacy source regions retain their synthetic boundary IDs.
	# They do not exist in the continuous mainland field, which has no edge warps.
	if warp.get("edge_transition",false):return String(KantoWorld.LEGACY_WARP_MAPS.get(String(warp.to),""))
	return String(WARP_MAPS.get(String(warp.to),""))

static var current := DEFAULT

static func set_current(id: String) -> void:
	assert(DUNGEONS.has(id), "모르는 던전 " + id)
	current = id

static func is_overworld(id: String = current) -> bool:
	return bool(DUNGEONS[id].get("overworld", false))

static func is_indoor(id: String = current) -> bool:
	return bool(DUNGEONS[id].get("indoor", false))

# 적이 줄지어 나오는 던전이 아닌 곳(바깥 세계·건물 안).
static func is_hub(id: String = current) -> bool:
	return is_overworld(id) or is_indoor(id) or is_arena(id)

# 트레이너 배틀 경기장(원작 배틀 화면 자리). 원작처럼 배틀이 걸린 장소마다 다르다(플래티넘 지형 분류 — 숲·건물 …).
static func is_arena(id: String = current) -> bool:
	return bool(DUNGEONS[id].get("arena_field", false))

# 그 장소에서 트레이너 배틀이 걸리면 갈 경기장. 없으면 ""(그 자리에서 울타리 배틀).
static func arena_of(id: String = current) -> String:
	return String(DUNGEONS[id].get("arena", ""))

static func has_location(id: String) -> bool:
	return DUNGEONS.has(id)

# 바깥 세계의 구역 설정(출현표 등). 없으면 빈 사전.
static func area_cfg(area_id: String) -> Dictionary:
	if Johto.has(area_id): return Johto.area(area_id)
	if Johto.has(current): return Johto.area(area_id if Johto.has(area_id) else current)
	var cfg: Dictionary = DUNGEONS[current].get("areas", {}).get(area_id, {}).duplicate()
	if is_overworld(): cfg.merge(KantoWaterData.TABLES.get(area_id,{}))
	if is_overworld() and not cfg.is_empty(): cfg.merge(KantoWorldWild.area(area_id),true)
	return cfg

# 장소 이름 알림판 종류(플래티넘 MapNamePopUp 그림, tools/plat_popup.py): 건물 안 indoors, 그 밖엔 구역(또는 장소)의 "popup",
# 적어 두지 않았으면 route. 마을은 town(집), 시티는 city(빌딩) — 원작 플래티넘이 마을·시티를 나눠 쓰는 대로.
const POPUPS := {"pallet_town": "town", "viridian_city": "city", "pewter_city": "city", "cerulean_city": "city", "vermilion_city": "city", "saffron_city":"city", "lavender_town":"town", "viridian_forest": "forest", "celadon_city":"city", "fuchsia_city":"city", "cinnabar_island":"city", "indigo_plateau_exterior":"city"}

static func popup_kind(area_id: String = "") -> String:
	if Johto.has(area_id): return Johto.popup(area_id)
	if Johto.has(current): return Johto.popup(area_id if Johto.has(area_id) else current)
	if is_indoor():
		return "indoors"
	return String(POPUPS.get(area_id, POPUPS.get(current, "route")))

static func area_name(area_id: String) -> String:
	var a := area_cfg(area_id)
	if a.is_empty():
		return display_name()
	return a.get("name_ko", a["name"]) if Lang.is_ko() else a["name"]

# 출현표(표 하나)에서 하나 뽑는다(확률 가중). { species, level }
# 바깥 세계 야생 출현(사용자 결정 2026-10-28): 원작 파이어레드 걸음 판정을 "WILD_STEP 초 = 한 걸음"으로 옮기고, 이미 나와 있는
# 마리 수 + 1 로 나눠 여러 마리가 겹치는 일을 줄인다. 걷든 서 있든 굴린다(실시간이라). 동시 마리 수 상한은 없다.
#   기본 확률 p = 출현율 % + 허탕 보정(원작: 출현율×16 + 보정×16/200 을 1600 중에서 → 출현율/100 + 보정/20000)
#   직후 막기: 마지막 출현 뒤 (8 − 출현율/10)걸음 동안은 5% 만 넘어감(원작 최소 걸음)
#   살아 있는 야생이 n 마리면 p ÷ (n+1) — 1번도로(21): 걸음당 0마리 21%, 1마리 10.5%, 2마리 7%
#   (사용자 결정 2026-10-28: 처음엔 p^(n+1) 이었으나 직접 해 보니 너무 드물어 나누기로. 1번도로·한 마리 10초 싸움 가정 분당 약 8.3마리,
#    두 마리 이상 겹친 시간 약 41%, 셋 이상 약 4%.)
# 한 걸음을 몇 초로 칠지. 원작 걷기는 1걸음 약 0.27초 — 이 게임은 0.5초(사용자 결정 2026-10-28: 1초 → 0.75초 → 0.5초).
const WILD_STEP := 0.5

# 한 걸음(WILD_STEP 초)에 한 마리 더 나올 확률. since 는 마지막 출현 뒤 지난 초, buff 는 허탕 보정(허탕 걸음마다 출현율만큼).
static func wild_chance(rate: float, since: float, buff: float, alive: int) -> float:
	var p := clampf(rate / 100.0 + buff / 20000.0, 0.0, 1.0)
	var min_steps := clampf(8.0 - floorf(rate / 10.0), 0.0, 8.0)
	if since / WILD_STEP < min_steps:
		p *= 0.05
	return p / float(alive + 1)

static func roll_table(table: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for e in table:
		total += int(e[2])
	var r := rng.randi_range(1, maxi(1, total))
	for e in table:
		r -= int(e[2])
		if r <= 0:
			return {"species": e[0], "level": rng.randi_range(int(e[1]),int(e[3])) if e.size()>3 else int(e[1])}
	return {"species": table[0][0], "level": int(table[0][1])}

static func name_of(id: String) -> String:
	var d: Dictionary = DUNGEONS[id]
	return d.get("name_ko", d["name"]) if Lang.is_ko() else d["name"]

# 출현표의 레벨 범위 [최소, 최대].
static func level_range(id: String) -> Array:
	var lo := 999
	var hi := 0
	for e in DUNGEONS[id].get("encounters", []):
		lo = mini(lo, int(e[1]))
		hi = maxi(hi, int(e[1]))
	return [lo if lo != 999 else 0, hi]

static func display_name() -> String:
	var d: Dictionary = DUNGEONS[current]
	return d.get("name_ko", d["name"]) if Lang.is_ko() else d["name"]

static func theme() -> Dictionary:
	return THEMES[DUNGEONS[current]["theme"]]

# 출현표 방식인가(없으면 waves 방식).
static func has_encounters() -> bool:
	return DUNGEONS[current].has("encounters")

static func encounters() -> Array:
	return DUNGEONS[current].get("encounters", [])

static func enemy_count() -> int:
	return int(DUNGEONS[current].get("count", 0))

# 이 던전의 출현표에서 하나 뽑는다.
static func roll_encounter(rng: RandomNumberGenerator) -> Dictionary:
	return roll_table(encounters(), rng)

static func count() -> int:
	return DUNGEONS[current].get("waves", []).size()

# 웨이브의 졸개를 한 줄로 펼친다. 종류가 섞여 나오도록 번갈아 끼운다.
static func spawn_list(index: int) -> Array:
	var groups: Array = DUNGEONS[current]["waves"][index]["enemies"]
	var left: Array = []
	for g in groups:
		left.append(int(g[1]))
	var out: Array = []
	var remaining := true
	while remaining:
		remaining = false
		for i in groups.size():
			if left[i] > 0:
				out.append({"species": groups[i][0], "level": int(groups[i][2])})
				left[i] -= 1
				remaining = true
	return out

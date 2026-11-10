class_name ItemDB
extends RefCounted

# 도구. 이름·가격·설명은 플래티넘 데이터(assets/data/items.json, tools/plat_items.py), 아이콘은 assets/items/<id>.png(32×32).
# 사용자 결정 2026-10-28:
#   상점(프렌들리숍)은 플래티넘 상점 물건 중 지금 게임에서 효과가 있는 것만(몬스터볼 제외).
#   돈 대신 물물교환 — 교환 재료는 야생 포켓몬이 원작 확률로 지니고 나와 떨어뜨리는 물건뿐(held_items.json).
#   값은 원작 가격(화면엔 "가치"로, 글꼴에 ₽ 가 없다). 교환품 합계가 물건 값 이상이면 바꿀 수 있고, 거스름은 없다.

const DATA := "res://assets/data/items.json"
const HELD := "res://assets/data/held_items.json"
const ICON := "res://assets/items/%s.png"
const DEFAULT_CAP := 99
const STORY_ITEMS := {"ss_ticket":{"name":"S.S. TICKET","name_ko":"승선티켓","price":0,"desc":"A ticket for the S.S. ANNE in VERMILION CITY.","desc_ko":"갈색시티의 상트안느호에 탈 수 있는 중요한 티켓.","pocket":"key","shop":false,"held":false}}
const BERRY_CAP := 9999 # 거래 재료인 열매는 넉넉하게 비축한다.
# 원작 가방 주머니 순서(가방 그림·아이콘 번호도 이 순서). 우리 가방은 그중 다섯만 보여 준다(사용자 결정 2026-10-28).
const POCKET_ORDER := ["items", "medicine", "balls", "tms", "berries", "mail", "battle", "key"]
const BAG_POCKETS := ["items", "medicine", "tms", "berries", "battle"]
const STATUSES := ["burn", "poison", "paralyze", "slow", "sleep", "confuse"]   # 화상·독·마비·둔화(실뿜기류)·잠·혼란(만병통치제·회복약·센터가 고친다)
const HELD_COMMON := 0.5            # 원작: 흔한 지닌 물건 50%, 드문 것 5%, 둘이 같으면 100%
const HELD_RARE := 0.05

# 효과. heal: 회복량(-1 은 전부), cure: 고치는 상태, revive: 쓰러질 때 저절로(그 비율로 되살아남),
# escape: 던전에서 빠져나옴, repel: 바깥 세계에서 그 걸음(칸) 동안 야생이 안 나옴(원작 100/200/250걸음).
const EFFECTS := {
	"potion": {"heal": 20}, "super_potion": {"heal": 50}, "hyper_potion": {"heal": 200}, "max_potion": {"heal": -1},
	"full_restore": {"heal": -1, "cure": STATUSES}, "revive": {"revive": 0.5},
	"antidote": {"cure": ["poison"]}, "burn_heal": {"cure": ["burn"]}, "parlyz_heal": {"cure": ["paralyze"]},
	"full_heal": {"cure": STATUSES}, "escape_rope": {"escape": true},
	"repel": {"repel": 100}, "super_repel": {"repel": 200}, "max_repel": {"repel": 250},
	"oran_berry": {"heal": 10}, "sitrus_berry": {"heal_ratio":0.25},
	"leppa_berry": {"pp_restore":10},
	"cheri_berry": {"cure":["paralyze"]}, "chesto_berry": {"cure":["sleep"]},
	"pecha_berry": {"cure":["poison"]}, "rawst_berry": {"cure":["burn"]},
	"persim_berry": {"cure":["confuse"]},
	"lum_berry": {"cure":["burn","poison","paralyze","sleep","confuse"]},
	# hold: 지니는 물건 — 가방에서 고르면 지니기 ↔ 돌려받기(Game._on_bag_used). no_evolve = 지닌 동안 진화 안 함(변함없는돌, 원작 HOLD_EFFECT_NO_EVOLVE).
	"everstone": {"hold": "no_evolve"},
}

static var _data := {}
static var _held := {}
static var _icons := {}

static func _load() -> void:
	if not _data.is_empty():
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_data = (d if d is Dictionary else {}).merged(STORY_ITEMS,true)
	var h = JSON.parse_string(FileAccess.get_file_as_string(HELD))
	_held = h if h is Dictionary else {}

static func has_item(id: String) -> bool:
	_load()
	return _data.has(id)

static func get_item(id: String) -> Dictionary:
	_load()
	return _data.get(id, {})

static func name_of(id: String) -> String:
	var it := get_item(id)
	if it.is_empty():
		return id
	return String(it["name_ko"]) if Lang.is_ko() and String(it.get("name_ko", "")) != "" else String(it["name"])

# 원작 주머니(items.json 의 pocket, 플래티넘 fieldPocket).
static func pocket_of(id: String) -> String:
	return String(get_item(id).get("pocket", "items"))

# 설명(한국어는 PokeAPI 의 한국어가 있는 가장 이른 판).
static func desc_of(id: String) -> String:
	var it := get_item(id)
	if Lang.is_ko() and String(it.get("desc_ko", "")) != "":
		return String(it["desc_ko"])
	return String(it.get("desc", ""))

static func price(id: String) -> int:
	return int(get_item(id).get("price", 0))

static func cap(id: String) -> int:
	if id=="ss_ticket":return 1
	return BERRY_CAP if pocket_of(id) == "berries" else DEFAULT_CAP

static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path := ICON % id
		_icons[id] = load(path) if ResourceLoader.exists(path) else null
	return _icons[id]

# 상점 목록(데이터 순서 = 생성기의 ITEMS 순서).
static func shop_items() -> Array:
	_load()
	var out: Array = []
	for id in _data:
		if _data[id].get("shop", false):
			out.append(id)
	return out

# 가방에 보여 줄 순서: 상점 물건 다음 지닌 물건.
static func all_items() -> Array:
	_load()
	var out: Array = shop_items()
	for id in _data:
		if not out.has(id):
			out.append(id)
	return out

# 교환 재료(야생이 지니고 나오는 물건)인가.
static func is_trade_good(id: String) -> bool:
	return bool(get_item(id).get("held", false))

static func effect(id: String) -> Dictionary:
	return EFFECTS.get(id, {})

# 그 종이 지니고 나온 물건(쓰러뜨리면 떨어짐). 없으면 "".
static func roll_held(species_id: String, rng: RandomNumberGenerator) -> String:
	_load()
	var h: Dictionary = _held.get(species_id, {})
	if h.is_empty():
		return ""
	var common = h.get("common")
	var rare = h.get("rare")
	if common != null and common == rare:
		return String(common)
	var r := rng.randf()
	if common != null and r < HELD_COMMON:
		return String(common)
	if rare != null and r >= HELD_COMMON and r < HELD_COMMON + HELD_RARE:
		return String(rare)
	return ""

# 가방 속 교환품의 값 합계(₽).
static func trade_value(bag: Dictionary) -> int:
	var total := 0
	for id in bag:
		if is_trade_good(id):
			total += price(id) * int(bag[id])
	return total

# 값 price 를 치를 교환품 묶음 {id: 개수}. 넘치는 값(거스름 없음)이 가장 적고, 같으면 개수가 적은 것. 못 치르면 {}.
static func payment(bag: Dictionary, cost: int) -> Dictionary:
	if cost <= 0:
		return {}
	var units: Array = []
	var max_price := 0
	for id in bag:
		if is_trade_good(id) and price(id) > 0:
			var value := price(id)
			max_price = maxi(max_price, value)
			# 이 종류만으로 값을 치를 수 있는 수량보다 더 쓸 필요는 없다.
			for k in mini(int(bag[id]), ceili(float(cost) / value)):
				units.append(id)
	if units.is_empty():
		return {}
	var top := cost + max_price - 1
	# best[v] = 값 v 를 정확히 맞추는 가장 적은 개수 묶음(단위 목록의 인덱스). 0/1 배낭.
	var best := {0: []}
	for ui in units.size():
		var v_add := price(units[ui])
		for v in best.keys().duplicate():
			var nv: int = v + v_add
			if nv > top:
				continue
			var cand: Array = (best[v] as Array) + [ui]
			if not best.has(nv) or (best[nv] as Array).size() > cand.size():
				best[nv] = cand
	var pick := -1
	for v in best:
		if v >= cost and (pick < 0 or v < pick or (v == pick and (best[v] as Array).size() < (best[pick] as Array).size())):
			pick = v
	if pick < 0 or cost <= 0:
		return {}
	var out := {}
	for ui in best[pick]:
		out[units[ui]] = int(out.get(units[ui], 0)) + 1
	return out

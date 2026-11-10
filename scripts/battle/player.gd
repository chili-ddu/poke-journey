class_name Player
extends Mon

# 플레이어가 조종하는 포켓몬. 기술 4칸(좌클릭·우클릭·Q·E)과 점프, 경험치를 갖는다.
# 입력은 controller 를 통해서만 읽는다 — 사람(HumanController)과 봇(BotController)을 바꿔 끼우려고.
# 기술은 원작처럼 종족의 습득 레벨에 자동으로 배운다(game.gd). 강화 같은 건 없다.

# 기술 칸은 둘(사용자 결정 2026-10-28): 좌클릭 = 0번, 우클릭 = 1번. 지금까지 배운 기술(learned) 중에서 상태창(C)으로 골라 끼운다.
const SLOT_COUNT := 4         # 기술 칸: Q·W·E·R(사용자 결정 2026-11-02 — 처음엔 좌·우클릭 두 칸)
const HOTBAR := 4             # 도구 편성 칸: 1·2·3·4(사용자 결정 2026-11-02 — 처음엔 Q 하나에 오랭열매)
const SLOT_KEYS := ["Q", "W", "E", "R"]
# 점프(Space)와 회피(우클릭)는 따로(사용자 결정 2026-10-28).
# 점프: 원작처럼 두 칸(2×Arena.TILE). Hop 동작 길이(0.4초) 동안 날고, 언덕을 넘으면 바로 아래 칸에 내려선다. 무적·쿨타임 없음.
const JUMP_DISTANCE := 48.0
# 회피: 처음 값 그대로 되살림 — 64px 를 0.2초에 내달리고 잠깐 무적, 쿨타임 1.2초(사용자: 쿨타임이 느껴지게). 언덕은 못 넘는다. 걷기 동작 + 잔상.
const DODGE_DISTANCE := 64.0
const DODGE_DURATION := 0.2
const DODGE_COOLDOWN := 1.2
# 회피 잠금(사용자 결정 2026-10-28: 기능은 없애지 말고 잠가 둔다). 풀리기 전엔 우클릭이 아무 일도 안 한다(봇도 안 씀). 시험 도구만 잠깐 연다.
static var dodge_unlocked := false
const HIT_INVULN := 0.7
# 열매(사용자 결정 2026-10-28: 줍자마자 먹지 않고 들고 다니다 Q 로 먹는다 — 세피리아·디아블로 3·4 식 퀵키).
const BERRY_MAX := ItemDB.BERRY_CAP # 열매 소지 한도
# Q 를 누르는 즉시 회복. 먹기(Eat) 동작은 연출뿐 — 멈춰 있을 때만 보이고 움직이거나 기술·점프를 쓰면 바로 풀린다(사용자 결정 2026-10-28).
const BERRY_COOLDOWN := 1.5     # 연타 방지

var slots: Array = ["", "", "", ""]
var pp: Array = [0, 0, 0, 0]              # 남은 PP(탄창)
var use_t: Array = [0.0, 0.0, 0.0, 0.0]   # 다음 발까지 남은 시간
var regen_t: Array = [0.0, 0.0, 0.0, 0.0] # PP 회복: 다음 1 까지 쌓인 시간(가득이면 0)
var evolution_declined_level := 0
var learned: Array = []                   # 지금까지 배운 기술(배운 순서, 저장됨). 끼운 네 칸도 여기 들어 있다
var hotbar: Array = ["oran_berry", "", "", ""]   # 도구 편성(1~4, 저장됨): 가방의 도구 id. 가방에서 도구를 고르고 숫자 키로 편성
var dodge_cd := 0.0
var skill_lock_t := 0.0                    # 후딜레이(사용자 정의 2026-10-30): 스킬 동작이 끝난 뒤 다음(다른) 스킬을 쓰기까지. 움직임은 막지 않는다
const SKILL_DENIED_DURATION := 0.24
const SKILL_DENIED_STRENGTH := 3.5 # Keep the two rejection swings readable at gameplay scale.
var skill_denied_t := 0.0

func play_skill_denied_feedback() -> void:
	if not dead and skill_denied_t <= 0.0:
		skill_denied_t = SKILL_DENIED_DURATION

func command_feedback_offset() -> Vector2:
	if dead or skill_denied_t <= 0.0: return Vector2.ZERO
	var progress := clampf(1.0 - skill_denied_t / SKILL_DENIED_DURATION, 0.0, 1.0)
	var envelope := 1.0-progress*progress # Hold the first swing, then settle back to the origin.
	return Vector2(sin(progress * TAU * 2.0) * SKILL_DENIED_STRENGTH * envelope, 0.0)
var reward_reserve := {} # Awarded trainer berries waiting for bag capacity; saved.
var bag := {}                              # 가방 {도구 id: 개수}(저장됨). 도구는 ItemDB
var hold := ""                             # 지닌 물건(도구 id, 저장됨). 가방에서 고르면 지니기 ↔ 돌려받기(사용자 결정 2026-10-30). 변함없는돌: 진화 안 함
var berry_cd := 0.0
var repel_steps := 0                       # 스프레이: 남은 걸음(칸). 바깥 세계 야생이 안 나온다
# 퀵키 Q 의 오랭열매 수(가방의 oran_berry). 예전 코드·도구가 쓰던 이름을 그대로 둔다.
var berries: int:
	get:
		return int(bag.get("oran_berry", 0))
	set(v):
		if v > 0:
			bag["oran_berry"] = v
		else:
			bag.erase("oran_berry")

# 가방에 n 개 넣는다(한도까지). 실제로 넣은 개수.
func add_item(id: String, n: int = 1) -> int:
	var have := int(bag.get(id, 0))
	var put := clampi(ItemDB.cap(id) - have, 0, n)
	if put > 0:
		bag[id] = have + put
	return put

func take_item(id: String, n: int = 1) -> bool:
	var have := int(bag.get(id, 0))
	if have < n:
		return false
	if have == n:
		bag.erase(id)
	else:
		bag[id] = have - n
	return true
var exp_total := 0
var last_slot := -1                        # 마지막으로 쓴 기술 칸
var pp_focus_slot := 0 # Last pressed skill, even when empty PP or action-locked.
var selected_slot := 0                     # 마지막으로 쓴 칸(봇이 거리를 잡는 데 쓴다)
var controller = null

# ind: 개체 정보 {pid, ivs}(Individual). 비었으면 개체값 0(시험용).
func setup_player(id: String, lv: int, start_moves: Array, ind: Dictionary = {}) -> void:
	if not ind.is_empty():
		pid = int(ind["pid"])
		ivs = ind["ivs"].duplicate()
		shiny = Individual.is_shiny(pid)
	setup(id, lv, TEAM_PLAYER)
	exp_total = SpeciesDB.exp_for_level(lv, SpeciesDB.growth_of(id))
	for i in start_moves.size():
		add_learned(start_moves[i])
		if i < SLOT_COUNT:
			equip(i, start_moves[i])

# 지금까지 배운 기술 전부(끼우지 않은 것 포함).
func known_moves() -> Array:
	return learned.duplicate()

# 배운 기술 목록에 넣는다. 새로 넣었으면 true.
func add_learned(move_id: String) -> bool:
	if move_id == "" or learned.has(move_id):
		return false
	learned.append(move_id)
	return true

# 끼우지 않은 배운 기술(배운 순서).
func spare_moves() -> Array:
	var out: Array = []
	for m in learned:
		if not slots.has(m):
			out.append(m)
	return out

# 그 칸의 기술을 뺄 수 있나: 비었거나 PP 가 가득일 때만(사용자 결정 2026-10-28: PP 가 맥스일 때만 교체).
func can_swap(slot: int) -> bool:
	return slots[slot] == "" or int(pp[slot]) >= MoveDB.pp_of(slots[slot])

# 칸에 기술을 끼운다. 다른 칸에 이미 있으면 두 칸을 맞바꾼다(PP 도 함께). 새로 끼우는 기술은 PP 가득 —
# 뺄 때 늘 가득이어야 하므로(can_swap) 빼 둔 기술은 언제나 가득이다. 막는 건 부르는 쪽(can_swap)의 몫.
func equip(slot: int, move_id: String) -> void:
	var other := slots.find(move_id)
	if other == slot:
		return
	if other >= 0:
		var t: Array = [slots[slot], pp[slot], use_t[slot], regen_t[slot]]
		slots[slot] = slots[other]; pp[slot] = pp[other]; use_t[slot] = use_t[other]; regen_t[slot] = regen_t[other]
		slots[other] = t[0]; pp[other] = t[1]; use_t[other] = t[2]; regen_t[other] = t[3]
		return
	add_learned(move_id)
	slots[slot] = move_id
	pp[slot] = MoveDB.pp_of(move_id)
	regen_t[slot] = 0.0
	use_t[slot] = 0.0

# 그 기술의 남은 PP(끼웠으면 칸, 아니면 가득).
func pp_of_move(move_id: String) -> int:
	var s := slots.find(move_id)
	if s >= 0:
		return int(pp[s])
	return MoveDB.pp_of(move_id)

func first_empty_slot() -> int:
	return slots.find("")

# 배우고 그 칸에 바로 끼운다(새 탄창).
func learn(move_id: String, slot: int) -> void:
	add_learned(move_id)
	equip(slot, move_id)
	pp[slot] = MoveDB.pp_of(move_id)
	regen_t[slot] = 0.0

func can_use(slot: int) -> bool:
	return slots[slot] != "" and pp[slot] > 0 and use_t[slot] <= 0.0

# 한 발 쓴다. PP 는 줄어 있는 동안 저절로 1씩 회복한다(tick_cooldowns). 쓰면 쌓이던 회복 시간은 리셋.
func spend(slot: int) -> void:
	var id: String = slots[slot]
	last_slot = slot
	selected_slot = slot
	if not controller is Controllers.Human:select_skill(slot)
	pp[slot] -= 1
	use_t[slot] = MoveDB.use_delay(id)
	regen_t[slot] = 0.0     # 회복 도중 쓰면 다음 1 까지 처음부터(사용자 결정 2026-10-28)

# 경험치를 더하고 오른 레벨 수를 돌려준다. 능력치 반영은 레벨마다 set_level 로.
func gain_exp(amount: int) -> int:
	exp_total = mini(exp_total + maxi(0, amount), SpeciesDB.exp_for_level(100, SpeciesDB.growth_of(species_id)))
	var gained := 0
	while level + gained < 100 and exp_total >= SpeciesDB.exp_for_level(level + gained + 1, SpeciesDB.growth_of(species_id)):
		gained += 1
	return gained

func exp_progress() -> float:
	var lo := SpeciesDB.exp_for_level(level, SpeciesDB.growth_of(species_id))
	var hi := SpeciesDB.exp_for_level(level + 1, SpeciesDB.growth_of(species_id))
	return clampf(float(exp_total - lo) / float(hi - lo), 0.0, 1.0)

func evolution_target() -> String:
	var evo: Dictionary = SpeciesDB.get_species(species_id).get("evolve", {})
	if evo.is_empty() or level < int(evo["level"]):
		return ""
	if String(ItemDB.effect(hold).get("hold", "")) == "no_evolve":     # 변함없는돌을 지니면 진화하지 않는다(원작)
		return ""
	return evo["to"]

# 진화: 종족을 바꾸고 능력치를 다시 계산한다. HP 비율은 유지.
func evolve_to(id: String) -> void:
	evolution_declined_level = 0
	var ratio := hp_ratio()
	species_id = id
	var sp := SpeciesDB.get_species(id)
	_sprites = MonSprite.load_set(int(sp["dex"]), shiny)
	_apply_species_size(sp)
	if stat_overlay!=null:stat_overlay.tex=null
	stats = SpeciesDB.stats_at(id, level, ivs)
	max_hp = int(stats["hp"])
	hp = maxi(1, int(round(max_hp * ratio)))

func tick_cooldowns(dt: float) -> void:
	# Acknowledge inputs even during hitstop, when the ordinary pose clock pauses.
	skill_denied_t = maxf(0.0, skill_denied_t - dt)
	skill_lock_t = maxf(0.0, skill_lock_t - dt)
	for i in SLOT_COUNT:
		use_t[i] = maxf(0.0, use_t[i] - dt)
		if slots[i] == "":
			continue
		var full := MoveDB.pp_of(slots[i])
		if int(pp[i]) >= full:
			regen_t[i] = 0.0
			continue
		regen_t[i] += dt
		var step := MoveDB.regen_interval(slots[i])
		while regen_t[i] >= step and int(pp[i]) < full:
			regen_t[i] -= step
			pp[i] = int(pp[i]) + 1
		if int(pp[i]) >= full:
			regen_t[i] = 0.0     # 가득 차면 남은 시간은 버린다(다음에 줄면 처음부터)
	dodge_cd = maxf(0.0, dodge_cd - dt)
	berry_cd = maxf(0.0, berry_cd - dt)

# 다음 PP 1 까지의 진행도(0~1). 가득이면 0.
func regen_ratio(slot: int) -> float:
	var id: String = slots[slot]
	if id == "" or int(pp[slot]) >= MoveDB.pp_of(id):
		return 0.0
	return clampf(regen_t[slot] / MoveDB.regen_interval(id), 0.0, 1.0)

func select_skill(slot: int) -> bool:
	if slot<0 or slot>=SLOT_COUNT or slots[slot]=="":return false
	pp_focus_slot=slot
	return true

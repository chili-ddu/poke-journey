class_name Enemy
extends Mon

# 야생 포켓몬의 행동. 종족의 ai 값으로 갈린다.
#   crawler   캐터피. 느릿느릿 다가와 몸통박치기, 중간 거리에선 실뿜기(맞으면 느려짐).
#   stinger   뿔충이. 중간 거리를 유지하며 독침을 쏨.
#   zapper    야생 피카츄. 4칸쯤 거리를 두고 전기쇼크.
#   cocoon    단데기·딱충이. 아주 느리게 다가오며 몇 초마다 단단해지기(방어 ↑, 최대 6단계). 공격기는 없다(원작 그대로).
#   drill     독침붕. 연속찌르기 쿨타임이 돌면 다가가 Jab 으로 2~5번 찌르고, 아니면 3.5칸쯤 거리를 두고 돌며 독침(Shoot)을 쏜다.
# 보스는 없다(사용자 결정 2026-10-28). 모든 야생은 같은 규칙.
# 공격 전에는 반드시 준비 동작(windup)을 둔다 — 탄막 게임에서 "보고 피할 수 있다"가 공정함의 기준이다.

# 준비 동작 길이(초). 0 이면 웅크리지 않고 바로 쓴다 — 몸통박치기는 Attack 동작 자체가 예고라 대기 없음(사용자 결정).
const WINDUP := {"tackle": 0.0, "string_shot": 0.55, "poison_sting": 0.45, "harden": 0.3, "thunder_shock": 0.45, "fury_attack": 0.45,
	"scratch": 0.2, "defense_curl": 0.3, "bind": 0.35, "rock_tomb": 0.55}
const T := 24.0                    # 풀숲 한 칸(Arena.TILE)

var ai := ""
var cds := {}
var trainer_owned := false         # 트레이너의 포켓몬(도망·사라짐 없음, 도구 없음; 경험치는 공통 성장 정책)
var windup_t := 0.0
var windup_move := ""
var windup_dir := Vector2.ZERO
var wander_dir := Vector2.ZERO
var wander_t := 0.0
var strafe := 1.0
var _last_pos := Vector2.INF
var stuck_t := 0.0
var unstick_t := 0.0
var unstick_dir := Vector2.ZERO

# 연타 기술(연속찌르기): 남은 타수와 다음 타까지 시간. 치는 동안은 제자리에서 상대를 다시 겨눈다.
var multi_left := 0
var multi_t := 0.0
var multi_move := ""
var multi_interval := 0.3

func setup_enemy(id: String, lv: int, rng: RandomNumberGenerator) -> void:
	var sp := SpeciesDB.get_species(id)
	# 야생 개체: 원작처럼 PID·개체값을 뽑고, 이로치는 플레이어의 트레이너 ID 로 판정(1/8192).
	var ind := Individual.roll(rng)
	pid = int(ind["pid"])
	ivs = ind["ivs"]
	shiny = Individual.is_shiny(pid)
	setup(id, lv, TEAM_ENEMY)
	ai = sp["ai"]
	# 쓰는 기술: SpeciesExtras 에 적은 목록(없으면 그 레벨에 아는 자력기 중 모양 있는 것).
	var move_list: Array = SpeciesDB.enemy_moves(id, lv)
	for m in move_list:
		# 첫 공격 시점을 흩어서 한꺼번에 쏘지 않게.
		cds[m] = rng.randf_range(0.6, 1.8)
	strafe = 1.0 if rng.randf() < 0.5 else -1.0

# 트레이너의 포켓몬: 원작의 iv 스케일(0..255)을 0..31로 변환한 고정 개체값. 기본 0, 이로치 아님.
# moves 를 주면 그 기술만(CUSTOM_MOVES 파티), 비었으면 그 레벨의 자력기(DEFAULT_MOVES — 야생과 같은 enemy_moves).
func setup_trainer_mon(id: String, lv: int, moves: Array, rng: RandomNumberGenerator, fixed_iv: int = 0) -> void:
	var sp := SpeciesDB.get_species(id)
	pid = rng.randi()
	ivs = {}
	if fixed_iv>0:
		for key in sp.base:ivs[key]=clampi(fixed_iv,0,31)
	shiny = false
	trainer_owned = true
	setup(id, lv, TEAM_ENEMY)
	ai = "wild" if not moves.is_empty() else sp["ai"]
	var move_list: Array = moves if not moves.is_empty() else SpeciesDB.enemy_moves(id, lv)
	for m in move_list:
		cds[m] = rng.randf_range(0.6, 1.8)
	strafe = 1.0 if rng.randf() < 0.5 else -1.0

func think(dt: float, world) -> void:
	for m in cds:
		cds[m] = maxf(0.0, cds[m] - dt)
	if not can_act():
		return
	var p: Mon = world.player
	var to_p: Vector2 = p.position - position
	var dist := to_p.length()
	var dir := to_p / dist if dist > 0.001 else Vector2.DOWN

	# 연타 중: 멈춰서 간격마다 한 타씩(상대 쪽으로 다시 겨눔).
	if multi_left > 0:
		vel = Vector2.ZERO
		facing = dir
		multi_t -= dt
		if multi_t <= 0.0:
			_strike_once(multi_move, dir, world)
		return

	# 준비 동작 중: 멈춰서 떨다가 발사.
	if windup_t > 0.0:
		windup_t -= dt
		vel = Vector2.ZERO
		facing = windup_dir
		if windup_t <= 0.0:
			_fire(windup_move, windup_dir, world)
		return

	for move_id in cds:
		if cds[move_id]>0.0:continue
		var recovery:=MoveDB.get_move(move_id)
		if recovery["shape"]=="heal" and hp_ratio()<=0.5:
			_begin_windup(move_id,facing,world)
			return
		if recovery["shape"]=="teleport" and position.distance_to(world.player.position)<3*Arena.TILE:
			_begin_windup(move_id,facing,world)
			return

	match ai:
		"crawler":
			# 다가가며 아는 기술 중 지금 닿는 것을 쓴다(근접 → 부채꼴 변화기 → 실뿜기 순은 moves 순서).
			vel = dir * move_speed()
			var gap := dist - radius - p.radius
			for mv in cds:
				if cds[mv] > 0.0:
					continue
				var m := MoveDB.get_move(mv)
				var ok := false
				match m["shape"]:
					"arc": ok = gap < float(m["range"]) + float(m.get("step", 0.0)) * 0.6
					"status_cone": ok = gap < float(m["range"]) * 0.9 and not _stat_already_low(p, m)
					"beam": ok = dist > 2.75 * T and dist < float(m["range"])
					# 자기 강화(웅크리기·단단해지기): 6단계 전까지. 던지기(암석봉인): 조금 떨어져 있을 때.
					"buff": ok = int(get(String(m.get("stat", "def")) + "_stage")) < 6
					"lob": ok = dist > 1.5 * T and dist < float(m["range"]) + 0.5 * T
				if ok:
					_begin_windup(mv, dir, world)
					break
		"wild":
			var gap := dist - radius - p.radius
			var want := 0.6 * T
			for mid in cds:
				var shape := String(MoveDB.get_move(mid)["shape"])
				if shape in ["projectile", "drain", "burst"] and cds[mid] <= 0.0: want = 2.0 * T
			vel = dir * move_speed() * clampf((dist-want)/24.0,-1.0,1.0)
			for mid in cds:
				if cds[mid] > 0.0: continue
				var m := MoveDB.get_move(mid)
				var ready := false
				match String(m["shape"]):
					"arc": ready = gap <= float(m["range"])
					"projectile", "drain", "burst": ready = dist <= float(m["range"]) * 0.9
					"cone", "lob", "beam": ready = dist <= float(m["range"])*0.9
					"dash": ready = gap <= float(m["distance"])
					"ring", "zone": ready = gap <= float(m.get("range",m["radius"]))
					"transform": ready = form_species_id.is_empty() and p.form_species_id.is_empty() and dist<=float(m["range"])
					"counter": ready = counter_t<=0.0 and dist<=6*T
					"status_cone":
						ready = gap <= float(m["range"]) * 0.8 and not _stat_already_low(p,m)
						if m.has("sleep") and p.sleep_t > 0.0: ready = false
						if m.has("confuse") and p.confuse_t > 0.0: ready = false
					"buff": ready = int(get(String(m.get("stat","def"))+"_stage")) < 2
					"gesture": ready = true
				if ready:
					_begin_windup(mid,dir,world)
					break

		"stinger":
			var want := 4 * T
			vel = dir * move_speed() * clampf((dist - want) / 40.0, -1.0, 1.0)
			if cds["poison_sting"] <= 0.0 and dist < 5 * T:
				_begin_windup("poison_sting", dir, world)
		"cocoon":
			vel = dir * move_speed()
			if cds.has("harden") and cds["harden"] <= 0.0 and def_stage < 6:
				_begin_windup("harden", dir, world)
		"drill":
			# 연속찌르기가 준비되면 다가가서 찌르고, 아니면 3.5칸쯤 거리를 두고 옆으로 돌며 독침.
			var gap := dist - radius - p.radius
			if cds["fury_attack"] <= 0.0:
				vel = dir * move_speed()
				if gap < 1.0 * T:
					_begin_windup("fury_attack", dir, world)
			else:
				var want := 3.5 * T
				var side := Vector2(-dir.y, dir.x) * strafe
				vel = (dir * clampf((dist - want) / 40.0, -1.0, 1.0) + side * 0.5).normalized() * move_speed()
				if cds["poison_sting"] <= 0.0 and dist < 5 * T:
					_begin_windup("poison_sting", dir, world)
		"zapper":
			var want := 4 * T
			var side := Vector2(-dir.y, dir.x) * strafe
			vel = (dir * clampf((dist - want) / 30.0, -1.0, 1.0) + side * 0.6).normalized() * move_speed()
			if cds["thunder_shock"] <= 0.0 and dist < 6 * T:
				_begin_windup("thunder_shock", dir, world)
	_apply_unstick(dt, dir)
	if vel.length_squared() > 1.0:
		facing = vel.normalized()

# 변화기: 상대 랭크가 이미 −2 이하면 안 쓴다(헛수고).
func _stat_already_low(p: Mon, m: Dictionary) -> bool:
	for key in m.get("stat", {}):
		if int(p.get(key + "_stage")) <= -2:
			return true
	return false

# 나무에 막혀 제자리걸음이면 잠깐 옆으로 돌아간다. 지도에 길이 꼬여 있어도 적이 벽에 붙어 있지 않게.
func _apply_unstick(dt: float, dir: Vector2) -> void:
	if unstick_t > 0.0:
		unstick_t -= dt
		vel = unstick_dir * move_speed()
	elif vel.length_squared() > 100.0 and _last_pos != Vector2.INF and position.distance_to(_last_pos) < 0.25:
		stuck_t += dt
		if stuck_t > 0.6:
			stuck_t = 0.0
			strafe = -strafe
			unstick_t = 0.7
			unstick_dir = Vector2(-dir.y, dir.x) * strafe
	else:
		stuck_t = 0.0
	_last_pos = position

# 기술을 실제로 쓴다. 근접기는 동작이 끝날 때까지 제자리, 그 뒤 잠깐 쉰다(피하고 때릴 틈).
func _fire(move_id: String, dir: Vector2, world) -> void:
	if para_lock_t > 0.0 or world.full_paralysis(self):   # 마비: 25% 로 몸이 저려 기술이 안 나간다(쿨타임도 안 돈다)
		return
	cds[move_id] = MoveDB.cooldown(move_id)
	var mv := MoveDB.get_move(move_id)
	if mv.has("hits"):
		# 연타: 타수를 원작 분포(2·3 각 3/8, 4·5 각 1/8)로 뽑고 첫 타를 바로. 나머지는 think 가 간격마다.
		var r: float = world.rng.randf()
		multi_left = 2 if r < 0.375 else (3 if r < 0.75 else (4 if r < 0.875 else 5))
		multi_move = move_id
		var anim_name := String(mv.get("anim", "Attack"))
		multi_interval = MonSprite.anim_length(_sprites[anim_name]) if _sprites.has(anim_name) else 0.3
		_strike_once(move_id, dir, world)
		return
	facing = dir
	# 던지는 기술(암석봉인)은 상대가 선 자리를 노린다.
	var aim: Vector2 = world.player.position if mv["shape"] == "lob" else position + dir * 100.0
	world.cast(self, move_id, dir, aim)
	play_attack(String(mv.get("anim", "Attack")), 0.0, bool(mv.get("lunge", false)))
	if mv["shape"] == "arc":
		recover_t = attack_anim_t + RECOVER_DURATION

# 연타의 한 타. 마지막 타 뒤에만 멈춤(recover)을 둔다.
func _strike_once(move_id: String, dir: Vector2, world) -> void:
	facing = dir
	world.cast(self, move_id, dir, position + dir * 100.0)
	var mv := MoveDB.get_move(move_id)
	play_attack(String(mv.get("anim", "Attack")), 0.0, bool(mv.get("lunge", false)))
	multi_left -= 1
	multi_t = multi_interval
	if multi_left <= 0:
		multi_move = ""
		recover_t = attack_anim_t + RECOVER_DURATION

# 준비 동작: 웅크린 채 멈춘다. 준비 시간이 0 인 기술은 바로 쓴다.
func _begin_windup(move_id: String, dir: Vector2, world) -> void:
	var wait: float = WINDUP.get(move_id, 0.4)
	vel = Vector2.ZERO
	if wait <= 0.0:
		_fire(move_id, dir, world)
		return
	windup_t = wait
	windup_move = move_id
	windup_dir = dir
	crouch_t = windup_t
	# 돌진 경로의 빨간 예고선은 뺐다(사용자 결정) — 웅크리는 모습만으로 알린다.

func _wander(dt: float, world) -> void:
	wander_t -= dt
	if wander_t <= 0.0:
		wander_t = world.rng.randf_range(0.4, 1.0)
		wander_dir = Vector2.from_angle(world.rng.randf() * TAU)
	vel = wander_dir * move_speed() * 0.6
	facing = wander_dir

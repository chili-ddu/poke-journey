class_name Mon
extends Node2D

var travel_terrain := 0 # 0 land, 1 aquatic wild, 2 surfing player

# 아레나 위의 포켓몬 하나. 플레이어와 적이 같이 쓴다.
# 움직임·충돌·피격 판정은 World 가 일괄로 돌리고, 여기는 상태와 그리기만 갖는다.

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

# 스피드 28까지 기존 저레벨 걷기를 유지하고, 이후 로그 곡선으로 성장 폭을 완화. 상한 없음.
# 현재 데이터 최대: 아이스크 Lv100/IV31 스피드356 → 약131px/s(5.5칸/s), 랭크 보정 전.
const SPEED_BASE := 44.0
const SPEED_PER_STAT := 1.2
const SPEED_CURVE_START := 28.0
const SPEED_CURVE_WIDTH := 14.0
# 원작 '턴'을 실시간으로 옮긴 길이(사용자 결정 2026-10-29: 1.5초 — 내 포켓몬은 0.5초쯤, 적은 3초쯤마다 움직이는 사이 값).
# 턴으로 세는 효과(잠·혼란·난동·비·방어·모으기)와 턴마다 깎이는 피해(독·화상·씨뿌리기)가 모두 이 값을 쓴다.
const TURN := 1.5
# 독·화상·씨뿌리기(사용자 결정 2026-10-29): 원작처럼 한 턴(TURN 초)마다 최대 HP 의 1/8(최소 1)을 한 번에 깎는다.
# 독·화상은 고칠 때까지(해독제·화상치료제·만병통치제·회복약·포켓몬센터), 씨뿌리기는 쓰러지거나 심은 쪽이 쓰러질 때까지
# (사용자 결정 2026-10-29, 고속스핀으로도 벗어남) 계속된다.
# 4세대 원작 값: subscript_poison_damage·subscript_burn_damage 모두 최대 HP ÷ 8, 씨뿌리기도 ÷ 8.
const RESIDUAL_DIV := 8
# 독·화상은 잠가 둔다(사용자 결정 2026-10-29: 걸리면 난이도가 너무 오른다 — 배틀 안·밖 규칙은 나중에 다시 정한다).
# 잠긴 동안은 아무도 걸리지 않는다(독침 30%·불꽃세례 10% 화상·독가루 모두 '효과가 없다'). 계산 코드는 그대로 남겨 둔다.
static var poison_unlocked := false
static var burn_unlocked := false
const FLINCH_DURATION := 0.35
const SLEEP_TURNS := Vector2i(1, 4)      # 4세대 잠: 1~4턴
const CONFUSE_TURNS := Vector2i(1, 4)    # 4세대 혼란: 1~4턴
const RAMPAGE_TURNS := Vector2i(2, 3)    # 꽃잎댄스 난동: 2~3턴
const CONFUSE_SELF_HIT := 0.5            # 4세대: 50% 로 자신을 친다(위력 40, 타입 없음)
const PROTECT_TIME := TURN               # 방어: 한 턴(1.5초) 동안 모든 공격을 막는다(사용자 확인 2026-10-30)
const BIND_TURNS := Vector2i(2, 5)       # 조이기: 4세대 2~5턴, 턴마다 최대 HP 1/16
const BIND_DIV := 16
const HURT_ANIM := 0.25
const KNOCK_DECEL := 900.0        # 밀린 속도가 줄어드는 비율(px/s²) — 미끄러지는 거리 = 속도² ÷ (2 × 이 값)
const RECOVER_DURATION := 0.35
const FAINT_TIME := 1.0       # Fall, then gradually fade before the existing removal time.
const FAINT_FADE_DELAY := 0.15
const PARA_SPEED := 0.25      # 마비: 스피드 1/4(4세대 플래티넘)
const PARA_FAIL := 0.25       # 마비: 기술을 쓰려 할 때 이 확률로 몸이 저려 움직이지 못한다(원작)
const LUNGE_HOLD := 0.1       # 달려드는 근접기가 가장 앞 자세에서 머무는 시간(그 뒤 원래 자세 — 자리는 그만큼 옮겨져 있다)
const DIE_STUN := 0.3         # 특수기에 쓰러지면 경직 자세로 이만큼 버틴 뒤 넘어진다(사용자 결정 2026-10-30)
const GROUND_RATIO := 0.6   # 도트의 발밑 기준점 = 위치에서 반지름 × 이만큼 아래

var species_id := ""
var form_species_id := "" # Wild Transform changes appearance/types, not identity or rewards.
var counter_kind := ""
var counter_t := 0.0
var level := 1
var team := TEAM_ENEMY
var stats := {}
var max_hp := 1
var hp := 1
var radius := 8.0
# 이동 속도는 능력치 그대로 — 종족 보정은 일절 없다(사용자 결정 2026-10-28: 보정이 필요하면 먼저 물어볼 것).
var frozen := false        # 도구 전용(도감 캡처 허수아비를 제자리에 세움). 게임 규칙에는 쓰지 않는다

var vel := Vector2.ZERO
var facing := Vector2.DOWN
var knock := Vector2.ZERO
var dead := false

var invuln_t := 0.0
var hit_visual_t := 0.0
var hit_visual_length := 0.18
var hit_visual_color := Color.WHITE
var hit_visual_direction := Vector2.ZERO
var hit_visual_strength := 0.0
var hit_visual_squash := 0.0
var flash_t := 0.0
var preview_reveal := false # Draw the opening materials behind the opaque monologue.
var release_fx: Fx
var appear := 1.0                # 볼에서 나오는 중(0 = 안 보임 → 1). 1 보다 작으면 하얀 실루엣으로 커진다(원작 볼에서 나올 때처럼)
var lift := 0.0                  # 그림만 위로 띄우는 높이(px). 그림자는 바닥에 남는다(시작 연출의 뛰어내리기)
var burrow := {}                 # 구멍파기(World._burrow): {t, under, sink, move, hit, m, slot}. 비어 있지 않으면 땅속(sink 가 0 이 된 뒤) — 그림자만 그린다
var emote_t := 0.0               # 머리 위 "!"(라이벌이 따라잡을 때 — Npc 와 같은 원작 emoticons 그림). Game 이 줄인다
var burn_t := 0.0           # 화상: 0 보다 크면 걸려 있다(고칠 때까지). burn_acc 는 다음 턴까지 지난 시간
var burn_acc := 0.0
var poison_t := 0.0         # 독: 0 보다 크면 걸려 있다(고칠 때까지)
var para_t := 0.0           # 마비(사용자 결정 2026-11-02: 원작 그대로): 0 보다 크면 걸려 있다(고칠 때까지). 이동 속도 1/4(4세대),
                            # 기술을 쓰려 할 때 25% 로 "몸이 저려서 움직일 수 없다" — 기술이 안 나가고 한 턴(TURN) 동안 기술을 못 쓴다(para_lock_t)
var para_lock_t := 0.0
var poison_acc := 0.0
var slow_t := 0.0
var slow_amount := 0.0
var flinch_t := 0.0
var attack_anim_t := 0.0
var hurt_t := 0.0
var crouch_t := 0.0        # 준비 동작: 웅크린 그림
var faint_t := 0.0         # 쓰러진 뒤 남아 있는 시간(World 가 0 이 되면 치운다)
var glide := {}            # 근접기의 앞으로 미끄러지기 {dir, speed, left}(World._move_mons 가 옮긴다) — 할퀴기·몸통박치기 1칸 전진
var attack_direction := Vector2.ZERO # A committed directional attack never turns its drawn pose midway.
var ramp_n := 0            # 구르기: 3초 안에 이어 쓴 횟수(위력 2^n, 최대 4). ramp_t 가 0 이 되면 처음부터
var ramp_t := 0.0
var ramp_move := ""
var hitstop_t := 0.0       # 히트스톱(사용자 결정 2026-11-02): 맞는 순간 때린 쪽·맞은 쪽만 잠깐 멈춘다(동작·이동·넉백·경직 모두). 섬광만 흐른다
var dying_t := 0.0         # 쓰러지기 전 단계: 물리기면 다 밀려날 때까지, 특수기면 경직 자세로 DIE_STUN 동안. 끝나면 넘어진다(faint_t 가 흐른다)
var recover_t := 0.0       # 공격 뒤 멈춤
var anim_t := 0.0
var _anim_name := ""
var _anim_start := 0.0
var _attack_start := -1.0 # Independent of temporary Hurt/Idle display changes.
const CharmanderMotion = preload("res://scripts/view/charmander_motion.gd")
var _walk_visual_time := 0.0

# 돌진 중이면 { dir, speed, t, move, hit_ids, hit }
var dash := {}

var _sprites := {}
var trail: Array = []       # 돌진 잔상 위치(월드 좌표)
var last_volley := 0         # 마지막으로 맞은 연발 묶음 번호(불꽃세례 셋 = 한 번만 맞는다)
var def_stage := 0           # 방어 단계(단단해지기). 원작 배율 (2+n)/2, 최대 6
var shine_t := 0.0           # 금속빛 번쩍임(단단해지기의 원작 연출 MetallicShine)
const LANDING_DURATION := 0.15
const LANDING_COMPRESS_TIME := 0.03
var landing_t := 0.0
var hop_t := 0.0             # 점프 동작(Hop) 남은 시간
var eat_t := 0.0             # 먹기(Eat) 동작 남은 시간 — 연출뿐. 움직이면 World 가 0 으로(시트가 없는 종은 0)
var shake_t := 0.0           # 맞은 뒤 좌우로 떨리는 시간(연속찌르기 등, 원작 ShakeMon)
var shake_px := 2.0          # 흔들림 폭(px). 불꽃세례는 원작 Func_Shake extentX 1
var tint_t := 0.0            # 색 물들이기 남은 시간(원작 FadeBattlerSprite: 한 프레임에 한 단계씩 올라갔다 내려옴)
var tint_len := 0.0
var tint_color := Color.RED
var tint_alpha := 0.0        # 물들이는 최대 세기(원작 alpha/16)

# 색 물들이기 시작(불꽃세례: 빨강 10/16, 10프레임 올라가고 10프레임 내려옴).
func start_tint(c: Color, alpha: float, length: float) -> void:
	tint_color = c
	tint_alpha = alpha
	tint_len = length
	tint_t = length

# 지금 물들임 세기(0~tint_alpha, 가운데서 최대).
func tint_weight() -> float:
	if tint_t <= 0.0 or tint_len <= 0.0:
		return 0.0
	var p := 1.0 - tint_t / tint_len
	return tint_alpha * (1.0 - absf(2.0 * p - 1.0))
var atk_stage := 0           # 공격 랭크(-6~6): 울음소리로 내려가고 메탈클로우로 오른다
var spe_stage := 0           # 스피드 랭크(-6~6): 무서운얼굴로 내려간다. 이동 속도에 stage_mult 로 반영
var acc_stage := 0           # 명중률 랭크(-6~6): 연막으로 내려간다. 이 포켓몬의 공격이 빗나갈 확률(stage_acc)
var spa_stage := 0           # 특수공격 랭크: 성장으로 오른다. 특수 기술에 곱한다
var spd_stage := 0           # 특수방어 랭크: 러스터캐논 10% 로 내려간다
var eva_stage := 0           # 회피율 랭크: 달콤한향기로 내려간다. 명중 = 쓰는 쪽 명중 − 맞는 쪽 회피(원작)
var sleep_t := 0.0           # 잠(수면가루): 움직이지도 기술을 쓰지도 못한다. 맞아도 깨지 않는다(원작)
var confuse_t := 0.0         # 혼란(물의파동 20%·꽃잎댄스 뒤): 기술을 쓰려 하면 50% 로 자신을 친다
var leech_t := 0.0           # 씨뿌리기: 0 보다 크면 심겨 있다(쓰러지거나 심은 쪽이 쓰러질 때까지). 빼앗은 HP 는 leech_by 가 회복
var leech_acc := 0.0
var leech_by: Node = null
var bind_t := 0.0            # 조이기: 남은 시간(조인 쪽 bind_by 가 쓰러지면 풀린다)
var bind_acc := 0.0
var bind_by: Node = null
var protect_t := 0.0         # 방어 중(남은 시간)
var protect_chain := 0       # 연달아 성공한 방어 횟수(원작: 연속으로 쓰면 1/2, 1/4 … 로 실패)
var protect_gap := 0.0       # 마지막 방어 뒤 지난 시간(길면 연속이 끊긴다)
var insomnia := false        # 고민씨: 특성이 불면이 되어 잠들지 않는다
var rampage_t := 0.0         # 꽃잎댄스: 난동 남은 시간(그동안 다른 기술을 못 쓰고, 끝나면 혼란)
var stat_overlay: StatOverlay = null   # 능력 변화 연출(몸 안에 흐르는 무늬). setup 에서 붙인다
var sprite_scale := 1.0
var size_tier := 2
var display_span := 22.0
const SCRATCH_REACH_HOLD := 0.10
const SCRATCH_DOWN_HOLD := 0.20
const SCRATCH_SETTLE := 0.10
const SCRATCH_POSE_ORDER := [0, 2, 2, 3, 4, 4, 4, 4, 1]
var attack_full_recovery := false # Scratch retains the authored recovery at the reached position.
var attack_anim := "Attack"  # 지금 재생할 공격 동작 이름
var attack_contact_hold := 0.0  # Grounded contact moves hold their authored impact frame.
var attack_contact_time := 0.0
var attack_lunge := false    # 시트 안의 움직임을 그대로 보여 줄지(할퀴기의 Strike, 몸통박치기의 Attack). 아니면 몸 중심을 발밑에 고정

# 개체 정보(Individual): setup 전에 정해 둔다. 개체값은 능력치마다 0~31, 이로치는 PID 와 트레이너 ID 로 정해진다.
var ivs := {}
var pid := 0
var shiny := false

func setup(id: String, lv: int, t: int) -> void:
	species_id = id
	form_species_id="";counter_kind="";counter_t=0.0
	team = t
	var sp := SpeciesDB.get_species(id)
	_sprites = MonSprite.load_set(int(sp["dex"]), shiny)
	_apply_species_size(sp)
	if stat_overlay != null:
		stat_overlay.tex = null # Never retain the previous species frame when the new sheet is absent.
	light_mask = Look.UNLIT_MASK          # HD-2D 조명은 포켓몬 도트를 비추지 않는다(바닥만)
	set_level(lv, true)
	if stat_overlay == null:
		stat_overlay = StatOverlay.new()
		add_child(stat_overlay)

func _apply_species_size(species: Dictionary) -> void:
	size_tier=int(species.size_tier)
	display_span=float(species.display_span)
	radius=float(species.radius)
	sprite_scale=PokemonSize.scale_for(species,_sprites)

# 능력 변화 연출(원작 General_StatsChange): "def_up"(단단해지기) / "spe_down"(실뿜기).
func play_stat(kind: String) -> void:
	if stat_overlay != null:
		stat_overlay.pattern_scale = clampf(radius / StatOverlay.GBA_RADIUS, 0.3, 1.0)
		stat_overlay.play(kind)

# 회복 빛(포켓몬센터): 몸에 노란 빛이 위에서 아래로 세 번 흐르고 한 번 번쩍인다(StatOverlay.play_heal). 길이(초)를 돌려준다.
func play_heal_glow() -> float:
	if stat_overlay == null:
		return 0.0
	stat_overlay.body_r = radius
	stat_overlay.play_heal()
	return stat_overlay.heal_length()

# 레벨이 오르면 원작처럼 최대 HP 증가분만큼 현재 HP도 오른다.
func set_level(lv: int, fill: bool = false) -> void:
	var old_max := max_hp
	level = lv
	stats = SpeciesDB.stats_at(species_id, level, ivs)
	max_hp = int(stats["hp"])
	if fill:
		hp = max_hp
	else:
		hp = mini(max_hp, hp + maxi(0, max_hp - old_max))

# 원작 능력치 단계 배율: +1 = 1.5배, +2 = 2배 … +6 = 4배.
# 명중률 랭크 배율(원작): 내려가면 3/(3+n). 공격이 맞을 확률에 곱한다.
static func stage_acc(stage: int) -> float:
	return 3.0 / (3.0 - stage) if stage < 0 else (3.0 + stage) / 3.0

static func stage_mult(stage: int) -> float:
	var s := clampi(stage, -6, 6)
	return (2.0 + s) / 2.0 if s >= 0 else 2.0 / (2.0 - s)

func appearance_id() -> String:
	return form_species_id if not form_species_id.is_empty() else species_id

func types() -> Array:
	return SpeciesDB.get_species(appearance_id())["types"]

# 몸무게(kg, 플래티넘 도감). 넉백 비율에 쓴다(사용자 결정 2026-10-30).
func weight_kg() -> float:
	return float(SpeciesDB.get_species(species_id).get("weight", 10.0))

func display_name() -> String:
	return Lang.species_name(species_id)

func move_speed() -> float:
	if frozen:
		return 0.0
	var spe := maxf(0.0, float(stats["spe"]))
	var growth := spe
	if spe > SPEED_CURVE_START:
		# Value and slope join continuously; larger stats always remain faster.
		growth = SPEED_CURVE_START + SPEED_CURVE_WIDTH * log(1.0 + (spe - SPEED_CURVE_START) / SPEED_CURVE_WIDTH)
	var s: float = SPEED_BASE + growth * SPEED_PER_STAT
	if spe_stage != 0:
		s *= stage_mult(spe_stage)
	if para_t > 0.0:
		s *= PARA_SPEED
	if slow_t > 0.0:
		s *= 1.0 - slow_amount
	return s

# 발(그림자 가운데)이 position 보다 아래로 얼마나 내려와 있는가. 위치 값은 몸 쪽이라, 풀숲처럼 '발이 어느 칸에 있나'는 이걸로 본다.
func feet_offset() -> float:
	if not _sprites.has("Walk"):
		return radius * 0.75 * sprite_scale
	return radius * GROUND_RATIO + (float(_sprites.get("feet_dy", 0.0)) - 1.0) * sprite_scale

func is_dashing() -> bool:
	return not dash.is_empty()

func can_act() -> bool:
	return not dead and flinch_t <= 0.0 and recover_t <= 0.0 and not is_dashing() and sleep_t <= 0.0 and hitstop_t <= 0.0

func hp_ratio() -> float:
	return float(hp) / float(max(1, max_hp))

# 상태 타이머. 화상 피해량을 돌려준다(World 가 HP 에 반영하고 숫자를 띄운다).
func tick_status(dt: float) -> int:
	if attack_anim_t>0.0 and not attack_direction.is_zero_approx():facing=attack_direction
	if hitstop_t > 0.0:
		hitstop_t = maxf(0.0, hitstop_t - dt)
		flash_t = maxf(0.0, flash_t - dt)
		return 0
	anim_t += dt
	var walking_speed := maxf(vel.length(), float(dash.get("speed", 0.0)))
	if uses_motion_polish() and _sprites.has("Walk") and walking_speed >= 2.0:
		# Velocity already includes slow/paralysis/stage modifiers. This clock
		# owns no movement and freezes together with animation during hit-stop.
		var cycles := minf(3.5, walking_speed / (CharmanderMotion.STRIDE_PIXELS * maxf(sprite_scale, 0.01)))
		_walk_visual_time = fposmod(_walk_visual_time + dt * cycles * MonSprite.anim_length(_sprites.Walk), MonSprite.anim_length(_sprites.Walk))
	invuln_t = maxf(0.0, invuln_t - dt)
	counter_t=maxf(0.0,counter_t-dt)
	flash_t = maxf(0.0, flash_t - dt)
	slow_t = maxf(0.0, slow_t - dt)
	flinch_t = maxf(0.0, flinch_t - dt)
	if attack_anim_t > 0.0 and attack_anim_t - dt <= 0.0 and attack_lunge and _sprites.has(attack_anim):
		# 달려든 동작이 끝나는 순간: 몸이 나가 있던 만큼 자리를 옮겨 그 자리에 선다(벽이면 거기까지).
		var an: Dictionary = _sprites[attack_anim]
		var row := MonSprite.row_for(an, facing)
		var off := MonSprite.lunge_offset(an, row, MonSprite.lunge_mid(an, row)) * sprite_scale
		# 바라보는 쪽으로 나간 만큼만(할퀴기처럼 몸을 숙이는 아래 성분은 자세일 뿐이라 빼고).
		var fwd := facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN
		var ahead := maxf(0.0, off.dot(fwd))
		if ahead > 0.5:
			var owner_world:=get_parent()
			position = owner_world.resolve_melee_advance(self,fwd*ahead) if owner_world!=null and owner_world.has_method("resolve_melee_advance") else Arena.resolve(position + fwd * ahead, radius)
	attack_anim_t = maxf(0.0, attack_anim_t - dt)
	if attack_anim_t<=0.0:attack_direction=Vector2.ZERO
	crouch_t = maxf(0.0, crouch_t - dt)
	recover_t = maxf(0.0, recover_t - dt)
	hurt_t = maxf(0.0, hurt_t - dt)
	shine_t = maxf(0.0, shine_t - dt)
	hop_t = maxf(0.0, hop_t - dt)
	landing_t = maxf(0.0, landing_t - dt)
	hit_visual_t = maxf(0.0, hit_visual_t - dt)
	eat_t = maxf(0.0, eat_t - dt)
	shake_t = maxf(0.0, shake_t - dt)
	if shake_t <= 0.0:
		shake_px = 2.0
	tint_t = maxf(0.0, tint_t - dt)
	confuse_t = maxf(0.0, confuse_t - dt)
	protect_t = maxf(0.0, protect_t - dt)
	protect_gap += dt
	ramp_t = maxf(0.0, ramp_t - dt)
	para_lock_t = maxf(0.0, para_lock_t - dt)
	if sleep_t > 0.0:
		sleep_t = maxf(0.0, sleep_t - dt)
		vel = Vector2.ZERO
	if stat_overlay != null:
		stat_overlay.step(dt)
	knock = knock.move_toward(Vector2.ZERO, KNOCK_DECEL * dt)
	var dmg := 0
	# 독·화상·씨뿌리기: 걸린 뒤 한 턴마다 최대 HP 의 1/8 을 한 번에.
	if burn_t > 0.0:
		burn_acc += dt
		if burn_acc >= TURN:
			burn_acc -= TURN
			dmg += residual()
	if poison_t > 0.0:
		poison_acc += dt
		if poison_acc >= TURN:
			poison_acc -= TURN
			dmg += residual()
	if bind_t > 0.0:
		bind_t = maxf(0.0, bind_t - dt)
		bind_acc += dt
		if bind_acc >= TURN:
			bind_acc -= TURN
			dmg += maxi(1, max_hp / BIND_DIV)
	leech_drained = 0
	if leech_t > 0.0:
		leech_acc += dt
		if leech_acc >= TURN:
			leech_acc -= TURN
			leech_drained = mini(residual(), hp)
			dmg += leech_drained
	return dmg

# 독·화상·씨뿌리기 한 번 피해(원작: 최대 HP ÷ 8, 최소 1).
func residual() -> int:
	return maxi(1, max_hp / RESIDUAL_DIV)

# 독·화상·씨뿌리기를 새로 건다(다음 턴 셈은 처음부터).
func inflict(kind: String) -> void:
	if (kind == "poison" and not poison_unlocked) or (kind == "burn" and not burn_unlocked):
		return
	match kind:
		"poison":
			poison_t = 1.0
			poison_acc = 0.0
		"burn":
			burn_t = 1.0
			burn_acc = 0.0
		"paralyze":
			para_t = 1.0
		"leech":
			leech_t = 1.0
			leech_acc = 0.0

var leech_drained := 0       # 이번 틱에 씨뿌리기로 빼앗긴 HP(World 가 leech_by 를 회복)

# 고칠 때까지 남는 상태이상 이름(저장·지도 이동용). 없으면 "".
func status_name() -> String:
	if para_t > 0.0:
		return "paralyze"
	if poison_t > 0.0:
		return "poison"
	if burn_t > 0.0:
		return "burn"
	return ""

func set_status(name: String) -> void:
	para_t = 0.0
	poison_t = 0.0
	burn_t = 0.0
	if name != "":
		inflict(name)

# 랭크 변화를 모두 0 으로(원작: 배틀이 끝나면 초기화). 바뀐 게 있었으면 true.
func reset_stages() -> bool:
	var had := atk_stage != 0 or def_stage != 0 or spe_stage != 0 or acc_stage != 0 or spa_stage != 0 or spd_stage != 0 or eva_stage != 0
	atk_stage = 0
	def_stage = 0
	spe_stage = 0
	acc_stage = 0
	spa_stage = 0
	spd_stage = 0
	eva_stage = 0
	return had

func is_asleep() -> bool:
	return sleep_t > 0.0

# 먹기: Eat 동작을 한 번 재생한다(시트가 없으면 아무것도 안 함).
func play_eat() -> void:
	eat_t = MonSprite.anim_length(_sprites["Eat"]) if _sprites.has("Eat") else 0.0

# 점프: Hop 동작을 한 번(시트 길이만큼) 재생한다.
func play_hop() -> void:
	landing_t = 0.0
	hop_t = MonSprite.anim_length(_sprites["Hop"]) if _sprites.has("Hop") else 0.0

# 공격 동작을 한 번 재생한다. 원하는 동작(Strike 등)이 없으면 Attack, 그것도 없으면 0.25초만 표시.
func play_attack(name: String = "Attack", hold: float = 0.0, lunge: bool = false) -> void:
	_attack_start = anim_t
	eat_t = 0.0   # 기술을 쓰면 먹기 동작은 바로 풀린다
	attack_anim = name if _sprites.has(name) else "Attack"
	attack_full_recovery = attack_full_recovery and attack_anim == "Strike"
	attack_lunge = (lunge or name == "Strike") and not attack_full_recovery
	if hold > 0.0:
		attack_anim_t = hold   # Charge 처럼 정해진 시간 동안 되풀이하는 동작
	else:
		attack_anim_t = MonSprite.anim_length(_sprites[attack_anim]) if _sprites.has(attack_anim) else 0.25
		# 달려드는 근접기: 가장 앞으로 나간 프레임에서 LUNGE_HOLD 만 머물고 끝낸다(사용자 2026-11-02: 할퀸 뒤 0.2초 넘게 굳어 있어 어색).
		var tm := lunge_timing(attack_anim)
		if attack_lunge and not attack_full_recovery and tm.y > 0.0:
			attack_anim_t = minf(attack_anim_t, tm.y + LUNGE_HOLD)

	if attack_contact_hold > 0.0 and hold <= 0.0:
		attack_lunge = false
		attack_contact_time = minf(attack_contact_time, maxf(0.0, attack_anim_t - 1.0 / 60.0))
		attack_anim_t += attack_contact_hold
	if attack_full_recovery:
		attack_anim_t += scratch_hold_time() + (SCRATCH_SETTLE if species_id == "charmander" else 0.0)

func scratch_hold_time() -> float:
	return SCRATCH_DOWN_HOLD if species_id == "charmander" else SCRATCH_REACH_HOLD

# Hold the low follow-through pose before playing the remaining authored recovery.
func attack_sheet_time(elapsed: float) -> float:
	if attack_contact_hold > 0.0:
		return elapsed if elapsed < attack_contact_time else maxf(attack_contact_time, elapsed - attack_contact_hold)
	if not attack_full_recovery or not _sprites.has(attack_anim): return elapsed
	var anim: Dictionary = _sprites[attack_anim]
	var row := MonSprite.row_for(anim, facing)
	var hit := MonSprite.lunge_hit_frame(anim, row, facing.normalized())
	var reach := MonSprite.frame_start(anim, 4 if species_id == "charmander" and anim["durations"].size() == 9 else hit)
	return elapsed if elapsed < reach else maxf(reach, elapsed - scratch_hold_time())

# Lift -> downward strike -> low follow-through. Never replay the raised-arm
# anticipation frames during recovery. The last stance rises from a low settle.
func attack_pose_frame(source_frame: int) -> int:
	if not _scratch_downstroke(): return source_frame
	return SCRATCH_POSE_ORDER[clampi(source_frame, 0, 8)]

# Rendering clocks never alter action locks, hit delays, or hurt duration.
# Resuming after Hurt must not replay an attack's anticipation from frame zero.
func attack_visual_elapsed() -> float:
	return maxf(0.0, anim_t - (_attack_start if _attack_start >= 0.0 else _anim_start))

func hurt_sheet_time(elapsed: float) -> float:
	if not _sprites.has("Hurt"): return elapsed
	var length := MonSprite.anim_length(_sprites.Hurt)
	return maxf(elapsed, 0.0) * length / maxf(HURT_ANIM, length)

func _scratch_downstroke() -> bool:
	return attack_full_recovery and attack_anim == "Strike" and species_id == "charmander" and _sprites.has("Strike") and _sprites["Strike"]["durations"].size() == 9

func attack_settle_scale(sheet_time: float) -> Vector2:
	if not _scratch_downstroke(): return Vector2.ONE
	var anim: Dictionary = _sprites["Strike"]
	var start := MonSprite.frame_start(anim, 8)
	if sheet_time < start: return Vector2.ONE
	var duration := MonSprite.anim_length(anim) - start + SCRATCH_SETTLE
	var rise := smoothstep(0.0, 1.0, clampf((sheet_time - start) / duration, 0.0, 1.0))
	return Vector2(lerpf(1.04, 1.0, rise), lerpf(0.86, 1.0, rise))

# 달려드는 동작의 박자(초): x = 몸이 앞으로 나가기 시작하는 시각, y = 앞으로 다 나간 시각(맞는 순간). 도트가 없으면 (-1, -1).
func lunge_timing(anim_name: String) -> Vector2:
	if not _sprites.has(anim_name):
		return Vector2(-1, -1)
	var an: Dictionary = _sprites[anim_name]
	var row := MonSprite.row_for(an, facing)
	var mid := MonSprite.lunge_mid(an, row)
	if mid <= 0:
		return Vector2(-1, -1)
	var fwd := facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN
	var hit := MonSprite.lunge_hit_frame(an, row, fwd)
	return Vector2(MonSprite.frame_start(an, mini(MonSprite.lunge_start(an, row, fwd), hit)), MonSprite.frame_start(an, hit))

func _process(_dt: float) -> void:
	queue_redraw()
	if stat_overlay != null:
		stat_overlay.queue_redraw()
	_step_tail_light()

var _tail_light: PointLight2D = null
var _tail_halo: Sprite2D = null

# HD-2D 느낌(Look): 꼬리에 불이 있는 종은 꼬리불이 빛난다 — 빛은 꼬리 끝에만 모은다(사용자 2026-11-02: 처음엔 몸 뒤에 넓게 둬서
# 몸 둘레·바닥 전체가 밝아졌다). 자리는 지금 프레임에서 꼬리불 픽셀이 모인 곳(Look.flame_point), 작은 빛무리 + 좁은 조명.
func _step_tail_light() -> void:
	if not Look.TAIL_FLAME.has(appearance_id()):
		if _tail_light != null: _tail_light.visible = false
		if _tail_halo != null: _tail_halo.visible = false
		return
	if _tail_light == null:
		_tail_light = Look.make_light(Color(1.0, 0.62, 0.28), 0.9, radius * 2.2)
		add_child(_tail_light)
		_tail_halo = Sprite2D.new()
		_tail_halo.texture = Fx.sheet("g4_glow")
		_tail_halo.material = Look.additive()
		_tail_halo.light_mask = Look.UNLIT_MASK
		add_child(_tail_halo)
	var so := stat_overlay
	var flame := Look.flame_point(so.tex, so.src) if so != null else Vector2(-1, -1)
	var on := Look.hd2d() and visual_appear() > 0.0 and not dead and burrow.is_empty() and flame.x >= 0.0
	_tail_light.visible = on
	_tail_halo.visible = on and _tail_halo.texture != null
	if not on:
		return
	var at: Vector2 = so.xform * (so.dst.position + flame)
	_tail_light.position = at
	_tail_light.energy = (0.85 + 0.12 * sin(anim_t * 9.0) + 0.05 * sin(anim_t * 23.0)) * Look.light_gain()
	_tail_halo.position = at
	var hs := (7.0 + 0.8 * sin(anim_t * 11.0)) / 32.0
	_tail_halo.scale = Vector2(hs, hs)
	_tail_halo.modulate = Color(1.0, 0.6, 0.2, 0.55)

# 쓰러진 뒤: 시간을 흘리고, 다 되면 World 가 치운다.
func tick_faint(dt: float) -> void:
	if hitstop_t > 0.0:            # 마무리 타의 히트스톱: 밀려나기·넘어지기도 그만큼 멈췄다 이어진다
		hitstop_t = maxf(0.0, hitstop_t - dt)
		flash_t = maxf(0.0, flash_t - dt)
		return
	anim_t += dt
	if dying_t > 0.0:
		# 맞은 기세대로 밀려나는 동안(또는 굳은 채로) 아직 서 있다. 다 밀리면 그 자리에서 넘어진다.
		dying_t = maxf(0.0, dying_t - dt)
		if knock != Vector2.ZERO:
			position = Arena.resolve(position + knock * dt, radius)
			knock = knock.move_toward(Vector2.ZERO, KNOCK_DECEL * dt)
		if dying_t <= 0.0:
			knock = Vector2.ZERO
		return
	faint_t = maxf(0.0, faint_t - dt)

func visual_appear() -> float:
	return 0.6 if preview_reveal else appear

func _draw() -> void:
	if get_meta("lapras_carrier",false):return
	if dead and dying_t <= 0.0:
		_draw_fainted()
		return
	if visual_appear() <= 0.0:
		return
	# 구멍파기로 땅속에 있는 동안은 그림자만(흙 알갱이 연출은 World).
	if not burrow.is_empty() and float(burrow.get("sink", 0.0)) <= 0.0:
		draw_set_transform(Vector2(0, feet_offset()), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO)
		return
	# 깜빡임: 무적 중인 플레이어는 반짝인다. 점프(돌진 0.2초 + Hop 동작 0.4초) 동안은 깜빡이지 않는다 —
	# 돌진이 끝난 뒤 남는 무적 0.06초가 Hop 최고점에서 깜빡여 보였다(사용자).
	if team == TEAM_PLAYER and invuln_t > 0.0 and not is_dashing() and hop_t <= 0.0 and burrow.is_empty() and int(anim_t * 20.0) % 2 == 0:
		return      # (구멍파기로 가라앉는 동안은 무적이어도 깜빡이지 않는다)
	var has_sheet := _sprites.has("Walk")
	# 도트는 몸 중심을 ground 에 놓고, 그림자는 그보다 발끝만큼(feet_dy) 아래에 깐다.
	var ground := Vector2(0,radius*GROUND_RATIO if has_sheet else feet_offset())
	var shadow_at := ground + Vector2(0, (float(_sprites.get("feet_dy", 0.0)) - 1.0) * sprite_scale) if has_sheet else ground
	shadow_at += _lunge_shift()      # 달려드는 동안 그림자도 몸을 따라간다(사용자 지적 2026-10-30) — 끝나면 자리가 그만큼 옮겨져 이어진다
	draw_set_transform(shadow_at, 0.0, Vector2(1.0, 0.4))
	var height_weight := clampf(visual_shadow_height() / Arena.TILE, 0.0, 1.0)
	if not has_meta("lapras_ride"):
		draw_circle(Vector2.ZERO, radius * minf(visual_appear(), 1.0) * lerpf(1.0, 0.55, height_weight),
			Color(0, 0, 0, lerpf(0.28, 0.096, height_weight)))
	draw_set_transform(Vector2.ZERO)
	if has_sheet:
		# 잔상은 기술 돌진(불꽃엄니 등)과 회피에만. 점프(Hop)는 원작 도트 그대로 — 잔상 없음(사용자).
		if is_dashing() and (String(dash.get("move", "")) != "" or dash.get("trail", false)) and _sprites.has("Walk"):
			_draw_trail(ground)
		_draw_sheet(ground - Vector2(0, lift))
		if emote_t > 0.0:
			_draw_emote(ground)
	else:
		draw_set_transform(command_feedback_offset()-Vector2(0,lift),0.0,Vector2.ONE*sprite_scale)
		_draw_placeholder()
		draw_set_transform(Vector2.ZERO)
		if flash_t > 0.0:
			draw_circle(Vector2(0, -radius * 0.2), radius * 1.05, Color(1, 1, 1, 0.65 * flash_t / 0.12))
	if def_stage > 0:
		draw_arc(Vector2(0, -radius * 0.2), radius * 1.15, 0.0, TAU, 16, Color(0.85, 0.9, 1.0, 0.12 + 0.08 * def_stage), 1.5)
	if burn_t > 0.0 and int(anim_t * 8.0) % 2 == 0:
		draw_circle(Vector2(radius * 0.6, -radius * 1.1), 2.0, Color("ff7a2a"))
	if poison_t > 0.0 and int(anim_t * 6.0) % 2 == 1:
		draw_circle(Vector2(-radius * 0.6, -radius * 1.1), 2.0, Color("b060e0"))
	if para_t > 0.0 and int(anim_t * 5.0) % 3 == 0:
		# 마비: 노란 불꽃이 몸 둘레에서 지직거린다(원작 상태 아이콘 대신).
		var sp := Fx.sheet("g4_tw_bolt_a")
		if sp != null:
			var k := float(int(anim_t * 5.0) % 2) * 2.0 - 1.0
			draw_set_transform(Vector2(k * radius * 0.7, -radius * 0.6), 0.0, Vector2(0.28, 0.28))
			draw_texture(sp, -Vector2(sp.get_width(), sp.get_height()) / 2.0, Color(1.0, 0.95, 0.2, 0.9))
			draw_set_transform(Vector2.ZERO)

# 쓰러짐. PMD 의 Trip(넘어짐)이 있으면 그걸 한 번 재생하고 마지막 프레임에 멈춘다. 없으면 Sleep(누워 잠, 모든 종에 있음)을
# 되풀이한다(사용자 결정). 둘 다 없는 종은 피격 마지막 프레임을 옆으로 눕혀(90°) 대신한다. 넘어지기 시작한 뒤 서서히 투명해진다.
func faint_alpha() -> float:
	if not dead or dying_t>0.0: return 1.0
	var elapsed := FAINT_TIME-faint_t
	return 1.0-smoothstep(FAINT_FADE_DELAY,FAINT_TIME,elapsed)

func _draw_fainted() -> void:
	var alpha := faint_alpha()
	if not _sprites.has("Walk"):
		draw_set_transform(Vector2(0,feet_offset()),0.0,Vector2(1.0,0.4))
		draw_circle(Vector2.ZERO,radius*0.95,Color(0,0,0,0.28*alpha))
		draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE*sprite_scale)
		draw_circle(Vector2(0,-radius*0.2),radius,Color(SpeciesDB.get_species(species_id)["color"],alpha))
		draw_set_transform(Vector2.ZERO)
		return
	var ground := Vector2(0, radius * GROUND_RATIO)
	draw_set_transform(ground + Vector2(0, (float(_sprites.get("feet_dy", 0.0)) - 1.0) * sprite_scale), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius * 0.95, Color(0, 0, 0, 0.28 * alpha))
	draw_set_transform(Vector2.ZERO)
	var elapsed := FAINT_TIME - faint_t
	var fall := "Trip" if _sprites.has("Trip") else ("Sleep" if _sprites.has("Sleep") else "")
	if fall != "":
		var anim: Dictionary = _sprites[fall]
		var fw: int = anim["fw"]
		var fh: int = anim["fh"]
		var row := MonSprite.row_for(anim, facing)
		var frame := MonSprite.frame_at(anim, elapsed, fall == "Sleep")
		var visual := MonSprite.display_frame(anim, row, elapsed, fall == "Sleep", frame)
		var center := MonSprite.anchor_of(_sprites, anim)
		draw_set_transform(ground, 0.0, Vector2(sprite_scale, sprite_scale))
		draw_texture_rect_region(visual.tex, Rect2(-center, Vector2(fw, fh)),
			visual.src, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO)
		# 3D 화면(View3D)도 이 프레임을 세운다 — 넘기지 않아 3D 에선 마지막 피격 자세로 흐려지기만 하고 넘어지지 않았다(사용자 2026-11-02).
		_remember_frame(visual.tex, Rect2(-center, Vector2(fw, fh)), visual.src,
			Transform2D(0.0, Vector2(sprite_scale, sprite_scale), 0.0, ground))
		return
	var anim: Dictionary = _sprites["Hurt"] if _sprites.has("Hurt") else _sprites["Walk"]
	var fw: int = anim["fw"]
	var fh: int = anim["fh"]
	var row := MonSprite.row_for(anim, facing)
	var frame: int = anim["durations"].size() - 1
	var center := MonSprite.anchor_of(_sprites, anim)
	# 바라보던 쪽으로 넘어진다. 처음 0.15초 동안 기울어지고 조금 가라앉는다.
	var k := clampf(elapsed / 0.15, 0.0, 1.0)
	var side := -1.0 if facing.x < 0.0 else 1.0
	draw_set_transform(ground + Vector2(0, radius * 0.25 * k), side * PI / 2.0 * k, Vector2(sprite_scale, sprite_scale))
	draw_texture_rect_region(anim["tex"], Rect2(-center, Vector2(fw, fh)),
		Rect2(frame * fw, row * fh, fw, fh), Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)
	_remember_frame(anim["tex"], Rect2(-center, Vector2(fw, fh)), Rect2(frame * fw, row * fh, fw, fh),
		Transform2D(side * PI / 2.0 * k, Vector2(sprite_scale, sprite_scale), 0.0, ground + Vector2(0, radius * 0.25 * k)))

# 돌진 잔상. trail 은 World 가 돌진 중 매 걸음 넣어 준다.
func _draw_trail(ground: Vector2) -> void:
	var anim: Dictionary = _sprites["Walk"]
	var fw: int = anim["fw"]
	var fh: int = anim["fh"]
	var row := MonSprite.row_for(anim, facing)
	var src := Rect2(0, row * fh, fw, fh)
	var center := MonSprite.anchor_of(_sprites, anim)
	var n := trail.size()
	for i in n:
		var p: Vector2 = trail[i] - position
		var a := 0.12 + 0.25 * float(i + 1) / float(n)
		draw_set_transform(p + ground, 0.0, Vector2(sprite_scale, sprite_scale))
		draw_texture_rect_region(anim["tex"], Rect2(-center, Vector2(fw, fh)), src, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)

# 프레임 상자의 기준점(MonSprite.anchor_of)을 ground 에 놓는다.
# 달려드는 근접 동작 중 몸이 앞으로 나가 있는 만큼(바라보는 쪽 성분만, 그림 px). 그림자가 몸을 따라가고, tick_status 가 끝날 때 같은 값으로 자리를 옮긴다.
# 카메라가 따라갈 자리: 달려드는 동안은 앞으로 나가 있는 몸(사용자 요청 2026-10-30: 몸통박치기 때 화면이 자연스럽게).
# 동작이 끝나 자리가 옮겨지는 순간 shift 는 0 이 되고 position 이 그만큼 늘어나 있어 화면이 튀지 않는다.
func cam_anchor() -> Vector2:
	return position + _lunge_shift()

func _lunge_shift() -> Vector2:
	if not attack_lunge or attack_anim_t <= 0.0 or not _sprites.has(attack_anim) or _anim_name != attack_anim:
		return Vector2.ZERO
	var an: Dictionary = _sprites[attack_anim]
	var row := MonSprite.row_for(an, facing)
	var frame := mini(MonSprite.frame_at(an, attack_visual_elapsed(), false), MonSprite.lunge_mid(an, row))
	var off := MonSprite.lunge_offset(an, row, frame) * sprite_scale
	var fwd := facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN
	return fwd * maxf(0.0, off.dot(fwd))

# "!": 톡 튀어나온다(Npc.EMOTE_TIME 동안). 높이는 '내 발끝에 선 사람' 의 "!" 와 같게 — 발을 맞춰 나란히 서면 "!" 도 나란히(사용자 지적 2026-10-30).
static var _emote_tex: Texture2D = null
func _draw_emote(ground: Vector2) -> void:
	if _emote_tex == null:
		_emote_tex = load("res://assets/fx/emote_exclaim.png") if ResourceLoader.exists("res://assets/fx/emote_exclaim.png") else null
		if _emote_tex == null:
			return
	var pop := minf(1.0, (Npc.EMOTE_TIME - emote_t) / 0.12)
	var es := 16.0 * Arena.MAP_SCALE
	var bottom := feet_offset() + (Npc.emote_bottom() - Arena.TILE / 2.0) - lift
	draw_texture_rect(_emote_tex, Rect2(Vector2(-es / 2.0, bottom - es * pop), Vector2(es, es)), false)

# Cosmetic compression only: keep feet fixed and never extend movement/skill locks.
func play_hit_feedback(type: String, category: String, direction: Vector2) -> void:
	hit_visual_squash = 0.0
	hit_visual_length = 0.14 if category=="physical" else 0.22
	hit_visual_t = hit_visual_length
	hit_visual_color = Color(1.65,1.65,1.65)
	if type=="fire": hit_visual_color = Color(1.55,1.1,0.85)
	elif type=="dragon": hit_visual_color = Color(1.25,1.05,1.6)
	hit_visual_direction = direction.normalized()
	hit_visual_strength = 1.6 if category=="physical" else 0.7

func hit_feedback_tint() -> Color:
	var strength := clampf(hit_visual_t/hit_visual_length,0.0,1.0)
	return Color.WHITE.lerp(hit_visual_color,strength*strength)

func hit_feedback_offset() -> Vector2:
	if hit_visual_t<=0.0 or dead: return Vector2.ZERO
	var progress := 1.0-hit_visual_t/hit_visual_length
	return hit_visual_direction*hit_visual_strength*sin(progress*PI)*pow(1.0-progress,2.0)

# Player overrides this for rejected commands. Drawing offsets never move the
# node, camera anchor, collision, or ground shadow.
func command_feedback_offset() -> Vector2:
	return Vector2.ZERO

func hit_feedback_scale() -> Vector2:
	if hit_visual_t <= 0.0 or dead: return Vector2.ONE
	var weight := clampf(hit_visual_t / hit_visual_length, 0.0, 1.0)
	var compression := hit_visual_squash * weight * weight
	return Vector2(1.0 + compression * 0.5, 1.0 - compression)

func landing_scale() -> Vector2:
	if landing_t<=0.0 or hop_t>0.0 or dead: return Vector2.ONE
	return landing_scale_at(LANDING_DURATION - landing_t)

# Fast absorption at foot contact, then a gentler recovery. Feet remain the
# transform pivot in both 2D and 3D; this timer never blocks actions.
static func landing_scale_at(elapsed: float) -> Vector2:
	if elapsed < 0.0 or elapsed >= LANDING_DURATION: return Vector2.ONE
	var weight: float
	if elapsed < LANDING_COMPRESS_TIME:
		weight = 1.0 - pow(1.0 - elapsed / LANDING_COMPRESS_TIME, 3.0)
	else:
		weight = 1.0 - smoothstep(0.0, 1.0, (elapsed - LANDING_COMPRESS_TIME) / (LANDING_DURATION - LANDING_COMPRESS_TIME))
	return Vector2(1.0 + 0.08 * weight, 1.0 - 0.10 * weight)

# Shared by flat and 3D shadows. Hop's height lives inside its sheet, so use
# the same retimed C pose as the body instead of discrete source-key heights.
func visual_shadow_height() -> float:
	var height := maxf(0.0, lift)
	if _anim_name == "Hop" and _sprites.has("Hop"):
		var anim: Dictionary = _sprites.Hop
		var row := MonSprite.row_for(anim, facing)
		var time := MonSprite.hop_sheet_time(anim, anim_t - _anim_start)
		var visual := MonSprite.display_frame(anim, row, time, false)
		var first: Vector2 = anim.centers[row][0]
		height += maxf(0.0, (first.y - (visual.body_center as Vector2).y) * sprite_scale)
	return height

# Grounded attacks share the facing-specific walking origin. Offset markers
# are absolute within each action's box; subtracting only their delta leaves
# the action's initial sideways bias in place (especially the up-facing row).
func grounded_attack_anchor(anim: Dictionary, row: int, visual: Dictionary) -> Vector2:
	var center := MonSprite.anchor_of(_sprites, anim)
	var walk: Dictionary = _sprites.Walk
	var walk_row := mini(row, int(walk.get("rows", 8)) - 1)
	var walk_center: Vector2 = walk.centers[walk_row][0]
	var reference_x := walk_center.x - MonSprite.anchor_of(_sprites, walk).x
	center.x = (visual.body_center as Vector2).x - reference_x
	center.y = MonSprite.visual_bottom(visual) - (float(_sprites.get("feet_dy", 0.0)) - 1.0)
	return center

func uses_motion_polish() -> bool:
	return species_id == "charmander" and not get_meta("legacy_motion", false)

func motion_sheet_time(name: String, elapsed: float) -> float:
	if not uses_motion_polish() or not _sprites.has(name): return elapsed
	if name == "Walk": return _walk_visual_time
	if name == "Idle": return CharmanderMotion.loop_time(_sprites[name], elapsed, CharmanderMotion.IDLE_SECONDS)
	if name == "Charge": return CharmanderMotion.loop_time(_sprites[name], elapsed, CharmanderMotion.CHARGE_SECONDS)
	return elapsed

func _draw_sheet(ground: Vector2) -> void:
	var name := "Walk"
	if sleep_t > 0.0 and _sprites.has("Sleep"):
		name = "Sleep"          # 잠: PMD 의 누워 자는 동작(되풀이)
	elif (flinch_t > 0.0 or hurt_t > 0.0 or dying_t > 0.0) and _sprites.has("Hurt"):
		name = "Hurt"
	elif hop_t > 0.0 and _sprites.has("Hop"):
		name = "Hop"
	elif eat_t > 0.0 and _sprites.has("Eat"):
		name = "Eat"
	elif attack_anim_t > 0.0 and _sprites.has(attack_anim):
		name = attack_anim
	elif (has_meta("lapras_ride") or (vel.length_squared() < 4.0 and not is_dashing())) and _sprites.has("Idle"):
		name = "Idle"
	# 동작이 바뀌면 첫 프레임부터. 공격·피격은 한 번만 재생하고 마지막 프레임에 멈춘다.
	if name != _anim_name:
		_anim_name = name
		_anim_start = anim_t
		if name == "Walk": _walk_visual_time = 0.0
	var anim: Dictionary = _sprites[name]
	var fw: int = anim["fw"]
	var fh: int = anim["fh"]
	var sheet_time := attack_sheet_time(attack_visual_elapsed()) if name == attack_anim and attack_anim_t > 0.0 else anim_t - _anim_start
	# Retiming an idle/charge loop must not change the duration of the action.
	if name in ["Walk", "Idle", "Charge"]:
		sheet_time = motion_sheet_time(name, sheet_time)
	if name == "Hurt": sheet_time = hurt_sheet_time(anim_t - _anim_start)
	if name == "Hop": sheet_time = MonSprite.hop_sheet_time(anim, anim_t - _anim_start)
	var frame := MonSprite.frame_at(anim, sheet_time, (name in ["Walk", "Idle", "Charge", "Sleep", "Dance", "Rotate"] or get_meta("loop_animation", "")==name))
	if name == attack_anim and attack_anim_t > 0.0:
		frame = attack_pose_frame(frame)
	var row := MonSprite.row_for(anim, facing)
	# 달려드는 근접 동작은 가장 앞으로 나간 프레임에서 멈춘다(돌아오는 반은 안 쓴다). 끝나면 tick_status 가 그만큼 자리를 옮긴다.
	if name == attack_anim and attack_lunge and attack_anim_t > 0.0 and not attack_full_recovery:
		frame = mini(frame, MonSprite.lunge_mid(anim, row))
	var last := MonSprite.lunge_mid(anim, row) if name == attack_anim and attack_lunge and attack_anim_t > 0.0 and not attack_full_recovery else -1
	var pose_order: Array = SCRATCH_POSE_ORDER if name == attack_anim and attack_anim_t > 0.0 and _scratch_downstroke() else []
	var display_time := CharmanderMotion.strike_time(anim, sheet_time, false) if uses_motion_polish() and not pose_order.is_empty() else sheet_time
	var visual := MonSprite.display_frame(anim, row, display_time, (name in ["Walk", "Idle", "Charge", "Sleep", "Dance", "Rotate"] or get_meta("loop_animation", "")==name), frame, last, pose_order)
	var src: Rect2 = visual.src
	# 프레임 안의 몸 중심(오프셋 시트)을 발밑에 맞춘다. 뛰어드는 동작은 첫 프레임 기준으로 고정해 시트의 움직임을 살린다.
	# 참고 사이트처럼 프레임 상자를 고정하고 그대로 보여 준다(돌아보기·뛰기·공격의 움직임이 시트대로).
	var center := MonSprite.anchor_of(_sprites, anim)
	if has_meta("lapras_ride"):
		ground+=get_meta("lapras_ride").offset_2d()
		center.y=MonSprite.visual_bottom(visual)-(float(_sprites.get("feet_dy",0.0))-1.0)
	# Real movement owns the step. Anchor the feet, not the torso: normalizing
	# torso Y made crouched/extended frames lift both feet like a jump.
	if ((name == "Strike" and attack_full_recovery) or (name == attack_anim and attack_contact_hold > 0.0)) and attack_anim_t > 0.0:
		center = grounded_attack_anchor(anim, row, visual)
	if get_meta("loop_animation","")==name:
		center=MonSprite.flight_anchor(anim,row,sheet_time,visual)
	elif get_meta("carried",false):
		# Carrying owns the trajectory; the authored attack must not drift sideways.
		center=visual.body_center
	# 웅크리기: 발밑을 축으로 납작하게 누르고 살짝 떤다. 뛰어들기 직전이라는 신호.
	if crouch_t > 0.0:
		var jitter := Vector2(sin(anim_t * 70.0) * 0.8, 0.0)
		var origin := ground + jitter + command_feedback_offset()
		draw_set_transform(origin, 0.0, Vector2(1.14, 0.8) * sprite_scale)
		var dst_c := Rect2(-center, Vector2(fw, fh))
		var tint_c := Color(4, 4, 4, 1) if flash_t > 0.0 else Color.WHITE
		draw_texture_rect_region(visual.tex, dst_c, src, tint_c)
		draw_set_transform(Vector2.ZERO)
		_remember_frame(visual.tex, dst_c, src, Transform2D(0.0, Vector2(1.14, 0.8) * sprite_scale, 0.0, origin))
		return
	# 배율은 발밑(ground)을 축으로. 흔들림(shake_t)은 원작 ShakeMon 처럼 좌우 ±shake_px.
	var shake := Vector2(roundf(sin(anim_t * 60.0) * shake_px), 0.0) if shake_t > 0.0 else Vector2.ZERO
	var sc := sprite_scale * minf(visual_appear(), 1.0)
	var landing := landing_scale() * hit_feedback_scale()
	if uses_motion_polish() and name in ["Idle", "Charge"] and not has_meta("lapras_ride") and not get_meta("carried", false):
		var breathing_time := attack_visual_elapsed() if name == "Charge" and attack_anim_t > 0.0 else anim_t - _anim_start
		landing *= CharmanderMotion.stance_scale(name, breathing_time)
	if name == attack_anim and attack_anim_t > 0.0:
		landing *= attack_settle_scale(sheet_time)
	var body_scale := Vector2(sc,sc)*landing
	var feet := (float(_sprites.get("feet_dy",0.0))-1.0)*sc
	var body_origin := ground+shake+hit_feedback_offset()+command_feedback_offset()+Vector2(0,feet*(1.0-landing.y))
	draw_set_transform(body_origin, 0.0, body_scale)
	var dst := Rect2(-center, Vector2(fw, fh))
	# 맞으면 도트 자체를 하얗게. 1을 넘는 색은 화면 출력에서 잘려 거의 흰색이 된다.
	var tint := hit_feedback_tint() if hit_visual_t>0.0 else Color(4, 4, 4, 1) if flash_t > 0.0 or appear < 1.0 else Color.WHITE
	# 단단해지기: 처음엔 하얗게, 그 뒤 푸르스름한 금속빛이 가라앉는다.
	if shine_t > 0.0 and flash_t <= 0.0:
		var k := clampf(shine_t / 0.6, 0.0, 1.0)
		tint = Color(4, 4, 4, 1) if k > 0.8 else Color(1.0 + 0.6 * k, 1.0 + 0.7 * k, 1.0 + 1.2 * k, 1)
	# 색 물들이기: 원작은 도트 색을 목표색 쪽으로 섞는다(c + (목표 − c)·w). 곱하기 색으로 근사 — 빨강은 밝히고 나머지는 줄인다.
	var w := tint_weight()
	if w > 0.0 and flash_t <= 0.0:
		tint = Color(tint.r * (1.0 + (tint_color.r * 1.6 - 1.0) * w), tint.g * (1.0 + (tint_color.g * 1.6 - 1.0) * w),
			tint.b * (1.0 + (tint_color.b * 1.6 - 1.0) * w), 1)
	if is_instance_valid(release_fx) and not Look.view3d:
		var bounds := MonSprite.release_bounds(visual.tex,Rect2i(src))
		var sole := body_origin+(dst.position+Vector2(bounds.get_center().x,bounds.end.y))*body_scale
		var lip := release_fx.position-position-Vector2.DOWN*5.0*BallRelease.PIXEL*(1.0-smoothstep(0.045,BallRelease.OPEN,release_fx.age))
		draw_set_transform(body_origin+(lip-sole)*(1.0-smoothstep(0.055,0.24,release_fx.age)),0,body_scale)
		draw_texture_rect_region(visual.tex,dst,src,Color.WHITE)
		var strength := BallRelease.strength(release_fx.age)
		if strength > 0.0:
			draw_texture_rect(BallRelease.mask(visual.tex,Rect2i(src)),dst,false,Color(BallRelease.CREAM,strength))
	else:
		draw_texture_rect_region(visual.tex, dst, src, tint)
	draw_set_transform(Vector2.ZERO)
	_remember_frame(visual.tex, dst, src, Transform2D(0.0, body_scale, 0.0, body_origin))

# 방금 그린 프레임을 능력 변화 연출(StatOverlay)이 같은 자리에 무늬로 한 번 더 그릴 수 있게 넘긴다.
func _remember_frame(tex: Texture2D, dst: Rect2, src: Rect2, xf: Transform2D) -> void:
	if stat_overlay == null:
		return
	stat_overlay.tex = tex
	stat_overlay.dst = dst
	stat_overlay.src = src
	stat_overlay.xform = xf

# 도트를 받기 전 자리표시. 몸통 원 + 무늬 + 바라보는 쪽 눈.
func _draw_placeholder() -> void:
	var sp := SpeciesDB.get_species(species_id)
	var body: Color = sp["color"]
	var accent: Color = sp["accent"]
	var r := radius
	var c := Vector2(0, -r * 0.2)
	draw_circle(c, r, body.darkened(0.45))
	draw_circle(c, r - 1.0, body)
	draw_circle(c + Vector2(0, r * 0.35), r * 0.5, accent)
	var f := facing.normalized() if facing.length_squared() > 0.0 else Vector2.DOWN
	var side := Vector2(-f.y, f.x)
	for s in [-1.0, 1.0]:
		var e: Vector2 = c + f * r * 0.45 + side * s * r * 0.35 + Vector2(0, -r * 0.15)
		draw_circle(e, maxf(1.0, r * 0.16), Color.WHITE)
		draw_circle(e + f * 0.6, maxf(0.6, r * 0.09), Color("1d1d26"))
	# 파이리 계열은 꼬리 불꽃으로 구분한다.
	if species_id in ["charmander", "charmeleon", "charizard"]:
		var tail := c - f * (r + 3.0)
		var flick := 1.0 + 0.25 * sin(anim_t * 18.0)
		draw_circle(tail, 3.0 * flick, Color("ff6a1a"))
		draw_circle(tail, 1.6 * flick, Color("ffe066"))

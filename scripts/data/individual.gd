class_name Individual
extends RefCounted

# 포켓몬 한 마리의 개체 정보 — 원작(3·4세대) 방식 그대로(사용자 결정 2026-10-28: 개체값·이로치를 원작과 동일하게).
#   성격값(PID) 32비트와 개체값(IV) 여섯 개를 원작 난수기(LCRNG: seed = seed × 0x41C64E6D + 0x6073)로 뽑는다 — "Method 1"
#   (플래티넘 스타팅·선물 포켓몬과 같은 순서): PID 아래 16비트 → 위 16비트 → IV 묶음 둘(각 15비트 = 5비트 × 3).
#     첫 묶음: HP · 공격 · 방어 / 둘째 묶음: 스피드 · 특공 · 특방. 각 0~31, 고르게.
#   이로치: (트레이너 ID ^ 비밀 ID ^ PID 위 16비트 ^ PID 아래 16비트) < 8 → 확률 8/65536 = 1/8192.
#   (플래티넘 야생은 성격을 먼저 정하는 Method J 지만 이 게임엔 성격이 없어서 PID·IV 분포가 같은 Method 1 하나로 쓴다.)
# 트레이너 ID·비밀 ID 는 새 게임을 시작할 때 한 번 정해 저장한다(SaveData [trainer]). 야생의 이로치 여부도 이 값으로 판정 — 원작처럼.

const SHINY_THRESHOLD := 8

static var tid := 0                 # 트레이너 ID(상태창 IDNo. 에 보인다)
static var sid := 0                 # 비밀 ID(어디에도 안 보인다)
static var force_shiny := false     # 시험 도구(SHINY=1)만 켠다: 새로 뽑는 개체를 모두 이로치로

static func _next(state: Array) -> int:
	state[0] = (int(state[0]) * 0x41C64E6D + 0x6073) & 0xFFFFFFFF
	return int(state[0]) >> 16

# Method 1: {pid, ivs{hp,atk,def,spe,spa,spd}}. seed 는 32비트(rng.randi()).
static func method1(seed_value: int) -> Dictionary:
	var st := [seed_value & 0xFFFFFFFF]
	var lo := _next(st)
	var hi := _next(st)
	var a := _next(st)
	var b := _next(st)
	return {"pid": (hi << 16) | lo,
		"ivs": {"hp": a & 31, "atk": (a >> 5) & 31, "def": (a >> 10) & 31,
			"spe": b & 31, "spa": (b >> 5) & 31, "spd": (b >> 10) & 31}}

static func roll(rng: RandomNumberGenerator) -> Dictionary:
	return method1(rng.randi())

static func shiny_value(pid: int, t: int, s: int) -> int:
	return (t ^ s ^ ((pid >> 16) & 0xFFFF) ^ (pid & 0xFFFF)) & 0xFFFF

static func is_shiny(pid: int) -> bool:
	return force_shiny or shiny_value(pid, tid, sid) < SHINY_THRESHOLD

# 새 트레이너 ID·비밀 ID(각 16비트).
static func new_trainer(rng: RandomNumberGenerator) -> Array:
	return [rng.randi() & 0xFFFF, rng.randi() & 0xFFFF]

class_name MoveShapes
extends RefCounted

# 기술의 "액션 게임 모양". 이름·타입·분류·위력·PP·효과는 플래티넘 데이터(assets/data/moves.json, tools/gen_gen4.py)에서 오고,
# 여기엔 원작에 없는 것만 적는다: 사거리·탄·판정·연출(fx)·쓰는 쪽 도트 동작(anim)·적 쿨타임. MoveDB.get_move 가 둘을 합친다.
# 여기 없는 기술은 MoveDB 가 분류로 기본 모양을 준다(물리 → 몸 옆 1칸 근접, 특수 → 투사체 4칸, 변화 → 효과별).
#
# 거리(range·distance·radius)는 풀숲 한 칸 = T(24px) 단위. 근접(arc)의 range 는 몸 가장자리에서 재는 틈(할퀴기 1칸 = 바로 옆 칸만).
# shape 별 필드
#   arc        근접 부채꼴. range, arc_deg, hit_delay(동작이 닿는 순간), hits(연타 [최소,최대]), knock, invuln
#   projectile 투사체. speed, radius, range, count, spread_deg, pierce
#   burst      같은 방향으로 연사. 위와 같고 + interval, volley(한 묶음 = 한 타), grow(날아가며 커짐)
#   cone       짧은 투사체를 부채꼴로 흩뿌림
#   dash       조준 방향으로 돌진하며 부딪힌 적을 친다. distance, duration
#   zone       조준 지점에 장판. radius, lifetime, slow
#   ring       회전 장판. 회오리불꽃은 착지점 고정. radius, lifetime, tick
#   beam       쏜 자리에서 사거리만큼 늘어나는 선(실뿜기). range, width, grow, lifetime, slow
#   buff       자기 랭크 ↑. stat, stages
#   status_cone 앞 부채꼴의 상대 랭크 변화. range, arc_deg, stat{atk/def/spe: ±n}
# 모으기(charge_turns): 원작 '한 턴 모으기' 기술. MoveDB 가 cast_delay(선딜)에 charge_turns × Mon.TURN 을 더한다.
# 부가: burn·flinch·slow 확률(없으면 플래티넘 effect 에서 MoveDB 가 채운다), crit(급소율), fixed(고정 피해), hit_fx, self_atk_up
# 플레이어 기술은 PP 를 탄창처럼 쓴다: 한 발 간격 USE_DELAY[모양], 재장전 RELOAD_BASE + RELOAD_PER_WEIGHT × 가중치(MoveDB).

const T := 24.0

const SHAPES := {
	# Mainland wild species keep their legal minimum-level attacks.
	"leer": {"shape":"status_cone","range":2*T,"arc_deg":90.0,"stat":{"def":-1},"anim":"Charge","cast_delay":0.3,"cooldown":4.0},
	"headbutt": {"shape":"arc","range":T,"arc_deg":110.0,"anim":"Attack","fx":"bump","hit_delay":0.18,"cooldown":3.2},
	"lick": {"shape":"arc","range":T,"arc_deg":100.0,"anim":"Attack","fx":"lick","hit_delay":0.16,"cooldown":3.2},
	"mud_slap": {"shape":"projectile","range":4*T,"speed":135.0,"radius":5.0,"count":1,"spread_deg":0.0,"pierce":false,"anim":"Shoot","fx":"mud","stat_hit":{"acc":-1},"stat_hit_chance":1.0,"cooldown":3.5},
	"icy_wind": {"shape":"cone","range":4*T,"speed":145.0,"radius":5.0,"count":3,"spread_deg":30.0,"pierce":false,"anim":"Shoot","fx":"ice","stat_hit":{"spe":-1},"stat_hit_chance":1.0,"cooldown":4.0},
	"transform": {"shape":"transform","range":6*T,"anim":"Charge","cast_delay":0.4,"cooldown":5.0},
	"counter": {"shape":"counter","counter_cat":"physical","anim":"Charge","cast_delay":0.15,"cooldown":6.0},
	"mirror_coat": {"shape":"counter","counter_cat":"special","anim":"Charge","cast_delay":0.15,"cooldown":6.0},
	"splash": {"shape":"gesture","anim":"Hop","cooldown":4.0},
	"hypnosis": {"shape":"status_cone","anim":"Charge","cast_delay":0.4,"range":3*T,"arc_deg":75.0,"sleep":1.0,"fx":"noise","cooldown":6.0},
	# 갈색시티까지의 신규 야생 기술. 기존 공통 HD-2D 연출·판정 재사용.
	"peck": {"shape": "arc", "range": 24.0, "arc_deg": 110.0, "anim": "Jab", "fx": "peck", "hit_delay": 0.15, "glide": 10.0, "contact_hold": 0.12, "cooldown": 3.0},
	"pound": {"shape": "arc", "range": 24.0, "arc_deg": 110.0, "anim": "Attack", "fx": "pound", "hit_delay": 0.15, "glide": 12.0, "contact_hold": 0.16, "cooldown": 3.0},
	"astonish": {"shape": "arc", "range": 24.0, "arc_deg": 110.0, "anim": "Attack", "fx": "astonish", "hit_delay": 0.15, "glide": 8.0, "contact_hold": 0.14, "cooldown": 3.0},
	"wrap": {"shape": "arc", "range": 4.0, "arc_deg": 110.0, "anim": "Attack", "fx": "bind", "hit_delay": 0.15, "glide": 8.0, "contact_hold": 0.18, "contact_stop": true, "knock": 0.0, "cooldown": 3.0},
	"fury_swipes": {"shape": "arc", "range": 24.0, "arc_deg": 110.0, "anim": "Strike", "fx": "slash", "hit_delay": 0.15, "hits": [2, 5], "knock": 30.0, "invuln": 0.25, "cooldown": 3.5},
	"absorb": {"shape": "drain", "range": 72.0, "anim": "Charge", "cast_delay": 0.4, "drain": 0.5, "fx": "gigadrain", "cooldown": 3.5},
	"mega_drain": {"shape": "drain", "range": 84.0, "anim": "Charge", "cast_delay": 0.4, "drain": 0.5, "fx": "gigadrain", "cooldown": 3.5},
	"acid": {"shape": "projectile", "range": 96.0, "speed": 135.0, "radius": 5.0, "count": 1, "spread_deg": 0.0, "pierce": false, "anim": "Shoot", "fx": "acid", "cooldown": 3.0},
	"disarming_voice": {"shape": "projectile", "range": 96.0, "speed": 135.0, "radius": 5.0, "count": 1, "spread_deg": 0.0, "pierce": false, "anim": "Shoot", "fx": "voice", "cooldown": 3.0},
	"sing": {"shape": "status_cone", "range": 72.0, "arc_deg": 90.0, "anim": "Charge", "fx": "noise", "cast_delay": 0.4, "cooldown": 6.0},
	"supersonic": {"shape": "status_cone", "range": 72.0, "arc_deg": 90.0, "anim": "Charge", "fx": "noise", "cast_delay": 0.4, "cooldown": 6.0, "confuse": 1.0},

	# ── 파이리 계열(4세대 자력기) ──
	# glide(사용자 요청 2026-11-02): 때리면서 몸이 앞으로 미끄러져 나간다(px). 도트의 달려듦(Strike 11px·Attack 18px)과 합쳐 약 1칸(24px).
	"scratch": {"fx": "claw", "anim": "Strike", "hit_delay": 0.13, "shape": "arc", "range": 1 * T, "arc_deg": 110.0, "glide": 1 * T},
	# 울음소리: 원작 Move_GROWL 의 소음 선이 입에서 퍼지고 맞은 쪽이 떨린 뒤 공격 ↓. 사용자: Charge 동작, 앞 2칸 부채꼴.
	"growl": {"anim": "Charge", "cast_delay": 0.3, "shape": "status_cone", "range": 2 * T, "arc_deg": 90.0, "stat": {"atk": -1}, "fx": "noise"},
	# 입에서 일곱 불씨를 짧게 내뿜는 한 묶음. 전방으로 조금 벌어지고 적 하나에는 한 번만 피해.
	"ember": {"fx": "ember", "anim": "Charge", "cast_delay": 0.15, "shape": "burst", "speed": 150.0, "radius": 3.0, "range": 3 * T,
		"count": 7, "interval": 0.03, "volley": true, "spread_deg": 12.0, "pierce": false, "grow": 1.6},
	# 연막(사용자 결정 2026-10-28): 장판이 아니라 검은 공을 사거리 4칸 안의 조준한 자리(클릭)에 던져 터뜨리고,
	# 떨어진 자리 둘레 1.5칸의 상대 명중률 −1(원작 효과·연출).
	"smoke_screen": {"targeting":"charged_area", "anim": "Charge", "cast_delay": 0.3, "shape": "lob", "range": 4 * T, "radius": 1.5 * T, "stat": {"acc": -1}, "fx": "smoke"},
	# 용의분노: 원작 Move_DRAGON_RAGE — 힘을 모았다가 불씨를 뱉고, 맞은 자리에 불기둥 넷. 항상 40.
	"dragon_rage": {"fixed": 40, "fx": "dragon", "anim": "Charge", "cast_delay": 0.4, "shape": "burst", "speed": 180.0, "radius": 3.0, "range": 4 * T,
		"count": 3, "interval": 4.0 / 60.0, "spread_deg": 0.0, "pierce": false, "volley": true, "grow": 1.6, "hit_fx": "dragonfire"},
	# 무서운얼굴: 원작 Move_SCARY_FACE — 화면이 어두워지고 큰 얼굴, 맞은 쪽이 떨며 스피드 ↓↓.
	"scary_face": {"anim": "Charge", "cast_delay": 0.5, "shape": "status_cone", "range": 2 * T, "arc_deg": 90.0, "stat": {"spe": -2}, "fx": "scaryface"},
	# 불꽃엄니: 조준 방향으로 4칸 달려들어 문다. 돌진 중엔 무적. 화상·풀죽음 10% 는 플래티넘 효과(flinch_burn_hit)에서.
	# 불꽃엄니: 조준 방향으로 4칸 뛰어들어 문다. 맞으면 플래티넘 fire_fang.spa 의 송곳니가 닫히고 불덩이·불길(World.apply_hit 의 fang).
	# 불꽃엄니(사용자 결정 2026-10-28): 돌진이 아니라 Attack 동작(시트 움직임 그대로)으로 반 칸 앞으로 나서며 앞 1.5칸을 문다. 맞으면 송곳니·불.
	"fire_fang": {"fx": "fang", "anim": "Attack", "lunge": true, "hit_delay": 0.2, "shape": "arc", "range": 1.5 * T, "arc_deg": 120.0, "step": 0.5 * T},
	"slash": {"fx": "slash", "anim": "Strike", "hit_delay": 0.13, "shape": "arc", "range": 1.5 * T, "arc_deg": 170.0},
	# 화염방사(사용자 결정 2026-10-28): 열 발이 조준을 따라 연사되지만 한 묶음이 한 타(one_hit), 관통, 사거리 4칸.
	"flamethrower": {"fx": "flame", "shape": "burst", "speed": 200.0, "radius": 5.0, "range": 4 * T,
		"count": 10, "interval": 0.04, "spread_deg": 6.0, "pierce": true, "one_hit": true},
	# 회오리불꽃: 시전 순간만 Charge 동작(0.3초 모은 뒤 고리가 생김), 고리가 도는 동안은 평소 동작(사용자 결정 2026-10-28).
	"fire_spin": {"targeting":"charged_area","anim":"Charge","cast_delay":.3,"shape":"ring","zone_kind":"fire_spin","range":3*T,"radius":23.0,"lifetime":4*Mon.TURN,"tick":Mon.TURN,"bind":false},
	"flare_blitz": {"shape":"dash","distance":66.0,"duration":.32,"anim":"Attack","cast_delay":.20,"lunge":false},
	# 메탈클로우(4세대 자력엔 없지만 기술머신·가르침으로 올 수 있어 모양은 둔다): 금속 번쩍임 뒤 발톱 자국 두 번, 10% 자기 공격 ↑.
	"metal_claw": {"fx": "metal", "anim": "Strike", "hit_delay": 0.13, "shape": "arc", "range": 1 * T, "arc_deg": 110.0, "self_atk_up": 0.1},

	# ── 이상해씨 계열(플래티넘 자력기, 사용자 요청 2026-10-28) ──
	# 씨뿌리기: 씨앗 셋이 포물선으로 조준한 자리에 떨어지고(원작 leech_seed 의 bullet_seed 구슬) 둘레 1칸의 상대에 싹이 튼다.
	# 4초 동안 초당 최대 HP 1/8 을 빼앗아 쓴 쪽이 회복(풀 타입은 안 걸림).
	"leech_seed": {"targeting":"charged_area", "anim": "Shoot", "cast_delay": 0.2, "shape": "lob", "range": 4 * T, "radius": 1.0 * T, "fx": "leechseed"},
	# 덩굴채찍: 앞 1.5칸을 채찍질(Double 동작). 맞은 자리에 초록 채찍 자국 둘(vine_whip.spa 초승달).
	"vine_whip": {"anim": "Double", "fx": "vine", "hit_delay": 0.15, "shape": "arc", "range": 1.5 * T, "arc_deg": 110.0},
	# 독가루·수면가루: 앞 2칸 부채꼴에 가루가 흩날리고(원작 가루 5알, 보라 / 청록) 닿은 상대는 독 / 잠(1~4초).
	# Preserve their established cadence/AI class; charged_area changes the actual footprint to a ground circle.
	"poison_powder": {"targeting":"charged_area", "radius":T, "anim": "Charge", "cast_delay": 0.3, "shape": "status_cone", "range": 2 * T, "arc_deg": 90.0, "fx": "powder_poison"},
	"sleep_powder": {"targeting":"charged_area", "radius":T, "anim": "Charge", "cast_delay": 0.3, "shape": "status_cone", "range": 2 * T, "arc_deg": 90.0, "fx": "powder_sleep"},
	# 돌진: 조준 방향으로 3칸 들이받는다. 준 피해의 1/4 반동.
	"take_down": {"anim": "Attack", "shape": "dash", "distance": 3 * T, "duration": 0.25, "fx": "takedown"},
	# 잎날가르기: 잎 두 장이 부채꼴로 날아간다(한 묶음 한 타, 급소 1/8).
	"razor_leaf": {"fx": "leaf", "anim": "Shoot", "shape": "burst", "speed": 190.0, "radius": 4.0, "range": 4 * T,
		"count": 2, "interval": 0.06, "spread_deg": 24.0, "pierce": false, "volley": true},
	# 달콤한향기(사용자 결정 2026-10-29): 분홍 향기와 꽃잎이 몸 둘레 2.5칸 원으로 퍼져 회피율 −1. 바깥 풀숲에서 쓰면
	# 10초 동안 야생 출현 확률 2배, 야생이 하나도 없으면 원작처럼 바로 한 마리(Game._on_lured).
	"sweet_scent": {"anim": "Dance", "cast_delay": 0.3, "shape": "status_cone", "range": 2.5 * T, "arc_deg": 360.0, "stat": {"eva": -1},
		"fx": "sweetscent", "lure": true},
	# 성장: 몸이 커졌다 돌아오며(원작 Func_Growth) 특수공격 +1.
	"growth": {"anim": "Charge", "shape": "buff", "stat": "spa", "stages": 1, "fx": "growth"},
	# 이판사판태클: 4칸 들이받는다. 준 피해의 1/3 반동.
	"double_edge": {"anim": "Attack", "shape": "dash", "distance": 4 * T, "duration": 0.3, "fx": "doubleedge"},
	# 고민씨: 씨앗 하나가 포물선으로 떨어져 둘레 1칸 상대의 특성이 불면(잠들지 않고, 자고 있으면 깬다).
	"worry_seed": {"targeting":"charged_area", "anim": "Shoot", "cast_delay": 0.2, "shape": "lob", "range": 4 * T, "radius": 1.0 * T, "fx": "worryseed"},
	# 광합성: 빛줄기가 내려와 최대 HP 의 1/2 회복(비가 오면 1/4 — 원작).
	"low_kick": {"anim":"Attack", "shape":"arc", "range":T, "arc_deg":100.0, "hit_delay":0.15, "cooldown":3.0},
	"confusion": {"anim":"Shoot", "cast_delay":0.3, "cooldown":3.0, "shape":"projectile", "speed":150.0, "radius":5.0, "range":4*T, "count":1, "spread_deg":0.0, "pierce":false},
	"recover": {"anim":"Charge", "cast_delay":0.4, "cooldown":8.0, "shape":"heal", "heal":0.5},
	"teleport": {"anim":"Charge", "cast_delay":0.35, "cooldown":5.0, "shape":"teleport", "range":3*T},
	"synthesis": {"anim": "Charge", "cast_delay": 0.4, "shape": "heal", "heal": 0.5, "fx": "synthesis"},
	# 씨폭탄: 씨앗 구슬이 포물선으로 떨어져 둘레 1칸에 터진다(물리 80).
	"seed_bomb": {"targeting":"charged_area", "anim": "Shoot", "cast_delay": 0.15, "shape": "lob", "range": 4 * T, "radius": 1.0 * T, "fx": "seedbomb"},
	# 솔라빔: 선딜 0.25초 + 한 턴(Mon.TURN) 빛을 모았다가(사용자 결정 2026-10-29) 6칸 빛줄기. 관통. 비가 오면 위력 절반(원작).
	"solar_beam": {"anim": "Charge", "cast_delay": 0.25, "charge_turns": 1, "shape": "beam", "range": 6 * T, "width": 6.0, "grow": 0.1, "lifetime": 0.5, "fx": "solar"},
	# 꽃잎댄스: 2~3초 동안 꽃잎이 몸 둘레를 돌며 닿는 상대를 친다(그동안 다른 기술 못 씀). 끝나면 지쳐서 혼란.
	"petal_dance": {"anim": "Dance", "fx": "petal", "shape": "ring", "zone_kind": "petal", "radius": 1.6 * T, "lifetime": 2.5, "tick": 0.4, "rampage": true},

	# ── 꼬북이 계열(플래티넘 자력기, 사용자 요청 2026-10-28) ──
	# 거품: 거품 셋이 천천히 부채꼴로(한 묶음 한 타). 10% 로 스피드 −1.
	"bubble": {"fx": "bubble", "anim": "Shoot", "shape": "burst", "speed": 110.0, "radius": 4.0, "range": 2 * T,     # 3칸은 길다(사용자 2026-10-30)
		"count": 3, "interval": 0.08, "spread_deg": 30.0, "pierce": false, "volley": true},
	# 껍질에숨기: 껍질에 숨으며(Withdraw 동작) 방어 +1. 파란 고리가 조여 든다.
	"withdraw": {"anim": "Withdraw", "shape": "buff", "stat": "def", "stages": 1, "fx": "withdraw"},
	# 물대포: 물줄기(짧은 연사, 한 묶음 한 타).
	"water_gun": {"fx": "water", "anim": "Shoot", "shape": "burst", "speed": 200.0, "radius": 4.0, "range": 3.5 * T,
		"count": 5, "interval": 0.03, "spread_deg": 4.0, "pierce": false, "volley": true, "vary": true},   # vary: 쏠 때마다 물줄기 무늬가 다르다(사용자 요청 2026-10-30)
	# 물기: 1칸 안을 문다. 위아래 이빨(bite.spa)이 닫힌다. 30% 풀죽음.
	"bite": {"fx": "bite", "anim": "Attack", "lunge": true, "hit_delay": 0.15, "shape": "arc", "range": 1 * T, "arc_deg": 110.0},
	# 고속스핀: 제자리에서 돌며(Rotate 동작) 둘레 1칸을 모두 친다. 씨뿌리기 같은 묶임에서 벗어난다.
	"rapid_spin": {"fx": "spin", "anim": "Rotate", "hit_delay": 0.1, "shape": "arc", "range": 1 * T, "arc_deg": 360.0, "clear_hazards": true},
	# 방어: 1초(원작 한 턴) 동안 모든 공격을 막는다. 연달아 쓰면 1/2, 1/4 … 확률로 실패(원작).
	"protect": {"anim": "Charge", "shape": "protect", "fx": "protect"},
	# 물의파동: 물결 고리 한 발. 20% 로 혼란.
	"water_pulse": {"fx": "pulse", "anim": "Shoot", "shape": "projectile", "speed": 150.0, "radius": 6.0, "range": 4 * T,
		"count": 1, "spread_deg": 0.0, "pierce": false},
	# 아쿠아테일: 꼬리로 앞 1.5칸을 크게 휘두른다(물보라).
	"aqua_tail": {"fx": "aquatail", "anim": "Attack", "hit_delay": 0.18, "shape": "arc", "range": 1.5 * T, "arc_deg": 160.0},
	# 로케트박치기: 선딜 0.25초 + 한 턴(Mon.TURN) 웅크려 방어 +1, 그 뒤 4칸 들이받는다.
	"skull_bash": {"anim": "Charge", "cast_delay": 0.25, "charge_turns": 1, "charge_stat": {"def": 1}, "shape": "dash", "distance": 4 * T, "duration": 0.3, "fx": "skullbash"},
	# 철벽: 금속빛이 돌며 방어 +2.
	"iron_defense": {"anim": "Charge", "shape": "buff", "stat": "def", "stages": 2, "fx": "irondefense"},
	# 비바라기: 5초(원작 5턴) 동안 비 — 물 1.5배, 불꽃 0.5배, 솔라빔 절반, 광합성 1/4.
	"rain_dance": {"anim": "Charge", "cast_delay": 0.3, "shape": "weather", "weather": "rain", "turns": 5},
	# 하이드로펌프: 굵은 물줄기가 4.5칸 관통(한 묶음 한 타).
	"hydro_pump": {"fx": "hydro", "anim": "Shoot", "cast_delay": 0.25, "shape": "burst", "speed": 230.0, "radius": 7.0, "range": 4.5 * T,
		"count": 8, "interval": 0.035, "spread_deg": 6.0, "pierce": true, "one_hit": true},
	# 러스터캐논: 빛 구슬 한 발(5칸). 10% 로 특수방어 −1.
	"flash_cannon": {"fx": "flash", "anim": "Shoot", "cast_delay": 0.2, "shape": "projectile", "speed": 200.0, "radius": 6.0, "range": 5 * T,
		"count": 1, "spread_deg": 0.0, "pierce": false},

	# ── 회색체육관 트레이너 기술(사용자 결정 2026-10-29, 쿨타임은 적 전용) ──
	# 웅크리기: 몸을 둥글게 말아 방어 +1. defense_curl.spa 의 물방울 막이 몸을 감싸고 C 자 고리가 돈다.
	"defense_curl": {"anim": "Charge", "cooldown": 6.0, "shape": "buff", "stat": "def", "stages": 1, "fx": "defensecurl"},
	# 조이기: 바로 옆 칸을 감아 조인다(위력 15). 원작 2~5턴 동안 턴마다 최대 HP 1/16, 조인 쪽이 쓰러지면 풀린다(Mon.bind_t).
	# 원작의 '도망·교체 못 함'은 트레이너 배틀이 이미 그렇다. bind.spa 의 고리가 감긴 몸에서 조여 든다.
	"bind": {"anim": "Attack", "lunge": true, "fx": "bind", "hit_delay": 0.25, "cooldown": 5.0, "shape": "arc", "range": 1 * T, "arc_deg": 110.0},
	# 암석봉인: 조준한 자리(4칸 안)에 바위 셋이 위에서 떨어져 둘레 1칸을 친다(위력 50·명중 80). 맞으면 스피드 −1(100%).
	"rock_tomb": {"targeting":"charged_area", "anim": "Shoot", "cooldown": 5.0, "shape": "lob", "range": 4 * T, "radius": 1.0 * T, "fx": "rocktomb"},

	# ── 상록숲 적(쿨타임은 적 전용) ──
	# 몸통박치기: 이동하지 않고 Attack 동작으로 바로 옆 칸을 친다(사용자 결정).
	# 근접기의 '앞으로 나가며 치기'(사용자 결정 2026-10-30)는 step 이 아니라 도트의 달려드는 동작 그 자체로: Attack 도트를 가장 앞으로 나간 프레임에서
	# 멈추고(반만 재생), 끝나면 그만큼 자리를 옮겨 돌아오지 않는다(Mon.attack_lunge, MonSprite.lunge_of). step 은 불꽃엄니처럼 따로 적은 것만.
	"tackle": {"anim": "Attack", "lunge": true, "fx": "bump", "hit_delay": 0.2, "cooldown": 3.2, "shape": "arc", "range": 1 * T, "arc_deg": 100.0, "glide": 6.0},
	# 실뿜기: 피해 없음. 실이 사거리만큼 늘어났다가 뒤에서부터 사라지고, 닿은 상대는 스피드 랭크 −1(원작, 사용자 결정 2026-10-29 —
	# 따로 느려지게 하지 않고 랭크가 이동 속도를 낮춘다: 2/3·1/2·…). 랭크라 배틀이 끝나면 풀린다.
	"string_shot": {"fx": "thread", "cooldown": 4.0, "shape": "beam", "range": 4 * T, "width": 3.0, "grow": 0.25, "lifetime": 0.7,
		"stat_hit": {"spe": -1}, "stat_hit_chance": 1.0},
	# 단단해지기: 방어 1단계(최대 6). 금속 번쩍임 뒤 능력 상승 연출.
	"harden": {"anim": "Charge", "cooldown": 4.0, "shape": "buff", "stat": "def", "stages": 1},
	"poison_sting": {"fx": "needle", "anim": "Shoot", "cooldown": 2.2, "shape": "projectile", "speed": 120.0, "radius": 2.0, "range": 5 * T,
		"count": 1, "spread_deg": 0.0, "pierce": false},
	# 연속찌르기: Jab 동작으로 2~5타(원작 분포). 한 타마다 넉백·무적을 짧게 둬 연타가 이어진다.
	"fury_attack": {"anim": "Jab", "fx": "horn", "hit_delay": 0.15, "cooldown": 3.0, "shape": "arc", "range": 1 * T, "arc_deg": 100.0,
		"hits": [2, 5], "knock": 30.0, "invuln": 0.25},
	# 전기쇼크: 번개 한 줄기(사용자 결정 2026-10-28: 세 갈래 아님).
	"thunder_shock": {"fx": "spark", "cooldown": 2.8, "shape": "projectile", "speed": 150.0, "radius": 4.0, "range": 6 * T,
		"count": 1, "spread_deg": 0.0, "pierce": false},
	# ── 1번도로(구구·꼬렛) ──
	# 모래뿌리기: 앞 2칸 부채꼴에 모래를 뿌려 명중률 −1(원작 효과). 연기 텍스처를 모래색으로.
	"sand_attack": {"anim": "Attack", "cast_delay": 0.25, "cooldown": 6.0, "shape": "status_cone", "range": 2 * T, "arc_deg": 80.0, "stat": {"acc": -1}, "fx": "sand"},
	# 꼬리흔들기: 앞 2칸 부채꼴의 방어 −1. 꼬렛 TailWhip 동작.
	"tail_whip": {"anim": "TailWhip", "cast_delay": 0.25, "cooldown": 6.0, "shape": "status_cone", "range": 2 * T, "arc_deg": 90.0, "stat": {"def": -1}},
	# 전광석화: 한 칸 앞으로 재빨리 나서며 친다(우선도 대신 짧은 준비·빠른 판정).
	"quick_attack": {"anim": "Attack", "lunge": true, "fx": "bump", "hit_delay": 0.08, "cooldown": 3.5, "shape": "arc", "range": 1 * T, "arc_deg": 90.0, "step": 1.0 * T},
	# ── 기술머신(사용자 결정 2026-10-30, C안): 새미·웅·그린이 주는 기술. 위력·명중·PP·타입은 플래티넘 그대로, 모양만 이 게임 것 ──
	#   dig      구멍파기: 0.25초에 땅속으로(Rotate 동작) → under 초 동안 땅속(무적·절반 속도·기술 못 씀, 같은 칸을 다시 누르면 바로) →
	#            내 자리 둘레 radius 타격 → recover 초 후딜(사용자 결정: 길게). shape burrow.
	#   brine    소금물: 굵은 물덩이 하나. 맞은 상대 HP 가 절반 이하면 위력 2배(half_double).
	#   giga_drain 기가드레인: 투사체 없이 정면 경로 안의 상대(shape drain), 모으는 동안 Charge 동작. 준 피해의 절반 회복(drain).
	#   brick_break 깨뜨리다: Strike 근접. 상대의 방어 랭크 상승을 무시(ignore_def_up — 원작 '벽 부수기' 대신).
	#   sludge_bomb 오물폭탄: 씨폭탄처럼 포물선으로 떨어지는 오물 덩이, 30% 독(플래티넘 effect).
	#   facade   객기: 몸통박치기형 돌진. 내가 화상·독·둔화면 위력 2배(statused_double). PP 는 원작 20 그대로(사용자 지적).
	"dig": {"anim": "Rotate", "shape": "burrow", "sink": 0.25, "under": 2.0, "radius": 1.2 * T, "recover": 0.8, "fx": "dig"},
	"brine": {"fx": "brine", "anim": "Shoot", "shape": "projectile", "speed": 180.0, "radius": 5.0, "range": 4 * T, "count": 1, "spread_deg": 0.0, "half_double": true},
	"giga_drain": {"anim": "Charge", "cast_delay": 0.5, "shape": "drain", "range": 4 * T, "drain": 0.5, "fx": "gigadrain"},
	"brick_break": {"fx": "brick", "anim": "Strike", "hit_delay": 0.15, "lunge": true, "shape": "arc", "range": 1 * T, "arc_deg": 90.0, "ignore_def_up": true},
	"sludge_bomb": {"targeting":"charged_area", "anim": "Shoot", "cast_delay": 0.15, "shape": "lob", "range": 4 * T, "radius": 1.0 * T, "fx": "sludgebomb"},
	"facade": {"anim": "Attack", "shape": "dash", "distance": 2 * T, "duration": 0.2, "fx": "facade", "statused_double": true},

	# ── 최신 습득표(사용자 결정 2026-11-02, A안: 데이터는 최신 판, 연출은 플래티넘 파티클)로 데모 구간(Lv5~16)에 들어온 기술 ──
	#   dragon_breath 용의숨결(파이리 12·롱스톤 12): 자홍빛 숨결 뭉치 넷을 짧게 내뿜는다(불꽃세례처럼 한 묶음 한 타). 30% 마비(원작 그대로, Mon.para_t).
	"dragon_breath": {"fx": "breath", "anim": "Shoot", "shape": "burst", "speed": 150.0, "radius": 4.0, "range": 3 * T,
		"count": 4, "interval": 0.05, "spread_deg": 10.0, "pierce": false, "volley": true, "grow": 1.8, "hit_fx": "breath"},
	#   bug_bite 벌레먹음(뿔충이·캐터피 9): 물기와 같은 근접 1칸, 초록 물린 자국. (열매를 먹는 효과는 없다.)
	"bug_bite": {"fx": "bugbite", "anim": "Attack", "lunge": true, "hit_delay": 0.15, "shape": "arc", "range": 1 * T, "arc_deg": 110.0},
	#   thunder_wave 전기자석파(피카츄 4): 앞 3칸 부채꼴의 상대를 마비(확정, 땅 타입 무효). 노란 고리가 퍼지고 번개가 몸을 감싼다.
	"thunder_wave": {"anim": "Charge", "cast_delay": 0.2, "cooldown": 6.0, "shape": "status_cone", "range": 3 * T, "arc_deg": 70.0,
		"fx": "thunderwave"},
	#   rollout 구르기(꼬마돌 10·모래두지 9): 2칸 돌진(Rotate 동작). 3초 안에 이어 쓰면 위력 2배씩(최대 5번째 16배, 원작 '5턴 동안 커진다').
	"rollout": {"anim": "Rotate", "shape": "dash", "distance": 2 * T, "duration": 0.25, "fx": "rollout", "ramp": true},
	#   rock_polish 록커트(꼬마돌 6·롱스톤 8): 스피드 +2. 별빛이 번쩍이고 빛줄기가 솟는다.
	"rock_polish": {"anim": "Charge", "cooldown": 6.0, "shape": "buff", "stat": "spe", "stages": 2, "fx": "rockpolish"},
	#   rock_throw: one falling rock at the selected ground area; preserve the former projectile cadence.
	"rock_throw": {"targeting":"charged_area", "area_radius":T, "anim": "Shoot", "shape": "projectile", "speed": 140.0, "radius": 5.0, "range": 4 * T, "count": 1, "spread_deg": 0.0, "pierce": false, "fx": "rock"},
	#   smack_down 떨어뜨리기(롱스톤 4, 5세대): 작은 바위를 빠르게 던진다. (날던 상대를 떨어뜨리는 효과는 없다.)
	"smack_down": {"anim": "Shoot", "shape": "projectile", "speed": 180.0, "radius": 4.0, "range": 4 * T, "count": 1, "spread_deg": 0.0, "pierce": false, "fx": "rock"},
	#   bulldoze 땅고르기(꼬마돌 12·모래두지 18, 5세대): 땅을 밟아 둘레 1.5칸 전부를 치고 스피드 −1(확정).
	"bulldoze": {"anim": "Attack", "hit_delay": 0.2, "shape": "arc", "range": 1.5 * T, "arc_deg": 360.0, "fx": "bulldoze",
		"stat_hit": {"spe": -1}, "stat_hit_chance": 1.0},
}

# 커스텀 연출(FxStyle, 사용자 요청 2026-11-02): FxStyle.mode == "custom" 일 때 그 기술의 그림 키만 이걸로 덮어쓴다.
# 판정·위력·타이밍 키는 넣지 않는다(두 모드의 게임이 같게). 한 기술을 원작으로 되돌리려면 그 줄만 지운다.
#   claw_c   할퀴기: 맞으면 세 줄이 짧은 간격으로 나타나는 발톱 자국 + 작은 타격 섬광. 범위 호는 그리지 않는다(사용자 2026-11-02 —
#            처음엔 판정 끝을 따라 흰 호가 그어졌다).
#   ember_c  불꽃세례: 입에서 불씨가 터지고, 불꽃이 혜성처럼 꼬리를 끌며 날아간다. 맞으면 맞은 쪽으로 불티가 튀고 바닥이 잠깐 그을린다.
#            사거리 끝·벽에서 꺼지면 작은 연기 — 어디까지 날아가는지 보인다.
#   smoke_c  연막: 던지는 순간 떨어질 자리에 터질 범위(1.5칸)의 점선 고리가 조여 들고, 연막탄은 포물선(그림자가 바닥을 따라감)으로 날아가
#            그 고리 안을 연기로 꽉 채운다.
const CUSTOM_FX := {
	"flamethrower": {"fx": "flame_c"},
	"scary_face": {"fx": "scaryface_c"},
	"dragon_rage": {"fx": "dragon_c", "hit_fx": "dragonfire_c"},
	"fire_fang": {"fx": "fang_c"},
	"scratch": {"fx": "claw_c"},
	"growl": {"fx": "noise_c"},
	"ember": {"fx": "ember_c"},
	"smoke_screen": {"fx": "smoke_c"},
}

# 모양이 없는 기술의 기본값(분류별). 변화기는 플래티넘 효과 이름으로 랭크 변화를 추정한다.
static func default_shape(data: Dictionary) -> Dictionary:
	match String(data.get("cat", "physical")):
		"physical":
			return {"anim": "Attack", "hit_delay": 0.15, "shape": "arc", "range": 1 * T, "arc_deg": 110.0, "cooldown": 3.0}
		"special":
			return {"anim": "Shoot", "shape": "projectile", "speed": 160.0, "radius": 3.0, "range": 4 * T,
				"count": 1, "spread_deg": 0.0, "pierce": false, "cooldown": 3.0}
	var eff := String(data.get("effect", ""))
	var stat_key := {"atk": "atk", "def": "def", "sp_atk": "spa", "sp_def": "spd", "speed": "spe"}
	for k in stat_key:
		if eff.begins_with(k + "_up"):
			return {"anim": "Charge", "cooldown": 4.0, "shape": "buff", "stat": stat_key[k], "stages": 2 if eff.ends_with("_2") else 1}
		if eff.begins_with(k + "_down"):
			return {"anim": "Charge", "cast_delay": 0.3, "cooldown": 4.0, "shape": "status_cone", "range": 2 * T, "arc_deg": 90.0,
				"stat": {stat_key[k]: -2 if eff.ends_with("_2") else -1}}
	return {"anim": "Charge", "cast_delay": 0.3, "shape": "status_cone", "range": 2 * T, "arc_deg": 90.0, "stat": {}, "cooldown": 4.0}

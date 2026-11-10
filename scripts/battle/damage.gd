class_name Damage
extends RefCounted

# 원작 데미지 공식(5세대 이후)을 그대로 쓴다.
#   기본 = ⌊⌊⌊2L/5 + 2⌋ · 위력 · A/D⌋ / 50⌋ + 2
#   최종 = 기본 × 자속(1.5) × 상성 × 급소(1.5) × 난수(0.85~1.0)
# 액션 게임이라 한 대의 무게가 원작보다 가볍지만, 공식을 바꾸면 종족값·레벨의 의미가 흐려져서
# 손대지 않는다(HP 배율 같은 보정도 없다).

const CRIT_MULT := 1.5
const STAB_MULT := 1.5
const BASE_CRIT := 1.0 / 24.0

static func calc(level: int, attack: int, defense: int, power: float,
		stab: bool, effectiveness: float, crit: bool, roll: float) -> int:
	if effectiveness <= 0.0 or power <= 0.0:
		return 0
	var base := floorf(floorf(floorf(2.0 * level / 5.0 + 2.0) * power * attack / maxf(1.0, defense)) / 50.0) + 2.0
	var mult := effectiveness * roll
	if stab:
		mult *= STAB_MULT
	if crit:
		mult *= CRIT_MULT
	return maxi(1, int(floor(base * mult)))

static func effect_text(effectiveness: float, target_name: String = "") -> String:
	if effectiveness <= 0.0:
		return Lang.t("no_effect", [target_name])
	if effectiveness >= 2.0:
		return Lang.t("super_effective", [target_name])
	if effectiveness < 1.0:
		return Lang.t("not_very_effective", [target_name])
	return ""

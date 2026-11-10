class_name TypeChart
extends RefCounted

# 타입 상성표. 원작 9세대 기준에서 이 게임에 나오는 타입만 옮겼다.
# 표에 없는 조합은 1배다. 이중 타입은 두 배율을 곱한다.

const NAMES := {
	"normal": "NORMAL", "fire": "FIRE", "water": "WATER", "grass": "GRASS", "electric": "ELECTRIC",
	"poison": "POISON", "flying": "FLYING", "dragon": "DRAGON", "dark": "DARK", "bug": "BUG",
	"ground": "GROUND", "rock": "ROCK", "ghost": "GHOST", "psychic": "PSYCHIC", "ice": "ICE",
	"fighting": "FIGHTING", "steel": "STEEL", "fairy": "FAIRY",
}

const COLORS := {
	"normal": Color("a8a77a"), "fire": Color("ee8130"), "water": Color("6390f0"),
	"grass": Color("7ac74c"), "electric": Color("f7d02c"), "poison": Color("a33ea1"),
	"flying": Color("a98ff3"), "dragon": Color("6f35fc"), "dark": Color("705746"), "bug": Color("a6b91a"),
	"ground": Color("e2bf65"), "rock": Color("b6a136"), "ghost": Color("735797"), "psychic": Color("f95587"),
	"ice": Color("96d9d6"), "fighting": Color("c22e28"), "steel": Color("b7b7ce"), "fairy": Color("d685ad"),
}

# 공격 타입 → { 방어 타입: 배율 }
const CHART := {
	"normal": {"rock": 0.5, "ghost": 0.0, "steel": 0.5},
	"fire": {"fire": 0.5, "water": 0.5, "grass": 2.0, "ice": 2.0, "bug": 2.0,
		"rock": 0.5, "dragon": 0.5, "steel": 2.0},
	"water": {"fire": 2.0, "water": 0.5, "grass": 0.5, "ground": 2.0, "rock": 2.0, "dragon": 0.5},
	"grass": {"fire": 0.5, "water": 2.0, "grass": 0.5, "poison": 0.5, "ground": 2.0,
		"flying": 0.5, "bug": 0.5, "rock": 2.0, "dragon": 0.5, "steel": 0.5},
	"electric": {"water": 2.0, "electric": 0.5, "grass": 0.5, "ground": 0.0,
		"flying": 2.0, "dragon": 0.5},
	"poison": {"grass": 2.0, "poison": 0.5, "ground": 0.5, "rock": 0.5, "ghost": 0.5,
		"steel": 0.0, "fairy": 2.0},
	"flying": {"grass": 2.0, "electric": 0.5, "fighting": 2.0, "bug": 2.0, "rock": 0.5, "steel": 0.5},
	"dragon": {"dragon": 2.0, "steel": 0.5, "fairy": 0.0},
	"dark": {"psychic": 2.0, "ghost": 2.0, "fighting": 0.5, "dark": 0.5, "fairy": 0.5},
	"bug": {"fire": 0.5, "grass": 2.0, "fighting": 0.5, "poison": 0.5, "flying": 0.5,
		"psychic": 2.0, "ghost": 0.5, "dark": 2.0, "steel": 0.5, "fairy": 0.5},
}

static func effectiveness(attack_type: String, defend_types: Array) -> float:
	var row: Dictionary = CHART.get(attack_type, {})
	var mult := 1.0
	for t in defend_types:
		mult *= float(row.get(t, 1.0))
	return mult

static func type_name(t: String) -> String:
	return Lang.type_name(t)

static func type_color(t: String) -> Color:
	return COLORS.get(t, Color.GRAY)

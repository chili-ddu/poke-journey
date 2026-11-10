class_name SpeciesExtras
extends RefCounted

# 종족의 "액션 게임용" 값. 종족값·타입·경험치·진화·습득표는 플래티넘 데이터(assets/data/species.json)에서 오고,
# 여기엔 적 AI·기술·자리표시 색을 둔다. 몸 크기·충돌 반경은 PokemonSize의 공통 8단계에서 정한다.
# 여기 없는 종도 공통 크기 분류와 기술 사거리에 맞춰 움직이는 "wild" AI를 사용한다.
# 새 포켓몬 추가 = assets/sprites/<도감번호 4자리>/ 에 PMD 도트 + (원하면) 여기 한 줄.

const DEFAULT := {"ai": "wild", "color": Color("a0a0a0"), "accent": Color("ffffff")}

const EXTRAS := {
	"ditto": {"ai":"wild","moves":["transform"]},
	"wobbuffet": {"ai":"wild","moves":["counter","mirror_coat"]},
	# Route 11 and Diglett's Cave use the shared distance-aware wild AI.
	"diglett": {"ai":"wild","moves":["scratch","sand_attack","astonish","growl"]},
	"dugtrio": {"ai":"wild","moves":["scratch","sand_attack","astonish","growl"]},
	"drowzee": {"ai":"wild","moves":["pound","hypnosis","confusion"]},
	"raticate": {"ai":"wild"},
	"nidorino": {"ai":"wild"},
	"vulpix": {"ai":"wild"},
	"growlithe": {"ai":"wild"},
	"magneton": {"ai":"wild"},
	"eevee": {"ai":"wild"},
	"vaporeon": {"ai":"wild"},
	"jolteon": {"ai":"wild"},
	"flareon": {"ai":"wild"},
	"kadabra": {"ai":"wild"},

	# 블루시티 구간: 종별 전용 AI 대신 보유 기술의 사거리로 싸운다.
	"pidgeotto": {"ai":"wild"},
	"pidgeot": {"ai":"wild"},
	"abra": {"ai":"wild"},
	"machop": {"ai":"wild"},
	"slowpoke": {"ai":"wild"},
	"staryu": {"ai":"wild"},
	"starmie": {"ai":"wild"},
	"parasect": {"ai":"wild"},

	# 관동 낚시·수상 출현. 실제 이동 지형은 개체별 travel_terrain으로 지정.
	"psyduck": {"ai": "wild", "moves": ["water_gun", "scratch", "water_pulse", "fury_swipes"]},
	"poliwag": {"ai": "wild", "moves": ["water_gun", "hypnosis", "pound"]},
	"poliwhirl": {"ai": "wild", "moves": ["water_gun", "hypnosis", "pound"]},
	"tentacool": {"ai": "wild", "moves": ["water_gun", "poison_sting", "acid", "water_pulse"]},
	"shellder": {"ai": "wild", "moves": ["water_gun", "tackle", "withdraw", "supersonic"]},
	"krabby": {"ai": "wild", "moves": ["water_gun", "metal_claw", "harden", "leer"]},
	"horsea": {"ai": "wild", "moves": ["water_gun", "dragon_breath", "smoke_screen", "leer"]},
	"seadra": {"ai": "wild", "moves": ["water_gun", "dragon_breath", "smoke_screen", "leer"]},
	"goldeen": {"ai": "wild", "moves": ["peck", "water_pulse", "supersonic", "tail_whip"]},
	"magikarp": {"ai": "wild", "moves": ["tackle", "splash"]},
	"gyarados": {"ai": "wild", "moves": ["bite", "brine", "tackle", "leer"]},

	# 관동 도보 야생: SV 습득 레벨을 유지하며 공통 거리 판단을 사용.
	"spearow": {"ai": "wild", "moves": ["peck", "leer", "fury_attack"]},
	"ekans": {"ai": "wild", "moves": ["wrap", "poison_sting", "bite", "leer"]},
	"nidoran_f": {"ai": "wild", "moves": ["scratch", "poison_sting", "tail_whip", "growl"]},
	"nidoran_m": {"ai": "wild", "moves": ["peck", "poison_sting", "leer"]},
	"clefairy": {"ai": "wild", "moves": ["pound", "disarming_voice", "sing", "defense_curl"]},
	"jigglypuff": {"ai": "wild", "moves": ["disarming_voice", "sing", "defense_curl"]},
	"zubat": {"ai": "wild", "moves": ["absorb", "astonish", "supersonic"]},
	"oddish": {"ai": "wild", "moves": ["mega_drain", "absorb", "acid", "growth", "sweet_scent", "poison_powder"]},
	"paras": {"ai": "wild", "moves": ["scratch", "absorb", "poison_powder"]},
	"meowth": {"ai": "wild", "moves": ["scratch", "growl"]},
	"mankey": {"ai": "wild", "moves": ["scratch", "fury_swipes", "leer"]},

	# 스타팅 세 계열(PC 박스에서 고름). 크기·반경은 종족의 원작 키에 따른 공통 분류를 사용한다.
	"bulbasaur": {"ai": "crawler", "color": Color("78c850"), "accent": Color("3a9a6a")},
	"ivysaur": {"color": Color("68b048"), "accent": Color("e070a0")},
	"venusaur": {"color": Color("5a9a48"), "accent": Color("e05060")},
	"squirtle": {"ai": "crawler", "color": Color("68a8e0"), "accent": Color("c89050")},
	"wartortle": {"color": Color("6890d0"), "accent": Color("b07840")},
	"blastoise": {"color": Color("5878c0"), "accent": Color("a07040")},
	"charmander": {"ai": "crawler", "color": Color("f08a3c"), "accent": Color("ffd34e")},
	"charmeleon": {"color": Color("d8462e"), "accent": Color("ffd34e")},
	"charizard": {"color": Color("f08a3c"), "accent": Color("3c8ad8")},
	# ── 상록숲 ──
	"butterfree": {"ai":"wild","moves":["gust","confusion","supersonic"]},
	"scyther": {"ai":"wild"},
	"caterpie": {"ai": "crawler", "moves": ["tackle", "string_shot"], "color": Color("6ab04c"), "accent": Color("f6e58d")},
	"metapod": {"ai": "cocoon", "moves": ["harden"], "color": Color("8fbf5a"), "accent": Color("5c8a3a")},
	"weedle": {"ai": "stinger", "moves": ["poison_sting"], "color": Color("d4a05a"), "accent": Color("e07b7b")},
	"kakuna": {"ai": "cocoon", "moves": ["harden"], "color": Color("e0c050"), "accent": Color("8a7a2a")},
	# 보스지만 특별한 건 덩치 1.5배와 개체값 31 뿐(사용자 결정). 연속찌르기(Jab 2~5타)·독침(뿔충이 때부터)만 쓴다.
	"beedrill": {"ai": "drill", "moves": ["fury_attack", "poison_sting"], "color": Color("e8c84a"), "accent": Color("3a3a3a")},
	# 야생(Lv3~5)으로만. 그 레벨에 아는 공격기는 전기쇼크뿐.
	"pikachu": {"ai": "zapper", "moves": ["thunder_shock"], "color": Color("f8d030"), "accent": Color("e04040")},
	# 1번도로(Lv2~5): 구구는 몸통박치기·모래뿌리기(5), 꼬렛은 몸통박치기·꼬리흔들기·전광석화(4). 레벨 제한은 enemy_moves 가.
	"pidgey": {"ai": "crawler", "moves": ["tackle", "sand_attack"], "color": Color("c8a070"), "accent": Color("f0e0b0")},
	"rattata": {"ai": "crawler", "moves": ["quick_attack", "tackle", "tail_whip"], "color": Color("a070c0"), "accent": Color("f0e0d8")},
	# 회색체육관(트레이너 배틀, 사용자 결정 2026-10-29). 기술은 트레이너 파티에 적힌 것(TrainerDB)을 쓴다. 롱스톤은 몸이 길어 크게.
	"geodude": {"ai": "crawler", "color": Color("a09070"), "accent": Color("706050")},
	"onix": {"ai": "crawler", "color": Color("b0b0b8"), "accent": Color("707078")},
	"sandshrew": {"ai": "crawler", "color": Color("e0c070"), "accent": Color("a08040")},
}

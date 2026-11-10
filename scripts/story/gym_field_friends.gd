extends RefCounted

const HMs=preload("res://scripts/data/field_hms.gd")
const REWARDS={
	"leader_misty":{"move":"surf",
		"intro":["라프라스가 네 여행을 도와줄 거야.\n물가에서 불러 함께 건너 봐!","LAPRAS will travel with you.\nCall it by water to cross!"],
		"joined":["라프라스가 파도타기를\n도와주기로 했다!","LAPRAS will help you SURF!"]},
	"leader_lt_surge":{"move":"flash",
		"intro":["피카츄가 네 여행을 도와줄 거다!\n어두운 동굴에서 길을 밝혀 줄 거야.","PIKACHU will travel with you!\nIt will light up dark caves."],
		"joined":["피카츄가 플래시를\n도와주기로 했다!","PIKACHU will help you with FLASH!"]}
}

# Compatibility wrapper only: Game owns the current Misty/Surge assistance
# grants and old-win recovery. FieldHMs.sync preserves existing move knowledge;
# these deprecated generic entry points intentionally do not grant rewards.
static func grant(_game: Node,_leader: String) -> bool:
	return false

static func sync(_game: Node) -> bool:
	return false

static func award(_game: Node,_leader: String,_speaker: Npc) -> Array:
	return []

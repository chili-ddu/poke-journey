extends RefCounted

const ID="fuchsia_lapras_escape"
const PLACE="kanto_world"
const ARENA="arena_lapras_escape"
const STARTED="lapras_escape_started"
const WON="lapras_escape_won"
const FRIEND="friend_lapras_surf"
const DISPLAY_TILE=Vector2i(12,20) # Original Fuchsia City Lapras object.
const TALK_TILE=Vector2i(12,23)
const BEACH_PLAYER=Vector2i(12,13)
const BEACH_LAPRAS=Vector2i(12,15)
const STAFF_TILES=[Vector2i(4,4),Vector2i(9,4),Vector2i(14,4),Vector2i(19,4)]
const SPAWN_TILES=[Vector2i(4,9),Vector2i(9,9),Vector2i(14,9),Vector2i(19,9)]
const PARTIES=[
	[["growlithe",25],["raticate",26],["rhyhorn",28]],
	[["parasect",25],["venonat",26],["venomoth",28]],
	[["nidorino",25],["nidorina",26],["kangaskhan",28]],
	[["exeggcute",25],["doduo",26],["tauros",28]],
]

static func count() -> int:
	var total:=0
	for party in PARTIES:total+=party.size()
	return total

static func themes() -> Dictionary:
	return {ARENA:{"map":"res://assets/maps/"+ARENA,"tiles":{}}}

static func places() -> Dictionary:
	return {ARENA:{"name":"LAPRAS ESCAPE","name_ko":"라프라스 탈출","theme":ARENA,"arena_field":true,"count":0,"encounters":[]}}

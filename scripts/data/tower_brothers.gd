extends RefCounted

# The copies include each brother's visible original: 5, 10, 15, 10, 25, 10.
const ARENA := "arena_tower_brothers"
const COMPLETE := "tower_brothers_cleared"
const INTERVENTION_INTERVAL := 8.0
const BROTHERS := {
	"youngest":{"species":"gastly","level":22,"copies":5,"ko":"막내 고오스","en":"Youngest GASTLY","moves":["lick"]},
	"third":{"species":"gastly","level":24,"copies":10,"ko":"셋째 고오스","en":"Third GASTLY","moves":["lick","astonish"]},
	"second":{"species":"haunter","level":29,"copies":10,"ko":"둘째 고우스트","en":"Second HAUNTER","moves":["lick","sucker_punch"]},
	"eldest":{"species":"gengar","level":34,"copies":10,"ko":"첫째 팬텀","en":"Eldest GENGAR","moves":["lick","sucker_punch"]},
}
const STAGES := {2:["youngest"],3:["third"],4:["youngest","third"],5:["second"],6:["youngest","third","second"],7:["eldest"]}
const SPEAKERS := {2:["youngest"],3:["youngest","third"],4:["youngest","third"],5:["youngest","third","second"],6:["youngest","third","second"],7:["youngest","third","second","eldest"]}
# Clear source-floor positions for the brief arrival scene, not a walking route.
const PLAYER_TILES := {2:Vector2i(16,12),3:Vector2i(13,12),4:Vector2i(15,9),5:Vector2i(11,10),6:Vector2i(10,9),7:Vector2i(11,11)}
const SPEAKER_TILES := {
	2:[Vector2i(16,8)],3:[Vector2i(10,8),Vector2i(13,7)],4:[Vector2i(13,9),Vector2i(17,8)],
	5:[Vector2i(10,9),Vector2i(11,8),Vector2i(12,9)],6:[Vector2i(8,7),Vector2i(10,6),Vector2i(12,7)],
	7:[Vector2i(9,7),Vector2i(11,6),Vector2i(13,7),Vector2i(11,4)]}

# Both the brothers and their projections face the player along shallow arcs.
static func brother_position(index: int,total: int) -> Vector2:
	var u:=0.0 if total<=1 else float(index)/float(total-1)*2.0-1.0
	var stagger:=0.3 if total==2 and index==0 else (-0.3 if total==2 else 0.0)
	return Vector2(12.5+u*3.6,10.5+u*u*0.9+stagger)*Arena.TILE

static func formation(total: int) -> Array[Vector2]:
	var points: Array[Vector2]=[]
	var rows:=ceili(float(total)/5.0)
	var end_y:=10.5 if rows==1 else 13.0
	for row in rows:
		var columns:=mini(5,total-row*5)
		var half_width:=lerpf(4.8,6.0,float(row)/float(maxi(1,rows-1)))
		var y:=end_y-float(rows-1-row)*2.1
		for column in columns:
			var u:=0.0 if columns==1 else float(column)/float(columns-1)*2.0-1.0
			points.append(Vector2(12.5+u*half_width,y+u*u)*Arena.TILE)
	return points

static func floor_id(number: int) -> String:return "pokemon_tower_%df"%number
static func floor_number(place: String) -> int:
	for number in range(1,8):
		if place==floor_id(number):return number
	return 0
static func flag(number: int) -> String:return "tower_brothers_floor_%d"%number
static func next_floor(events: Array) -> int:
	for number in range(2,8):
		if not events.has(flag(number)):return number
	return 8
static func count(number: int) -> int:
	var result:=0
	for brother in STAGES.get(number,[]):result+=int(BROTHERS[brother].copies)
	return result
static func brother_name(id: String) -> String:return String(BROTHERS[id].ko if Lang.is_ko() else BROTHERS[id].en)
static func themes() -> Dictionary:return {ARENA:{"map":"res://assets/maps/"+ARENA,"tiles":{}}}
static func places() -> Dictionary:
	var result: Dictionary={ARENA:{"name":"THE FOUR BROTHERS","name_ko":"포켓몬타워 네 형제","theme":ARENA,"arena_field":true,"battle_style":"room","count":0,"encounters":[]}}
	for number in range(1,8):
		var id:=floor_id(number)
		result[id]={"name":"POKéMON TOWER %dF"%number,"name_ko":"포켓몬타워 %d층"%number,"theme":id,
			"indoor":true,"count":0,"encounters":[],"npcs":[],"trainers":[],
			"areas":{id:{"name":"POKéMON TOWER %dF"%number,"name_ko":"포켓몬타워 %d층"%number,"encounter_rate":0,"encounters":[]}}}
	return result

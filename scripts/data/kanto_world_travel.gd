class_name KantoWorldTravel
extends RefCounted

const ID="kanto_world"
const Continent=preload("res://scripts/data/continent_world.gd")
const AREA_ALIASES={"route21_north":"route21","route21_south":"route21","indigo_plateau_exterior":"indigo_plateau"}

static func promote(place: String,destination: Dictionary) -> Dictionary:
	if Continent.exterior(place):
		var joined:=destination.duplicate(true)
		if joined.has("pos") and joined.pos!=Vector2(-1,-1):joined.pos+=Vector2(Continent.offset())*Arena.TILE
		elif not joined.has("warp"):
			joined.pos=(Continent.collection().spawn(int(place.trim_prefix("johto_")))+Vector2(Continent.offset()))*Arena.TILE
		joined.map=ID
		joined.layout=1
		return {"map":ID,"destination":joined}
	if place==DungeonDB.Johto.LEGACY_GATE:
		var gate:=destination.duplicate(true)
		gate.map="johto_299"
		if gate.has("warp"):
			# FRLG's north exit is index 0; indices 1~3 face Route 22.
			gate.warp={"map":"johto_299","index":1 if int(gate.warp.index)==0 else 2}
		elif gate.has("pos"):
			# Old saves resume safely inside the corresponding new junction.
			gate.pos=Vector2(20.5,8.5)*Arena.TILE
		return {"map":"johto_299","destination":gate}
	var offsets: Dictionary=DungeonDB.KantoWorld.LEGACY_OFFSETS
	if not offsets.has(place):return {"map":place,"destination":destination}
	var dest:=destination.duplicate(true)
	if dest.has("pos"):
		var at: Vector2=dest.pos
		var version:=int(dest.get("layout",DungeonDB.LAYOUTS.get(place,1)))
		while version<int(DungeonDB.LAYOUTS.get(place,1)):
			at+=Vector2(DungeonDB.LAYOUT_SHIFT.get(place,{}).get(version,Vector2i.ZERO))*Arena.TILE
			version+=1
		var offset: Array=offsets[place]
		dest.pos=at+Vector2(offset[0],offset[1])*Arena.TILE
		dest.layout=1
	dest.map=ID
	return {"map":ID,"destination":dest}

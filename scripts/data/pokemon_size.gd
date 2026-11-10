class_name PokemonSize
extends RefCounted

const PATH := "res://assets/data/pokemon_sizes.json"
static var _data: Dictionary={}

static func _load() -> void:
	if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))

static func tiers() -> Array:
	_load();return _data.tiers

static func tier_for_height(height_dm: int) -> int:
	for tier in tiers():
		if tier.max_height_dm==null or height_dm<=int(tier.max_height_dm):return int(tier.id)
	return 8

static func profile(id: String) -> Dictionary:
	_load()
	assert(_data.species.has(id),"Missing Pokemon size profile: "+id+"; run tools/pokemon_sizes.py")
	return _data.species[id]

static func label(tier: int) -> String:
	return String(tiers()[clampi(tier,1,8)-1].label_ko)

static func scale_for(profile: Dictionary, sprites: Dictionary) -> float:
	var span:=float(sprites.get("reference_span",float(profile.radius)*2.0))
	return float(profile.display_span)/maxf(1.0,span)

static func carrier_for(tier: int) -> String:
	return "pidgeot" if tier>=4 else "pidgeotto"

extends RefCounted

## Shared presentation rules. No gameplay or encounter state is changed.
const PATH := "res://assets/data/visual_style_profiles.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data

static func profile(header: Dictionary) -> String:
	if header.get("mapsec", "") == "MAPSEC_ILEX_FOREST": return "forest"
	if header.get("mapType", "") == "MAP_TYPE_CAVE": return "cave"
	if header.get("mapType", "") == "MAP_TYPE_INTERIOR": return "indoor"
	return "outdoor"

static func game_profile(location: String) -> String:
	if DungeonDB.Johto.has(location): return profile(DungeonDB.Johto.metadata(location))
	var cfg: Dictionary = DungeonDB.DUNGEONS.get(location, {})
	if String(cfg.get("theme", "")) == "forest" or location.begins_with("arena_viridian_forest") or location == "arena_forest_rescue":
		return "forest"
	# Encounter terrain alone cannot identify caves: factories and mansions
	# also use cave-style random encounters in the native source data.
	for name in ["mt_moon", "rock_tunnel", "digletts_cave", "seafoam_islands", "victory_road", "cerulean_cave", "arena_mt_moon"]:
		if location.begins_with(name): return "cave"
	if bool(cfg.get("indoor", false)) or cfg.get("battle_style", "") == "room": return "indoor"
	return "outdoor"

static func apply_game(material: ShaderMaterial, location: String, battle: bool = false) -> void:
	apply(material, game_profile(location))
	if battle:
		material.set_shader_parameter("band_top", 0.14)
		material.set_shader_parameter("band_bottom", 0.08)
		material.set_shader_parameter("blur_px", 2.0)

static func apply(material: ShaderMaterial, kind: String) -> void:
	var values: Dictionary = data().profiles[kind]
	for key in values:
		var value = values[key]
		if key == "light_tint": value = Vector3(value[0], value[1], value[2])
		material.set_shader_parameter(key, value)

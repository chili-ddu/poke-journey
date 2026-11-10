class_name LevelProgression
extends RefCounted

const PATH="res://assets/data/level_progression.json"
static var _config: Dictionary={}

static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _config

static func unlocked(events: Array) -> bool:
	return events.has(config().unlock_event)

static func band(area: String) -> Array:
	for rule in config().bands:
		if area in rule.get("areas",[]):return rule.levels
		for prefix in rule.get("prefixes",[]):
			if area.begins_with(prefix):return rule.levels
	return []

# Native tables remain the source of species, weights and early levels.
static func encounter_window(area: String, native_level: int, player_level: int, events: Array) -> Vector2i:
	if not unlocked(events):
		var level:=clampi(native_level,1,int(config().tutorial_max_level))
		return Vector2i(level,level)
	var limits:=band(area)
	if limits.is_empty():return Vector2i(native_level,native_level)
	var offsets: Array=config().player_offsets
	return Vector2i(clampi(player_level+int(offsets[0]),int(limits[0]),int(limits[1])),
		clampi(player_level+int(offsets[1]),int(limits[0]),int(limits[1])))

static func encounter_level(area: String, native_level: int, player_level: int, events: Array, rng: RandomNumberGenerator) -> int:
	var window:=encounter_window(area,native_level,player_level,events)
	return window.x if window.x==window.y else rng.randi_range(window.x,window.y)

static func experience(base_exp: int, enemy_level: int, player_level: int) -> int:
	var original:=int(floor(float(base_exp)*enemy_level/7.0))
	var penalties: Array=config().overlevel_factors
	var gap:=clampi(player_level-enemy_level,0,penalties.size()-1)
	return maxi(0,int(floor(original*float(config().experience_multiplier)*float(penalties[gap]))))

# Ordinary road trainers only; story rosters and leaders stay authored.
static func trainer(source: Dictionary, area: String, player_level: int, events: Array) -> Dictionary:
	var result:=source.duplicate(true)
	var party: Array=result.party
	if not unlocked(events):party=party.slice(0,int(config().tutorial_trainer_party_limit))
	var lowest:=100;var highest:=1
	for row in party:
		lowest=mini(lowest,int(row[1]));highest=maxi(highest,int(row[1]))
	for row in party:
		var old_level:=int(row[1])
		var window:=encounter_window(area,old_level,player_level,events)
		var rank:=float(old_level-lowest)/float(highest-lowest) if highest>lowest else 0.5
		row[1]=window.x+roundi((window.y-window.x)*rank)
		if int(row[1])!=old_level and row.size()>2:row[2]=[]
	result.party=party
	result["reference_level"]=player_level
	result["progression_area"]=area
	return result

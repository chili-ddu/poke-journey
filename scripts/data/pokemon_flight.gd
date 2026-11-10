extends RefCounted

const PATH="res://assets/data/pokemon_flight.json"
static var _rules: Dictionary={}

static func rules() -> Dictionary:
	if _rules.is_empty():_rules=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _rules

static func can_fly(species: String) -> bool:
	var data:=rules()
	if species in data.excluded:return false
	# Compatibility describes the species, not a required HM, learned move or PP.
	return species in data.additional or "HM02" in SpeciesDB.get_species(species).get("tms",[])

static func animation(mon: Mon) -> String:
	var data:=rules()
	var preferred: String=data.hover_animation if mon.species_id in data.hover else data.wing_animation
	preferred=String(data.animation_overrides.get(mon.species_id,preferred))
	if mon._sprites.has(preferred):return preferred
	return "Walk" if mon._sprites.has("Walk") else ""

static func prepare_animation(mon: Mon) -> String:
	var name:=animation(mon)
	var cycle: Dictionary=rules().cycles.get(name,{})
	if cycle.is_empty():return name
	var source: Dictionary=mon._sprites[name]
	var order: Array=cycle.frames
	var ticks: Array=cycle.ticks
	if source.durations.size()==int(cycle.get("short_source_frames",-1)):
		order=cycle.short_frames;ticks=cycle.short_ticks
	if not source.has("flight_centers"):
		source.flight_centers=MonSprite._load_centers(String(source.offsets_path),int(source.fw),int(source.fh),source.durations.size(),int(source.rows),true)
	var pose:=source.duplicate(true)
	pose.durations=ticks.duplicate();pose.pose_order=order.duplicate()
	pose.source_animation=name
	if cycle.get("native_frames",false):pose.native_frames=true
	pose.flight_centers=[]
	for row: Array in source.flight_centers:
		var centers: Array=[]
		for frame in order:centers.append(row[int(frame)])
		pose.flight_centers.append(centers)
	# Virtual poses are local to this actor; ordinary attacks keep their source timings.
	mon._sprites=mon._sprites.duplicate()
	mon._sprites["Flight"]=pose
	return "Flight"

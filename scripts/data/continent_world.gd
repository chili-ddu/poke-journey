extends RefCounted

## One exterior coordinate space. FRLG coordinates remain stable; original HGSS
## exterior chunks are translated as a unit. Interior/cave scenes retain IDs.
const Collection = preload("res://scripts/johto/hgss_map_collection.gd")
const BASE = "res://assets/maps/johto_border_hgss/"
static var _collection: Collection
static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		_config=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/continent_world.json"))
	return _config

static func offset() -> Vector2i:
	var at: Array=config().johto_offset
	return Vector2i(int(at[0]),int(at[1]))

static func collection() -> Collection:
	if _collection==null:_collection=Collection.new(BASE)
	return _collection

static func scene() -> Dictionary:
	return collection().scene_data(config().mainland_scene)

static func exterior(place: String) -> bool:
	if not place.begins_with("johto_"):return false
	return collection().scene_for(int(place.trim_prefix("johto_")))==config().mainland_scene

static func area_at(pos: Vector2) -> String:
	var header:=collection().header_at(scene(),Vector2i((pos/24.0).floor())-offset())
	return "johto_%03d" % header if header!=0 else ""

static func title_at(pos: Vector2) -> String:
	var header:=collection().header_at(scene(),Vector2i((pos/24.0).floor())-offset())
	return collection().title(header) if header!=0 else ""

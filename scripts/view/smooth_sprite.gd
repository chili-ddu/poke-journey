class_name SmoothSprite
extends RefCounted

# Baked passing poses affect drawing only. Logical frame numbers,
# collision/attack markers and animation duration always use the source sheet.
static var enabled := OS.get_environment("SMOOTH_SPRITES") != "0"
static var _manifest: Dictionary = {}
static var _loaded := false
static var _textures: Dictionary = {}
static var _pokemon_profiles: Dictionary = {}
const PROFILE_LIMIT := 32
const TEXTURE_LIMIT := 96

# Parse the catalog while an actor is being set up, not on its first changing
# pose. The generated images themselves remain lazy-loaded.
static func prepare() -> void:
	if _loaded: return
	_loaded = true
	var path := "res://assets/smooth/manifest.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			# NPC/UI/FX retain their existing four-step catalog. Pokémon use
			# their own native two-step profiles, loaded by participating species.
			for source: String in parsed:
				if not source.begins_with("res://assets/sprites/"):
					_manifest[source] = parsed[source]

static func prepare_pokemon(dex: int) -> void:
	prepare()
	if _pokemon_profiles.has(dex): return
	if _pokemon_profiles.size() >= PROFILE_LIMIT:
		var oldest: int = _pokemon_profiles.keys()[0]
		for source: String in _pokemon_profiles[oldest]: _manifest.erase(source)
		_pokemon_profiles.erase(oldest)
	_pokemon_profiles[dex] = []
	var path := "res://assets/motion_2x/%04d.json" % dex
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_manifest.merge(parsed, true)
			_pokemon_profiles[dex] = parsed.keys()

static func pokemon_centers(source: String, torso: bool = false) -> Array:
	if not source.begins_with("res://assets/sprites/"): return []
	prepare_pokemon(int(source.get_slice("/", 4)))
	var entry: Dictionary = _manifest.get(source, {})
	var result: Array = []
	for row: Array in entry.get("flight_centers" if torso else "centers", []):
		var centers: Array = []
		for point: Array in row: centers.append(Vector2(float(point[0]), float(point[1])))
		result.append(centers)
	return result

static func between(tex: Texture2D, src: Rect2, next: Rect2, progress: float, next_tex: Texture2D = null, source_path: String = "", timed: bool = true) -> Dictionary:
	var original := {"tex": tex, "src": src}
	if not enabled or tex == null or (src == next and (next_tex == null or next_tex == tex)):
		return original
	prepare()
	var source := source_path if source_path != "" else tex.resource_path
	if source.begins_with("res://assets/sprites/"):
		prepare_pokemon(int(source.get_slice("/", 4)))
	if not _manifest.has(source): return original
	var entry: Dictionary = _manifest[source]
	var size := Vector2(float(entry.size[0]), float(entry.size[1]))
	# Callers may crop a frame (grass occlusion/title icons). Find its whole
	# source cell and apply the identical crop within the generated atlas.
	var start := (src.position / size).floor() * size
	var end := (next.position / size).floor() * size
	var key := "%d,%d,%d,%d" % [int(start.x), int(start.y), int(end.x), int(end.y)]
	if next_tex != null and next_tex != tex:
		key += "@" + next_tex.resource_path.trim_prefix("res://")
	if not entry.pairs.has(key): return original
	var steps := int(entry.get("steps", 4))
	var phase := clampi(int(progress * steps), 0, steps - 1)
	if steps == 2:
		var hold := float(entry.get("holds", {}).get(key, 0.5)) if timed else 0.5
		phase = 1 if progress >= hold else 0
	if phase == 0: return original
	var sheet: String = entry.sheet
	if not _textures.has(sheet):
		if _textures.size() >= TEXTURE_LIMIT: _textures.erase(_textures.keys()[0])
		if ResourceLoader.exists(sheet):
			_textures[sheet] = load(sheet)
		elif FileAccess.file_exists(sheet):
			var image := Image.load_from_file(sheet)
			if image == null: return original
			_textures[sheet] = ImageTexture.create_from_image(image)
		else: return original
	var slot := int(entry.pairs[key]) + phase - 1
	var cols := int(entry.cols)
	var at := Vector2(slot % cols, slot / cols) * size
	var visual := {"tex": _textures[sheet], "src": Rect2(at + src.position - start, src.size), "phase_weight": float(phase) / steps}
	if steps == 2:
		visual.phase_weight = float(entry.get("weights", {}).get(key, 0.5))
		var delta: Array = entry.get("deltas", {}).get(key, [0, 0, 0, 0])
		visual.body_delta = Vector2(float(delta[0]), float(delta[1]))
		visual.torso_delta = Vector2(float(delta[2]), float(delta[3]))
	return visual

static func horizontal(tex: Texture2D, size: Vector2, first: int, next: int, progress: float) -> Dictionary:
	return between(tex, Rect2(Vector2(first * size.x, 0), size), Rect2(Vector2(next * size.x, 0), size), progress)

static func vertical(tex: Texture2D, size: Vector2, first: int, next: int, progress: float, source_path: String = "") -> Dictionary:
	return between(tex, Rect2(Vector2(0, first * size.y), size), Rect2(Vector2(0, next * size.y), size), progress, null, source_path)

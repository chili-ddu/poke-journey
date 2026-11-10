extends RefCounted

## Original HGSS art fitted to the existing FRLG gameplay footprints.
const BASE := "res://assets/maps/hgss_render/"
const Palette = preload("res://scripts/view/map_palette.gd")
static var enabled := OS.get_environment("HGSS_ART") != "0"
static var _manifest: Dictionary = {}
static var _maps: Dictionary = {}
static var _models: Dictionary = {}
static var _textures: Dictionary = {}
static var _tree_texture: Texture2D
const MODEL_CACHE_LIMIT := 48

static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(BASE + "manifest.json"):
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json"))
	return _manifest

static func replacements(map_dir: String) -> Dictionary:
	if not enabled: return {}
	var id := map_dir.get_file()
	if not _maps.has(id):
		var path: String = manifest().get("maps",{}).get(id,"")
		_maps[id] = JSON.parse_string(FileAccess.get_file_as_string(path)) if not path.is_empty() else {}
	return _maps[id]

static func surface(map_dir: String, file: String, fallback: Texture2D = null) -> Texture2D:
	var path: String = manifest().get("terrain",{}).get(map_dir.get_file(),{}).get(file,"") if enabled else ""
	if path.is_empty():
		if fallback != null: return fallback
		var original := map_dir+"/"+file
		return load(original if ResourceLoader.exists(original) else map_dir+"/bottom.png")
	if _textures.has(path): return _textures[path]
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK: return fallback
	if _textures.size() >= 12: _textures.erase(_textures.keys()[0])
	var texture := ImageTexture.create_from_image(image)
	_textures[path]=texture
	return texture

static func tree_texture() -> Texture2D:
	if not enabled: return null
	if _tree_texture == null:
		var path := "res://assets/maps/hgss_pallet_sample/models/terrain_0201_018/tree01gs.png"
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK: return null
		image=image.get_region(image.get_used_rect())
		_tree_texture=Palette.texture(ImageTexture.create_from_image(image))
	return _tree_texture

static func remaining_cards(map_dir: String, cards: Array) -> Array:
	var remove := PackedInt32Array(replacements(map_dir).get("skip_cards",[]))
	if remove.is_empty(): return cards
	var result: Array = []
	for i in cards.size():
		if not remove.has(i): result.append(cards[i])
	return result

static func replaces_house(map_dir: String, index: int) -> bool:
	return PackedInt32Array(replacements(map_dir).get("skip_houses",[])).has(index)

static func model(path: String) -> PackedScene:
	if _models.has(path): return _models[path]
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path,state) != OK:
		push_error("Unable to read HGSS environment model: " + path)
		return null
	var node := document.generate_scene(state)
	materials(node)
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	if _models.size() >= MODEL_CACHE_LIMIT: _models.erase(_models.keys()[0])
	_models[path] = packed
	return packed

static func materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material is BaseMaterial3D:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				if material.albedo_texture != null: material.albedo_texture = Palette.texture(material.albedo_texture)
	for child in node.get_children(): materials(child)

static func build(view: CanvasLayer, map_dir: String) -> int:
	var count := 0
	for spec in replacements(map_dir).get("buildings",[]):
		var packed := model(spec.asset)
		if packed == null: continue
		var node := packed.instantiate() as Node3D
		# The source coordinates are DS units. Fit the complete native shell
		# inside the existing solid area with its doorway at the actual warp.
		node.scale = Vector3(spec.scale[0],spec.scale[1],spec.scale[2]) / 16.0
		node.position = Vector3(spec.position[0],spec.position[1],spec.position[2])
		node.position.y += Arena.ground_height(Vector2(spec.door[0],spec.door[1])*Arena.TILE)
		node.set_meta("hgss_door",Vector2(spec.door[0],spec.door[1]))
		view.root3d.add_child(node)
		count += 1
	return count

extends Node3D

# One tile beyond a cell boundary is already visible from the previous cell.
# Keep its eight neighbors resident, including corners seen by the tilted camera.
const CELL := 32
const CACHE := "res://assets/maps/kanto_world/terrain_chunks"
var active := {}
var _pending: Array[Vector2i] = []
var _center := Vector2i.MAX
var _bounds: Rect2i
var _view: View3D
var _map_dir: String
var _cards := {}
var _grass_blades := {}
var _buildings := {}
var _boxes := {}
var _tile_size: int
var _corners := {}

static func cell_at(tile: Vector2) -> Vector2i:
	return Vector2i((tile / CELL).floor())

static func mesh_path(cell: Vector2i) -> String:
	return CACHE.path_join("%d_%d.res" % [cell.x, cell.y])

func setup(view: View3D, map_dir: String, scenery: Dictionary) -> void:
	_view = view
	_map_dir = map_dir
	_bounds = Rect2i(0, 0, Arena.map.width, Arena.map.height).grow(Arena._pad)

	_tile_size = scenery.tile
	var cards := View3D.HgssEnvironment.remaining_cards(map_dir, scenery.cards)
	# The original metadata is also used by the source-map renderer.
	# Keep its UVs intact when loading the compact atlas for this view.
	if scenery.get("corner_walls", []).is_empty():
		cards = _compact_cards(cards)
	for key in ["houses", "props", "tables", "log_fences"]:
		var specs: Array = scenery.get(key, [])
		for i in specs.size():
			var spec: Dictionary = specs[i]
			var at: Vector2
			match key:
				"houses":
					if View3D.HgssEnvironment.replaces_house(map_dir, i): continue
					at = Vector2(spec.x + spec.w/2.0, spec.z)
				"props": at = Vector2((spec.x0+spec.x1)/2.0, spec.z)
				"tables": at = Vector2((spec.x0+spec.x1)/2.0, spec.z1)
				"log_fences": at = Vector2(spec.posts[0][0], spec.posts[0][1])
			_index_building(cell_at(at), key, spec)
	for spec in View3D.HgssEnvironment.replacements(map_dir).get("buildings", []):
		_index_building(cell_at(Vector2(spec.door[0], spec.door[1])), "models", spec)
	if scenery.has("museum_stairs"):
		var stairs: Dictionary = scenery.museum_stairs
		_index_building(cell_at(Vector2(stairs.x0, stairs.z0)), "stairs", stairs)
	# Group each tree before partitioning so its crown shares one root across seams.
	for tree in View3D.TreeCanopy.groups(cards):
		var cell := cell_at(Vector2(tree.x + tree.width * 0.5, tree.z))
		if not _cards.has(cell): _cards[cell] = []
		_cards[cell].append_array(tree.columns)
	for card: Array in View3D._ledge_card_fragments(cards):
		var kind := int(card[9]) if card.size() > 9 else 0
		if kind == 1: continue
		var x := int(card[0])
		var height := int(card[2])
		var z := int(card[1]) + height - View3D._ovf(card)
		if card.size() > 7 and float(card[7]) > 0:
			var tile := Vector2i(x, z - 1)
			if Arena.is_grass(tile): _grass_blades[tile] = true
		var roof := float(card[5]) if card.size() > 5 else 0.0
		if roof > 0 and (height >= 4 or kind == 2):
			_boxes["%d:%d" % [x,z]] = View3D.box_profile(card)
		var cell := cell_at(Vector2(x + 0.5, z - 0.5))
		if not _cards.has(cell): _cards[cell] = []
		_cards[cell].append(card)
	for corner in scenery.get("corner_walls", []):
		var cell := cell_at(Vector2(corner.column, 0))
		if not _corners.has(cell): _corners[cell] = []
		_corners[cell].append(corner)

# On HGSS mainland art the ground is plain lawn. The upright foliage is a
# separate card and can be absent at a seam even on a native encounter tile.
func shows_grass_at(tile: Vector2i) -> bool:
	return not View3D.HgssEnvironment.enabled or Arena.native_at(tile) or _grass_blades.has(tile)

func _index_building(cell: Vector2i, kind: String, spec: Dictionary) -> void:
	if not _buildings.has(cell): _buildings[cell] = {}
	var entry: Dictionary = _buildings[cell]
	if not entry.has(kind): entry[kind] = []
	entry[kind].append(spec)

func _compact_cards(cards: Array) -> Array:
	var path := _map_dir.path_join("card_atlas.res")
	if not ResourceLoader.exists(path): return cards
	var atlas := load(path) as Resource
	var offsets: Dictionary = atlas.get_meta("offsets")
	var result := []
	for card: Array in cards:
		var uv := Vector2i(card[3], card[4])
		if not offsets.has(uv): return cards
		var offset: Vector2i = offsets[uv]
		var copy := card.duplicate()
		copy[3] = offset.x
		copy[4] = offset.y
		result.append(copy)
	var image := Image.new()
	var key := "hgss_png" if View3D.HgssEnvironment.enabled else "original_png"
	if image.load_png_from_buffer(atlas.get_meta(key)) != OK: return cards
	if View3D.MapPalette.enabled: image = View3D.MapPalette.surface(image)
	_view._card_atlas = ImageTexture.create_from_image(image)
	_view._fence_image = image
	return result

func stream(tile: Vector2) -> void:
	var center := cell_at(tile)
	if center != _center:
		# Walking enters an already loaded neighbor. Fill the new outer strip
		# over subsequent frames. Fast travel needs the new view immediately.
		var neighboring := active.has(center)
		_center = center
		_pending.clear()
		var window := Rect2i(center - Vector2i.ONE, Vector2i(3, 3))
		for cell: Vector2i in active.keys():
			if not window.has_point(cell):
				active[cell].queue_free()
				active.erase(cell)
		for y in range(window.position.y, window.end.y):
			for x in range(window.position.x, window.end.x):
				var cell := Vector2i(x, y)
				if active.has(cell) or not _bounds.intersects(Rect2i(cell * CELL, Vector2i.ONE * CELL)): continue
				_pending.append(cell)
		if not neighboring:
			for cell in _pending: _load_cell(cell)
			_pending.clear()
	if not _pending.is_empty(): _load_cell(_pending.pop_front())

func _load_cell(cell: Vector2i) -> void:
	var chunk := load(mesh_path(cell)) as PackedScene
	if chunk == null: return
	var group := chunk.instantiate() as Node3D
	var ground := _ground(group, cell)
	for part: MeshInstance3D in group.get_children():
		part.material_override = _view.road_material(_map_dir, true) if part.name == &"RoadLedgeWalls" else ground
	var old_grounding := _view._ground_static_geometry
	_view._ground_static_geometry = true
	if _cards.has(cell) or _corners.has(cell):
		var scenery := {"tile":_tile_size, "cards":_cards.get(cell, []), "corner_walls":_corners.get(cell, [])}
		_view._draw_cards(_map_dir, scenery, scenery.cards, scenery.cards, group, _boxes)
	if _buildings.has(cell):
		var entries: Dictionary = _buildings[cell]
		if entries.has("stairs"): entries.museum_stairs = entries.stairs[0]
		_view._draw_houses(_map_dir, entries, entries.get("houses", []), group)
		View3D.HgssEnvironment.build_models(group, entries.get("models", []))
	_view._ground_static_geometry = old_grounding
	add_child(group)
	active[cell] = group

# Vertices retain their original world UVs so the generated ledge rims and
# floor match pixel-for-pixel. Map that range onto this cell's source crop.
func _ground(group: Node3D, cell: Vector2i) -> StandardMaterial3D:
	var image := Image.new()
	var key := "hgss_floor_png" if View3D.HgssEnvironment.enabled and group.has_meta("hgss_floor_png") else "floor_png"
	var error := image.load_png_from_buffer(group.get_meta(key))
	if error != OK:
		push_error("Cannot decode Kanto ground at %s: %s" % [cell, error_string(error)])
		return null
	if View3D.MapPalette.enabled: image = View3D.MapPalette.surface(image)
	var material := View3D.road_ground_material(ImageTexture.create_from_image(image))
	var area := Rect2i(cell * CELL, Vector2i.ONE * CELL).intersection(_bounds)
	var scale_uv := Vector2(_bounds.size) / Vector2(area.size)
	var offset_uv := Vector2(_bounds.position - area.position) / Vector2(area.size)
	material.uv1_scale = Vector3(scale_uv.x, scale_uv.y, 1)
	material.uv1_offset = Vector3(offset_uv.x, offset_uv.y, 0)
	material.texture_repeat = false
	return material

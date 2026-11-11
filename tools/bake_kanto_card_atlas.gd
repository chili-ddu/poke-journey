extends RefCounted

# The combined atlas contains entire source maps, including large empty areas.
# Pack the actual 16-pixel strips, keeping their original pixels and one-pixel
# neighbors so nearest-filtered seams sample the same colors.
static func bake(map_dir: String) -> Error:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map_dir.path_join("hd2d_cards.json")))
	var heights := {}
	var tile := int(data.tile)
	for card in data.cards:
		var origin := Vector2i(card[3], card[4])
		heights[origin] = maxi(heights.get(origin, 0), int(card[2]) * tile)
	var offsets := {}
	var columns := PackedInt32Array()
	columns.resize(64)
	for origin: Vector2i in heights:
		var column := 0
		for i in range(1, columns.size()):
			if columns[i] < columns[column]: column = i
		offsets[origin] = Vector2i(column * (tile+2), columns[column]) + Vector2i.ONE
		columns[column] += int(heights[origin]) + 2
	var size := Vector2i(columns.size() * (tile+2), 0)
	for height in columns: size.y = maxi(size.y, height)
	var resource := Resource.new()
	resource.set_meta("offsets", offsets)
	var alternate: String = View3D.HgssEnvironment.manifest().terrain.kanto_world["hd2d_atlas.png"]
	for path: String in [map_dir.path_join("hd2d_atlas.png"), alternate]:
		var source := Image.new()
		var error := source.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		if error != OK: return error
		source.convert(Image.FORMAT_RGBA8)
		var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		for origin: Vector2i in heights:
			var rect := Rect2i(origin, Vector2i(tile, heights[origin])).grow(1)
			var clipped := rect.intersection(Rect2i(Vector2i.ZERO, source.get_size()))
			image.blit_rect(source, clipped, Vector2i(offsets[origin])-Vector2i.ONE + clipped.position-rect.position)
		resource.set_meta("hgss_png" if path == alternate else "original_png", image.save_png_to_buffer())
	return ResourceSaver.save(resource, map_dir.path_join("card_atlas.res"), ResourceSaver.FLAG_COMPRESS)

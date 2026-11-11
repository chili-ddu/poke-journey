extends SceneTree

# Rebuild after changing the combined Kanto elevation, ledge patches or terrain mesher.
# godot --headless -s tools/bake_kanto_terrain.gd
const Stream = preload("res://scripts/view/kanto_terrain_stream.gd")
const MAP := "res://assets/maps/kanto_world"

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var atlas_error := preload("res://tools/bake_kanto_card_atlas.gd").bake(MAP)
	if atlas_error != OK or "--atlas-only" in OS.get_cmdline_user_args():
		quit(atlas_error)
		return
	Arena.configure({"map":MAP})
	var source := Arena.map.duplicate()
	source.pad = Arena._pad
	var bounds := Rect2i(0, 0, source.width, source.height).grow(source.pad)
	# Preserve both selectable art sets. Use source PNGs to avoid GPU readback.
	var source_floor := Image.new()
	var source_error := source_floor.load_png_from_buffer(FileAccess.get_file_as_bytes(MAP.path_join("elevation_floor.png")))
	var hgss_path: String = View3D.HgssEnvironment.manifest().terrain.kanto_world["elevation_floor.png"]
	var hgss_floor := Image.new()
	var hgss_error := hgss_floor.load_png_from_buffer(FileAccess.get_file_as_bytes(hgss_path))
	if source_error != OK or hgss_error != OK or source_floor.get_size() != hgss_floor.get_size():
		push_error("Missing or mismatched Kanto ground textures")
		quit(1)
		return
	var pixels := source_floor.get_size() / bounds.size
	var patches := {}
	for tile: Vector2i in Arena._ledge_patches:
		var cell := Stream.cell_at(Vector2(tile))
		if not patches.has(cell): patches[cell] = []
		patches[cell].append(tile)
	var view := View3D.new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Stream.CACHE))
	var first := Stream.cell_at(bounds.position)
	var last := Stream.cell_at(bounds.end - Vector2i.ONE)
	for y in range(first.y, last.y+1):
		for x in range(first.x, last.x+1):
			var cell := Vector2i(x, y)
			var area := Rect2i(cell * Stream.CELL, Vector2i.ONE * Stream.CELL).intersection(bounds)
			var group := Node3D.new()
			view._build_elevated_road(MAP, source, area, patches.get(cell, []), group)
			for part: MeshInstance3D in group.get_children():
				part.material_override = null
				part.owner = group
			var rect := Rect2i((area.position - bounds.position) * pixels, area.size * pixels)
			var original := source_floor.get_region(rect).save_png_to_buffer()
			var hgss := hgss_floor.get_region(rect).save_png_to_buffer()
			group.set_meta("floor_png", original)
			if hgss != original: group.set_meta("hgss_floor_png", hgss)
			var chunk := PackedScene.new()
			var error := chunk.pack(group)
			if error == OK: error = ResourceSaver.save(chunk, Stream.mesh_path(cell), ResourceSaver.FLAG_COMPRESS)
			group.free()
			if error != OK:
				push_error("Failed baking Kanto cell %s: %s" % [cell, error_string(error)])
				view.free()
				quit(1)
				return
	view.free()
	print("Baked Kanto terrain from ", first, " to ", last)
	quit()

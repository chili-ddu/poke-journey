extends SceneTree

const Preview = preload("res://scripts/johto/hgss_map_preview.gd")
var preview: Node3D
var out := "res://docs/johto_maps/"

func _init() -> void:
	run.call_deferred()

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	preview = load("res://scenes/johto_map_preview.tscn").instantiate()
	root.add_child(preview)
	preview.automatic_portals = false
	for i in 12: await process_frame
	print("HGSS viewport ", root.get_visible_rect(), " window ", root.size, " scale ", root.content_scale_size,
		" UI ", preview.info.get_global_transform_with_canvas(), " text ", preview.info.text, " visible ", preview.info.is_visible_in_tree())
	await shot("01_new_bark")
	var selected: Array = []
	for name in ["MAP_CHERRYGROVE", "MAP_VIOLET", "MAP_AZALEA", "MAP_GOLDENROD", "MAP_OLIVINE", "MAP_ECRUTEAK", "MAP_CIANWOOD", "MAP_MAHOGANY", "MAP_BLACKTHORN", "MAP_ICE_PATH_1F", "MAP_BELL_TOWER_1F", "MAP_WHIRL_ISLANDS_1F", "MAP_NEW_BARK_ELMS_LAB_1F"]:
		for key in preview.collection.manifest.headers:
			if preview.collection.manifest.headers[key].constant == name: selected.append(int(key))
	for id in selected:
		preview.visit(id)
		for i in 6: await process_frame
		await shot("map_%03d" % id)
	preview.visit(60)
	for i in 4: await process_frame
	var scene: Dictionary = preview.data
	var portal: Dictionary = {}
	for warp in scene.warps:
		if int(warp.header) == 60 and int(warp.to_header) == 61: portal = warp
	assert(not portal.is_empty())
	preview.automatic_portals = true
	preview.move_by(Vector2(float(portal.x) + 0.5, float(portal.z) + 0.5) - preview.position_2d)
	for i in 4: await process_frame
	assert(preview.header == 61)
	await shot("02_lab_arrival")
	var back: Dictionary = {}
	for warp in preview.data.warps:
		if int(warp.header) == 61 and int(warp.to_header) == 60: back = warp
	preview.move_by(preview.collection.spawn(61) - preview.position_2d)
	for i in 2: await process_frame
	preview.move_by(Vector2(float(back.x) + 0.5, float(back.z) + 0.5) - preview.position_2d)
	for i in 4: await process_frame
	assert(preview.header == 60)
	assert(root.size == Vector2i(384, 216))
	await shot("03_return_new_bark")
	preview.picker.popup_centered(Vector2i(364, 196))
	for i in 4: await process_frame
	await shot("04_map_picker")
	preview.picker.hide()
	var report := FileAccess.open(out + "native_review.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"window": [384, 216], "representative_headers": selected, "laboratory_walk_roundtrip": true, "embedded_picker": true, "save_access": false}))
	report.close()
	print("HGSS native review: %d representative locations, laboratory roundtrip, embedded picker, 384x216; no save access" % selected.size())
	preview.free()
	quit()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + name + ".png")

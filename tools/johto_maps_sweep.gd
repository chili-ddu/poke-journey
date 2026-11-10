extends SceneTree

var preview: Node3D

func _init() -> void:
	run.call_deferred()

func run() -> void:
	await CaptureWindow.park(self)
	preview = load("res://scenes/johto_map_preview.tscn").instantiate()
	root.add_child(preview)
	preview.automatic_portals = false
	var checked: Array = []
	for key in preview.collection.manifest.headers:
		var id := int(key)
		preview.visit(id)
		for i in 3: await process_frame
		assert(preview.header == id, "wrong physical header after loading " + str(id))
		assert(preview.loaded_chunks.size() > 0, "missing geometry " + str(id))
		assert(preview.actor.position.is_finite())
		assert(root.size == Vector2i(384, 216))
		checked.append({"header": id, "scene": preview.scene_id, "chunks": preview.loaded_chunks.size(), "ground": preview.ground_y})
		if checked.size() % 50 == 0: print("HGSS native sweep: ", checked.size(), " locations loaded")
	var file := FileAccess.open("res://docs/johto_maps/native_sweep.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"window": [384, 216], "checked": checked, "save_access": false}))
	file.close()
	print("HGSS native sweep passed: ", checked.size(), " locations, no user saves")
	preview.free()
	quit()

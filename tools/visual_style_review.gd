extends SceneTree

var out := "res://docs/visual_style_review/"
var sample: Node3D
const LOCATIONS := [{"id":117,"name":"forest"},{"id":99,"name":"cave"},{"id":76,"name":"city"}]

func _init() -> void:
	run.call_deferred()

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var reports: Array = []
	for location in LOCATIONS:
		OS.set_environment("HGSS_HEADER", str(location.id))
		var start := Vector2.ZERO
		for raw in [true, false]:
			sample = load("res://scenes/visual_style_sample.tscn").instantiate()
			sample.raw_art = raw
			root.add_child(sample)
			sample.automatic_portals = false
			if int(location.id) == 99:
				# Review the cave floor beyond the original entrance light cone.
				sample.position_2d = Vector2(19.5, 48.5)
			elif int(location.id) == 76:
				sample.position_2d = Vector2(358.5, 366.5)
			elif int(location.id) == 117:
				sample.position_2d = Vector2(20.5, 68.5)
			assert(sample.collection.can_stand(sample.data,Vector2i(sample.position_2d.floor())))
			for i in 15: await process_frame
			assert(sample.header == int(location.id))
			assert(sample.sample_game.world.player.level == 5)
			assert(sample.sample_game.world.player.hp == 18)
			assert(sample.hud.game == sample.sample_game)
			assert(root.size == Vector2i(384,216))
			if raw: start = sample.position_2d
			else: assert(sample.position_2d == start)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out + location.name + ("_source.png" if raw else "_styled.png"))
			if not raw:
				var tile := Vector2i(start.floor())
				var moved := false
				for dir in [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP]:
					if not sample.collection.can_stand(sample.data,tile+dir):continue
					if not sample.collection.portal(sample.data,tile+dir).is_empty():continue
					sample.move_by(Vector2(dir)*0.5)
					moved=sample.position_2d.distance_to(start)>0.2
					if moved:break
				assert(moved,"No safe native movement at " + location.name)
				reports.append({"header":location.id,"profile":sample.current_profile(),"position":[start.x,start.y],
					"native_movement":moved,"ground_y":sample.ground_y,"loaded_chunks":sample.loaded_chunks.size(),
					"hp":sample.sample_game.world.player.hp,"hud":"current","actor":"current Mon draw"})
			sample.free()
			await process_frame
	var file := FileAccess.open(out+"checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"window":[384,216],"locations":reports,"save_access":false,"gameplay_replaced":false}))
	file.close()
	print("Visual style review passed: forest/cave/city source and styled pairs, current actor/HUD, original collision movement, 384x216")
	quit()

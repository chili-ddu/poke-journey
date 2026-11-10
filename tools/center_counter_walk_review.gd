extends SceneTree
const Model := preload("res://tools/counter_review_model.gd")
var OUT := "res://docs/source_object_audit/center_masks/counter_restored/map_review/"
var game: Node
var results: Array = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var production := OS.get_environment("COUNTER_PRODUCTION") == "1"
	if production:
		OUT = "res://docs/center_counter_integrated/"
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","1")
	for place in ["viridian_center","pewter_center"]:
		OS.set_environment("DUNGEON",place)
		game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		await process_frame
		game.banner_t = 0
		game.stream.clear()
		assert(game.view3d != null)
		var view: View3D = game.view3d
		if not production:
			var removed := 0
			for child in view.root3d.get_children():
				if child is MeshInstance3D and child.mesh is ArrayMesh:
					for i in child.mesh.get_surface_count():
						# Palette conversion may replace the texture with an ImageTexture.
						var bounds: AABB = child.mesh.get_aabb()
						if is_equal_approx(bounds.position.x,4.0) and is_equal_approx(bounds.size.x,7.0) and is_equal_approx(bounds.end.z,4.0):
							child.visible = false
							removed += 1
							break
			assert(removed == 1, "Exactly one existing counter must be replaced")
			view.root3d.add_child(Model.build())
		for entry in [["front",Vector2(7.5,4.5)],["left",Vector2(3.5,3.5)],["right",Vector2(11.5,3.5)],["inside",Vector2(8.5,2.5)]]:
			var requested: Vector2 = entry[1]*Arena.TILE
			var resolved := Arena.resolve(requested,game.world.player.radius)
			game.world.player.position = resolved
			game.world.player.facing = Vector2.DOWN
			for i in 30:
				game.world.step_visual(1.0/60)
				await process_frame
			await shot(place+"_"+entry[0])
			results.append({"map":place,"case":entry[0],"requested":str(requested),"resolved":str(resolved),"displaced":requested.distance_to(resolved)})
		# Walk collision sweeps along public front and side aisles using actual radius/resolve.
		for route in [["front",Vector2(3.5,4.5),Vector2(11.5,4.5)],["left",Vector2(3.5,4.5),Vector2(3.5,3.0)],["right",Vector2(11.5,4.5),Vector2(11.5,3.0)]]:
			var blocked := 0
			for i in 97:
				var p: Vector2 = route[1].lerp(route[2],i/96.0)*Arena.TILE
				if p.distance_to(Arena.resolve(p,game.world.player.radius)) > 0.01:
					blocked += 1
			results.append({"map":place,"route":route[0],"samples":97,"blocked_samples":blocked,"player_radius":game.world.player.radius})
		# Orbit just the camera to expose inner/back/side faces, with real map intact.
		view.set_process(false)
		for side in [-1,1]:
			view.cam.position = Vector3(7.5+side*7,7,0)
			view.cam.look_at(Vector3(7.5,0.4,3))
			# Recompute camera-relative sprite offsets after the diagnostic orbit.
			var seen := {}
			view._sync_mon(game.world.player, seen)
			for npc in game.world.npcs:
				view._sync_npc(npc, seen)
			for i in 8:
				await process_frame
			await shot(place+"_rear_"+str(side))
		game.queue_free()
		await process_frame
	var file := FileAccess.open(OUT+"review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results,"geometry":"top + source front + seven inferred perimeter faces; height 0.5; front z4", "limitations":["Production model" if production else "Runtime-only replacement; original assets and collision unchanged","Inside position is a placement probe, not a reachable player route","Collision sweeps use Arena.resolve only, not NPC interaction"]},"  "))
	print("Map review complete: ",results)
	quit()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+label+".png")==OK)
	print(label)

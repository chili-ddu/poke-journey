extends SceneTree
func _init() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT", "1")
	OS.set_environment("GOD", "1")
	OS.set_environment("SEED", "1")
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	for place in ["viridian_mart", "pewter_mart"]:
		OS.set_environment("DUNGEON", place)
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		await process_frame
		game.banner_t = 0
		game.hud.visible = false
		for entry in [["front", Vector2(4.5,6.5)], ["clerk", Vector2(4.5,3.5)], ["right", Vector2(6.5,5.5)]]:
			game.world.player.position = Arena.resolve(entry[1] * Arena.TILE, game.world.player.radius)
			game.view3d._cam_ready = false
			for frame in 20:
				game.world.step_visual(1.0 / 60.0)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out + "/" + place + "_" + entry[0] + ".png")
		var p: Player = game.world.player
		for route in [[Vector2(4.5,3.5),Vector2(4.5,7.5)],[Vector2(4.5,5.5),Vector2(6.5,5.5)],[Vector2(9.5,3.5),Vector2(9.5,7.5)],[Vector2(4.5,7.5),Vector2(9.5,7.5)]]:
			for step in 49:
				var at: Vector2 = route[0].lerp(route[1],step/48.0)*Arena.TILE
				assert(at.distance_to(Arena.resolve(at,p.radius))<0.01,"Public aisle clear: "+str(at/Arena.TILE))
		p.position = Arena.tile_center(Vector2i(4,3))
		var clerk: Npc = game.npc_in_reach()
		assert(clerk != null,"Clerk reachable from aisle")
		p.bag = {"oran_berry":5,"light_ball":1}
		game._talk(clerk)
		assert(game.state=="menu" and game.menu=="shop")
		game._resolve_menu(game.menu_ids.find("antidote"))
		assert(game.menu=="shop_confirm")
		game._resolve_menu(1)
		assert(p.bag=={"oran_berry":5,"light_ball":1},"Cancel leaves inventory intact")
		game._resolve_menu(game.menu_ids.find("antidote"))
		game._resolve_menu(0)
		assert(p.bag.get("antidote",0)==1 and not p.bag.has("light_ball") and p.bag.get("oran_berry",0)==5,"Exchange deducts agreed items once")
		game._resolve_menu(game.menu_ids.find("potion"))
		assert(game.menu=="shop" and p.bag.get("antidote",0)==1,"Insufficient value cannot exchange")
		game._close_menu()
		assert(game.state=="town")
		print(place+": aisle, clerk, cancel, exchange, insufficient value, close OK")
		game.free()
		await process_frame
	print("mart structure review OK")
	quit()

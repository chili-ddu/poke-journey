extends SceneTree
func _init() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","1")
	var out := OS.get_cmdline_user_args()[0]
	var cases := [["lab_shelf","oaks_lab",Vector2(9.5,7.7)], ["lab_machine","oaks_lab",Vector2(1.5,3.5)], ["lab_left_wall","kanto_south",Vector2(24,211)], ["tail_north","kanto_south",Vector2(23,209)]]
	var report := []
	for row in cases:
		OS.set_environment("DUNGEON",row[1])
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		await process_frame
		var w: World = game.world
		w.player.position = row[2]*Arena.TILE
		w.player.facing = Vector2.UP
		game.banner_t = 0
		game.view3d._cam_ready = false
		for i in 30:
			w.step_visual(1.0/60)
			await process_frame
		for frame in 3:
			w.step_visual(0.12)
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"/"+row[0]+"_"+str(frame)+".png")
		var ent: Dictionary = game.view3d._sprites[w.player.get_instance_id()]
		report.append({"case":row[0],"center_blocked":Arena.blocks(w.player.position,0),"cue":ent.has("occlusion_cue"),"light_shadow":ent.light.shadow_enabled if ent.has("light") else false})
		if row[0]=="lab_machine":
			game.view3d.set_process(false)
			for node in ent.values():
				if node is Node3D: node.visible = false
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"/lab_machine_hidden.png")
		game.free()
		await process_frame
	FileAccess.open(out+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit()

extends "res://tools/material_hit_fx_review.gd"

const DIRECTORY := "res://docs/charmander_move_audit/no-target/"

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path = "user://save_charmander_empty_cast_review.cfg"
	var settings := {"BOT":"1","GOD":"1","SEED":"7","STARTER":"charmander","DUNGEON":"kanto_south"}
	for key in settings: OS.set_environment(key, settings[key])
	FxStyle.set_mode("custom")
	var rows := []
	for pair in SpeciesDB.get_species("charmander").learnset:
		var move := String(pair[1])
		seed(7)
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		game.set_process(false)
		game.ui_root.visible = false
		game.stream.clear()
		game.view3d.set_process(false)
		var w: World = game.world
		w.player.setup_player("charmander",40,[move])
		w.player.position = open_cross() - Vector2.RIGHT * 30
		w.player.facing = Vector2.RIGHT
		var input := ReviewInput.new() # A null target aims 48 world pixels forward.
		w.player.controller = input
		w.no_skills = false
		w.player.repel_steps = 100000
		game.view3d._cam_ready = false
		var folder := DIRECTORY+move+"/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		var pp_before := int(w.player.pp[0])
		var used := false
		var duration := 120 if move == "fire_spin" else (84 if move in ["smoke_screen","scary_face"] else 54)
		for frame in duration:
			if frame == 6: input.requested = true
			w.step(1.0/30)
			if not w.enemies.is_empty() or not w.pending_spawns.is_empty():
				push_error("Unexpected opponent or spawn: "+move)
				quit(1)
				return
			used = used or int(w.player.pp[0]) < pp_before
			game.view3d._process(1.0/30)
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.size == Vector2i(384,216))
			root.get_texture().get_image().save_png(folder+"%03d.png"%frame)
		if not used:
			push_error("No cast: "+move)
			quit(1)
			return
		rows.append({"move":move,"level":pair[0],"frames":duration,"opponents":0,"pp_used":used})
		print("Captured ", move, " without opponents: ",duration)
		game.free()
		current_scene = null
		await process_frame
	FileAccess.open(DIRECTORY+"captures.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()

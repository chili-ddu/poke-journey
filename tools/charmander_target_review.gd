extends "res://tools/material_hit_fx_review.gd"

const PreviewWorld = preload("res://tools/samples/charmander_target_world.gd")
const DESTINATION := "res://docs/charmander_target_review/"

func run() -> void:
	var visual := DisplayServer.get_name() != "headless"
	if visual:
		await CaptureWindow.park(self)
	var settings := {"BOT":"1","GOD":"1","SEED":"7","STARTER":"charmander","DUNGEON":"kanto_south"}
	for key in settings:
		OS.set_environment(key, settings[key])
	SaveData.path = "user://save_charmander_target_review.cfg"
	FxStyle.set_mode("custom")
	var crowd := "--crowd" in OS.get_cmdline_user_args()
	var destination := DESTINATION + "crowd/" if crowd else DESTINATION
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	var report := []
	var moves := ["scratch","ember"] if crowd else ["scratch","growl","ember","smoke_screen"]
	for move in moves:
		for variant in ["existing","sample"]:
			seed(7)
			var game = load("res://scenes/main.tscn").instantiate()
			root.add_child(game)
			current_scene = game
			game.set_process(false)
			game.stream.clear()
			game.ui_root.visible = false
			var original: World = game.world
			var w := PreviewWorld.new()
			game.add_child(w)
			game.world = w
			if visual:
				game.view3d.world = w
				game.view3d.set_process(false)
				game.view3d._cam_ready = false
			original.free()
			var input := ReviewInput.new()
			w.setup(7, "charmander", 12, [move], input)
			w.visibility_layer |= Look.GROUND_LAYER
			w.focused = crowd or variant == "sample"
			w.crowd_damage = crowd and variant == "sample"
			w.player.repel_steps = 100000
			w.player.position = open_cross() - Vector2.RIGHT * 30.0
			w.player.facing = Vector2.RIGHT
			var front := Vector2(28,0) if move == "scratch" else Vector2(40,0)
			var side := Vector2(30,-20) if move == "scratch" else Vector2(40,-22)
			var positions := [front, side]
			if crowd:
				positions = [front, side, Vector2(-28,-12)] if move == "scratch" else [Vector2(29,0), Vector2(55,0), Vector2(40,-28)]
			for offset: Vector2 in positions:
				var enemy := Enemy.new()
				enemy.setup_enemy("chansey",25,w.rng)
				enemy.frozen = true
				for id in enemy.cds: enemy.cds[id] = 9999.0
				enemy.position = w.player.position + offset
				enemy.facing = Vector2.LEFT
				w.add_child(enemy)
				w.enemies.append(enemy)
			input.target = w.enemies[0]
			var folder: String = destination + move + "/" + variant + "/"
			if visual: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			var hit_counts := []
			hit_counts.resize(positions.size())
			hit_counts.fill(0)
			for frame in 51:
				var hp_before := w.enemies.map(func(foe): return foe.hp)
				if frame == 5: input.requested = true
				w.step(1.0/30.0)
				for i in positions.size():
					if w.enemies[i].hp < hp_before[i]: hit_counts[i] += 1
				if visual:
					game.view3d._process(1.0/30.0)
					await process_frame
					await RenderingServer.frame_post_draw
					assert(root.size == Vector2i(384,216))
					root.get_texture().get_image().save_png(folder + "%03d.png" % frame)
			var victims := []
			for enemy: Enemy in w.enemies:
				victims.append([enemy.max_hp-enemy.hp, enemy.atk_stage, enemy.acc_stage])
			report.append({"move":move,"variant":variant,"victims":victims})
			if crowd:
				report.back()["damage_frames"] = hit_counts
			print(move, " ", variant, " ", victims)
			game.free()
			current_scene = null
			await process_frame
	var output := "native.json" if visual else "headless.json"
	FileAccess.open(destination+output, FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()

extends SceneTree

const Palette = preload("res://scripts/view/charmander_palette.gd")
const OUT := "res://docs/charmander_palette_review/"
var checks := 0

class Sheet:
	extends Node2D
	var anim: Dictionary
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 960, 800), Color("151d29"))
		draw_string(font, Vector2(24, 28), "CHARMANDER / OUTLINE & PALETTE / 8 DIRECTIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		for scene in 3:
			var y := 48 + scene * 224
			var background: Color = [Color("a7bb8b"), Color("454e48"), Color("bfac94")][scene]
			draw_rect(Rect2(0, y, 960, 216), background)
			for variant in 2:
				var baseline := y + variant * 104
				draw_string(font, Vector2(14, baseline + 22), "BEFORE" if variant == 0 else "AFTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("182332"))
				for row in 8:
					var raw := {"tex": anim.tex, "src": Rect2(0, row * anim.fh, anim.fw, anim.fh)}
					var visual := Look.selout_frame(raw.tex, raw.src, ["day", "forest", "indoor"][scene]) if variant == 0 else Palette.frame(raw)
					draw_texture_rect_region(visual.tex, Rect2(108 + row * 104, baseline + 4, 96, 96), visual.src)
		draw_string(font, Vector2(24, 746), "1x / before - after", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		for row in 8:
			var raw := {"tex": anim.tex, "src": Rect2(0, row * anim.fh, anim.fw, anim.fh)}
			var before := Look.selout_frame(raw.tex, raw.src)
			var after := Palette.frame(raw)
			draw_texture_rect_region(before.tex, Rect2(240 + row * 84, 736, 32, 32), before.src)
			draw_texture_rect_region(after.tex, Rect2(276 + row * 84, 736, 32, 32), after.src)

func _init() -> void: call_deferred("run")

func verify() -> void:
	var sprites := MonSprite.load_set(4)
	for name in MonSprite.ANIMS:
		if not sprites.has(name): continue
		var anim: Dictionary = sprites[name]
		var raw_anim := anim.duplicate()
		raw_anim.polished_charmander = false
		for row in anim.rows:
			for f in anim.durations.size():
				for phase in [0.0, 0.5]:
					var t: float = MonSprite.frame_start(anim, f) + float(anim.durations[f]) * MonSprite.TICK * phase
					var raw := MonSprite.visual_frame(raw_anim, row, t)
					var polished := MonSprite.display_frame(anim, row, t)
					var before: Image = raw.tex.get_image().get_region(Rect2i(raw.src))
					var after: Image = polished.tex.get_image().get_region(Rect2i(polished.src))
					assert(before.get_size() == after.get_size())
					assert(raw.body_center == polished.body_center)
					for y in before.get_height():
						for x in before.get_width():
							assert(before.get_pixel(x, y).a == after.get_pixel(x, y).a)
					assert(Look.flame_point(raw.tex, raw.src) == Look.flame_point(polished.tex, polished.src))
					assert(Look.selout_frame(polished.tex, polished.src).tex == polished.tex)
					checks += 1
	for pair in [[4, true]]:
		var anim: Dictionary = MonSprite.load_set(pair[0], pair[1]).Walk
		var visual := MonSprite.display_frame(anim, 0, 0.0)
		assert(visual.tex == anim.tex)
	print("Palette checks passed: %d source/interpolated frames; alpha, anchors, flame markers and shiny preserved" % checks)

func run() -> void:
	verify()
	if "--check-only" in OS.get_cmdline_user_args():
		quit()
		return
	await CaptureWindow.park(self)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var sheet := Sheet.new()
	sheet.anim = MonSprite.load_set(4).Idle
	viewport.add_child(sheet)
	for i in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport.get_texture().get_image().save_png(OUT + "comparison.png")
	if "--game" in OS.get_cmdline_user_args():
		viewport.queue_free()
		OS.set_environment("BOT", "1")
		OS.set_environment("GOD", "1")
		OS.set_environment("STARTER", "charmander")
		OS.set_environment("DUNGEON", "players_house_2f")
		SaveData.path = "user://save_charmander_palette_review.cfg"
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		game.banner_t = 0
		game.stream.clear()
		game.world.player.position = Vector2(7.5, 4.5) * Arena.TILE
		game.world.player.facing = Vector2.DOWN
		for i in 45:
			game.world.step_visual(1.0 / 60.0)
			await process_frame
		await RenderingServer.frame_post_draw
		var entry: Dictionary = game.view3d._sprites[game.world.player.get_instance_id()]
		assert(entry.sprite.texture.get_meta("authored_palette", false))
		root.get_texture().get_image().save_png(OUT + "in_game.png")
		game.free()
	print("Saved ", OUT + "comparison.png", "; window ", DisplayServer.window_get_size())
	quit()

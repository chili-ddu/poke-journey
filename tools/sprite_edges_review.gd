extends "res://tools/charmander_skill_review.gd"
const Edges = preload("res://tools/samples/sprite_edges.gd")

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("STARTER","charmander")
	OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_sprite_edges_review.cfg"
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);current_scene=game
	game.set_process(false);game.view3d.set_process(false)
	game.stream.clear();game.ui_root.visible=false
	game.world.player.position=Arena.resolve(Arena.tile_center(Vector2i(23,209)),game.world.player.radius)
	game.world.player.facing=Vector2.RIGHT
	for i in 24:
		game.world.step_visual(1.0/60.0);game.view3d._process(1.0/60.0)
		await process_frame
	var geometry: Rect2
	var output := "res://docs/sprite_edges_applied/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for on in [false,true]:
		Edges.enabled=on
		game.view3d._process(0.0)
		# Preview-only hook: production View3D never loads the sample filter.
		var preview_sprite: Sprite3D=game.view3d._sprites[game.world.player.get_instance_id()].sprite
		var preview := Edges.frame({"tex":preview_sprite.texture,"src":preview_sprite.region_rect})
		preview_sprite.texture=preview.tex
		preview_sprite.region_rect=preview.src
		await process_frame
		await RenderingServer.frame_post_draw
		var sprite: Sprite3D=game.view3d._sprites[game.world.player.get_instance_id()].sprite
		var rect := Rect2(sprite.offset,sprite.region_rect.size)
		if not on: geometry=rect
		else:
			assert(rect==geometry,"Edge expansion must preserve native geometry")
			assert(sprite.texture.get_image().get_width()==int(sprite.texture.get_width())*2)
		root.get_texture().get_image().save_png(output+("after.png" if on else "before.png"))
		var image := sprite.texture.get_image()
		if not on: image=image.get_region(Rect2i(sprite.region_rect))
		image.save_png(output+("frame-after.png" if on else "frame-before.png"))
	# More screen samples without enlarging the user's native test window.
	game.view3d.vp.size=Vector2i(1536,864)
	await process_frame
	await RenderingServer.frame_post_draw
	game.view3d.vp.get_texture().get_image().save_png(output+"offscreen-4x.png")
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	print("Sprite edge review: unchanged native geometry, doubled GPU pixels")
	quit()

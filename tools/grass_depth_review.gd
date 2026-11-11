extends SceneTree

# Preview geometry only. The game creates the normal View3D on startup.
class GrassPreview extends View3D:
	func _build_layered_flora(st: SurfaceTool, x: float, z: float, u0: float, u1: float, v0: float, v1: float, local_tile := Vector2i(-1,-1)) -> void:
		var is_static := _ground_static_geometry
		var tile := Vector2i(int(x), int(z)-1) if is_static else local_tile
		if not Arena.is_grass(tile):
			super._build_layered_flora(st,x,z,u0,u1,v0,v1,local_tile)
			return
		var ground := flora_ground_frame(tile)
		var stagger := -1.0 if posmod(tile.x + tile.y, 2) == 0 else 1.0
		# The rear tuft stays at terrain depth, even when a step draws leaves over the feet.
		if is_static:
			_flora_quad(st, ground, Vector3(-0.45 + stagger*0.045, 0.02, -0.09),
				Vector3(0.90,0,0), Vector3(stagger*0.04,0.68,-0.10),
				u0,u1,v0,v1,true,false)
		_flora_quad(st, ground, Vector3(-0.44 - stagger*0.055, 0.02, 0.35),
			Vector3(0.88,0,0), Vector3(-stagger*0.04,0.40,-0.12),
			u0,u1,lerpf(v0,v1,0.375),v1,true,not is_static)

func _init() -> void:
	run.call_deferred()

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("DUNGEON","kanto_world")
	OS.set_environment("SEED","1")
	SaveData.path = "user://grass_depth_review_only.cfg"
	var args := OS.get_cmdline_user_args()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.ui_layer.hide()
	var view: View3D = game.view3d
	if args[0] in ["preview", "natural", "route1_tile", "route1_relief"]:
		view.free()
		match args[0]:
			"preview": view = GrassPreview.new()
			"natural": view = preload("res://tools/grass_depth_preview/natural_grass.gd").new()
			"route1_tile": view = preload("res://tools/grass_depth_preview/route1_tile.gd").new()
			"route1_relief": view = preload("res://tools/grass_depth_preview/route1_relief.gd").new()
		game.view3d = view
		view.layer = 1
		game.add_child(view)
		view.build(game.world, DungeonDB.theme().map)
	view.set_process(false)
	var player: Player = game.world.player
	var start := Arena.tile_center(Vector2i(72,260)) - Vector2(0,player.feet_offset())
	for frame in 140:
		var progress := clampf((frame-8)/60.0,0.0,1.0)
		var returning := frame >= 80
		if returning: progress = 1.0 - clampf((frame-80)/52.0,0.0,1.0)
		player.facing = Vector2.DOWN if returning else Vector2.UP
		player.vel = player.facing * player.move_speed() if progress > 0 and progress < 1 else Vector2.ZERO
		player.position = start + Vector2.UP * progress * 3.4 * Arena.TILE
		game.world._step_tall_grass()
		game.world.step_visual(1./30)
		player.queue_redraw()
		if frame == 0: view._cam_ready = false
		await process_frame
		view._process(1./30)
		await RenderingServer.frame_post_draw
		if frame % 2 == 0:
			var result := view.vp.get_texture().get_image().save_png(args[1].path_join("%02d.png" % frame))
			if result != OK:
				game.free()
				quit(1)
				return
	game.free()
	quit()

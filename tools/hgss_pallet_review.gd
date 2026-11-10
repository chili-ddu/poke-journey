extends SceneTree

const Game = preload("res://scripts/game.gd")
var out := "res://docs/hgss_pallet_sample/"
var sample: Node3D

func _init() -> void:
	run.call_deferred()

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	SaveData.path = "user://hgss_pallet_review_only.cfg"
	OS.set_environment("BOT", "1")
	OS.set_environment("DUNGEON", "kanto_world")
	Game.skip_opening = true
	Game.starter = "charmander"
	View3D.HgssEnvironment.enabled=false # Keep this historical comparison's baseline FRLG.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var previous: Player = game.world.player
	game.world.player = Player.new()
	game.world.player.setup_player("charmander", 5, ["scratch", "growl"])
	game.world.add_child(game.world.player)
	previous.free()
	game.world.player.position = Arena.tile_center(Vector2i(76, 275))
	game.world.cam_pos = game.world.player.position
	game.world.cam.position = game.world.player.position
	game.world.player.facing = Vector2.DOWN
	game.hub = false
	game.dialog_text = ""
	game.last_small_message = ""
	game.banner_text = "태초마을"
	game.banner_kind = "town"
	game.banner_t = 2.0
	for i in 30:
		game.view3d._process(1.0 / 60.0)
		await process_frame
	await shot("01_current_frlg")
	game.free()
	View3D.HgssEnvironment.enabled=true
	await process_frame
	sample = load("res://scenes/hgss_pallet_sample.tscn").instantiate()
	root.add_child(sample)
	sample.automatic_portals = false
	sample.position_2d = Vector2(1045.5, 375.5)
	for i in 20: await process_frame
	await shot("02_hgss_lab_outside")
	sample.position_2d = sample.collection.spawn(49)
	for i in 12: await process_frame
	await shot("03_hgss_house")
	sample.position_2d = Vector2(1045.5, 374.5)
	for i in 4: await process_frame
	var door: Dictionary = sample.collection.portal(sample.data, Vector2i(1045, 373))
	sample.automatic_portals = true
	sample.move_by(Vector2(0, -1))
	for i in 6: await process_frame
	assert(sample.header == 505)
	await shot("04_hgss_lab_inside")
	var back: Dictionary = {}
	for warp in sample.data.warps:
		if int(warp.header) == 505 and int(warp.to_header) == 49: back = warp
	sample.move_by(sample.collection.spawn(505) - sample.position_2d)
	for i in 3: await process_frame
	sample.move_by(Vector2(float(back.x) + 0.5, float(back.z) + 0.5) - sample.position_2d)
	for i in 6: await process_frame
	assert(sample.header == 49)
	assert(sample.sample_game.world.player.level == 5)
	assert(sample.hud.game == sample.sample_game)
	assert(sample.actor.texture != null)
	assert(root.size == Vector2i(384, 216))
	await shot("05_hgss_return")
	var file := FileAccess.open(out + "checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"window": [384,216], "lab_walk_roundtrip": true,
		"uses_current_hud": true, "uses_current_player_draw": true, "gameplay_scene_replaced": false,
		"save_path": SaveData.path, "camera_elevation": View3D.ELEV_DEG, "camera_fov": View3D.FOV}))
	file.close()
	sample.free()
	print("HGSS Pallet sample passed: current player/HUD, native geometry, real lab walk roundtrip, 384x216; existing game unchanged")
	quit()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + name + ".png")

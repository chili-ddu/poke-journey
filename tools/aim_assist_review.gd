extends SceneTree
## Same engine, input, velocity and capture timing with assistance disabled/enabled.
const OUT := "res://docs/aim_assist/"
const FPS := 30
const FRAMES := 90
var results := []

class Runner:
	extends Enemy
	var clock := 0.0
	func think(dt: float, _world) -> void:
		clock += dt
		vel = Vector2(0,12.0*cos(clock*2.0))
		facing = Vector2.DOWN

func _init() -> void: call_deferred("run")

func run() -> void:
	for pair in [["BOT","1"],["GOD","0"],["SEED","17"],["LANG_CODE","ko"],["STARTER","charmander"],["DUNGEON","arena_viridian_forest"],["CAP_VIEW","384x216"],["CAP_AUDIO","0"]]:OS.set_environment(pair[0],pair[1])
	SaveData.path = "user://aim_assist_review_private.cfg"
	SaveData.slot_pattern = "user://aim_assist_review_%s.cfg"
	SaveData.allow_migrate = false
	Controllers.ensure_input_map()
	await CaptureWindow.park(self)
	ViewScale.window_ready = true
	for enabled in [false,true]: await capture_case(enabled)
	assert(int(results[1].damage) > int(results[0].damage), "The same moving-target situation becomes easier to hit")
	FileAccess.open(OUT+"native.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":results,"native_window":"384x216","fps":FPS,"simulation_hz":60,"real_user_saves_used":false,"common_stats_and_damage":true},"  "))
	print("Aim assistance native comparison: ",JSON.stringify(results))
	quit()

func capture_case(enabled: bool) -> void:
	var case_name := "assisted" if enabled else "original"
	var folder := OUT+case_name+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game);current_scene = game
	game.set_process(false);game.stream.clear();game.ui_root.hide()
	var view: View3D = game.view3d
	view.set_process(false)
	var old: World = game.world
	var world := World.new()
	game.add_child(world);game.world = world;view.world = world;old.free()
	var input := Controllers.Human.new()
	input.pad_move = Vector2.RIGHT;input.pad_active = true
	input.aim_assist.settings.enabled = enabled
	world.setup(17,"charmander",12,["ember"],input)
	world.player.position = Arena.tile_center(Vector2i(8,15))
	world.player.facing = Vector2.RIGHT
	world.player.frozen = true # Hold L right without moving the stationary comparison actor.
	world.visibility_layer |= Look.GROUND_LAYER
	var enemy := Runner.new()
	enemy.setup_trainer_mon("squirtle",12,["tackle"],world.rng)
	enemy.position = world.player.position+Vector2(55,14)
	world.add_child(enemy);world.enemies.append(enemy)
	var hp := enemy.hp
	for i in 4:
		view._process(1.0/60.0)
		view._set_arena_camera(View3D.to3d(world.player.position+Vector2(24,0),0.55),Vector2(40,25),9.3)
		await process_frame;await RenderingServer.frame_post_draw
	var axes: Array = []
	for frame in FRAMES:
		if frame in [2,40,76]: input.press_gamepad_key(KEY_Q)
		for tick in 2: world.step(1.0/60.0)
		input.release_gamepad_key(KEY_Q)
		axes.append(rad_to_deg(world.player.facing.angle()))
		view._process(1.0/FPS)
		view._set_arena_camera(View3D.to3d(world.player.position+Vector2(24,0),0.55),Vector2(40,25),9.3)
		await process_frame;await RenderingServer.frame_post_draw
		assert(DisplayServer.window_get_size() == Vector2i(384,216) and root.size == Vector2i(384,216))
		root.get_texture().get_image().save_png(folder+"%03d.png"%frame)
	results.append({"case":case_name,"frames":FRAMES,"initial_hp":hp,"final_hp":enemy.hp,"damage":hp-enemy.hp,"pp_remaining":world.player.pp[0],"max_aim_degrees":axes.max()})
	game.free();current_scene = null
	await process_frame

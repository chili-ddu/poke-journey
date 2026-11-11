extends SceneTree
## Records the real combat engine, not generated art. Never loads a player save.

const SparringWorld = preload("res://tools/samples/untamed_sparring_world.gd")
const OUT := "res://docs/untamed_loading_gameplay/"
const FPS := 30
const SECONDS := 14
var game: Node
var world: World
var view: View3D
var round_index := 0
var rounds: Array = []
var ending_t := 0.0
var total_casts := {}
var total_damage := {}
var visual := false
var focus := Vector2.ZERO
var camera_distance := 10.7

func _init() -> void: call_deferred("run")

func start_round() -> void:
	if world != null:
		rounds.append({"round":round_index,"seconds":world.elapsed,"casts":world.casts.duplicate(),"damage":world.damage_pairs.duplicate()})
		for key in world.casts: total_casts[key] = int(total_casts.get(key,0)) + int(world.casts[key])
		for key in world.damage_pairs: total_damage[key] = int(total_damage.get(key,0)) + int(world.damage_pairs[key])
		world.free()
	round_index += 1
	world = SparringWorld.new()
	if game != null: game.add_child(world)
	else: root.add_child(world)
	world.setup(613 + round_index, "charmander", 12, ["ember", "scratch"], SparringWorld.SparringInput.new())
	world.god = false
	world.no_skills = false
	var center := Arena.tile_center(Vector2i(9, 15))
	world.player.position = center + Vector2(40, 4)
	world.player.facing = Vector2.LEFT
	world.add_starter("bulbasaur", 1, ["razor_leaf", "vine_whip", "tackle"], center + Vector2(-28, -12))
	world.add_starter("squirtle", 2, ["water_gun", "tackle"], center + Vector2(-28, 28))
	ending_t = 0.0
	focus = center
	camera_distance = 10.7
	if view != null:
		game.world = world
		view.world = world
		world.visibility_layer |= Look.GROUND_LAYER
		world.move_override = Callable()
		world.aim_override = Callable()
	for actor: Mon in [world.player] + world.enemies:
		assert(actor.max_hp == int(SpeciesDB.stats_at(actor.species_id, actor.level, actor.ivs).hp))
	assert(world.opponents(0).size() == 2 and world.opponents(1).size() == 2 and world.opponents(2).size() == 2)

func frame_camera() -> void:
	var actors: Array = world.alive_enemies()
	if not world.player.dead: actors.append(world.player)
	if actors.is_empty(): return
	var box := Rect2(actors[0].position, Vector2.ZERO)
	for actor: Mon in actors: box = box.expand(actor.cam_anchor())
	focus = focus.lerp(box.get_center(), 0.15)
	var wanted := 10.7
	for attempt in 40:
		view._set_arena_camera(View3D.to3d(focus,0.55), Vector2(40,25), wanted)
		var inside := true
		for actor: Mon in actors:
			var at := view.cam.unproject_position(View3D.to3d(actor.cam_anchor(),0.65))
			if not Rect2(30,32,324,152).has_point(at): inside = false
		if inside: break
		wanted += 0.5
	camera_distance = maxf(wanted, lerpf(camera_distance, wanted, 0.08))
	view._set_arena_camera(View3D.to3d(focus,0.55), Vector2(40,25), camera_distance)
	for actor: Mon in actors:
		assert(Rect2(28,30,328,156).has_point(view.cam.unproject_position(View3D.to3d(actor.cam_anchor(),0.65))), "Living combatants stay inside the recording")

func run() -> void:
	visual = DisplayServer.get_name() != "headless"
	for pair in [["BOT","1"],["GOD","0"],["LANG_CODE","ko"],["SEED","613"],["STARTER","charmander"],["DUNGEON","arena_viridian_forest"],["CAP_VIEW","384x216"],["CAP_AUDIO","0"]]:
		OS.set_environment(pair[0],pair[1])
	SaveData.path = "user://untamed_loading_preview_private.cfg"
	SaveData.slot_pattern = "user://untamed_loading_preview_%s.cfg"
	SaveData.allow_migrate = false
	DungeonDB.current = "arena_viridian_forest"
	Arena.configure(DungeonDB.theme())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
	if visual:
		await CaptureWindow.park(self)
		ViewScale.window_ready = true
		game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		game.set_process(false)
		game.stream.clear()
		game.ui_root.hide()
		view = game.view3d
		assert(view != null)
		view.set_process(false)
		var old: World = game.world
		game.world = null
		view.world = null
		old.free()
	start_round()
	if visual:
		for warmup in 4:
			view._process(1.0 / 60.0)
			frame_camera()
			await process_frame
			await RenderingServer.frame_post_draw
	for frame in FPS * SECONDS:
		for substep in 2:
			world.step(1.0 / 60.0)
			var alive := (0 if world.player.dead else 1) + world.alive_enemies().size()
			if world.player.dead or alive <= 1: ending_t += 1.0 / 60.0
			if ending_t >= 1.0: start_round()
		if visual:
			view._process(1.0 / FPS)
			frame_camera()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(DisplayServer.window_get_size() == Vector2i(384,216))
			assert(root.size == Vector2i(384,216))
			assert(root.get_texture().get_image().save_png(OUT + "frames/%04d.png" % frame) == OK)
	start_round()
	var issues: Array = []
	for species in ["charmander", "bulbasaur", "squirtle"]:
		var found := false
		for key: String in total_casts: if key.begins_with(species + ":"): found = true
		if not found: issues.append(species + " must actually use a move")
	if not (total_damage.has("1>2") or total_damage.has("2>1")): issues.append("The two NPC starters must really damage one another")
	var report := {"visual":visual,"frames":FPS*SECONDS if visual else 0,"fps":FPS,"seconds":SECONDS,"native_window":"384x216" if visual else "headless","rounds":rounds,"casts":total_casts,"damage_pairs":total_damage,"common_stats_and_damage":true,"actual_saves_used":false,"generated_art_used":false,"game_loading_integrated":false}
	FileAccess.open(OUT + ("capture.json" if visual else "simulation.json"), FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("Actual gameplay preview: ",JSON.stringify(report))
	print("Issues: ",issues)
	if game != null: game.free()
	elif world != null: world.free()
	quit(0 if issues.is_empty() else 1)

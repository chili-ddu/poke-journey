extends SceneTree
const Pursuit = preload("res://scripts/battle/road_pursuit.gd")
var game: Node
func _init() -> void: call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path = "user://save_road_pursuit_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","7")
	OS.set_environment("DUNGEON","viridian_forest")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	OS.set_environment("DUNGEON","")
	var pursuit = game.road_pursuit
	game.stream.clear()
	game.world.scatter_enemies()
	game.world.player.position = Arena.tile_center(Vector2i(5,16))
	if not pursuit.walkable(Vector2i(5,16)):
		game.world.player.position = Arena.tile_center(Vector2i(5,15))
	assert(Arena.area_at(game.world.player.position)=="viridian_forest")
	game.banner_t = 0
	for i in 20:
		game.world.step_visual(1.0/60)
		await process_frame
	assert(game.trainers.is_empty(),"No stationary duplicate trainer")
	assert(pursuit.spawn(game.world,game.view3d,[]),"Connected offscreen spawn exists")
	assert(not pursuit.visible_at(game.world,game.view3d,pursuit.actor.position),"No visible teleport")
	assert(game.world.alive_enemies().is_empty(),"Only trainer appears on field")
	var from: Vector2 = pursuit.actor.position
	var caught: Npc
	for i in 3600:
		caught = pursuit.step(game.world,game.view3d,1.0/60,[],true)
		game.world.step_visual(1.0/60)
		if caught != null: break
		if i%15==0: await process_frame
	assert(caught != null,"Trainer reaches stationary player")
	assert(caught.position.distance_to(from)>Arena.TILE)
	assert(caught.position.distance_to(game.world.player.position)<=Pursuit.CATCH_DISTANCE)
	game._start_intro(caught)
	assert(game.state=="talk" and game.dialog_t==0.0,"Manual dialogue begins only after contact")
	assert(game.world.alive_enemies().is_empty(),"No field Pokémon release")
	var out := "res://docs/forest_pursuit_review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/contact.png")
	for i in 10:
		if game.state!="talk":break
		game._talk_next()
	assert(game.state=="encounter","Contact dialogue leads to existing arena transition")
	assert(Pursuit.Data.POOLS.viridian_forest.has(game.arena_trip.trainer))
	assert(game.arena_trip.arena=="arena_viridian_forest")
	# Verify abandonment in a fresh pursuit, without starting a scene transition.
	game.state="fight"
	pursuit.phase="chase"
	game.world.player.position=Vector2(-1000,-1000)
	pursuit.step(game.world,game.view3d,2.1,[],false)
	assert(pursuit.phase=="leaving" or pursuit.actor==null)
	pursuit.clear(game.world)
	assert(pursuit.actor==null and pursuit.cooldown==0.0)
	# Automatic defeat recovery uses only this tool's isolated save file.
	SaveData.store_respawn("pewter_center",Vector2(7.5,5.5)*Arena.TILE)
	game.arena_trip = {"trainer":"bug_catcher_sammy"}
	game.world.player.dead = true
	game.world.player.hp = 0
	game._on_player_fainted()
	assert(game.dialog_text=="눈앞이 캄캄해졌다!" if Lang.is_ko() else game.dialog_text=="Everything went black!")
	game.dialog_text = ""
	game.status_message_active = false
	game._finish_pending_battle_end()
	assert(game.state=="warp" and game.destination.map=="pewter_center")
	assert(game.world.player.hp==game.world.player.max_hp)
	game.arena_trip={}
	print("Road pursuit review passed: offscreen walk-in, navigation, manual intro, arena handoff, escape/cooldown, automatic center recovery")
	game.free()
	await process_frame
	quit()

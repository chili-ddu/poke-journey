extends SceneTree
var game: Node
func _init() -> void: call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_trainer_exposure_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","7")
	OS.set_environment("DUNGEON","kanto_north")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.set_process(false)
	OS.set_environment("DUNGEON","")
	game.world.player.position=Arena.tile_center(Vector2i(27,44))
	game.world.player.set_level(5)
	game.banner_t=0.0
	game.stream.clear()
	for i in 20:
		game.world.step_visual(1.0/60)
		await process_frame
	var e=game.road_pursuit
	e.notice("route3",99.0)
	e.step(game.world,game.view3d,0.0,[],true)
	assert(e.deployed.is_empty(),"No spawn before full gauge")
	e.notice("route3",1.0)
	e.step(game.world,game.view3d,0.0,[],false)
	assert(e.deployed.is_empty(),"Dialogue/transition spawn gate is respected")
	# One full alert starts one search; holding MAX cannot spawn every frame.
	e.step(game.world,game.view3d,0.0,e.Data.POOLS.route3,true)
	assert(e.deployed.size()==1 and e.attention==100.0)
	for i in 10:e.step(game.world,game.view3d,0.0,[],true)
	assert(e.pursuits.size()==1)
	assert(not e.pursuits[0].visible_at(game.world,game.view3d,e.pursuits[0].actor.position))
	game.hud.queue_redraw()
	print("Gauge UI: ",game.mode," ",game.battle.is_empty()," ",e.visit_area," ",e.gauge_visible(5)," HUD ",game.hud.size)
	var out:="res://docs/trainer_exposure_review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/gauge.png")
	# A moving searcher must discover an occupied grass tile without pushing its occupant away.
	var driver=e.pursuits[0]
	var patch:=Vector2i(-1,-1)
	var beside:=Vector2i.ZERO
	var bounds:=Arena.area_rect("route3")
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var cell:=Vector2i(x,y)
			if not Arena.is_grass(cell) or not driver.walkable(cell):continue
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if bounds.has_point(cell+offset) and driver.walkable(cell+offset):
					patch=cell
					beside=cell+offset
					break
			if patch.x>=0:break
		if patch.x>=0:break
	assert(patch.x>=0,"Road has searchable grass")
	game.world.player.position=Arena.tile_center(patch)-Vector2(0,game.world.player.feet_offset())
	driver.actor.position=Arena.tile_center(beside)
	driver.actor.walk_target=Arena.tile_center(patch)
	driver.actor.face_toward(driver.actor.walk_target)
	driver.path.clear()
	e.previous_position=game.world.player.position
	var caught: Npc
	for i in 60:
		game.world._push_out_of_npcs()
		game.world.step_visual(1.0/60)
		caught=e.step(game.world,game.view3d,1.0/60,[],false)
		if caught!=null:break
	assert(caught==driver.actor,"A trainer walking into the hidden cell discovers its occupant")
	assert(Arena.tile_of(game.world.player.position+Vector2(0,game.world.player.feet_offset()))==patch)
	game._start_intro(caught)
	assert(game.state=="talk" and game.dialog_t==0.0,"Discovery begins manual trainer dialogue")
	game.state="fight"
	game.dialog_text=""
	game.world.player.position=Arena.tile_center(Vector2i(27,44))
	# Retiring a search allows another full alert, up to the local roster.
	for i in range(1,8):
		e.pursuits[-1].retire()
		e.pursuits[-1].clear(game.world)
		e.notice("route3",100.0)
		e.step(game.world,game.view3d,0.0,e.Data.POOLS.route3,true)
		assert(e.deployed.size()==i+1)
		assert(e.attention==100.0)
	assert(e.remaining_ids(5).is_empty())
	assert(e.pursuits.size()==1)
	var n: Npc=e.pursuits[0].actor
	game._to_arena(n)
	assert(game.arena_trip.back.pursuit_visit.deployed.size()==8)
	game._leave_arena()
	assert(game.destination.from_arena)
	assert(game.destination.pursuit_visit.gauge==0.0,"Battle ends this search alert")
	assert(game.destination.pursuit_visit.actors.is_empty())
	game.arena_trip={}
	print("Exposure search review passed: offscreen arrival, full gauge held, one search per alert, distinct local roster cap, post-battle alert reset, occupied-grass discovery and manual intro")
	game.free()
	await process_frame
	quit()

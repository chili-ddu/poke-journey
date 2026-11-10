extends "res://tools/story_trainer_review.gd"
func fixtures() -> Array:
	if OS.get_environment("REVIEW_FIELDS_ONLY")=="1":return []
	return [["arena_route1","rival_cerulean_squirtle"],["arena_cerulean_gym","leader_misty"]]
func open_field(place: String) -> void:
	var script=load("res://scripts/game.gd")
	script.arena_trip={};script.destination={};script.rival_leaving=""
	OS.set_environment("DUNGEON",place)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);current_scene=game
	game.set_process(false);game.view3d.set_process(false)
	game.world.player.set_level(18)
	game.banner_t=0.0
func settle() -> void:
	for i in 15:
		game.world.step_visual(DT)
		await frame(false)
func run() -> void:
	await CaptureWindow.park(self)
	out="res://docs/cerulean_progression_review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	SaveData.path="user://save_cerulean_progression_review.cfg"
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	await open_field("kanto_south")
	var city:=Arena.area_rect("cerulean_city")
	game.world.player.position=Arena.tile_center(city.position+Vector2i(23,6));game.state="fight"
	assert(game._check_cerulean_rival())
	var guard:=0
	while game.state!="talk" and guard<600:
		await frame();guard+=1
	assert(game.state=="talk")
	await settle();await shot("field_green_reunion")
	game.free();await process_frame
	await open_field("cerulean_north")
	for fixture in [["route24",Vector2i(11,20)],["route25",Vector2i(28,5)]]:
		game.world.player.position=Arena.tile_center(fixture[1])
		await settle()
		var exposure=game.road_pursuit
		exposure.sync_visit(fixture[0]);exposure.attention=100.0
		exposure.step(game.world,game.view3d,0.0,[],true)
		assert(exposure.searching(),fixture[0]+" has an offscreen connected roaming trainer")
		var driver=exposure.pursuits.back()
		assert(not driver.visible_at(game.world,game.view3d,driver.actor.position))
		# Inspect the spawned trainer on its own clear route, without waiting for a random search leg.
		game.world.player.position=Arena.resolve(driver.actor.position+Vector2.DOWN*Arena.TILE*3,game.world.player.radius)
		await settle();await shot("field_"+fixture[0]+"_search")
	game.free();await process_frame
	await open_field("cerulean_city_gym")
	game.world.player.position=Arena.tile_center(Vector2i(8,8))
	assert(game.trainers.size()==1)
	await settle();await shot("field_misty_and_gym_trainers")
	var misty: Npc
	for n in game.trainers:
		if n.trainer_id=="leader_misty":misty=n
	game._to_arena(misty)
	game.encounter.step(1.25)
	await frame(false);await shot("misty_leader_cutin")
	game.free();await process_frame
	await super.run()

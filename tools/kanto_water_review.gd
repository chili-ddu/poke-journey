extends "res://tools/kanto_expansion_review.gd"
const WATER_OUT := "res://docs/kanto_water_review/"
func find_shore(area: String) -> bool:
	for water in Arena._water:
		var pos := Arena.tile_center(water)
		if Arena.area_at(pos)!=area or Arena.resolve(pos,11.0,false,1).distance_to(pos)>0.1: continue
		for d in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var land: Vector2i=water+d
			var at := Arena.tile_center(land)
			if Arena.is_water(land) or Arena.solid_at(land.x,land.y) or Arena.area_at(at)!=area:continue
			if Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1:continue
			game.world.player.position=at
			game.world.player.facing=-Vector2(d)
			walker.target=at
			return true
	return false
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WATER_OUT))
	await CaptureWindow.park(self)
	SaveData.path="user://save_kanto_water_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","17")
	for pair in [["kanto_south","pallet_town"],["kanto_south","viridian_city"],["kanto_north","cerulean_city"],["kanto_east","route6"],["kanto_east","vermilion_city"]]:
		await open_fixture(pair[0])
		assert(find_shore(pair[1]),"Native shore "+pair[1])
		assert(game.view3d!=null,"HD-2D active")
		game._open_water_menu()
		assert(game.menu=="water" and game.panel.visible,"F menu")
		if pair[1]=="vermilion_city": await shot("vermilion_menu")
		game._resolve_menu(0)
		assert(not game.world.field_water.fishing.is_empty(),"Old rod cast")
		for i in 45:
			game.advance(1.0/60.0)
			if i%8==0:await process_frame
		if pair[1]=="vermilion_city":await shot("vermilion_cast")
		for attempt in 20:
			game.world.field_water.step(game.world,3.0)
			game.world._step_spawns(1.0)
			if not game.world.enemies.is_empty():break
			assert(game.world.field_water.start_fishing(game.world,"old_rod"))
		assert(game.world.enemies.size()==1,"Auto hook")
		var fish: Enemy=game.world.enemies[0]
		assert(fish.species_id=="magikarp" and fish.travel_terrain==1,"Native old rod fish")
		for i in 60:
			game.advance(1.0/60.0)
			if i%8==0: await process_frame
		assert(not fish.dead,"City does not scatter fishing encounter")
		await shot(pair[1]+"_fishing")
		game.world.scatter_enemies()
		for i in 60:game.world.step(1.0/60.0)
		assert(game.world.field_water.surf(game.world),"Board surf")
		walker.target=game.world.player.position
		var cfg: Dictionary=game.world.wild_cfg()
		var pick := DungeonDB.roll_table(cfg.encounters,game.world.rng)
		# Tiny Pallet pond has no spawn point 60px away; casting still works there.
		var queued: bool=game.world.queue_spawn(pick.species,pick.level)
		game.world._step_spawns(2.0)
		for i in 30:
			game.advance(1.0/60.0)
			game.world.player.hp=game.world.player.stats.hp
			if i%6==0:await process_frame
		assert(game.world.player.travel_terrain==2,"Still surfing")
		await shot(pair[1]+"_surf")
		results.append({"area":pair[1],"menu":true,"auto_fishing":true,"surf":true,"water_wild_queued":queued})
	# The cliff-bound Route4 water is entered from Cerulean, preserving native walls.
	await open_fixture("kanto_north")
	game.world.player.position=Arena.tile_center(Vector2i(168,17))
	game.world.player.travel_terrain=2
	walker.target=Arena.tile_center(Vector2i(166,17))
	for i in 90:
		game.advance(1.0/60.0)
		if i%8==0:await process_frame
	assert(Arena.area_at(game.world.player.position)=="route4","Water route border")
	await shot("route4_surf_border")
	results.append({"area":"route4","surf_border":true})
	var f := FileAccess.open(WATER_OUT+"report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"));f.close()
	print("KANTO WATER REVIEW PASSED: ",results.size()," areas")
	quit()
func shot(label: String) -> void:
	game._update_dialogue_focus()
	game.queue_redraw()
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(WATER_OUT+label+".png")

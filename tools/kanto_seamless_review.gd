extends "res://tools/kanto_expansion_review.gd"
const Game = preload("res://scripts/game.gd")

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_kanto_seamless_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	# Exercise the actual game position restore, including old field layouts and water.
	for entry in [
		["kanto_south",2,Vector2i(23,170),Vector2i(23,190)],
		["kanto_south",1,Vector2i(23,50),Vector2i(23,190)],
		["kanto_north",1,Vector2i(3,40),Vector2i(51,40)],
		["kanto_north",1,Vector2i(168,17),Vector2i(216,17)],
	]:
		Game.destination={"map":entry[0],"pos":Arena.tile_center(entry[2]),"layout":entry[1]}
		await open_fixture(entry[0])
		assert(game.world.player.position.distance_to(Arena.tile_center(entry[3]))<0.1,"Legacy location restored")
		assert(game.world.player.travel_terrain==(2 if Arena.is_water(entry[3]) else 0),"Surf restored after migration")
		results.append({"restore":entry[0],"layout":entry[1],"tile":[entry[3].x,entry[3].y]})
	# Building and cave/tunnel thresholds continue using the existing transition flow.
	for pair in [
		["kanto_south","pewter_city_pokemon_center_1f"],
		["pewter_center","pewter_city"],
		["kanto_south","mt_moon_1f"],
		["mt_moon_b1f","route4"],
		["kanto_south","cerulean_city_pokemon_center_1f"],
		["cerulean_city_pokemon_center_1f","cerulean_city"],
		["kanto_south","underground_path_north_entrance"],
		["underground_path_north_entrance","route5"],
		["underground_path_south_entrance","route6"],
	]:
		await open_fixture(pair[0])
		var selected := {}
		for warp in Arena.warps():
			if warp.to==pair[1]:selected=warp;break
		assert(not selected.is_empty(),"Facility entrance exists")
		game.world.player.position=Arena.tile_center(Vector2i(int(selected.x),int(selected.y)))
		walker.target=game.world.player.position
		game.warp_armed=true
		game._check_warp()
		assert(game.state=="warp","Facility still transitions")
		await arrive(DungeonDB.WARP_MAPS[pair[1]],"seamless_facility_"+pair[0]+"_"+pair[1])
	FileAccess.open(OUT+"seamless_restore_checks.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("Seamless field: 4 legacy position restores and 9 facility transitions passed")
	game.queue_free()
	await process_frame
	quit()

extends "res://tools/kanto_expansion_review.gd"
const WILD_OUT := "res://docs/kanto_wild_review/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WILD_OUT))
	await CaptureWindow.park(self)
	SaveData.path="user://save_kanto_wild_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","17")
	var cases := [
		["kanto_north","route3",["spearow","mankey","nidoran_m","nidoran_f","jigglypuff"]],
		["kanto_north","route4",["ekans","rattata"]],
		["kanto_north","route5",["oddish","meowth","pidgey"]],
		["kanto_east","route6",["oddish","meowth"]],
		["mt_moon_1f","mt_moon_1f",["zubat","clefairy","geodude"]],
		["mt_moon_b1f","mt_moon_b1f",["paras"]],
		["mt_moon_b2f","mt_moon_b2f",["zubat","paras","clefairy"]]]
	for entry in cases:
		await open_fixture(entry[0])
		var area: String=entry[1]
		var rect := Arena.area_rect(area)
		var candidates: Array=[]
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var tile := Vector2i(x,y)
				if Arena.solid_at(x,y) or not Arena.warp_at(Arena.tile_center(tile)).is_empty(): continue
				if not area.begins_with("mt_moon") and not Arena.is_grass(tile): continue
				candidates.append(Arena.tile_center(tile))
		candidates.sort_custom(func(a,b): return a.distance_to(Arena.tile_center(rect.get_center()))<b.distance_to(Arena.tile_center(rect.get_center())))
		var found := false
		for pos in candidates:
			game.world.player.position=pos
			if game.world._wild_spawn_points(DungeonDB.area_cfg(area),8.0).size()>=3:
				found=true;break
		assert(found,area+" accessible native terrain")
		walker.target=game.world.player.position
		for id in entry[2]:
			var lv := 0
			for e in DungeonDB.area_cfg(area).encounters:
				if e[0]==id: lv=int(e[1]);break
			assert(lv>0,"Native encounter "+id)
			assert(game.world.queue_spawn(id,lv),"Queued "+id)
		game.world._step_spawns(2.0)
		assert(game.world.enemies.size()==entry[2].size(),"All queued wild spawn")
		for enemy in game.world.enemies:
			assert(enemy._sprites.has("Walk"),"Native sprite "+enemy.species_id)
		for i in 150:
			game.advance(1.0/60.0)
			game.world.player.hp=game.world.player.stats.hp
			if i%10==0: await process_frame
		await shot(area)
		results.append({"area":area,"species":entry[2],"hd2d":game.view3d!=null,"live_ai":true})
	var f := FileAccess.open(WILD_OUT+"report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"));f.close()
	print("KANTO WILD REVIEW PASSED: ",results.size()," areas")
	quit()
func shot(label: String) -> void:
	game.ui_root.visible=false
	game._update_dialogue_focus()
	game.queue_redraw()
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(WILD_OUT+label+".png")

extends "res://tools/north_walk_review.gd"
const Canopy = preload("res://scripts/view/tree_canopy_3d.gd")

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_tree_volume_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","1")
	var phase := OS.get_environment("REVIEW_PHASE")
	if phase=="":phase="after"
	var output := "res://docs/tree_volume_review/"+phase+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var report := []
	for fixture in [{"id":"route1_ledge","place":"kanto_south","tile":Vector2i(16,202)},
		{"id":"route1_forest","place":"kanto_south","tile":Vector2i(33,188)},
		{"id":"round_forest","place":"viridian_forest","tile":Vector2i(7,47)},
		{"id":"arena_pine","place":"arena_route1","tile":Vector2i(-1,-1)},
		{"id":"arena_round","place":"arena_viridian_forest","tile":Vector2i(-1,-1)}]:
		await open_fixture(fixture.place)
		game.ui_root.visible=false
		game.view3d.set_process(false)
		var desired: Vector2i=fixture.tile
		if desired.x>=0:
			var chosen := Vector2i(-1,-1)
			var distance := INF
			for y in range(desired.y-5,desired.y+6):
				for x in range(desired.x-5,desired.x+6):
					var at := Arena.tile_center(Vector2i(x,y))
					if Arena.solid_at(x,y) or Arena.ledge_at(x,y)!=0 or not Arena.warp_at(at).is_empty():continue
					if Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1:continue
					var score := Vector2(x,y).distance_squared_to(Vector2(desired))
					if score<distance:chosen=Vector2i(x,y);distance=score
			assert(chosen.x>=0)
			game.world.player.position=Arena.tile_center(chosen)
		walker.target=game.world.player.position
		game.view3d._cam_ready=false
		for i in 60:
			game.advance(1.0/60)
			game.view3d._process(1.0/60)
		await shot("tree_volume_"+phase+"_"+String(fixture.id))
		var screenshot: Image=root.get_texture().get_image()
		screenshot.save_png(output+String(fixture.id)+".png")
		var node: MeshInstance3D=game.view3d.root3d.get_node_or_null("TreeCanopies")
		var count := int(node.get_meta("trees",0)) if node!=null else 0
		if phase=="after":assert(count>100,"Whole native trees use the new shared canopy mesh")
		report.append({"fixture":fixture.id,"tree_count":count,"player_tile":[Arena.tile_of(game.world.player.position).x,Arena.tile_of(game.world.player.position).y]})
		if phase=="after" and fixture.id=="route1_ledge":
			var jumps_before := automatic_jumps
			await walk_to(Vector2i(16,199))
			assert(automatic_jumps==jumps_before,"Native one-tile passage remains walkable without jumping")
			report[-1]["native_gap_walked"]=true
		if phase=="after" and String(fixture.id).begins_with("arena_"):
			var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DungeonDB.theme().map+"/hd2d_cards.json"))
			var nearest := Vector3.ZERO
			var height := 3.0
			var distance := INF
			for tree in Canopy.groups(source.cards):
				var tree_root := Canopy.root_of(tree,false)
				var d := tree_root.distance_squared_to(View3D.to3d(game.world.player.position))
				if d<distance:nearest=tree_root;height=float(tree.height);distance=d
			game.view3d._set_arena_camera(nearest+Vector3.UP*height*0.5,View3D.arena_camera_angles("fight"),12.0)
			await shot("tree_volume_"+phase+"_"+String(fixture.id)+"_oblique")
			root.get_texture().get_image().save_png(output+String(fixture.id)+"_oblique.png")
			report[-1]["oblique_canopy_view"]=true
		print("TREE VOLUME ",phase," ",fixture.id," trees=",count)
	FileAccess.open(output+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.queue_free()
	await process_frame
	quit()

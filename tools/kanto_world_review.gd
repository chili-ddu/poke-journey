extends "res://tools/saffron_access_review.gd"

const WORLD_OUT="res://docs/kanto_world/"

func shot(label: String) -> void:
	game.ui_root.visible=false
	for _i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(WORLD_OUT+label+".png")

func setup_controller() -> void:
	super.setup_controller()
	game.bot=true;game.lure_t=100000
	game.world.player.repel_steps=100000
	game.beaten.append(TrainerDB.cerulean_rival_for(game.starter))

func cross(a: String,b: String) -> void:
	var rect:=Arena.area_rect(a)
	var choices: Array=[]
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var at:=Vector2i(x,y)
			for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var other: Vector2i=at+direction
				if Arena.area_at(Arena.tile_center(other))!=b:continue
				var start: Vector2i=at-direction;var finish: Vector2i=other+direction
				var clear:=true
				for tile in [start,at,other,finish]:
					var p:=Arena.tile_center(tile)
					if Arena.solid_at(tile.x,tile.y) or Arena.is_water(tile) or Arena.ledge_at(tile.x,tile.y)!=0 or not Arena.warp_at(p).is_empty() or Arena.resolve(p,game.world.player.radius).distance_to(p)>0.1:clear=false;break
				if clear:choices.append([start,finish])
	if choices.is_empty():push_error("No native seamless lane "+a+" -> "+b);quit(1);return
	var lane: Array=choices[choices.size()/2]
	game.world.player.position=Arena.tile_center(lane[0]);walker.target=game.world.player.position
	var scene_id:=game.get_instance_id()
	await walk_to(lane[1])
	assert(game.get_instance_id()==scene_id and current_scene==game,"Outdoor seam never reloads the scene")
	if Arena.area_at(game.world.player.position)!=b:push_error("World seam did not finish "+a+" -> "+b);quit(1);return
	results.append({"from":a,"to":b,"same_scene":true})
	print("WORLD SEAM ",a," -> ",b)

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLD_OUT))
	SaveData.path="user://save_kanto_world_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	# This geography review crosses unlocked roads; gate behavior has its own review.
	Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[RoadAccess.SAFFRON_VISITED,RoadAccess.SNORLAX_AWAKENED]
	await open_fixture("kanto_world")
	print("WORLD RENDER READY")
	for id in ["celadon_city","fuchsia_city","cinnabar_island","indigo_plateau","lavender_town","route17","route20"]:
		var entry:=FlyDestinations.find(id)
		var at: Vector2=game.bird_event.arrival_point(id)
		if at==Vector2.INF:push_error("Invalid world landing: "+id);quit(1);return
		game.world.player.position=at;walker.target=at;game.view3d._cam_ready=false
		await shot("world_"+id)
	for pair in [["cerulean_city","route24"],["cerulean_city","route9"],["vermilion_city","route11"],["celadon_city","route7"],["lavender_town","route8"],["route12","route13"],["route14","route15"]]:
		await cross(pair[0],pair[1]);await cross(pair[1],pair[0])
	# New native city services and an actual cave entrance/return.
	for target in ["celadon_city_pokemon_center_1f","fuchsia_city_mart","seafoam_islands_1f"]:
		var door: Dictionary=Arena.warps().filter(func(w):return w.to==target)[0]
		var tile:=Vector2i(int(door.x),int(door.y))
		game.world.player.position=Arena.tile_center(tile+game._door_out_dir(tile));walker.target=game.world.player.position
		await go(target,"entry_"+target)
		if target.ends_with("pokemon_center_1f"):
			var nurse: Npc=game.world.npcs.filter(func(n):return n.talk=="nurse")[0]
			await walk_to(nurse.talk_tile)
			var p: Player=game.world.player
			p.hp=maxi(1,p.max_hp-4);p.pp[0]=0
			game._talk(nurse);finish_talk()
			assert(game.state=="heal")
			for _i in 300:
				if game.state!="heal":break
				game.advance(0.1)
			assert(p.hp==p.max_hp and p.pp[0]>0)
			finish_talk();await shot("service_center")
		elif target.ends_with("mart"):
			var clerk: Npc=game.world.npcs.filter(func(n):return n.talk=="shop")[0]
			await walk_to(clerk.talk_tile)
			game._talk(clerk);assert(game.menu=="shop");game._close_menu()
		var here:=Arena.tile_of(game.world.player.position)
		for direction in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var off: Vector2i=here+direction
			if not Arena.solid_at(off.x,off.y) and Arena.warp_at(Arena.tile_center(off)).is_empty():
				await walk_to(off);break
		var exit: Dictionary=Arena.warps().filter(func(w):return DungeonDB.WARP_MAPS.get(w.to,"")=="kanto_world")[0]
		await walk_to(Vector2i(int(exit.x),int(exit.y)),true)
		await arrive("kanto_world","return_"+target)
	var report={"outdoor_seams":results.filter(func(r):return r.has("from")),"scene_transitions":results.filter(func(r):return r.has("arrival")),"city_views":7,"new_facility_and_cave_returns":3,"new_center_healing":true,"new_mart_shop":true}
	FileAccess.open(WORLD_OUT+"native_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.free();await process_frame;SaveData.clear()
	print("Kanto world native review passed")
	quit()

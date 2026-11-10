extends "res://tools/kanto_world_review.gd"

const WILD_OUT="res://docs/kanto_world_wild/"

func shot(label: String) -> void:
	game.ui_root.visible=false
	for _i in 18:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(WILD_OUT+label+".png")

func habitat(area: String,terrain: String) -> Array:
	var rect:=Arena.area_rect(area)
	var candidates: Array[Vector2i]=[]
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var tile:=Vector2i(x,y);var at:=Arena.tile_center(tile)
			if Arena.terrain_blocked(tile,2 if terrain=="water" else 0) or not Arena.warp_at(at).is_empty():continue
			if terrain=="water" and not Arena.is_water(tile):continue
			if terrain=="grass" and not Arena.is_grass(tile):continue
			if Arena.resolve(at,game.world.player.radius,false,2 if terrain=="water" else 0).distance_to(at)>0.1:continue
			candidates.append(tile)
	candidates.sort_custom(func(a,b):return a.distance_squared_to(rect.get_center())<b.distance_squared_to(rect.get_center()))
	for tile in candidates:
		game.world.player.position=Arena.tile_center(tile)
		game.world.player.travel_terrain=2 if terrain=="water" else 0
		var points: Array=game.world._wild_spawn_points(game.world.wild_cfg(),10.0)
		if area=="cerulean_cave_1f":
			points=points.filter(func(at):
				var t:=Arena.tile_of(at)
				for dy in range(0,2):
					for dx in range(-1,2):
						var near:=t+Vector2i(dx,dy)
						if Arena.terrain_blocked(near,0):return false
				return true)
		if points.size()>=4:return points
	return []

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WILD_OUT))
	SaveData.path="user://save_kanto_world_wild_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","29");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[]
	var cases=[
		["route7","grass",["growlithe","oddish","meowth"]],
		["safari_zone_center","grass",["rhyhorn","chansey","scyther"]],
		["safari_zone_west","grass",["tauros","kangaskhan","venomoth"]],
		["pokemon_tower_3f","cave",["gastly","haunter","cubone"]],
		["pokemon_mansion_1f","cave",["grimer","koffing","weezing"]],
		["power_plant","cave",["electabuzz","magneton","magnemite"]],
		["seafoam_islands_b4f","cave",["seel","dewgong","golduck"]],
		["cerulean_cave_1f","cave",["ditto","wobbuffet","electrode"]],
		["route19","water",["tentacool"]],
	]
	var report: Array=[]
	for sample in cases:
		var area: String=sample[0]
		var owner: String=DungeonDB.WARP_MAPS[area]
		if not DungeonDB.is_overworld(owner):
			report.append({"area":area,"story_only":true,"random_encounters":false})
			print("WILD STORY-ONLY ",area," retains authored event configuration")
			continue
		await open_fixture(owner)
		var points:=habitat(area,sample[1])
		if points.is_empty():push_error("No native habitat "+area);quit(1);return
		var w: World=game.world
		w.player.repel_steps=0
		var placed: Array[Vector2]=[]
		for id in sample[2]:
			var slots: Array=w.wild_cfg().encounters.filter(func(e):return e[0]==id)
			assert(not slots.is_empty(),area+" "+id)
			assert(w.queue_spawn(id,int(slots[0][1])))
			w._step_spawns(2.0)
			var e: Enemy=w.enemies.back()
			assert(e.species_id==id and not e._sprites.is_empty())
			for at in points:
				if placed.all(func(p):return p.distance_to(at)>48.0) and Arena.resolve(at,e.radius,false,e.travel_terrain).distance_to(at)<0.1:
					e.position=at;placed.append(at);break
			e.ai="review";e.frozen=true;e.facing=(w.player.position-e.position).normalized()
		w.player.repel_steps=100000
		game.view3d._cam_ready=false
		await shot(area)
		report.append({"area":area,"terrain":sample[1],"species":sample[2],"native_spawn":true,"sprites":true})
		if area=="cerulean_cave_1f":
			var ditto: Enemy=w.enemies.filter(func(e):return e.species_id=="ditto")[0]
			var wob: Enemy=w.enemies.filter(func(e):return e.species_id=="wobbuffet")[0]
			assert(WildActions.transform(w,ditto,w.player));ditto.ai="review"
			WildActions.stance(w,wob,"special")
			await shot("ditto_transform_and_mirror_coat")
		print("WILD NATIVE ",area," ",sample[2])
	FileAccess.open(WILD_OUT+"native_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.free();await process_frame;SaveData.clear()
	print("Mainland wild native review passed")
	quit()

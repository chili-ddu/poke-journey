extends GutTest
const Game=preload("res://scripts/game.gd")
const Rescue=preload("res://scripts/story/pikachu_rescue.gd")
const PATH="user://save_pikachu_rescue_test.cfg"
const DT:=1.0/60.0
var old_path: String
var old_events: Array
var old_starter: String
var old_beaten: Array

func before_each() -> void:
	old_path=SaveData.path;SaveData.path=PATH
	old_events=Game.bot_events.duplicate();Game.bot_events=[]
	old_beaten=Game.bot_beaten.duplicate();Game.bot_beaten=[]
	old_starter=Game.starter;Game.starter="charmander"
	if FileAccess.file_exists(PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func after_each() -> void:
	SaveData.path=old_path;Game.bot_events=old_events;Game.bot_beaten=old_beaten;Game.starter=old_starter
	Game.destination={};Game.arena_trip={};Game.carry={}
	if FileAccess.file_exists(PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture(place: String=Rescue.PLACE,human: bool=false):
	var old_bot:=OS.get_environment("BOT");var old_place:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0" if human else "1");OS.set_environment("DUNGEON",place)
	Game.destination={};Game.arena_trip={};Game.carry={}
	var game=load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",old_bot);OS.set_environment("DUNGEON",old_place)
	game.world.god=true
	return game

func finish_talk(game) -> void:
	for i in 40:
		if game.state!="talk":break
		game._talk_next()

func reachable(start: Vector2i) -> Dictionary:
	var seen: Dictionary={start:true};var queue: Array[Vector2i]=[start];var cursor:=0
	while cursor<queue.size():
		var at:=queue[cursor];cursor+=1
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var tile: Vector2i=at+d
			if seen.has(tile) or Arena.solid_at(tile.x,tile.y):continue
			var p:=Arena.tile_center(tile)
			if Arena.resolve(p,8.0).distance_to(p)>0.1:continue
			seen[tile]=true;queue.append(tile)
	return seen

func test_fence_turns_do_not_become_building_roofs() -> void:
	var j: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_rock_pass/hd2d_cards.json"))
	var cells: Dictionary={}
	for c in j.cards:
		if c.size()>9 and int(c[9])==1:continue
		for dy in int(c[2]):
			var tile:=Vector2i(int(c[0]),int(c[1])+dy)
			cells[tile]=c
	var fence: Array[Vector2i]=[]
	for x in range(78,91):fence.append(Vector2i(x,5))
	for y in range(6,30):
		if y!=12:fence.append(Vector2i(90,y)) # Native decorated post occupies this tile.
	for tile in fence:
		assert_true(cells.has(tile),"Fence panel retained at %s"%tile)
		if not cells.has(tile):continue
		var c: Array=cells[tile]
		assert_eq(int(c[2]),1,"Fence cannot merge with adjacent panels or shrubs")
		assert_eq(int(c[5]),0,"Fence ends cannot acquire a building roof")
		assert_gte(c.size(),11)
		if c.size()>10:assert_eq(int(c[9]),5,"Fence is classified separately from buildings")
	# Preserve the native decorated post independently of the long side run.
	assert_eq(int(cells[Vector2i(90,12)][2]),1)
	# The side rail starts at the corner post, continues across tile boundaries,
	# and meets the southern return at a shared ground position.
	var corner:=View3D.fence_panels(Vector2i(90,5),0x0ef)
	var upper:=View3D.fence_panels(Vector2i(90,6),0x0f4)
	var next:=View3D.fence_panels(Vector2i(90,7),0x0f4)
	assert_eq(upper[0].a.y,corner[0].a.y)
	assert_true(upper[0].a.x>corner[0].a.x and upper[0].a.x<corner[0].b.x)
	assert_eq(upper[0].b,next[0].a,"Adjacent side panels share an endpoint")
	var lower:=View3D.fence_panels(Vector2i(90,29),0x0f4)
	var end:=View3D.fence_panels(Vector2i(90,30),0x0f7)
	assert_eq(end.size(),2)
	assert_eq(lower[0].b,end[1].a)
	assert_eq(end[1].b.y,end[0].a.y)
	assert_true(end[1].b.x>end[0].a.x and end[1].b.x<end[0].b.x)

func test_retired_route10_event_never_spawns_bullies_or_resumes_old_rewards() -> void:
	for place in [Rescue.PLACE,KantoWorldTravel.ID]:
		for flags in [[],["pikachu_rescue_won"]]:
			Game.bot_events=flags.duplicate()
			var game=fixture(place)
			assert_null(game.pikachu_rescue)
			assert_true(game.world.bystanders.filter(func(m):return m.species_id in ["pikachu","magnemite","voltorb"]).is_empty())
			assert_true(game.world.npcs.filter(func(n):return n.talk=="route10_pikachu_rescue").is_empty())
			game.world.player.position=Arena.tile_center(Arena.area_rect("route10").position+Vector2i(15,4))
			game.advance(DT)
			assert_eq(game.state,"fight");assert_true(Game.arena_trip.is_empty())
			assert_false(game.events.has(Rescue.FRIEND))

func test_tunnel_is_dark_until_unlocked_and_auto_joins_on_both_floors() -> void:
	for place in Rescue.CAVES:
		Game.bot_events=[]
		var dark=fixture(place)
		assert_null(dark.pikachu_rescue.helper)
		assert_not_null(dark.pikachu_rescue.veil)
		assert_eq(dark.pikachu_rescue.brightness,0.0)
		Game.bot_events=[Rescue.FRIEND]
		var game=fixture(place);var event=game.pikachu_rescue
		assert_eq(event.helper.species_id,"pikachu")
		assert_true(event.helper.get_meta("flash_helper"))
		assert_false(game.world.enemies.has(event.helper))
		assert_eq(game.world.bystanders.filter(func(m):return m.get_meta("flash_helper",false)).size(),1)
		event.arrive()
		assert_eq(game.world.bystanders.filter(func(m):return m.get_meta("flash_helper",false)).size(),1,"Repeated arrival notification cannot spawn a second helper")
		var feet: Vector2=event.helper.position+Vector2(0,event.helper.feet_offset())
		assert_lt(Arena.resolve(feet,event.helper.radius).distance_to(feet),0.1,"Helper joins on clear floor")
		for i in 50:event.follow(DT)
		assert_eq(event.brightness,1.0)
		var pos: Vector2=event.helper.position
		game.state="menu";event.follow(5.0)
		assert_eq(event.helper.position,pos,"Menus pause the follower")
	var outside=fixture(Rescue.PLACE)
	assert_null(outside.pikachu_rescue)

func test_helper_follows_walkable_paths_without_crossing_walls_or_spending_pp() -> void:
	Game.bot_events=[Rescue.FRIEND]
	var game=fixture("rock_tunnel_1f");var event=game.pikachu_rescue
	var start:=Arena.tile_of(game.world.player.position)
	var seen:=reachable(start)
	var destination:=start
	for cell in seen:
		var distance: float=Vector2(cell-start).length()
		if distance>=5.0 and distance<7.0:destination=cell;break
	assert_ne(destination,start)
	game.world.player.position=Arena.tile_center(destination)-Vector2(0,game.world.player.feet_offset())
	var pp: Array=game.world.player.pp.duplicate()
	var position: Vector2=game.world.player.position
	for i in 300:
		event.follow(DT)
		var feet: Vector2=event.helper.position+Vector2(0,event.helper.feet_offset())
		assert_lt(Arena.resolve(feet,event.helper.radius).distance_to(feet),0.1,"Follower stays on floor")
	assert_lt(event.helper.position.distance_to(game.world.player.position),Arena.TILE*2.0)
	assert_eq(game.world.player.position,position)
	assert_eq(game.world.player.pp,pp,"Flash help is automatic and spends no player PP")

func test_helper_stays_within_one_tile_through_turns_fast_movement_and_stops() -> void:
	Game.bot_events=[Rescue.FRIEND]
	for place in Rescue.CAVES:
		var game=fixture(place);var event=game.pikachu_rescue
		finish_talk(game)
		var player: Player=game.world.player
		var start:=Arena.tile_of(player.position)
		var route: PackedVector2Array=[]
		var turns: int=0
		for cell in reachable(start):
			var path: PackedVector2Array=event.pathfinder.get_point_path(start,cell)
			if path.size()<12 or path.size()>28:continue
			var bends:=0
			for i in range(1,path.size()-1):
				if (path[i]-path[i-1]).normalized()!=(path[i+1]-path[i]).normalized():bends+=1
			if bends>turns:route=path;turns=bends
			if turns>=3:break
		assert_gte(turns,3,"Native route includes several cave corners: "+place)
		assert_false(route.is_empty())
		var max_gap:=0.0
		var max_collision:=0.0
		var pp:=player.pp.duplicate()
		# Walk the same route out, dash back, then walk out at increased speed.
		for speed in [player.move_speed(),Player.DODGE_DISTANCE/Player.DODGE_DURATION,160.0]:
			for goal in route:
				for _tick in 600:
					if player.position.distance_to(goal)<0.01:break
					var next:=player.position.move_toward(goal,speed*DT)
					player.vel=(next-player.position)/DT
					player.position=next
					event.follow(DT)
					var helper_feet: Vector2=event.helper.position+Vector2(0,event.helper.feet_offset())
					max_gap=maxf(max_gap,helper_feet.distance_to(next+Vector2(0,player.feet_offset())))
					max_collision=maxf(max_collision,Arena.resolve(helper_feet,event.helper.radius).distance_to(helper_feet))
				assert_lt(player.position.distance_to(goal),0.01,"Player reaches each waypoint")
			player.vel=Vector2.ZERO
			for _tick in 30:event.follow(DT)
			var parked: Vector2=event.helper.position
			for _tick in 30:event.follow(DT)
			assert_eq(event.helper.position,parked,"Pikachu settles without jitter when the player stops")
			route.reverse()
		assert_lte(max_gap,float(Arena.TILE)+0.01,"One-tile limit while moving, including corners: "+place)
		assert_lt(max_collision,0.1,"Fast catch-up stays on walkable floor: "+place)
		assert_eq(player.pp,pp)
		game.state="menu"
		var parked: Vector2=event.helper.position
		event.follow(1.0)
		assert_eq(event.helper.position,parked)
		assert_eq(event.helper.vel,Vector2.ZERO)

func test_native_cave_ladder_network_connects_north_to_south_exit() -> void:
	var edges: Dictionary={}
	for place in Rescue.CAVES:
		DungeonDB.set_current(place);Arena.configure(DungeonDB.theme())
		var map: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/"+place+"/map.json"))
		for warp in map.warps:
			var key: String=place+":"+str(int(warp.index))
			edges[key]=[]
			var seen:=reachable(Vector2i(int(warp.x),int(warp.y)))
			for other in map.warps:
				if seen.has(Vector2i(int(other.x),int(other.y))):edges[key].append(place+":"+str(int(other.index)))
			if String(warp.to) in Rescue.CAVES:edges[key].append(String(warp.to)+":"+str(int(warp.to_warp)))
	var seen: Dictionary={"rock_tunnel_1f:0":true};var queue: Array=["rock_tunnel_1f:0"]
	while not queue.is_empty():
		var at: String=queue.pop_front()
		for next in edges.get(at,[]):
			if not seen.has(next):seen[next]=true;queue.append(next)
	assert_true(seen.has("rock_tunnel_1f:5"),"Both floors form a traversable north-to-south route")

func test_new_city_links_are_reciprocal_and_native_water_stays_flat() -> void:
	var region: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_rock_pass/map.json"))
	var field: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_field/map.json"))
	var links: Array=region.warps.filter(func(w):return w.get("rock_pass_link",false))
	assert_gt(links.size(),0)
	for link in links:
		var matching: Array=field.warps.filter(func(w):return w.get("rock_pass_link",false) and int(w.index)==int(link.to_warp))
		assert_eq(matching.size(),1)
		assert_eq(matching[0].to,"route9")
		assert_eq(int(matching[0].to_warp),int(link.index))
	var water: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_rock_pass/water.json"))
	var cards: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_rock_pass/hd2d_cards.json"))
	var intrusions: Array=[]
	for card in cards.cards:
		var x:=int(card[0]);var y:=int(card[1])+int(card[2])-1
		if x>=0 and x<int(region.width) and y>=0 and y<int(region.height) and water.water[y][x]=="1":intrusions.append(card)
	assert_eq(intrusions.size(),0,"Water behind the frightened Pikachu is a horizontal surface, not a blue wall")

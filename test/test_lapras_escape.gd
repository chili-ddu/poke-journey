extends GutTest
const Game=preload("res://scripts/game.gd")
const Event=preload("res://scripts/story/lapras_escape.gd")
const Data=Event.Data
const DT=1.0/60.0
var old_path: String
var old_events: Array
var old_starter: String
var old_beaten: Array

class Still:
	extends RefCounted
	var moving:=Vector2.ZERO
	func move_dir(_w):return moving
	func aim_point(w):return w.player.position+Vector2.UP*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func before_each() -> void:
	old_path=SaveData.path;SaveData.path="user://save_lapras_escape_test.cfg";SaveData.clear()
	old_events=Game.bot_events.duplicate();old_starter=Game.starter
	old_beaten=Game.bot_beaten.duplicate();Game.bot_beaten=[]

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path
	Game.bot_events=old_events;Game.bot_beaten=old_beaten;Game.starter=old_starter;Game.destination={};Game.carry={};Game.arena_trip={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func beach() -> Vector2:return Vector2(216.5,353.5)*Arena.TILE

func fixture(place: String=Data.PLACE,flags: Array=[],human: bool=false):
	var bot:=OS.get_environment("BOT");var where:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0" if human else "1");OS.set_environment("DUNGEON",place)
	Game.starter="charmander";Game.bot_events=flags.duplicate();Game.destination={};Game.carry={}
	Game.arena_trip={"event":Data.ID,"arena":Data.ARENA,"back":{"map":Data.PLACE,"pos":beach(),"layout":1}} if place==Data.ARENA else {}
	if human:
		for flag in flags:SaveData.store_progress("events",flag)
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	game.world.player.controller=Still.new();game.world.player.repel_steps=99999;game.lure_t=99999
	game.dialog_text="" if game.state in ["fight","town"] else game.dialog_text;game.dialog_t=0
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",where)
	return game

func finish(game) -> void:
	for _i in 60:
		if game.state!="talk":break
		game._talk_next()

func shore(game,area: String) -> bool:
	for tile in Arena._water:
		if Arena.area_at(Arena.tile_center(tile))!=area:continue
		for d in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var land: Vector2i=tile+d;var at:=Arena.tile_center(land)
			if Arena.is_water(land) or Arena.area_at(at)!=area or Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1:continue
			if Arena.resolve(Arena.tile_center(tile),game.world.player.radius,false,2).distance_to(Arena.tile_center(tile))>0.1:continue
			game.world.player.position=at;game.world.player.facing=-Vector2(d);return true
	return false

func test_old_escape_flags_do_not_spawn_the_exhibit_staff_or_grant_surf() -> void:
	for flags in [[],[Data.STARTED],[Data.WON],[Data.STARTED,Data.WON]]:
		var game=fixture(Data.PLACE,flags)
		assert_not_null(game.lapras_escape)
		assert_eq(game.lapras_escape.phase,"idle")
		assert_false(game.events.has(Data.FRIEND))
		assert_true(game.world.bystanders.filter(func(m):return m.species_id=="lapras").is_empty())
		assert_true(game.world.npcs.filter(func(n):return n.talk==Data.ID or n.id.begins_with("lapras_staff_")).is_empty())
		assert_true(shore(game,"fuchsia_city"));assert_false(game.lapras_escape.try_call())
		assert_eq(game.state,"fight");assert_true(Game.arena_trip.is_empty())

func test_call_requires_friend_and_real_shore_then_boards_with_no_pp_or_exp_cost() -> void:
	var locked=fixture()
	assert_true(shore(locked,"fuchsia_city"));assert_false(locked.lapras_escape.try_call())
	assert_eq(locked.world.player.travel_terrain,0)
	var game=fixture(Data.PLACE,[Data.FRIEND]);var event=game.lapras_escape
	assert_true(shore(game,"route19"))
	var pp: Array=game.world.player.pp.duplicate();var exp: int=game.world.player.exp_total
	assert_true(event.try_call());assert_false(event.try_call())
	assert_eq(game.state,"lapras_event")
	for at in event.call_path:assert_true(Arena.is_water(Arena.tile_of(at)))
	game.advance(0.4);game.advance(0.7)
	assert_eq(game.state,"fight");assert_eq(game.world.player.travel_terrain,2)
	assert_not_null(event.helper);assert_true(event.mounted)
	assert_eq(game.world.player.pp,pp);assert_eq(game.world.player.exp_total,exp)
	assert_eq(game.world.player.lift,Event.RIDE_LIFT)
	assert_eq(game.world.bystanders.filter(func(m):return m==event.helper).size(),1)
	game.state="menu";assert_false(event.try_call())
	game.state="fight";game.world.player.travel_terrain=0
	event.follow(0.1);event.follow(0.4)
	assert_null(event.helper);assert_eq(game.world.player.lift,0.0)

func test_existing_surf_save_recreates_only_one_mount_and_boarding_save_stays_on_land() -> void:
	var game=fixture(Data.PLACE,[Data.FRIEND],true);var event=game.lapras_escape
	assert_true(shore(game,"route19"));var original: Vector2=game.world.player.position
	assert_true(event.try_call());game.advance(0.4)
	game._save_here();assert_eq(SaveData.load_saved().pos,original)
	game.advance(0.7);game._save_here()
	assert_true(Arena.is_water(Arena.tile_of(SaveData.load_saved().pos)))
	event.follow(0.1);event.follow(0.1)
	assert_eq(game.world.bystanders.filter(func(m):return m.species_id=="lapras").size(),1)
	assert_true(SaveData.load_saved().events.has(Data.FRIEND))

func test_friend_answers_at_safari_and_cave_water_and_yields_to_fly_carry() -> void:
	for place in ["safari_zone_center","seafoam_islands_b4f"]:
		var game=fixture(place,[Data.FRIEND]);var event=game.lapras_escape
		var area: String=Arena._areas[0].id
		assert_true(shore(game,area),place+" has an accessible shoreline")
		assert_true(event.try_call(),place+" can call the friend")
		for point in event.call_path:assert_true(Arena.is_water(Arena.tile_of(point)))
		game.advance(0.4);game.advance(0.7)
		assert_true(event.mounted);assert_eq(game.world.player.travel_terrain,2)
		game.world.player.set_meta("carried",true);game.world.player.lift=30.0
		event.follow(0.1)
		assert_null(event.helper);assert_false(event.mounted)
		assert_eq(game.world.player.lift,30.0,"Does not reset the bird's carrying height")

func test_eight_direction_seats_and_front_masks_follow_native_swim_frames() -> void:
	var game=fixture(Data.PLACE,[Data.FRIEND]);var event=game.lapras_escape
	assert_true(shore(game,"route19"));assert_true(event.try_call())
	game.advance(0.4);game.advance(0.7)
	var ride=event.ride;var p: Player=game.world.player
	assert_true(p.has_meta("lapras_ride"));assert_true(event.helper.get_meta("lapras_carrier"))
	var original:=p.position
	for row in 8:
		p.facing=Vector2.from_angle(PI/2.0-row*TAU/8.0)
		for frame in 4:
			event.helper.anim_t=MonSprite.frame_start(event.helper._sprites.Walk,frame)+0.001
			event.follow(0.0)
			var pose: Dictionary=ride.pose()
			assert_eq(pose.row,row)
			var foot: Vector2=Vector2(0,p.feet_offset()-p.lift)+ride.offset_2d()
			var seat: Vector2=event.helper.position-p.position+Vector2(0,event.helper.radius*Mon.GROUND_RATIO)+(pose.seat-pose.center)*event.helper.sprite_scale
			assert_lt(foot.distance_to(seat),0.001)
			var image: Image=Event.Ride.foreground(pose.visual.tex,pose.visual.src,pose).get_image()
			assert_gt(image.get_used_rect().size.length(),0.0)
			if row in [0,1,7]:
				var source: Image=pose.visual.tex.get_image()
				if source.is_compressed():source.decompress()
				var samples: Dictionary={0:[Vector2(17,23),Vector2(23,11)],1:[Vector2(17,22),Vector2(28,12)],7:[Vector2(30,22),Vector2(19,12)]}
				var delta: Vector2=pose.seat-Event.Ride.SEATS[row]
				var shell:=Vector2i(samples[row][0]+delta)
				var neck:=Vector2i(samples[row][1]+delta)
				var cell:=source.get_region(Rect2i(pose.visual.src))
				assert_gt(cell.get_pixelv(shell).a,0.5,"Shell sample belongs to the native sprite")
				assert_eq(image.get_pixelv(shell).a,0.0,"Passenger renders over the shell")
				assert_gt(cell.get_pixelv(neck).a,0.5,"Neck sample belongs to the native sprite")
				assert_eq(image.get_pixelv(neck),cell.get_pixelv(neck),"Near head and neck stay in front of the passenger")
		assert_eq(p.position,original,"Direction changes only affect the drawing, not collision or saved coordinates")
	assert_true(Event.Ride.in_front(Vector2(23,11),Event.Ride.SEATS[0],0),"South-facing neck is in front")
	assert_false(Event.Ride.in_front(Vector2(23,11),Event.Ride.SEATS[4],4),"North-facing neck is behind the rider")
	p.travel_terrain=0;event.follow(0.0)
	assert_false(p.has_meta("lapras_ride"));assert_false(event.helper.has_meta("lapras_carrier"))
	assert_null(event.ride)

func test_surf_support_keeps_both_lapras_sprite_variants() -> void:
	assert_true(MonSprite.load_set(131).has("Walk"))
	assert_true(MonSprite.load_set(131,true).has("Walk"))

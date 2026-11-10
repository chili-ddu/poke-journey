extends "res://tools/kanto_expansion_review.gd"
const Game=preload("res://scripts/game.gd")
const CITY_OUT="res://docs/saffron_access/"

func setup_controller() -> void:
	super.setup_controller()
	game.bot=false;game.world.god=true
	game.road_pursuit.clear(game.world)

func shot(label: String) -> void:
	game.ui_root.visible=label=="10_mart"
	for _i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CITY_OUT+label+".png")

func go(to: String, label: String) -> void:
	var doors: Array=Arena.warps().filter(func(w):return w.to==to)
	assert(not doors.is_empty())
	var door: Dictionary=doors[0]
	print("SAFFRON WALK ",DungeonDB.current," -> ",to)
	await walk_to(Vector2i(int(door.x),int(door.y)),true)
	print("SAFFRON DOOR REACHED ",to)
	assert(game.state=="warp")
	await arrive(DungeonDB.WARP_MAPS[to],label)
	print("SAFFRON ARRIVED ",DungeonDB.current)

func finish_talk() -> void:
	for _i in 10:
		if game.state!="talk":return
		game._talk_next()

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CITY_OUT))
	SaveData.path="user://save_saffron_access_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander";Game.bot_events=[];Game.destination={};Game.carry={};Game.arena_trip={}
	await open_fixture("kanto_south")
	var gate: Dictionary=Arena.warps().filter(func(w):return w.to=="route5_south_entrance")[0]
	var gate_tile:=Vector2i(int(gate.x),int(gate.y))
	game.world.player.position=Arena.tile_center(gate_tile+game._door_out_dir(gate_tile));walker.target=game.world.player.position
	game.events.clear();game.beaten.clear();game.world.player.bag.clear()
	game.world.player.hp-=3
	var pp: Array=game.world.player.pp.duplicate();var exp_before: int=game.world.player.exp_total
	OS.set_environment("BOT","0")
	await go("route5_south_entrance","00_route5_gate")
	await go("saffron_city","01_north_entry")
	assert(game.events.has(FlyDestinations.visit_flag("saffron_city")))
	await walk_to(Vector2i(24,40));await shot("02_city_street")
	await go("route6_north_entrance","03_south_gate")
	await go("route6","04_route6")
	assert(Arena.area_at(game.world.player.position)=="route6")
	await go("route6_north_entrance","05_return_south_gate")
	await go("saffron_city","06_south_entry")
	await go("route5_south_entrance","07_north_gate")
	await go("route5","08_route5")
	assert(Arena.area_at(game.world.player.position)=="route5")
	assert(results.size()==8)
	# Ordinary doors already restore HP/PP throughout this game.
	assert(game.world.player.hp==game.world.player.max_hp and game.world.player.pp==pp and game.world.player.exp_total==exp_before)
	var saved:=SaveData.load_saved()
	assert(saved.events.has(FlyDestinations.visit_flag("saffron_city")))
	assert(FlyDestinations.can_fly("saffron_city",saved.events))
	var report={"actual_scene_transitions":results.duplicate(true),"north_south_round_trip_walked":true,
		"tea_badge_bill_silph_requirements":false,"normal_door_recovery":true,"pp_exp_preserved":true,"visit_flag_saved":true,"fly_requires_visit":true}
	OS.set_environment("BOT","1")
	await open_fixture("saffron_city_pokemon_center_1f")
	var nurse: Npc=game.world.npcs.filter(func(n):return n.talk=="nurse")[0]
	var p: Player=game.world.player
	p.hp=maxi(1,p.max_hp-4);p.pp[0]=0
	game._talk(nurse);finish_talk()
	assert(game.state=="heal")
	for _i in 300:
		if game.state!="heal":break
		game.advance(0.1)
	assert(p.hp==p.max_hp and p.pp[0]>0)
	finish_talk();await shot("09_center")
	report.healing_works=true
	await open_fixture("saffron_city_mart")
	var clerk: Npc=game.world.npcs.filter(func(n):return n.talk=="shop")[0]
	game._talk(clerk);assert(game.menu=="shop")
	await shot("10_mart")
	report.shop_opens=true
	FileAccess.open(CITY_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("Saffron review passed: eight real transitions, both gate directions walked without progress/items, visit saved, healing and shop verified")
	game.free();await process_frame;SaveData.clear();quit()

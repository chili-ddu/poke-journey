extends GutTest
const Game=preload("res://scripts/game.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
const PATH="user://save_fly_map_test.cfg"
var old_path: String
var old_events: Array
var old_starter: String

func before_each() -> void:
	old_path=SaveData.path;SaveData.path=PATH;SaveData.clear()
	old_events=Game.bot_events.duplicate();Game.bot_events=[Bird.FRIEND]
	SaveData.store_progress("events",Bird.FRIEND)
	old_starter=Game.starter;Game.starter="charmander"

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path;Game.bot_events=old_events;Game.starter=old_starter
	Game.destination={};Game.arena_trip={};Game.carry={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture(place: String="kanto_south", human: bool=false):
	var keep_bot:=OS.get_environment("BOT");var keep_place:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0" if human else "1");OS.set_environment("DUNGEON",place)
	Game.destination={};Game.arena_trip={};Game.carry={}
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",keep_bot);OS.set_environment("DUNGEON",keep_place)
	game.dialog_text="";game.dialog_t=0.0
	return game

func key(screen,code: Key,echo: bool=false) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;event.echo=echo
	screen._unhandled_input(event)

func click(screen,at: Vector2) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	event.position=screen.origin()+at;screen._gui_input(event)

func open_map(game) -> void:
	game.world.player.position=Arena.tile_center(Arena.area_tile("pallet_town",Vector2i(11,9)))
	game.world._start_hop(game.world.player.position+Vector2.UP*24.0)
	var event:=InputEventKey.new();event.physical_keycode=KEY_SPACE;event.pressed=true
	game._unhandled_input(event)

func test_native_map_only_visited_implemented_regions_are_available() -> void:
	assert_true(FlyDestinations.available().is_empty())
	var visits: Array=[]
	for entry in FlyDestinations.all_locations():visits.append(FlyDestinations.visit_flag(entry.id))
	visits.append(RoadAccess.SNORLAX_AWAKENED)
	var ids: Array=FlyDestinations.available(visits).map(func(entry):return entry.id)
	assert_eq(ids.size(),36)
	for id in ["pallet_town","viridian_city","pewter_city","cerulean_city","vermilion_city","saffron_city","route1","route2","route3","route4","route5","route6","route11","route24","route25"]:
		assert_true(ids.has(id),id)
	assert_true(FlyDestinations.find("saffron_city").enabled)
	assert_false(FlyDestinations.can_fly("saffron_city",[]),"An open city still has to be visited before flying there")
	assert_true(FlyDestinations.find("route8").enabled)
	var texture: Texture2D=load("res://assets/ui/kanto_town_map.png")
	assert_eq(texture.get_size(),Vector2(240,160))
	assert_eq(FlyDestinations.find("pallet_town").region,[64.0,120.0,8.0,8.0])

func test_second_airborne_space_opens_map_and_pauses_hop_before_pickup() -> void:
	var game=fixture();open_map(game)
	assert_eq(game.state,"menu");assert_eq(game.menu,"fly")
	assert_true(game.fly_screen.visible);assert_eq(game.bird_event.phase,"selecting")
	assert_null(game.bird_event.helper)
	var at: Vector2=game.world.player.position;var hop: float=game.world.player.hop_t
	var dash: Dictionary=game.world.player.dash.duplicate(true)
	game.advance(2.0)
	assert_eq(game.world.player.position,at);assert_eq(game.world.player.hop_t,hop);assert_eq(game.world.player.dash,dash)
	assert_false(game.bird_event.camera_locked,"Choosing or cancelling a destination cannot lock the camera")

func test_town_map_opens_without_fly_and_views_unvisited_places_without_travel() -> void:
	var game=fixture();game.events=[]
	var at: Vector2=game.world.player.position
	var hp: int=game.world.player.hp
	var pp: Array=game.world.player.pp.duplicate()
	game._open_town_map()
	assert_eq(game.menu,"town_map");assert_true(game.fly_screen.browse_only)
	assert_eq(game.fly_screen.entries.size(),FlyDestinations.all_locations().size())
	var entry:=FlyDestinations.find("vermilion_city");var r: Array=entry.region
	click(game.fly_screen,game.fly_screen.MAP.position+Vector2(r[0]+4,r[1]+4))
	assert_eq(game.fly_screen.selected().id,"vermilion_city")
	key(game.fly_screen,KEY_ENTER)
	assert_eq(game.state,"fight");assert_false(game.fly_screen.visible)
	assert_eq(game.bird_event.phase,"idle");assert_true(game.bird_event.travel_target.is_empty())
	assert_eq(game.world.player.position,at);assert_eq(game.world.player.hp,hp);assert_eq(game.world.player.pp,pp)
	assert_true(game.events.is_empty())

func test_town_map_m_toggles_and_flight_reopens_with_original_restrictions() -> void:
	var game=fixture()
	key(game,KEY_M);assert_eq(game.menu,"town_map")
	key(game.fly_screen,KEY_M);assert_eq(game.state,"fight")
	open_map(game)
	assert_eq(game.menu,"fly");assert_false(game.fly_screen.browse_only)
	assert_false(game.fly_screen.entries.any(func(entry):return entry.id=="vermilion_city"))
	key(game.fly_screen,KEY_ESCAPE)
	assert_eq(game.bird_event.phase,"idle")

func test_cancel_resumes_same_jump_without_a_bird_or_resource_cost() -> void:
	var game=fixture();open_map(game)
	var at: Vector2=game.world.player.position;var hp: int=game.world.player.hp
	var pp: Array=game.world.player.pp.duplicate();var exp_before: int=game.world.player.exp_total
	key(game.fly_screen,KEY_ESCAPE)
	assert_eq(game.state,"fight");assert_eq(game.bird_event.phase,"idle");assert_false(game.fly_screen.visible)
	assert_null(game.bird_event.helper);assert_true(game.world.player.dash.get("hop",false))
	assert_eq(game.world.player.position,at);assert_eq(game.world.player.hp,hp);assert_eq(game.world.player.pp,pp);assert_eq(game.world.player.exp_total,exp_before)

func test_keyboard_selection_confirms_once_and_repeated_space_does_not_choose() -> void:
	var game=fixture();game.events.append(FlyDestinations.visit_flag("viridian_city"));open_map(game)
	var screen: FlyMapScreen=game.fly_screen
	key(screen,KEY_DOWN);assert_eq(screen.cursor,1)
	key(screen,KEY_SPACE,true)
	assert_eq(game.menu,"fly");assert_null(game.bird_event.helper)
	key(screen,KEY_ENTER)
	assert_eq(game.bird_event.travel_target.id,"viridian_city")
	assert_eq(game.bird_event.phase,"calling");assert_false(screen.visible)
	assert_eq(game.bird_event.helper.species_id,"pidgeotto")
	game.bird_event.choose_destination("route25")
	assert_eq(game.bird_event.travel_target.id,"viridian_city","A confirmed trip cannot be overwritten")

func test_mouse_selects_map_routes_and_rejects_unbuilt_regions() -> void:
	var game=fixture();game.events.append(FlyDestinations.visit_flag("route24"));open_map(game)
	var screen: FlyMapScreen=game.fly_screen
	var saffron:=FlyDestinations.find("saffron_city");var r: Array=saffron.region
	click(screen,screen.MAP.position+Vector2(float(r[0])+4,float(r[1])+4))
	assert_string_contains(screen.notice,FlyDestinations.label(saffron));assert_eq(game.menu,"fly")
	game.events.append(RoadAccess.SAFFRON_VISITED);screen.open("pallet_town",game.events)
	var route:=FlyDestinations.find("route24");r=route.region
	click(screen,screen.MAP.position+Vector2(float(r[0])+4,float(r[1])+4))
	assert_eq(screen.selected().id,"route24")
	click(screen,screen.CONFIRM.get_center())
	assert_eq(game.bird_event.travel_target.id,"route24");assert_eq(game.bird_event.phase,"calling")

func test_every_destination_has_safe_ground_for_small_and_large_passengers() -> void:
	for place in ["kanto_world","saffron_city"]:
		var game=fixture(place)
		for radius in [8.0,12.0,16.0]:
			game.world.player.radius=radius
			for entry in FlyDestinations.all_locations():
				if not entry.enabled:continue
				if entry.map!=place:continue
				var at: Vector2=game.bird_event.arrival_point(entry.id)
				assert_ne(at,Vector2.INF,entry.id)
				assert_eq(Arena.area_at(at),String(entry.get("area",entry.id)))
				assert_true(game.bird_event.can_land(at),entry.id)
				assert_false(Arena.is_water(Arena.tile_of(at)));assert_true(Arena.warp_at(at).is_empty())
		game.free()

func test_arrival_saves_target_ground_before_the_bird_leaves() -> void:
	var game=fixture("cerulean_north");game.bot=false
	game.world.player.hp=11
	game.bird_event.arrive("route25")
	assert_eq(game.bird_event.phase,"fly_arrive");assert_eq(game.world.player.lift,game.bird_event.arrival_height)
	assert_false(game.bird_event.camera_locked,"Arrival releases the departure camera lock")
	assert_true(game.bird_event.landing_camera_active(),"Frame the ground instead of following the falling passenger")
	assert_eq(game.world.player.hp,11)
	var saved:=SaveData.load_saved()
	assert_eq(saved.map,"cerulean_north");assert_eq(Arena.area_at(saved.pos),"route25")
	assert_true(saved.events.has(Bird.FRIEND))
	game.advance(Bird.ARRIVE_TIME+0.01)
	assert_eq(game.bird_event.phase,"landing_release")
	assert_true(game.world.player.get_meta("carried",false),"Feet touch down before the talons release")
	game.advance(Bird.RELEASE_TIME+0.01)
	var lift: float=game.bird_event.helper.lift
	game.advance(0.01)
	assert_gt(game.bird_event.helper.lift,lift,"The helper lifts away without snapping down to zero")
	game.advance(Bird.LEAVE_TIME+0.01)
	assert_eq(game.state,"fight");assert_eq(game.bird_event.phase,"idle")
	assert_eq(game.world.player.lift,0.0);assert_eq(game.world.player.hp,11)

func test_landing_descends_vertically_slows_near_ground_and_releases_after_touchdown() -> void:
	for species in ["charmander","blastoise"]:
		var game=fixture("cerulean_north")
		game.world.player.setup_player(species,5 if species=="charmander" else 36,[],{})
		game.bird_event.arrive("route25")
		var bird=game.bird_event
		var p: Player=game.world.player
		var at:=p.position;var initial:=p.lift
		assert_gte(initial,96.0,"Start above the visible field")
		var drops: Array[float]=[]
		var previous:=initial
		for _i in 3:
			game.advance(Bird.ARRIVE_TIME*0.25)
			drops.append(previous-p.lift);previous=p.lift
			assert_eq(p.position,at,"Descent cannot slide sideways")
			assert_true(p.get_meta("carried",false))
			assert_almost_eq(bird.helper.lift-p.lift,bird.carry_gap,0.001,"Keep the talons attached while descending")
			assert_eq(game.world.cam.position,at.round(),"Hold the camera on the landing site")
		assert_gt(drops[0],drops[1]);assert_gt(drops[1],drops[2],"Decelerate toward the feet")
		game.advance(Bird.ARRIVE_TIME*0.25-0.01)
		assert_gt(p.lift,0.0);assert_lt(p.lift,0.1,"Ease into contact without a final drop")
		game.advance(0.02)
		assert_eq(p.lift,0.0);assert_eq(bird.phase,"landing_release")
		assert_true(p.get_meta("carried",false))
		game.advance(Bird.RELEASE_TIME-0.01)
		assert_true(p.get_meta("carried",false),"Support the grounded passenger for a short beat")
		game.advance(0.02)
		assert_false(p.get_meta("carried",false));assert_eq(bird.phase,"flight_leave")
		game.free()

func test_unvisited_map_click_and_direct_request_cannot_start_flight() -> void:
	var game=fixture();open_map(game)
	assert_false(game.fly_screen.entries.any(func(entry):return entry.id=="vermilion_city"))
	var selected_before: String=game.fly_screen.selected().id
	var entry:=FlyDestinations.find("vermilion_city");var rect: Array=entry.region
	click(game.fly_screen,game.fly_screen.MAP.position+Vector2(rect[0]+4,rect[1]+4))
	assert_eq(game.fly_screen.selected().id,selected_before,"Unvisited clicks must not select the first available row")
	assert_string_contains(game.fly_screen.notice,FlyDestinations.label(entry))
	assert_eq(game.menu,"fly")
	game.bird_event.choose_destination("vermilion_city")
	assert_eq(game.menu,"fly")
	assert_eq(game.bird_event.phase,"selecting")
	assert_null(game.bird_event.helper)
func test_walking_into_region_unlocks_only_that_region_and_persists() -> void:
	var game=fixture();game.bot=false
	game.events=[Bird.FRIEND]
	game.quests.flag("campaign_hooh_sighted") # This test follows travel visits after the one-time tutorial.
	game.world.player.position=Arena.tile_center(Arena.area_tile("pallet_town",Vector2i(11,9)))
	game._record_area_visit()
	assert_true(FlyDestinations.can_fly("pallet_town",game.events))
	assert_false(FlyDestinations.can_fly("cerulean_city",game.events),"Sharing a loaded field is not a visit")
	game.world.player.position=game.bird_event.arrival_point("route1")
	game.advance(0.0)
	assert_true(FlyDestinations.can_fly("route1",game.events))
	assert_false(FlyDestinations.can_fly("vermilion_city",game.events))
	var saved:=SaveData.load_saved()
	assert_true(FlyDestinations.can_fly("route1",saved.events))
	game._carry_out()
	assert_true(FlyDestinations.can_fly("route1",Game.carry.events))
	game._save_here()
	var restored=fixture("kanto_south",true)
	assert_true(FlyDestinations.can_fly("route1",restored.events),"Visits are restored from the active save")
	assert_false(FlyDestinations.can_fly("vermilion_city",restored.events))
	game.events=[Bird.FRIEND]
	assert_false(FlyDestinations.can_fly("route1",game.events),"A separate record cannot inherit another record's visits")
	game.world.player.position=game.bird_event.arrival_point("route2")
	game.world.player.set_meta("carried",true)
	game._record_area_visit()
	assert_false(FlyDestinations.can_fly("route2",game.events),"Being carried over an area is not a visit")

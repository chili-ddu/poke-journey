extends GutTest
const Exposure = preload("res://scripts/battle/trainer_exposure.gd")
const Search = preload("res://scripts/battle/trainer_search.gd")

func test_hiding_wait_starts_after_stopping_and_resets_when_moving_or_using_skills() -> void:
	var e=Exposure.new()
	e.sync_visit("viridian_forest")
	e.attention=100.0
	e.advance_gauge(60.0,false,false)
	e.advance_gauge(1.5,true,false)
	assert_eq(e.attention,100.0,"Time spent exposed cannot count toward hiding")
	e.advance_gauge(1.0,true,false)
	assert_eq(e.attention,93.0)
	e.advance_gauge(0.1,true,true)
	e.advance_gauge(1.5,true,false)
	assert_eq(e.attention,93.0,"Moving restarts the hiding wait")
	e.notice("viridian_forest",Exposure.MOVE_ATTENTION,true)
	e.advance_gauge(1.5,true,false)
	assert_eq(e.attention,99.0,"Using a skill also restarts the hiding wait")

func test_exposure_alone_reaches_alert_without_skill_use() -> void:
	for fps in [30,60,120]:
		var e=Exposure.new()
		e.sync_visit("viridian_forest")
		for frame in fps*49:e.advance_gauge(1.0/fps,false,true)
		assert_almost_eq(e.attention,98.0,0.001,"Exposure builds alert without using skills")
		for frame in fps:e.advance_gauge(1.0/fps,false,true)
		assert_almost_eq(e.attention,100.0,0.001,"Alert reaches its cap after 50 seconds")

func test_cave_exposure_rises_faster_than_outdoor_exposure() -> void:
	var previous := DungeonDB.current
	for place in ["mt_moon_1f","mt_moon_b1f","mt_moon_b2f"]:
		DungeonDB.set_current(place)
		var e=Exposure.new()
		e.sync_visit(place)
		e.advance_gauge(10.0,false,false)
		assert_eq(e.attention,30.0,"Each cave floor gains three points per second")
		e.advance_gauge(24.0,false,true)
		assert_eq(e.attention,100.0,"Cave exposure stays capped at 100")
	DungeonDB.set_current("kanto_north")
	var outdoor=Exposure.new()
	outdoor.sync_visit("route3")
	outdoor.advance_gauge(10.0,false,false)
	assert_eq(outdoor.attention,20.0,"Outdoor exposure remains two points per second")
	DungeonDB.set_current(previous)

func test_full_alert_hiding_time_is_consistent_across_frame_rates() -> void:
	for fps in [30,60,120]:
		var e=Exposure.new()
		e.sync_visit("viridian_forest")
		e.attention=100.0
		for frame in fps*11:e.advance_gauge(1.0/fps,true,false)
		assert_gt(e.attention,Exposure.RETREAT_BELOW,"At eleven seconds the search is still active")
		for frame in fps:e.advance_gauge(1.0/fps,true,false)
		assert_lt(e.attention,Exposure.RETREAT_BELOW,"At twelve seconds hiding has ended the search")

class RetreatProbe:
	extends "res://scripts/battle/trainer_search.gd"
	func step(_world: World,_view,_dt: float,_excluded: Array,_allow_spawn: bool) -> Npc:return null

func test_search_retires_below_thirty_even_after_local_roster_is_exhausted() -> void:
	var w:=forest_world()
	var e=Exposure.new()
	e.sync_visit("viridian_forest")
	var fixture=searcher(w)
	var driver=RetreatProbe.new()
	driver.actor=fixture.actor
	driver.area="viridian_forest"
	driver.phase="search"
	e.pursuits.append(driver)
	e.deployed=e.Data.POOLS.viridian_forest.duplicate()
	var bounds:=Arena.area_rect("viridian_forest")
	var found:=false
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var cell:=Vector2i(x,y)
			if not Arena.is_grass(cell) or not driver.walkable(cell):continue
			w.player.position=Arena.tile_center(cell)-Vector2(0,w.player.feet_offset())
			found=true
			break
		if found:break
	assert_true(found)
	e.previous_position=w.player.position
	e.attention=30.0
	e.quiet_t=1.5
	e.step(w,null,0.0,[],false)
	assert_eq(driver.phase,"search","Thirty percent still permits searching")
	e.step(w,null,0.1,[],false)
	assert_lt(e.attention,30.0)
	assert_eq(driver.phase,"leaving","Below thirty percent sends the trainer home")
	assert_false(e.searching())

func forest_world() -> World:
	DungeonDB.set_current("viridian_forest")
	Arena.configure(DungeonDB.theme())
	var w:=World.new()
	add_child_autofree(w)
	w.player=Player.new()
	w.add_child(w.player)
	w.player.setup_player("charmander",5,["scratch","growl"])
	return w

func searcher(w: World):
	var driver=Search.new()
	driver.area="viridian_forest"
	driver.phase="search"
	driver.actor=Npc.new()
	driver.actor.setup({"id":"bug_catcher_sammy","trainer":"bug_catcher_sammy","tile":Vector2i(5,16)})
	w.add_child(driver.actor)
	return driver

func test_active_search_holds_full_gauge_outside_and_hiding_reduces_it() -> void:
	var w:=forest_world()
	var e=Exposure.new()
	e.sync_visit("viridian_forest")
	var driver=searcher(w)
	e.pursuits.append(driver)
	e.attention=100.0
	e.advance_gauge(20.0,false,false)
	assert_eq(e.attention,100.0)
	e.advance_gauge(11.5,true,false)
	assert_eq(e.attention,30.0)
	e.advance_gauge(1.0,true,true)
	assert_eq(e.attention,30.0,"Moving in grass stops the hiding reduction")
	e.advance_gauge(0.1,false,true)
	assert_eq(e.attention,100.0,"Leaving cover restores full alert while a trainer is searching")

func test_hidden_player_is_only_detected_in_the_same_grass_cell() -> void:
	var w:=forest_world()
	var driver=searcher(w)
	var grass:=Vector2i(-1,-1)
	var bounds:=Arena.area_rect("viridian_forest")
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			if Arena.is_grass(Vector2i(x,y)) and driver.walkable(Vector2i(x,y)):
				grass=Vector2i(x,y)
				break
		if grass.x>=0:break
	assert_ne(grass,Vector2i(-1,-1))
	w.player.position=Arena.tile_center(grass)-Vector2(0,w.player.feet_offset())
	driver.actor.position=Arena.tile_center(grass)+Vector2.RIGHT*Arena.TILE
	driver.actor.face="left"
	assert_false(driver.detects(w),"Facing the player does not reveal a neighboring grass cell")
	driver.actor.position=Arena.tile_center(grass)
	assert_true(driver.detects(w),"Searching the occupied cell discovers a hidden player")
	driver.retire()
	assert_false(driver.detects(w),"A departing trainer no longer initiates encounters")

func test_searching_trainer_cannot_push_a_hidden_player_out_before_discovery() -> void:
	var w:=forest_world()
	var driver=searcher(w)
	driver.actor.set_meta("roaming_trainer",true)
	w.npcs.append(driver.actor)
	w.player.position=driver.actor.position+Vector2.RIGHT*5
	var before:=w.player.position
	w._push_out_of_npcs()
	assert_eq(w.player.position,before,"Search-cell detection happens without pushing the player out of cover")
	driver.actor.remove_meta("roaming_trainer")
	w._push_out_of_npcs()
	assert_ne(w.player.position,before,"Ordinary fixed NPCs retain body collision")

func test_outside_detection_respects_facing_range_and_occlusion() -> void:
	var w:=forest_world()
	var driver=searcher(w)
	var found:=false
	var bounds:=Arena.area_rect("viridian_forest")
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x-3):
			var start:=Vector2i(x,y)
			var end:=start+Vector2i(3,0)
			if Arena.is_grass(end) or not driver.reachable_contact(Arena.tile_center(start),Arena.tile_center(end)):continue
			driver.actor.position=Arena.tile_center(start)
			w.player.position=Arena.tile_center(end)
			if Arena.is_grass(driver.player_cell(w)):continue
			found=true
			break
		if found:break
	assert_true(found)
	driver.actor.face="right"
	assert_true(driver.detects(w),"Exposed Pokémon in the front of the trainer are spotted")
	driver.actor.face="left"
	assert_false(driver.detects(w),"Trainers cannot see behind themselves")
	driver.actor.face="right"
	w.player.position=driver.actor.position+Vector2.RIGHT*Arena.TILE*3.01
	assert_false(driver.detects(w),"Trainers cannot spot the player beyond three tiles")
	assert_false(driver.reachable_contact(driver.actor.position,Vector2(-100,-100)),"Solid tiles block line of sight")

func test_grass_search_route_does_not_track_hidden_player_coordinates() -> void:
	var w:=forest_world()
	var driver=searcher(w)
	w.rng.seed=42
	w.player.position=Arena.tile_center(Vector2i(4,4))
	driver.choose_search_path(w)
	var first: Array=driver.path.duplicate()
	assert_false(first.is_empty())
	assert_lte(first.size(),Search.MAX_SEARCH_STEPS,"Search legs stay short enough to turn and inspect locally")
	var delta: Vector2i=first.back()-Arena.tile_of(driver.actor.position)
	assert_lte(maxi(absi(delta.x),absi(delta.y)),Search.SEARCH_RADIUS)
	w.rng.seed=42
	w.player.position=Arena.tile_center(Vector2i(12,20))
	driver.choose_search_path(w)
	assert_eq(driver.path,first,"Identical search decisions do not depend on a hidden player's location")

func test_road_grass_skills_and_hiding_control_gauge() -> void:
	var e = Exposure.new()
	e.sync_visit("route3")
	e.advance_gauge(10.0,false,false)
	assert_eq(e.attention,20.0,"Road exposure rises even without walking")
	e.notice("route3",Exposure.GRASS_GAIN)
	e.notice("route3",Exposure.MOVE_ATTENTION,true)
	e.notice("route3",Exposure.MOVE_ATTENTION,true)
	assert_eq(e.attention,28.0,"One grass rustle and one skill; repeated skill emission is gated")
	e.advance_gauge(1.0,true,true)
	assert_eq(e.attention,28.0,"Walking through grass does not hide the player")
	e.advance_gauge(1.0,true,false)
	assert_eq(e.attention,28.0,"One second still in grass is not yet hidden")
	e.advance_gauge(20.0,true,false)
	assert_eq(e.attention,0.0)
	e.notice("route3",1000.0)
	assert_eq(e.attention,100.0)

func test_level_gap_is_based_on_highest_actual_party_level() -> void:
	var e = Exposure.new()
	assert_true(e.eligible("road3_lass_janice",18))
	assert_false(e.eligible("road3_lass_janice",19))
	assert_true(e.eligible("bug_catcher_sammy",18),"Original Sammy has Weedle Lv9")
	assert_false(e.eligible("bug_catcher_sammy",19))

func test_visit_cap_and_reentry_do_not_use_global_victory_records() -> void:
	var e = Exposure.new()
	e.sync_visit("route3")
	var pool: Array = e.Data.POOLS.route3
	assert_eq(e.remaining_ids(5).size(),8)
	e.deployed=pool.duplicate()
	assert_eq(e.remaining_ids(5).size(),0)
	e.sync_visit("route3")
	assert_eq(e.remaining_ids(5).size(),0,"Same visit cannot redeploy a trainer")
	e.sync_visit("pewter")
	e.sync_visit("route3")
	assert_eq(e.remaining_ids(5).size(),8,"Leaving and returning restores the complete local roster")
	assert_eq(e.remaining_ids(100).size(),0)
	assert_false(e.gauge_visible(100))

func test_arena_snapshot_restores_gauge_roster_and_other_pursuers() -> void:
	DungeonDB.set_current("viridian_forest")
	Arena.configure(DungeonDB.theme())
	var w:=World.new()
	add_child_autofree(w)
	w.player=Player.new()
	w.add_child(w.player)
	w.player.position=Arena.tile_center(Vector2i(5,16))
	w.player.setup_player("charmander",5,["scratch","growl"])
	var first=Exposure.new()
	first.sync_visit("viridian_forest")
	var ids: Array=first.Data.POOLS.viridian_forest
	first.deployed=ids.slice(0,2)
	first.attention=42.0
	var saved: Dictionary=first.snapshot()
	saved.actors=[{"id":ids[0],"position":[176,256],"entry":[176,272],"phase":"engaged","area":"viridian_forest"},
		{"id":ids[1],"position":[192,256],"entry":[192,272],"phase":"chase","area":"viridian_forest"}]
	var returned=Exposure.new()
	returned.restore_visit(w,saved)
	assert_eq(returned.attention,42.0)
	assert_eq(returned.deployed,first.deployed)
	assert_eq(returned.remaining_ids(5).size(),3)
	assert_eq(returned.pursuits.size(),1,"Finished trainer is omitted; another pursuer survives arena round trip")
	assert_eq(returned.pursuits[0].actor.trainer_id,ids[1])
	assert_eq(returned.pursuits[0].actor.position,Vector2(192,256))
	var elsewhere=Exposure.new()
	saved.area="route3"
	elsewhere.restore_visit(w,saved)
	assert_true(elsewhere.deployed.is_empty(),"Unrelated destination cannot inherit a road visit")

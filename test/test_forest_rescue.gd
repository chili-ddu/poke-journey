extends GutTest
const Game=preload("res://scripts/game.gd")
const Rescue=preload("res://scripts/story/forest_rescue.gd")
const PATH="user://save_forest_rescue_test.cfg"
var old_path: String
var old_events: Array
var old_starter: String

func before_each() -> void:
	old_path=SaveData.path;SaveData.path=PATH
	old_events=Game.bot_events.duplicate();Game.bot_events=["visited_area_saffron_city"]
	old_starter=Game.starter;Game.starter="charmander"
	if FileAccess.file_exists(PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func after_each() -> void:
	SaveData.path=old_path;Game.bot_events=old_events;Game.starter=old_starter
	Game.destination={};Game.arena_trip={};Game.carry={}
	if FileAccess.file_exists(PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture(place: String=Rescue.PLACE,human: bool=false):
	var keep_bot:=OS.get_environment("BOT");var keep_place:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0" if human else "1");OS.set_environment("DUNGEON",place)
	if human:SaveData.store_progress("events","visited_area_saffron_city")
	Game.destination={};Game.arena_trip={};Game.carry={}
	var game=load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",keep_bot);OS.set_environment("DUNGEON",keep_place)
	game.world.god=true
	return game

func finish_talk(game) -> void:
	for _i in 40:
		if game.state!="talk":break
		game._talk_next()

func finish_field_cut(game) -> void:
	for _i in 240:
		if game.state!="field_cut":break
		game.advance(1.0/60.0)
	assert_eq(game.field_friends.phase,"idle")

func test_square_battlefield_and_real_species_art() -> void:
	var game=fixture(Rescue.ARENA)
	assert_eq(game.mode,"arena")
	assert_eq(int(Arena.map.width),int(Arena.map.height))
	assert_null(game.arena_trainer,"Story combat has no human trainer or Poké Ball send-out")
	assert_true(game.battle.is_empty())
	var field: Array=Arena.map.arena.field
	assert_eq(int(field[2]),16);assert_eq(int(field[3]),16)
	for y in range(4,20):
		for x in range(4,20):assert_false(Arena.solid_at(x,y),"The entire square is playable")
	for species in ["scyther","mankey"]:
		assert_false(MonSprite.load_set(int(SpeciesDB.get_species(species).dex)).is_empty())
	assert_not_null(Fx.sheet("field_cut_crescent"))
	assert_true(View3D.supported("res://assets/maps/"+Rescue.ARENA))

func test_discovery_ambush_dialogue_and_event_transition() -> void:
	var game=fixture();var event=game.forest_rescue
	assert_eq(event.actor.species_id,"scyther")
	assert_eq(event.actor.hp,1)
	assert_gt(event.actor.hurt_t,0.0)
	assert_false(event.actor.get_meta("silk_bound",false),"The injured Scyther is not tied up")
	assert_false(game.world.enemies.has(event.actor))
	assert_false(event.check_discovery(),"Entering the mainland away from Route22 never starts this event")
	game.world.player.position=Arena.tile_center(Rescue.tile(Rescue.PLAYER_TILE))
	game.advance(1.0/60)
	assert_eq(game.state,"talk");assert_eq(event.phase,"discovered")
	assert_true(game.dialog_text.contains("무슨") or game.dialog_text.contains("happened"))
	finish_talk(game)
	assert_eq(game.state,"forest_event")
	assert_eq(event.ambushers.size(),5)
	for mon in event.ambushers:assert_eq(mon.species_id,"mankey")
	assert_eq(game.world.remaining(),0,"The ambush actors cannot attack before the arena transition")
	game.advance(1.6)
	assert_eq(game.state,"talk")
	for mon in event.ambushers:
		var feet: Vector2=mon.position+Vector2(0,mon.feet_offset())
		assert_lt(Arena.resolve(feet,mon.radius).distance_to(feet),0.1,"Every ambusher stands on reachable Route22 floor")
		assert_gt(feet.distance_to(game.world.player.position),Arena.TILE*0.9,"The gang never stands on the player")
	assert_true(game.dialog_text.contains("구역") or game.dialog_text.contains("turf"))
	finish_talk(game)
	assert_eq(game.state,"encounter")
	assert_eq(Game.arena_trip.event,Rescue.ID)
	assert_eq(Game.arena_trip.arena,Rescue.ARENA)
	assert_false(Game.arena_trip.has("trainer"))
	assert_eq(Game.arena_trip.back.map,Rescue.PLACE)
	assert_false(game.events.has(Rescue.FRIEND))

func test_route22_rescue_is_reachable_from_viridian_without_cut_or_surf() -> void:
	var game=fixture()
	var goal:=Rescue.tile(Rescue.PLAYER_TILE)
	var queue: Array[Vector2i]=[Rescue.tile(Vector2i(47,7))]
	var seen: Dictionary={queue[0]:true}
	var index:=0
	while index<queue.size() and not seen.has(goal):
		var tile:=queue[index];index+=1
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=tile+d
			if seen.has(next) or not Arena.area_rect(Rescue.AREA).has_point(next) or Arena.solid_at(next.x,next.y) or Arena.is_water(next):continue
			var at:=Arena.tile_center(next)
			if Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1:continue
			seen[next]=true;queue.append(next)
	assert_true(seen.has(goal),"The first cutting friend is reachable on Route22 before any HM unlock")
	assert_eq(Arena.area_at(Arena.tile_center(Rescue.tile(Rescue.SCYTHER_TILE))),Rescue.AREA)
	for local in Rescue.AMBUSH_SPOTS+Rescue.AMBUSH_ENTRIES+[Rescue.SCYTHER_TILE,Rescue.PLAYER_TILE]:
		assert_true(seen.has(Rescue.tile(local)) or is_reachable_tile(game,goal,Rescue.tile(local)),"All story actors have accessible, dry positions")
	for local in Rescue.AMBUSH_SPOTS:
		assert_gte(Vector2(local-Rescue.SCYTHER_TILE).length(),4.0,"The fan leaves clearance around every discovery approach")

func is_reachable_tile(game,start: Vector2i,goal: Vector2i) -> bool:
	var queue: Array[Vector2i]=[start];var seen: Dictionary={start:true};var index:=0
	while index<queue.size():
		var at:=queue[index];index+=1
		if at==goal:return true
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=at+d
			if seen.has(next) or not Arena.area_rect(Rescue.AREA).has_point(next) or Arena.solid_at(next.x,next.y) or Arena.is_water(next):continue
			if Arena.resolve(Arena.tile_center(next),game.world.player.radius).distance_to(Arena.tile_center(next))>0.1:continue
			seen[next]=true;queue.append(next)
	return false

func test_timed_mankey_spawns_pause_in_menus_and_leader_waits() -> void:
	var game=fixture(Rescue.ARENA);var event=game.forest_rescue
	finish_talk(game)
	assert_eq(event.spawned,0)
	game.advance(0.5);assert_eq(event.spawned,0)
	game.state="menu";game.advance(20.0)
	assert_eq(event.spawned,0,"Paused time must not generate a burst of enemies")
	game.state="fight";game.advance(0.5)
	assert_eq(event.spawned,1)
	assert_eq(game.world.pending_spawns.size(),1)
	for _i in 11:event.step_battle(3.0)
	assert_eq(event.spawned,12)
	game.world._step_spawns(1.0)
	assert_eq(game.world.alive_enemies().size(),12,"The event has its own timed stream, not the dungeon's alive cap")
	for enemy in game.world.enemies:
		assert_eq(enemy.species_id,"mankey")
		assert_eq(enemy.level,Rescue.GRUNT_LEVEL)
		assert_eq(enemy.hp,enemy.max_hp,"Event opponents start with normal full HP")
		assert_eq(game.world.exp_gain(enemy),0)
	event.step_battle(30.0)
	assert_false(event.boss_spawned,"The Mankey leader waits for all twelve gang members to be defeated")
	assert_eq(game.world.alive_enemies().size(),12)

func test_all_13_defeats_award_zero_exp_and_save_victory_before_reward() -> void:
	var game=fixture(Rescue.ARENA,true);var event=game.forest_rescue
	Game.arena_trip={"event":Rescue.ID,"back":{"map":Rescue.PLACE,"pos":Arena.tile_center(Vector2i(25,196))}}
	finish_talk(game)
	var p: Player=game.world.player
	var exp_before:=p.exp_total;var level_before:=p.level
	var moves_before:=p.learned.duplicate()
	for _i in 12:
		event.step_battle(Rescue.INTERVAL)
		game.world._step_spawns(1.0)
		var enemy: Enemy=game.world.alive_enemies()[0]
		game.world.damage(enemy,enemy.hp)
	assert_eq(game.defeated,12);assert_eq(event.grunts_defeated,12)
	event.step_battle(0.1);game.world._step_spawns(1.0)
	assert_true(event.boss_spawned)
	var boss: Enemy=event.boss()
	assert_not_null(boss)
	assert_eq(boss.species_id,"mankey");assert_eq(boss.level,Rescue.BOSS_LEVEL)
	assert_true(boss.cds.has("scratch"),"The Mankey leader uses its own supported moves")
	assert_eq(boss.hp,boss.max_hp)
	assert_eq(game.world.exp_gain(boss),0)
	game.world.damage(boss,boss.hp)
	event.step_battle(0.1)
	assert_eq(game.defeated,13);assert_eq(game.enemies_left(),0)
	assert_eq(p.exp_total,exp_before);assert_eq(p.level,level_before);assert_eq(p.learned,moves_before)
	assert_true(game.exp_segments.is_empty());assert_true(game.stat_queue.is_empty())
	assert_true(game.pending_learns.is_empty());assert_true(game.beaten.is_empty())
	assert_true(SaveData.load_saved().events.has(Rescue.WON))
	assert_false(SaveData.load_saved().events.has(Rescue.FRIEND),"Friendship follows the rescue dialogue, not the last hit")
	assert_eq(SaveData.load_saved().map,Rescue.PLACE,"Saving inside the event restores Route22, never an orphaned arena")

func test_victory_reload_finishes_rescue_once_and_keeps_friend() -> void:
	SaveData.store_progress("events",Rescue.WON)
	var game=fixture(Rescue.PLACE,true);var event=game.forest_rescue
	assert_eq(event.phase,"idle","A pending reward never teleports a player from another mainland area")
	game.world.player.position=Arena.tile_center(Rescue.tile(Rescue.PLAYER_TILE))
	assert_true(event.check_discovery())
	assert_eq(game.state,"forest_event")
	game.advance(0.9)
	assert_false(event.actor.get_meta("silk_bound",false))
	assert_eq(event.actor.hp,event.actor.max_hp)
	finish_talk(game)
	assert_true(game.events.has(Rescue.FRIEND));assert_true(SaveData.load_saved().events.has(Rescue.FRIEND))
	finish_talk(game)
	var returned=fixture(Rescue.PLACE,true)
	assert_eq(returned.forest_rescue.phase,"idle")
	assert_false(returned.forest_rescue.actor.get_meta("silk_bound",false))
	returned.world.player.position=Arena.tile_center(Rescue.tile(Rescue.PLAYER_TILE))
	assert_false(returned.forest_rescue.check_discovery(),"A completed rescue cannot replay the ambush")
	returned._talk(returned.forest_rescue.target);finish_talk(returned)
	assert_eq(returned.events.count(Rescue.FRIEND),1)
	returned._carry_out();assert_true(Game.carry.events.has(Rescue.FRIEND))

func test_old_forest_has_no_encounter_and_old_victory_keeps_its_reward() -> void:
	var forest=fixture(Rescue.LEGACY_PLACE,true)
	assert_null(forest.forest_rescue,"An unfinished old forest encounter is now on Route22")
	SaveData.store_progress("events",Rescue.WON)
	var won=fixture(Rescue.LEGACY_PLACE,true)
	assert_true(won.events.has(Rescue.FRIEND),"An old battle victory grants its pending reward without fighting again")
	assert_true(won.world.player.known_moves().has("cut"))
	assert_true(SaveData.load_saved().events.has(Rescue.FRIEND))
	assert_null(won.forest_rescue.actor,"No old forest Scyther actor is recreated")
	finish_talk(won)
	var completed=fixture(Rescue.LEGACY_PLACE,true)
	assert_null(completed.forest_rescue)

func test_defeat_does_not_unlock_friend_or_continue_spawning() -> void:
	var game=fixture(Rescue.ARENA);var event=game.forest_rescue
	finish_talk(game);game.world.god=false
	game.world.damage(game.world.player,game.world.player.hp)
	assert_true(game.world.player.dead)
	event.step_battle(100.0)
	assert_eq(event.spawned,0)
	assert_false(game.events.has(Rescue.WON));assert_false(game.events.has(Rescue.FRIEND))
	assert_eq(game.pending_battle_end,"gameover")

func test_friend_cuts_original_tree_without_hm_pp_or_exp_and_persists() -> void:
	Game.starter="squirtle" # This case exercises the friend fallback, not self Cut.
	SaveData.store_progress("events",Rescue.FRIEND)
	var game=fixture("kanto_south",true)
	assert_gt(game.field_friends.trees.size(),0)
	var tree: Npc=game.field_friends.trees[0]
	game.world.player.position=cut_tree_approach(game,tree)
	var id:=tree.id;var tile:=tree.tile
	assert_true(Arena.solid_at(tile.x,tile.y))
	assert_false(game.world.player.learned.has("cut"))
	var pp: Array=game.world.player.pp.duplicate();var exp: int=game.world.player.exp_total
	game._talk(tree);finish_talk(game)
	assert_eq(game.state,"field_cut")
	game.advance(0.4)
	assert_true(Arena.solid_at(tile.x,tile.y),"Scyther must arrive before the tree can disappear")
	finish_field_cut(game)
	assert_false(Arena.solid_at(tile.x,tile.y))
	assert_eq(game.world.player.pp,pp);assert_eq(game.world.player.exp_total,exp)
	assert_true(SaveData.load_saved().events.has(id))
	var returned=fixture("kanto_south",true)
	assert_false(Arena.solid_at(tile.x,tile.y))
	assert_false(returned.field_friends.trees.any(func(n):return n.id==id))

func test_trees_require_friend_and_regular_wild_exp_is_unchanged() -> void:
	var game=fixture("kanto_south")
	var tree: Npc=game.field_friends.trees[0]
	game._talk(tree);finish_talk(game)
	assert_eq(game.field_friends.phase,"idle")
	assert_true(Arena.solid_at(tree.tile.x,tree.tile.y))
	var enemy:=Enemy.new();enemy.setup_enemy("caterpie",4,game.world.rng)
	add_child_autofree(enemy)
	assert_gt(game.world.exp_gain(enemy),0,"Normal wild battles still grant their original EXP")

func test_cut_targets_match_every_native_object_without_border_clones() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/field_cut_trees.json"))
	var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://test/fixtures/frlg_cut_tree_objects.json"))
	var total:=0
	for source: Dictionary in native.maps:
		var expected: Array=[]
		for obj in source.get("object_events",[]):
			if obj.get("type","")=="object" and obj.get("graphics_id","")=="OBJ_EVENT_GFX_CUT_TREE":
				expected.append([obj.x,obj.y])
		if expected.is_empty():continue
		var area:=String(source.id).trim_prefix("MAP_").to_lower()
		assert_eq(data.get(area,[]),expected,"Every original Cut tree keeps its own map-local coordinates: "+area)
		total+=expected.size()
	var extracted:=0
	for points in data.values():extracted+=points.size()
	assert_eq(total,extracted,"Every cached native Cut object is represented without border clones")
	assert_gte(total,15,"Existing Cut targets are retained when the mainland expands")

func cut_tree_approach(game,tree: Npc) -> Vector2:
	for direction in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
		var at:=Arena.tile_center(tree.tile+direction)
		if not Arena.is_water(Arena.tile_of(at)) and game.world.resolve_mon(game.world.player,at).distance_to(at)<0.1:
			return at
	return Vector2.INF

func test_every_native_cut_target_can_be_reached_cut_and_reloaded() -> void:
	Game.starter="squirtle"
	SaveData.store_progress("events",Rescue.FRIEND)
	var checked:=0
	for place in ["kanto_south","kanto_east","cerulean_north","kanto_rock_pass"]:
		var game=fixture(place,true)
		var targets: Array=game.field_friends.trees.duplicate()
		var cut_tiles: Array[Vector2i]=[]
		assert_eq(targets.size(),8 if place=="kanto_south" else 5 if place=="kanto_rock_pass" else 1)
		for tree: Npc in targets:
			var tile:=tree.tile;var id:=tree.id
			var approach:=cut_tree_approach(game,tree)
			assert_ne(approach,Vector2.INF,"The native tree has a walkable interaction side: "+id)
			assert_true(Arena.solid_at(tile.x,tile.y),"The tree blocks its exact original tile: "+id)
			assert_gt(game.world.resolve_mon(game.world.player,tree.position).distance_to(tree.position),0.1)
			assert_not_null(tree.visual_frame().tex,"The native Cut-tree art is loaded")
			game.world.player.position=approach
			game.world.player.facing=(tree.position-approach).normalized()
			assert_eq(game.npc_in_reach(),tree,"Space selects the exact obstacle being interacted with")
			game.dialog_text="";game.dialog_t=0.0
			var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true
			game._unhandled_input(key)
			assert_eq(game.state,"field_cut","One Space press starts the cry automatically")
			assert_eq(game.field_friends.target,tree)
			game.advance(0.56)
			assert_not_null(game.field_friends.helper)
			var across: Vector2=game.field_friends.work_at-Arena.tile_center(tile)
			assert_lte(across.dot(approach-Arena.tile_center(tile)),0.01,"Scyther lands across the tree, away from the caller")
			finish_field_cut(game)
			assert_eq(game.world.player.position,approach,"The player stays in place throughout the help animation")
			assert_false(Arena.solid_at(tile.x,tile.y),"Scyther opens the native obstacle: "+id)
			assert_lt(game.world.resolve_mon(game.world.player,Arena.tile_center(tile)).distance_to(Arena.tile_center(tile)),0.1,"The player can walk through the cut tile")
			assert_true(SaveData.load_saved().events.has(id))
			cut_tiles.append(tile)
			checked+=1
		var returned=fixture(place,true)
		assert_eq(returned.field_friends.trees.size(),0,"All cut objects stay removed on this map")
		for tile in cut_tiles:
			assert_false(Arena.solid_at(tile.x,tile.y))
	assert_eq(checked,15)

func test_scyther_appears_walks_and_slices_before_the_tree_disappears() -> void:
	Game.starter="squirtle"
	SaveData.store_progress("events",Rescue.FRIEND)
	var game=fixture("kanto_east",true)
	var tree: Npc=game.field_friends.trees[0]
	var tile:=tree.tile
	game.world.player.position=cut_tree_approach(game,tree)
	var caller: Vector2=game.world.player.position
	game._talk(tree);finish_talk(game)
	var event=game.field_friends
	assert_eq(event.phase,"calling")
	assert_null(event.helper,"The caller cries before Scyther answers")
	game.advance(0.56)
	var scyther: Mon=event.helper
	assert_not_null(scyther)
	assert_eq(scyther.species_id,"scyther")
	assert_has(game.world.bystanders,scyther)
	assert_false(game.world.enemies.has(scyther))
	assert_eq(event.phase,"arriving")
	assert_gt(event.entry_at.distance_to(event.work_at),Arena.TILE*8.0,"Scyther comes from beyond the view")
	assert_gt(scyther.lift,0.0,"Scyther flies over scenery")
	assert_gt(event.flight_point(0.5).distance_to(event.entry_at.lerp(event.work_at,0.5)),float(Arena.TILE),"The arrival has a curved path")
	assert_almost_eq(scyther.modulate.a,0.0,0.001)
	var half_arrival: float=game.field_friends.ARRIVE_TIME*0.5
	game.advance(half_arrival)
	assert_almost_eq(scyther.modulate.a,0.5,0.001)
	assert_almost_eq(scyther.anim_t,half_arrival,0.001,"The helper animation advances once per frame")
	assert_true(Arena.solid_at(tile.x,tile.y))
	game.advance(0.25)
	assert_eq(event.phase,"approaching")
	assert_gt(scyther.vel.length(),0.0)
	assert_lt(game.world.resolve_mon(game.world.player,game.world.player.position).distance_to(game.world.player.position),0.1)
	while event.elapsed<event.ARRIVE_TIME+event.WALK_TIME+0.09:game.advance(0.005)
	assert_true(event.eye_glinted)
	assert_true(game.world.fxs.any(func(f):return f.get_meta("field_eye_glint",false) and not f.dead),"Eyes flash before the blade moves")
	assert_eq(scyther.facing,Vector2.DOWN,"Scyther briefly shows its eyes to the camera")
	assert_gt(event.camera_zoom,1.0)
	while event.elapsed<event.cut_at-0.02:game.advance(0.005)
	assert_eq(scyther.attack_anim,"Slice")
	assert_gt(scyther.attack_anim_t,0.0)
	assert_true(Arena.solid_at(tile.x,tile.y),"The tree stays until the blade's authored contact frame")
	game.advance(0.025)
	assert_false(Arena.solid_at(tile.x,tile.y))
	assert_true(game.world.fxs.any(func(f):return f.text=="field_cut_crescent" and not f.dead))
	assert_eq(scyther.modulate.a,1.0,"The helper stays visible through the cut")
	assert_true(is_instance_valid(event.helper))
	game.advance(0.2)
	assert_true(is_instance_valid(event.helper),"Scyther does not vanish with the tree")
	while event.elapsed<event.gaze_at+0.05:game.advance(0.01)
	assert_eq(event.phase,"looking")
	assert_gt(scyther.facing.dot(Vector2(-1,-1).normalized()),0.99)
	game.advance(event.leave_at+event.LEAVE_TIME*0.5-event.elapsed)
	assert_eq(event.phase,"leaving")
	var exit_foot: Vector2=scyther.position+Vector2(0,scyther.feet_offset())
	assert_lt(exit_foot.x,event.work_at.x)
	assert_lt(exit_foot.y,event.work_at.y)
	assert_eq(game.world.player.position,caller)
	finish_field_cut(game)
	assert_null(event.helper)
	assert_false(game.world.bystanders.has(scyther))

func test_space_on_tree_automatically_calls_without_a_move_or_pp() -> void:
	Game.starter="squirtle"
	SaveData.store_progress("events",Rescue.FRIEND)
	var game=fixture("kanto_east",true)
	var tree: Npc=game.field_friends.trees[0]
	var tile:=tree.tile
	game.world.player.position=cut_tree_approach(game,tree)
	assert_ne(game.world.player.position,Vector2.INF)
	game.world.player.learned.erase("growl")
	game.world.player.slots=["scratch","","",""]
	game.world.player.pp=[0,0,0,0]
	var before: Array=game.world.player.pp.duplicate()
	var exp: int=game.world.player.exp_total
	var moves: Array=[]
	game.world.player_move_used.connect(func(id):moves.append(id))
	game.dialog_text="";game.dialog_t=0.0
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true
	game._unhandled_input(key)
	assert_eq(game.field_friends.phase,"calling")
	assert_eq(game.state,"field_cut","There is no second key press or confirmation dialogue")
	assert_eq(game.world.player.attack_anim,"Charge")
	game.advance(0.56)
	assert_not_null(game.field_friends.helper)
	finish_field_cut(game)
	assert_false(Arena.solid_at(tile.x,tile.y))
	assert_eq(game.world.player.pp,before)
	assert_eq(game.world.player.exp_total,exp)
	assert_true(moves.is_empty(),"Calling is independent of combat moves")

func test_tree_interaction_requires_a_friend_and_v_does_not_call() -> void:
	var game=fixture("kanto_east")
	var tree: Npc=game.field_friends.trees[0]
	game.world.player.position=cut_tree_approach(game,tree)
	var key:=InputEventKey.new();key.physical_keycode=KEY_V;key.pressed=true
	game._unhandled_input(key)
	assert_eq(game.state,"fight")
	assert_eq(game.field_friends.phase,"idle")
	assert_null(game.field_friends.helper)
	game.dialog_text="";game.dialog_t=0.0
	key.physical_keycode=KEY_SPACE
	game._unhandled_input(key)
	assert_eq(game.state,"talk","Before the rescue, Space inspects the blocking tree")
	finish_talk(game)
	assert_true(Arena.solid_at(tree.tile.x,tree.tile.y))
	assert_false(game.events.has(Rescue.FRIEND))
	game.events.append(Rescue.FRIEND)
	key.physical_keycode=KEY_V
	game._unhandled_input(key)
	assert_eq(game.field_friends.phase,"idle")
	assert_null(game.field_friends.helper)
	assert_true(Arena.solid_at(tree.tile.x,tree.tile.y),"The old dedicated key stays inactive after friendship")

func test_friend_calls_do_not_interrupt_menus_or_repeat_during_arrival() -> void:
	SaveData.store_progress("events",Rescue.FRIEND)
	var game=fixture("kanto_east",true)
	var tree: Npc=game.field_friends.trees[0]
	game.world.player.position=cut_tree_approach(game,tree)
	for state in ["menu","talk","encounter","gameover"]:
		game.state=state
		assert_false(game.field_friends.call_friend(tree))
	game.state="fight"
	assert_false(game.field_friends.call_friend(null),"A specific interaction object is required")
	var nearby: Vector2=game.world.player.position
	game.world.player.position=tree.position+Vector2.DOWN*Arena.TILE*3.0
	assert_false(game.field_friends.call_friend(tree),"A remote object cannot be activated")
	game.world.player.position=nearby
	assert_true(game.field_friends.call_friend(tree))
	assert_false(game.field_friends.call_friend(tree))
	game.advance(0.56)
	assert_false(game.field_friends.call_friend(tree),"Arrival cannot be restarted by repeated interaction")
	game.world.player.dead=true
	assert_false(game.field_friends.call_friend(tree))

func test_removed_call_key_does_not_interfere_with_battle() -> void:
	var game=fixture(Rescue.ARENA)
	finish_talk(game)
	var key:=InputEventKey.new();key.physical_keycode=KEY_V;key.pressed=true
	game._unhandled_input(key)
	assert_eq(game.state,"fight")
	assert_eq(game.field_friends.phase,"idle")
	assert_null(game.field_friends.helper)
	assert_false(game.field_friends.call_friend(null))
	game.advance(1.0)
	assert_eq(game.forest_rescue.spawned,1,"The event spawn clock continues")

func test_scyther_discovery_and_actor_are_absent_before_saffron() -> void:
	Game.bot_events=[]
	var game=fixture()
	assert_null(game.forest_rescue.actor)
	game.world.player.position=Arena.tile_center(Rescue.tile(Rescue.PLAYER_TILE))
	assert_false(game.forest_rescue.check_discovery())
	assert_false(game.events.has(Rescue.WON))

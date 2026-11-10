extends GutTest
const Pursuit = preload("res://scripts/battle/road_pursuit.gd")
const Data = preload("res://scripts/data/road_trainer_db.gd")
func test_original_pools_exclude_empty_roads_and_story_characters() -> void:
	assert_false(Data.POOLS.has("route1"))
	assert_false(Data.POOLS.has("route2"))
	for entry in [["route3",8],["route6",6],["route11",10],["route24",6],["route25",9],["viridian_forest",5],["mt_moon_1f",7],["mt_moon_b2f",4]]:
		assert_eq(Data.POOLS[entry[0]].size(),entry[1])
		for id in Data.POOLS[entry[0]]:
			assert_true(TrainerDB.has_trainer(id))
			var tr := TrainerDB.get_trainer(id)
			assert_false(tr.party.is_empty())
			assert_false(tr.has("gym"))
			assert_true(ResourceLoader.exists("res://assets/npcs/%s.png" % TrainerDB.sprite(id)))
	assert_eq(TrainerDB.get_trainer("road3_lass_janice").party,[["pidgey",9],["pidgey",9]])
func test_pursuit_route_is_walkable_and_contact_cannot_cross_walls() -> void:
	DungeonDB.set_current("kanto_north")
	Arena.configure(DungeonDB.theme())
	var pursuit = Pursuit.new()
	pursuit.area = "route3"
	var start := Vector2i.ZERO
	var goal := Vector2i.ZERO
	var rect := Arena.area_rect("route3")
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var tile := Vector2i(x,y)
			if pursuit.walkable(tile):
				if start==Vector2i.ZERO: start=tile
				if pursuit.route(start,tile).size()>12:
					goal=tile
					break
		if goal!=Vector2i.ZERO: break
	assert_ne(goal,Vector2i.ZERO)
	var previous := start
	for tile in pursuit.route(start,goal):
		assert_true(pursuit.walkable(tile))
		assert_eq(absi(tile.x-previous.x)+absi(tile.y-previous.y),1)
		previous=tile
	assert_false(pursuit.reachable_contact(Arena.tile_center(start),Arena.tile_center(rect.position-Vector2i.ONE)))

func test_forest_sammy_uses_original_party_and_berry_reward_without_fixed_blocker() -> void:
	assert_true(DungeonDB.DUNGEONS.viridian_forest.trainers.is_empty())
	assert_true(Data.POOLS.viridian_forest.has("bug_catcher_sammy"))
	var trainer := TrainerDB.get_trainer("bug_catcher_sammy")
	assert_false(trainer.has("tm_drop"))
	assert_eq(trainer.arena,"arena_viridian_forest")
	assert_eq(trainer.party,[["weedle",9]])
	assert_true(TrainerDB.berry_rewards("bug_catcher_sammy").has("pecha_berry"))

class PursuitProbe:
	extends "res://scripts/battle/trainer_exposure.gd"
	var allowed := false
	var calls := 0
	func step(_world: World, _view, _dt: float, _excluded: Array, allow_spawn: bool) -> Npc:
		allowed = allow_spawn
		calls += 1
		return null
class Idle:
	extends RefCounted
	func move_dir(_w): return Vector2.ZERO
	func aim_point(w): return w.player.position
	func want_skill(_i,_w): return false
	func want_dodge(_w): return false
	func want_jump(_w): return false
	func want_item(_w): return false
func test_live_wild_does_not_block_pursuit_but_dialogue_does() -> void:
	var old_bot := OS.get_environment("BOT")
	var old_map := OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1")
	OS.set_environment("DUNGEON","viridian_forest")
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	game.set_process(false)
	game.bot=false
	game.world.player.controller=Idle.new()
	game.world.player.position=Arena.tile_center(Vector2i(5,16))
	game.world.player.set_level(5)
	game.state="fight"
	var foe := Enemy.new()
	foe.setup_enemy("caterpie",4,game.world.rng)
	foe.position=game.world.player.position+Vector2.RIGHT*96
	game.world.add_child(foe)
	game.world.enemies.append(foe)
	game.dialog_text=""
	game.dialog_t=0.0
	game.timed_dialog_pages.clear()
	game.status_messages.clear()
	game.status_message_times.clear()
	var probe:=PursuitProbe.new()
	game.road_pursuit=probe
	game.advance(0.01)
	assert_gt(game.world.remaining(),0)
	assert_true(probe.allowed,"Wild Pokémon and approaching trainers can coexist")
	game.world.cast(game.world.player,"growl",Vector2.UP,game.world.player.position+Vector2.UP*100)
	assert_eq(probe.attention,Pursuit.MOVE_ATTENTION,"Actual player skill emission raises regional attention")
	game._on_enemy_defeated(foe,1)
	assert_eq(probe.attention,Pursuit.MOVE_ATTENTION,"Defeats are not an exposure source")
	var calls:=probe.calls
	var speaker: Npc=game.world.npcs[0] if not game.world.npcs.is_empty() else Npc.new()
	var owns_speaker:=not speaker.is_inside_tree()
	game._say_pages(game._pages(["Manual dialogue"],speaker))
	game.advance(0.1)
	assert_eq(probe.calls,calls,"Dialogue still pauses new pursuit checks")
	if owns_speaker:speaker.free()
	OS.set_environment("BOT",old_bot)
	OS.set_environment("DUNGEON",old_map)

class SpawnProbe:
	extends "res://scripts/battle/road_pursuit.gd"
	var attempts := 0
	func spawn(_world: World,_view,_excluded: Array) -> bool:
		attempts += 1
		return false
func test_activity_attention_is_bounded_and_quiet_reduces_it() -> void:
	var pursuit=Pursuit.new()
	pursuit.notice("viridian_forest",Pursuit.MOVE_ATTENTION,true)
	assert_eq(pursuit.attention,6.0)
	pursuit.notice("viridian_forest",Pursuit.MOVE_ATTENTION,true)
	assert_eq(pursuit.attention,6.0,"Repeated emission cannot inflate attention within 1.5 seconds")
	pursuit.tick_attention(2.0,"viridian_forest")
	pursuit.notice("viridian_forest",Pursuit.DEFEAT_ATTENTION)
	assert_eq(pursuit.attention,24.0)
	pursuit.tick_attention(4.0,"viridian_forest")
	assert_eq(pursuit.attention,24.0)
	pursuit.tick_attention(10.0,"viridian_forest")
	assert_eq(pursuit.attention,14.0)
	pursuit.notice("viridian_forest",1000.0)
	assert_eq(pursuit.attention,100.0)
	pursuit.tick_attention(200.0,"viridian_forest")
	assert_eq(pursuit.attention,0.0)
	pursuit.notice("route1",1000.0)
	assert_eq(pursuit.attention,0.0,"Empty original roads cannot accumulate trainer attention")
func test_attention_probability_scales_with_activity_and_not_frame_rate() -> void:
	var pursuit=Pursuit.new()
	var calm:float=pursuit.spawn_probability(1.0)
	pursuit.notice("route3",100.0)
	var alert:float=pursuit.spawn_probability(1.0)
	assert_gt(alert,calm*7.0)
	var per_frame:float=pursuit.spawn_probability(1.0/60.0)
	assert_almost_eq(1.0-pow(1.0-per_frame,60),alert,0.00001)
	pursuit.tick_attention(0.1,"route6")
	assert_eq(pursuit.attention,0.0,"Attention is local to the current region")
func test_attention_never_bypasses_cooldown_and_distance_is_not_required() -> void:
	DungeonDB.set_current("viridian_forest")
	Arena.configure(DungeonDB.theme())
	var w:=World.new()
	add_child_autofree(w)
	var player:=Player.new()
	w.add_child(player)
	w.player=player
	player.position=Arena.tile_center(Vector2i(5,16))
	var pursuit:=SpawnProbe.new()
	pursuit.notice("viridian_forest",100.0)
	Pursuit.begin_battle_cooldown(w.rng)
	Pursuit.tick_battle_cooldown(89.0)
	pursuit.step(w,null,89.0,[],true)
	assert_eq(pursuit.attempts,0,"Minimum encounter interval survives high attention")
	Pursuit.tick_battle_cooldown(10000.0)
	pursuit.step(w,null,10000.0,[],false)
	assert_eq(pursuit.attempts,0,"Story and other eligibility gates remain authoritative")
	pursuit.step(w,null,10000.0,[],true)
	assert_eq(pursuit.attempts,1,"No mandatory walking distance remains")

func test_first_encounter_has_no_minimum_wait_and_post_battle_wait_survives_new_controller() -> void:
	var keep: float = Pursuit.battle_cooldown
	Pursuit.battle_cooldown=0.0
	var first=Pursuit.new()
	assert_eq(first.cooldown,0.0)
	assert_gt(first.spawn_probability(1.0),0.0)
	var rng:=RandomNumberGenerator.new()
	rng.seed=7
	Pursuit.begin_battle_cooldown(rng)
	assert_between(Pursuit.battle_cooldown,90.0,150.0)
	var remaining:float=Pursuit.battle_cooldown
	var second=Pursuit.new()
	assert_eq(second.battle_cooldown,remaining,"Changing maps does not remove the post-battle cooldown")
	Pursuit.tick_battle_cooldown(30.0)
	assert_almost_eq(second.battle_cooldown,remaining-30.0,0.001)
	Pursuit.tick_battle_cooldown(200.0)
	assert_eq(second.battle_cooldown,0.0)
	Pursuit.battle_cooldown=keep

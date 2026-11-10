extends GutTest
const Game=preload("res://scripts/game.gd")
func after_each() -> void:
	Game.destination={};Game.arena_trip={};Game.carry={};Game.bot_events=[]
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())
func open_gym(place: String):
	var old_bot:=OS.get_environment("BOT");var old_map:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON",place)
	Game.destination={};Game.arena_trip={};Game.carry={};Game.bot_events=["visited_area_saffron_city","quest_moon_mining_complete"]
	var game=load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",old_bot);OS.set_environment("DUNGEON",old_map)
	return game
func finish_dialogue(game) -> void:
	for i in 20:
		if game.state!="talk":break
		game._talk_next()
func test_gym_members_are_visible_and_only_leaders_can_battle() -> void:
	for fixture in [["pewter_gym","leader_brock",1],["cerulean_city_gym","leader_misty",2]]:
		var game=open_gym(fixture[0])
		assert_eq(game.trainers.size(),1)
		assert_eq(game.trainers[0].trainer_id,fixture[1])
		var count:=0
		for n in game.world.npcs:
			if n.talk!="gym_surprised":continue
			count+=1
			assert_true(n.visible)
			assert_false(n.is_trainer())
			assert_false(n.sees(n.position+Vector2.RIGHT*Arena.TILE))
			if n.id!="gym_luis":assert_false(Arena.solid_at(n.tile.x,n.tile.y),n.id+" stands on walkable floor")
			assert_true(ResourceLoader.exists("res://assets/npcs/"+("camper" if n.id=="gym_liam" else "swimmer_m_water" if n.id=="gym_luis" else "picnicker")+".png"))
		assert_eq(count,fixture[2])
func test_speaking_to_surprised_members_never_starts_battle() -> void:
	for place in ["pewter_gym","cerulean_city_gym"]:
		var game=open_gym(place)
		var bag: Dictionary=game.world.player.bag.duplicate()
		var beaten: Array=game.beaten.duplicate()
		for n in game.world.npcs:
			if n.talk!="gym_surprised":continue
			var at:=Arena.tile_center(n.talk_tile)
			assert_false(Arena.solid_at(n.talk_tile.x,n.talk_tile.y),n.id+" has an accessible speaking position")
			game.world.player.position=at
			assert_true(n.can_talk(at))
			game._check_trainers()
			assert_eq(game.state,"town")
			game._talk(n)
			assert_eq(game.state,"talk")
			assert_eq(game.talk_focus.get_ref(),n)
			finish_dialogue(game)
			assert_eq(game.state,"town")
			assert_true(game.battle.is_empty())
			assert_true(Game.arena_trip.is_empty())
			assert_eq(game.beaten,beaten)
			assert_eq(game.world.player.bag,bag)
func test_both_gym_leaders_still_start_their_own_battles() -> void:
	for fixture in [["pewter_gym","leader_brock","arena_pewter_gym"],["cerulean_city_gym","leader_misty","arena_cerulean_gym"]]:
		var game=open_gym(fixture[0])
		game.events.append(RoadAccess.SAFFRON_VISITED)
		game.beaten=[]
		game._talk(game.trainers[0]);finish_dialogue(game)
		assert_eq(game.state,"encounter")
		assert_eq(Game.arena_trip.trainer,fixture[1])
		assert_eq(Game.arena_trip.arena,fixture[2])
		assert_eq(Game.arena_trip.back.map,fixture[0])

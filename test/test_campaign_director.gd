extends GutTest

const Director = preload("res://scripts/story/campaign_director.gd")
const Runtime = preload("res://scripts/story/quest_runtime.gd")
const Catalog = preload("res://scripts/story/campaign_quests.gd")

class WorldState:
	extends RefCounted
	var player: Player
	func award_berries(_reward: Dictionary, _at: Vector2) -> Dictionary:return {}

class GameState:
	extends Node
	var bot := true
	var events: Array = []
	var beaten: Array = []
	var starter := "charmander"
	var world := WorldState.new()
	var stat_queue: Array = []
	var exp_segments: Array = []
	var exp_display_level := 0
	var exp_display_progress := 0.0
	var state := "fight"
	var mode := "overworld"
	var dialog_text := ""
	func _toast(_message: String) -> void:pass
	func exp_display_pending() -> bool:return false

var old_path: String

func before_each() -> void:
	old_path = SaveData.path
	SaveData.path = "user://test_campaign_director_isolated.cfg"
	SaveData.clear()
	Director.bot_campaign = {}

func after_each() -> void:
	SaveData.clear()
	SaveData.path = old_path
	Director.bot_campaign = {}

func fixture(flags: Array = [],species: String = "charmander",level: int = 10) -> Dictionary:
	var game := GameState.new()
	add_child_autofree(game)
	game.events = flags.duplicate()
	game.starter = SpeciesDB.base_form(species)
	var player := Player.new()
	game.add_child(player)
	player.setup_player(species,level,SpeciesDB.learnable(species,level),Individual.method1(41203))
	game.world.player = player
	var runtime := Runtime.new()
	runtime.game = game
	var director := Director.new()
	director.setup(game,runtime)
	return {"game":game,"runtime":runtime,"director":director}

func _orders(values: Array) -> Array:
	if values.is_empty():return [[]]
	var result: Array = []
	for value in values:
		var rest := values.duplicate()
		rest.erase(value)
		for tail in _orders(rest):result.append([value]+tail)
	return result

func test_all_twenty_four_clue_orders_unlock_same_finale() -> void:
	var fixture_data := fixture()
	var game: GameState = fixture_data.game
	var director = fixture_data.director
	for order in _orders(Director.CLUES):
		game.events.clear()
		for index in order.size():
			game.events.append(order[index])
			director.on_commit("evidence",0)
			assert_eq(director.can_challenge("leader_giovanni"),index == 3,"All four independent clues, in any order")
		assert_true(game.events.has(Director.SUPPLY))
		assert_true(game.events.has(Director.TARGET))

func test_misty_waits_for_mining_resolution_only_in_first_cycle() -> void:
	var f := fixture()
	assert_false(f.director.can_challenge("leader_misty"))
	f.game.events.append("quest_moon_mining_complete")
	assert_true(f.director.can_challenge("leader_misty"))
	f.game.events = [Director.CYCLE]
	assert_true(f.director.can_challenge("leader_misty"))

func test_second_giovanni_requires_all_seven_wins_not_challenges() -> void:
	var f := fixture([Director.CYCLE])
	for id in Director.GYMS:f.director.on_gym_challenged(id)
	assert_false(f.director.can_challenge("leader_giovanni"))
	for index in Director.GYMS.size():
		f.game.events.append("campaign_child_won_"+Director.GYMS[index])
		assert_eq(f.director.can_challenge("leader_giovanni"),index == 6)

func test_parent_memories_remember_attempts_even_without_victory() -> void:
	var f := fixture()
	f.director.on_gym_challenged("leader_brock")
	assert_false(f.game.beaten.has("leader_brock"))
	f.director.on_trainer_defeated("leader_giovanni")
	f.game.events.append(Director.CYCLE)
	assert_eq(f.director.flashback_pages("leader_brock").size(),2)
	assert_true(f.director.flashback_pages("leader_misty").is_empty())
	assert_true(f.director.flashback_pages("leader_brock").is_empty(),"One memory scene per child gym")

func test_legacy_parent_gym_victories_also_make_memories() -> void:
	var f := fixture()
	f.game.beaten.append("leader_sabrina")
	f.director.on_trainer_defeated("leader_giovanni")
	assert_true(f.director.data.parent_challenges.has("leader_sabrina"))

func test_father_is_last_party_member_with_independent_original_growth() -> void:
	var f := fixture([],"charmeleon",27)
	f.director.on_trainer_defeated("leader_giovanni")
	var original: Dictionary = f.director.data.parent.duplicate(true)
	f.game.events.append(Director.CYCLE)
	f.game.world.player.set_level(40)
	var base := {"party":[["rhydon",45,["tackle"]]],"ivs":[12],"gym":{}}
	var roster: Dictionary = f.director.trainer_roster("leader_giovanni",base)
	assert_eq(roster.party.size(),2)
	assert_eq(roster.party[-1][0],"charmeleon")
	assert_eq(roster.party[-1][1],27)
	assert_eq(roster.campaign_father.ivs,original.ivs)
	assert_eq(roster.campaign_father.stats,SpeciesDB.stats_at("charmeleon",27,original.ivs))
	assert_eq(base.party.size(),1,"Does not mutate shared trainer data")
	roster.campaign_father.ivs.hp = 0
	assert_eq(f.director.data.parent,original,"Father payload is not aliased")

func test_child_starts_at_ten_with_egg_move_for_all_three_starters() -> void:
	for starter in ["charmander","bulbasaur","squirtle"]:
		var f := fixture(["daycare_egg_left","friend_scyther_cut","visited_area_saffron_city","quest_forest_complete"],starter,32)
		var child: Dictionary = f.director.child_snapshot()
		assert_eq(child.level,10)
		assert_eq(child.species,starter)
		assert_eq(child.slots[0],Director.EGG_MOVES[starter])
		assert_true(MoveDB.has_move(child.slots[0]))
		assert_true(child.events.has(Director.CYCLE))
		assert_true(child.events.has("visited_area_saffron_city"))
		assert_true(child.events.has("friend_scyther_cut"))
		assert_false(child.events.has("daycare_egg_left"),"Child must make its own relationships")
		assert_true(child.trainers.is_empty())

func test_gym_growth_is_once_only_and_does_not_depend_on_parent_memory() -> void:
	var f := fixture([Director.CYCLE])
	f.director.on_trainer_defeated("leader_brock")
	assert_eq(f.game.world.player.level,15)
	var exp: int = f.game.world.player.exp_total
	f.director.on_trainer_defeated("leader_brock")
	assert_eq(f.game.world.player.exp_total,exp)
	assert_true(f.director.flashback_pages("leader_brock").is_empty())

func test_selected_sidequest_path_reaches_mewtwo_band_without_all_subquests() -> void:
	var f := fixture([Director.CYCLE])
	for id in Director.GYMS:f.director.on_trainer_defeated(id)
	assert_eq(f.game.world.player.level,45,"Seven first wins supply 35 levels")
	f.director.on_trainer_defeated("leader_giovanni")
	assert_eq(f.game.world.player.level,48)
	# Only two optional stories, not the full regional/legendary catalog.
	for _index in 2:f.runtime.grant_reward({"reward":{},"xp_levels":1.5})
	assert_gte(f.game.world.player.level,50)
	assert_true(f.game.events.has("campaign_father_rescued"))
	assert_false(f.director.can_challenge("leader_giovanni"))

func test_per_slot_payload_and_new_cycle_save_preserve_father() -> void:
	var f := fixture(["daycare_egg_left"])
	f.director.on_trainer_defeated("leader_giovanni")
	var parent: Dictionary = f.director.data.parent.duplicate(true)
	SaveData.store_campaign({"cycle":2,"parent":parent})
	var child: Dictionary = f.director.child_snapshot()
	SaveData.store_cycle(child,"route5_pokemon_day_care")
	var loaded := SaveData.load_saved()
	assert_eq(loaded.level,10)
	assert_eq(loaded.map,"route5_pokemon_day_care")
	assert_eq(SaveData.load_campaign().parent,parent)
	SaveData.path = "user://test_campaign_other_isolated.cfg"
	SaveData.clear()
	assert_true(SaveData.load_campaign().is_empty())
	SaveData.path = "user://test_campaign_director_isolated.cfg"

func test_side_bird_branches_have_saffron_requirement_but_first_clue_does_not() -> void:
	for quest in Catalog.quests():
		if quest.id == "mysterious_bird_clue":assert_false(quest.requires.has("visited_area_saffron_city"))
		if quest.id in ["articuno_trail","zapdos_trail","moltres_trail"]:assert_true(quest.requires.has("visited_area_saffron_city"))

func test_no_bird_completion_is_needed_to_unlock_giovanni() -> void:
	var f := fixture(Director.CLUES)
	assert_true(f.director.can_challenge("leader_giovanni"))
	assert_false(f.game.events.has("quest_articuno_trail_complete"))

func test_egg_qualification_is_complete_story_flag() -> void:
	var f := fixture(["quest_daycare_courtship_stage_0","quest_daycare_courtship_stage_1"])
	assert_false(f.game.events.has("daycare_egg_left"))
	f.game.events.append("daycare_egg_left")
	f.director.on_commit("daycare_courtship",2)
	assert_eq(f.director.data.egg_move,"dragon_dance")

func test_bird_clues_can_be_collected_in_either_order_before_nest() -> void:
	var catalog: Array = Catalog.quests()
	for branch in ["articuno_trail","zapdos_trail","moltres_trail"]:
		var clues: Array = catalog.filter(func(quest):return String(quest.id).begins_with(branch+"_clue_"))
		assert_eq(clues.size(),2)
		for clue in clues:
			assert_eq(clue.requires.size(),2,"Neither clue depends on its sibling")
		var finale: Dictionary = catalog.filter(func(quest):return quest.id == branch)[0]
		assert_eq(finale.stages.size(),1)
		assert_true(finale.requires.has("quest_"+branch+"_clue_1_complete"))
		assert_true(finale.requires.has("quest_"+branch+"_clue_2_complete"))

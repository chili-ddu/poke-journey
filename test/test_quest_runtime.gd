extends GutTest
const Game=preload("res://scripts/game.gd")
const Runtime=preload("res://scripts/story/quest_runtime.gd")
const PATH="user://save_quest_runtime_test.cfg"
const UNLOCK="visited_area_saffron_city"
var old_path: String
var old_events: Array
var old_starter: String
var old_beaten: Array
var old_campaign: Dictionary
const Campaign=preload("res://scripts/story/campaign_director.gd")

func before_each() -> void:
	old_path=SaveData.path;SaveData.path=PATH;SaveData.clear()
	old_events=Game.bot_events.duplicate();old_starter=Game.starter
	old_beaten=Game.bot_beaten.duplicate();Game.bot_beaten=[]
	old_campaign=Campaign.bot_campaign.duplicate(true);Campaign.bot_campaign={}
	Game.starter="charmander";Game.bot_events=[];Game.carry={};Game.arena_trip={};Game.destination={}

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path;Game.bot_events=old_events;Game.starter=old_starter
	Game.carry={};Game.arena_trip={};Game.destination={}
	Game.bot_beaten=old_beaten;Campaign.bot_campaign=old_campaign
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture(flags: Array=[],place: String="route25_sea_cottage",trip: Dictionary={}):
	var bot:=OS.get_environment("BOT");var dungeon:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON",place)
	Game.bot_events=flags.duplicate();Game.arena_trip=trip;Game.carry={};Game.destination={}
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",dungeon)
	game.world.god=true;game.dialog_text="";game.dialog_t=0.0
	return game

func finish_talk(game) -> void:
	for _i in 70:
		if game.state!="talk":break
		game._talk_next()

func actor(game,id: String) -> Npc:
	for npc in game.quests.actors:
		if npc.get_meta("quest_id","")==id:return npc
	return null

func test_regional_starts_are_hidden_before_saffron_and_bill_does_not_attack() -> void:
	var game=fixture()
	assert_not_null(game.bill_event)
	assert_null(game.bill_event.actor,"Obsolete collector trainer is not created")
	assert_null(actor(game,"bill_rescue"))
	assert_eq(game.state,"town")
	for entry in game.quests.journal_entries():assert_false(entry.id in ["forest_truce","bill_rescue","daycare_courtship","ditto_rumor","museum_fossils","eevee_evolution","snorlax_wake"])

func test_bill_has_human_researcher_companion_and_persistent_marker_target() -> void:
	var game=fixture([UNLOCK])
	var target:=actor(game,"bill_rescue")
	assert_not_null(target)
	assert_eq(target.talk,"quest")
	assert_true(target.can_talk(target.position+Vector2(0,Arena.TILE)))
	assert_eq(game.quests.people.size(),1)
	assert_false(Arena.solid_at(Arena.tile_of(target.position).x,Arena.tile_of(target.position).y))
	assert_true(game.battle.is_empty())

func test_acceptance_not_proximity_activates_forest_dispute() -> void:
	var game=fixture([UNLOCK],"forest_gate_north")
	# Content currently places the boy at the southern gate; use its authored map.
	var quest: Dictionary=game.quests.find_quest("forest_truce")
	var place:=String(quest.stages[0].map)
	if DungeonDB.current!=place:
		game.free();game=fixture([UNLOCK],place)
	assert_false(game.quests.stage_done("forest_truce",0))
	assert_false(game.quests.check_discovery())
	assert_not_null(actor(game,"forest_truce"))
	game.quests.talk(actor(game,"forest_truce"));finish_talk(game)
	assert_true(game.quests.stage_done("forest_truce",0))
	assert_null(actor(game,"forest_truce"),"The accepted stage is now inside the forest")

func test_cost_requires_confirmation_and_consumes_once_at_commit() -> void:
	var game=fixture([UNLOCK],"route5_pokemon_day_care")
	var quest: Dictionary=game.quests.find_quest("daycare_courtship")
	var cost_index:=1
	while cost_index<quest.stages.size() and (quest.stages[cost_index].get("cost",{}) as Dictionary).is_empty():cost_index+=1
	assert_lt(cost_index,quest.stages.size())
	for i in cost_index:game.quests.flag(Runtime.stage_flag(quest.id,i))
	game.quests.refresh_actors()
	var cost: Dictionary=quest.stages[cost_index].cost
	for id in cost:game.world.player.add_item(id,int(cost[id]))
	var before: Dictionary=game.world.player.bag.duplicate()
	game.quests.talk(actor(game,quest.id))
	assert_eq(game.menu,"quest_cost")
	game.quests.choose_cost(1)
	assert_eq(game.world.player.bag,before,"Declining keeps every berry")
	game.quests.talk(actor(game,quest.id));game.quests.choose_cost(0)
	assert_eq(game.world.player.bag,before,"The offer is not consumed halfway through dialogue")
	finish_talk(game)
	for id in cost:assert_eq(int(game.world.player.bag.get(id,0)),int(before[id])-int(cost[id]))
	game.quests._commit_stage(quest,cost_index)
	for id in cost:assert_eq(int(game.world.player.bag.get(id,0)),int(before[id])-int(cost[id]),"Repeat callback does not pay twice")

func test_ditto_copies_growth_and_moves_into_independent_enemy() -> void:
	var game=fixture([UNLOCK])
	var player: Player=game.world.player
	player.set_level(28)
	player.ivs={"hp":31,"atk":24,"def":20,"spa":26,"spd":18,"spe":29};player.set_level(28)
	var snapshot: Dictionary={"species":player.species_id,"form_species":"","level":player.level,"ivs":player.ivs.duplicate(),"pid":player.pid,"stats":player.stats.duplicate(),"max_hp":player.max_hp,"slots":player.slots.duplicate(),"shiny":player.shiny}
	var enemy: Enemy=game.quests.spawn_opponent({"species":"ditto","mirror":true},snapshot)
	assert_eq(enemy.species_id,player.species_id)
	assert_eq(enemy.level,player.level)
	assert_eq(enemy.ivs,player.ivs);assert_eq(enemy.stats,player.stats);assert_eq(enemy.max_hp,player.max_hp)
	var equipped: Array=player.slots.filter(func(id):return not String(id).is_empty())
	assert_eq(enemy.cds.keys(),equipped)
	enemy.hp-=1;enemy.stats.atk+=1;enemy.ivs.hp=0
	assert_ne(enemy.hp,player.hp)
	assert_ne(enemy.stats.atk,player.stats.atk);assert_eq(player.ivs.hp,31)
	assert_true(enemy.get_meta("no_exp",false))

func test_postbattle_outro_is_required_before_quest_stage_and_reward() -> void:
	var flag:=Runtime._won_flag("bill_rescue",0)
	var game=fixture([UNLOCK,flag])
	assert_eq(game.state,"talk","Winning resumes the aftermath dialogue after return")
	assert_false(game.quests.stage_done("bill_rescue",0))
	finish_talk(game)
	assert_true(game.quests.stage_done("bill_rescue",0))
	assert_false(game.quests.has("quest_bill_rescue_complete"),"The research information conversation still remains")
	game.quests.talk(actor(game,"bill_rescue"));finish_talk(game)
	assert_true(game.quests.has("quest_bill_rescue_complete"))
	var bag: Dictionary=game.world.player.bag.duplicate()
	game.quests.talk(actor(game,"bill_rescue"));finish_talk(game)
	assert_eq(game.world.player.bag,bag)

func test_battle_uses_quest_runner_without_old_rescue_spawns() -> void:
	var stage: Dictionary={"battle":[{"species":"butterfree","level":18},{"species":"beedrill","level":18}]}
	var snapshot: Dictionary={"species":"charmander","level":18,"ivs":{},"stats":SpeciesDB.stats_at("charmander",18,{}),"max_hp":45,"slots":["scratch"],"pid":1}
	var trip: Dictionary={"event":"quest_battle","arena":Runtime.ARENA,"quest_id":"forest_truce","quest_index":1,"quest_stage":stage,"snapshot":snapshot,"back":{"map":"viridian_forest","pos":Vector2(100,100)}}
	var game=fixture([UNLOCK],Runtime.ARENA,trip)
	assert_null(game.forest_rescue);assert_null(game.arena_trainer)
	assert_true(game.is_event_battle());assert_same(game.event_battle(),game.quests)
	game.quests.step_battle(0.1)
	assert_eq(game.world.alive_enemies().size(),1)
	assert_eq(game.world.alive_enemies()[0].species_id,"butterfree")
	assert_eq(game.world.alive_enemies()[0].stats,SpeciesDB.stats_at("butterfree",18,{}))
	assert_eq(game.quests.enemies_left(),2)

func test_journal_is_accessible_from_pause_menu_and_keeps_game_paused() -> void:
	var flags: Array=[UNLOCK]
	for id in ["forest_truce","museum_fossils","bill_rescue","daycare_courtship","eevee_evolution","ditto_rumor"]:flags.append("quest_%s_started"%id)
	var game=fixture(flags)
	game._open_game_menu()
	assert_true(game.menu_ids.has("journal"))
	game._resolve_menu(game.menu_ids.find("journal"))
	assert_eq(game.menu,"quest_journal");assert_eq(game.state,"menu")
	assert_gt(game.quests.journal_entries().size(),4)
	game.quests.choose_journal(game.quests.journal_ids.find("@next"))
	assert_eq(game.quests.journal_page,1)
	game.quests.choose_journal(game.quests.journal_ids.find("@close"))
	assert_eq(game.state,"town")

func test_progress_persists_in_isolated_save_and_rewards_do_not_duplicate() -> void:
	var game=fixture([UNLOCK],"route25_sea_cottage")
	game.bot=false
	game.quests.flag(Runtime.stage_flag("bill_rescue",0));game.quests.refresh_actors()
	game.quests.talk(actor(game,"bill_rescue"));finish_talk(game)
	var saved:=SaveData.load_saved()
	assert_true(saved.events.has("quest_bill_rescue_complete"))
	assert_eq(saved.bag,game.world.player.bag)
	var bag: Dictionary=game.world.player.bag.duplicate()
	game.quests.arrive()
	assert_eq(game.world.player.bag,bag)

func test_mirror_with_empty_loadout_does_not_invent_enemy_moves() -> void:
	var game=fixture([UNLOCK])
	var p: Player=game.world.player
	var snapshot: Dictionary={"species":p.species_id,"form_species":"","level":p.level,"ivs":p.ivs.duplicate(),"pid":p.pid,"stats":p.stats.duplicate(),"max_hp":p.max_hp,"slots":["","","",""],"shiny":false}
	var enemy: Enemy=game.quests.spawn_opponent({"species":"ditto","mirror":true},snapshot)
	assert_true(enemy.cds.is_empty(),"An unequipped player has an unequipped mirror")

func test_eevee_is_a_noncombat_follower_and_never_enters_trainer_arenas() -> void:
	var flags: Array=[UNLOCK,"eevee_following"]
	var game=fixture(flags,"route5_pokemon_day_care")
	assert_not_null(game.quests.follower)
	assert_false(game.world.enemies.has(game.quests.follower))
	assert_true(game.world.bystanders.has(game.quests.follower))
	game.quests.flag("eevee_research_assistant");game.quests.refresh_actors()
	assert_null(game.quests.follower,"Bill's consultation ends the temporary following")
	game.free()
	game=fixture(flags,"arena_route1")
	assert_null(game.quests.follower,"Ordinary gym/trainer arenas also suppress Eevee")

func test_reloading_after_battle_win_resumes_outro_before_awarding() -> void:
	var game=fixture([UNLOCK],"route25_sea_cottage")
	game.bot=false
	game.quests.flag(Runtime._won_flag("bill_rescue",0));game._save_here()
	game.free()
	var bot:=OS.get_environment("BOT");var dungeon:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0");OS.set_environment("DUNGEON","route25_sea_cottage")
	Game.carry={};Game.destination={};Game.arena_trip={}
	game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",dungeon)
	assert_eq(game.state,"talk")
	assert_false(game.quests.stage_done("bill_rescue",0))
	finish_talk(game)
	assert_true(game.quests.stage_done("bill_rescue",0))
	assert_false(game.quests.has("quest_bill_rescue_complete"))

func test_misty_returns_only_after_moon_investigation() -> void:
	var game=fixture([UNLOCK],"cerulean_city_gym")
	assert_false(game.trainers.any(func(n):return n.trainer_id=="leader_misty"))
	game.free();game=fixture([UNLOCK,"quest_moon_mining_complete"],"cerulean_city_gym")
	assert_true(game.trainers.any(func(n):return n.trainer_id=="leader_misty"))

func test_losing_quest_battle_restores_health_without_progress_or_reward() -> void:
	var stage: Dictionary={"battle":[{"species":"butterfree","level":18}]}
	var snapshot: Dictionary={"species":"charmander","level":18,"ivs":{},"stats":SpeciesDB.stats_at("charmander",18,{}),"max_hp":45,"slots":["scratch"],"pid":1}
	var trip: Dictionary={"event":"quest_battle","arena":Runtime.ARENA,"quest_id":"forest_truce","quest_index":1,"quest_stage":stage,"snapshot":snapshot,"back":{"map":"viridian_forest","pos":Vector2(100,100)}}
	var game=fixture([UNLOCK],Runtime.ARENA,trip)
	var before: Dictionary=game.world.player.bag.duplicate()
	game.world.player.hp=0;game.world.player.dead=true;game.pending_battle_end="gameover"
	game.quests.handle_loss()
	assert_false(game.world.player.dead);assert_eq(game.world.player.hp,game.world.player.max_hp)
	assert_eq(game.state,"talk");assert_eq(game.pending_battle_end,"")
	assert_false(game.quests.has(Runtime._won_flag("forest_truce",1)))
	assert_false(game.quests.stage_done("forest_truce",1))
	assert_eq(game.world.player.bag,before)
	assert_eq(Game.arena_trip.back.map,"viridian_forest")

func test_legacy_misty_win_recovers_sea_travel_without_new_battle() -> void:
	Game.bot_beaten=["leader_misty"]
	var game=fixture([UNLOCK],"kanto_world")
	assert_true(game.events.has("friend_lapras_surf"))
	assert_true(game.battle.is_empty())
	assert_not_null(game.lapras_escape)
	assert_eq(game.lapras_escape.phase,"idle","The reward does not restart the removed rescue")

func test_story_growth_saves_every_crossed_level_move_without_changing_slots() -> void:
	var game=fixture([UNLOCK],"route25_sea_cottage")
	game.bot=false
	var player: Player=game.world.player
	var slots: Array=player.slots.duplicate()
	var first_level:=player.level
	game.quests.grant_exp(SpeciesDB.exp_for_level(20,SpeciesDB.growth_of(player.species_id))-player.exp_total)
	assert_eq(player.level,20)
	assert_eq(player.slots,slots,"Story growth adds knowledge, never a forced loadout")
	for level in range(first_level+1,21):
		for move_id in SpeciesDB.moves_at_level(player.species_id,level):assert_true(player.known_moves().has(move_id))
	game._save_here()
	var saved:=SaveData.load_saved()
	assert_eq(saved.level,20)
	for level in range(first_level+1,21):
		for move_id in SpeciesDB.moves_at_level(player.species_id,level):assert_true(saved.learned.has(move_id),"Move knowledge persists before any scene transition")
	assert_eq(saved.slots,slots)

func test_journal_does_not_reveal_hideout_until_evidence_or_acceptance() -> void:
	var game=fixture([UNLOCK])
	assert_true(game.quests.journal_entries().is_empty(),"Unaccepted map markers do not reveal every quest in the journal")
	assert_false(game.quests.recorded(game.quests.find_quest("hideout")))
	game.quests.flag("bill_silph_research_tip")
	assert_true(game.quests.journal_entries().any(func(entry):return entry.id=="silph_theft"))
	assert_false(game.quests.journal_entries().any(func(entry):return entry.id=="hideout"))
	game.quests.flag("quest_silph_theft_complete")
	assert_true(game.quests.journal_entries().any(func(entry):return entry.id=="hideout"))
	assert_false(game.quests.journal_entries().any(func(entry):return entry.id=="cinnabar_records"))
	game.quests.flag("rumor_cinnabar_research")
	assert_true(game.quests.journal_entries().any(func(entry):return entry.id=="cinnabar_records"))

func test_route1_sighting_records_parent_and_first_clue_only() -> void:
	var game=fixture(["campaign_hooh_sighted"])
	var entries: Array=game.quests.journal_entries()
	assert_true(entries.any(func(entry):return entry.id=="mysterious_bird_clue"))
	assert_eq(entries.size(),2,"The parent and tutorial clue are recorded without prematurely listing all three legendary hunts")

func test_started_conversation_is_recorded_before_battle_and_without_completion() -> void:
	var game=fixture([UNLOCK])
	game.quests.talk(actor(game,"bill_rescue"))
	assert_true(game.quests.has("quest_bill_rescue_started"))
	assert_true(game.quests.journal_entries().any(func(entry):return entry.id=="bill_rescue"))
	assert_false(game.quests.stage_done("bill_rescue",0))

func test_indoor_story_xp_display_converges_to_real_growth_without_slot_changes() -> void:
	var game=fixture([UNLOCK],"route25_sea_cottage")
	game.bot=false
	var player: Player=game.world.player
	player.controller=Controllers.Human.new()
	player.position=Arena.tile_center(Vector2i(7,7))
	var slots: Array=player.slots.duplicate()
	var before:=player.level
	game.quests.grant_exp(SpeciesDB.exp_for_level(before+2,SpeciesDB.growth_of(player.species_id))-player.exp_total)
	assert_eq(game.state,"town")
	for _i in 500:
		game.advance(0.1)
		if not game.exp_display_pending() and game.stat_queue.is_empty() and game.stat_box.is_empty() and game.stat_t<=0.0 and game.dialog_text.is_empty():break
	assert_false(game.exp_display_pending())
	assert_true(game.stat_queue.is_empty());assert_true(game.stat_box.is_empty())
	assert_eq(game.displayed_level(),player.level)
	assert_almost_eq(game.displayed_exp_progress(),player.exp_progress(),0.001)
	assert_eq(player.slots,slots)
	assert_eq(game.state,"town","Displaying story growth does not start a battle or evolution")

func test_journal_cards_keep_readable_titles_and_short_state_with_full_details() -> void:
	var game=fixture([UNLOCK])
	for quest in game.quests.catalog:
		var entry: Dictionary={"name":quest.name,"place":"A destination much too long for a small card","done":false}
		var card: Dictionary=game.quests.journal_card(entry)
		assert_lte(PixelUi.text_width(card.name),100.0,quest.id+" title fits one card line")
		assert_true(card.sub in ["진행 중","In progress"])
		assert_false(card.name.is_empty())
		assert_eq(entry.name,quest.name,"The full title remains available for details")
	var cold: Dictionary=game.quests.journal_card({"name":"신비로운 새를 찾아서 · 차가운 날개","done":false})
	var thunder: Dictionary=game.quests.journal_card({"name":"신비로운 새를 찾아서 · 우레의 울음","done":false})
	assert_ne(cold.name,thunder.name,"Legendary branch titles remain distinguishable")

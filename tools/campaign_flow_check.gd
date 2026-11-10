extends SceneTree

# Headless integration harness. Battle outcomes are scripted; scene transfers,
# dialogue callbacks, actual opponents, inventory and save files use game code.
const Game = preload("res://scripts/game.gd")
const Director = preload("res://scripts/story/campaign_director.gd")
var failures := 0
var checks := 0
var previous_path := ""
var previous_bot := ""
var previous_dungeon := ""
var previous_slot_pattern := ""
var previous_allow_migrate := true

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool,label: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	return condition

func drain(game: Node) -> void:
	for _i in 100:
		if not is_instance_valid(game) or game.state != "talk":break
		game._talk_next()

func settle() -> Node:
	await create_timer(0.45).timeout
	var scene := current_scene
	if scene != null:scene.set_process(false)
	return scene

func travel(game: Node,map_id: String,trip: Dictionary = {}) -> Node:
	game._carry_out()
	Game.arena_trip = trip
	Game.destination = {"map":map_id}
	reload_current_scene()
	await process_frame
	await process_frame
	var next := current_scene
	next.set_process(false)
	return next

func run() -> void:
	previous_path = SaveData.path
	previous_bot = OS.get_environment("BOT")
	previous_dungeon = OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0")
	OS.set_environment("DUNGEON","")
	OS.set_environment("LANG_CODE","ko")
	previous_slot_pattern = SaveData.slot_pattern
	previous_allow_migrate = SaveData.allow_migrate
	SaveData.slot_pattern = "user://campaign_flow_slot_isolated_%s.cfg"
	SaveData.allow_migrate = false
	SaveData.path = "user://campaign_flow_check_isolated.cfg"
	SaveData.clear()
	var parent := Player.new()
	parent.setup_player("charmeleon",27,["scratch","ember","dragon_breath","smoke_screen"],Individual.method1(12046))
	SaveData.store(parent,[],"viridian_city_gym",Vector2(7,8)*Arena.TILE)
	for flag in Director.CLUES + ["visited_area_saffron_city","daycare_egg_left","quest_forest_truce_complete"]:SaveData.store_progress("events",flag)
	parent.free()
	Game.starter = "charmander"
	Game.skip_opening = true
	Game.carry = {}
	Game.destination = {"map":"arena_giovanni_gym"}
	Game.arena_trip = {"trainer":"leader_giovanni","arena":"arena_giovanni_gym","back":{"map":"viridian_city_gym","pos":Vector2(7,8)*Arena.TILE}}
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	check(game.battle.get("trainer") != null,"Parent Giovanni battle initialized")
	# A first-playthrough loss to Brock must still be remembered.
	game.quests.campaign.on_gym_challenged("leader_brock")
	var expected_parent: Dictionary = Director.snapshot(game.world.player)
	game._trainer_defeated()
	check(game.quests.campaign.data.pending_capture,"Winning Giovanni schedules capture")
	drain(game)
	game = await settle()
	if not check(game != null and game.mode != "arena","Victory callback returned to gym"):return finish()
	if game.state != "talk":game.quests.campaign.step(0.0)
	check(game.state == "talk","Capture ending starts after arena return")
	drain(game)
	await process_frame
	await process_frame
	game = current_scene
	game.set_process(false)
	if not check(game.quests.campaign.cycle() == 2,"Capture dialogue reloads actual second generation"):return finish()
	check(game.world.player.level == 10,"Actual child Player is level10")
	check(game.world.player.slots[0] == "dragon_dance","Actual child has inherited egg move")
	check(DungeonDB.current == "route5_pokemon_day_care","Child begins inside daycare")
	check(game.events.has("visited_area_saffron_city"),"Saffron access persists without tutorial replay")
	check(game.events.has("campaign_parent_forest_truce"),"Saved forest eggs enable descendant story")
	check(game.quests.campaign.data.parent.ivs == expected_parent.ivs,"Father IV survives save/scene transfer")
	check(game.quests.campaign.flashback_pages("leader_brock").size() == 2,"Actual defeated-attempt record gives parent memory")
	check(not game.quests.campaign.can_challenge("leader_giovanni"),"Child cannot skip seven victories")
	for id in Director.GYMS:game.quests.campaign.on_trainer_defeated(id)
	check(game.world.player.level == 45,"Seven actual growth hooks raise child10to45")
	check(game.quests.campaign.can_challenge("leader_giovanni"),"All seven wins unlock second Giovanni")
	var roster: Dictionary = game.quests.campaign.trainer_roster("leader_giovanni",TrainerDB.for_battle("leader_giovanni",game.world.player.level,{"events":game.events}))
	var trip := {"trainer":"leader_giovanni","arena":"arena_giovanni_gym","roster":roster,"back":{"map":"viridian_city_gym","pos":Vector2(7,8)*Arena.TILE}}
	game = await travel(game,"arena_giovanni_gym",trip)
	var party: Array = game.battle_trainer().party
	game.battle.idx = party.size()-1
	game._send_next()
	var father: Enemy = game.battle.mon
	check(father.species_id == expected_parent.species,"Last actual enemy is father species")
	check(father.level == expected_parent.level,"Father original level is preserved")
	check(father.ivs == expected_parent.ivs,"Last actual enemy has father IVs")
	check(father.stats == expected_parent.stats,"Last actual enemy uses father common stats")
	check(father.cds.keys().size() == expected_parent.moves.size(),"Father retains original moves")
	game._trainer_defeated()
	check(game.events.has("campaign_father_rescued"),"Second Giovanni victory rescues father")
	drain(game)
	game = await settle()
	game = await travel(game,"cerulean_cave_b1f")
	var quest: Dictionary = game.quests.find_quest("mewtwo_final")
	var stage: Dictionary = quest.stages[0]
	check(game.quests.available(quest),"Mewtwo objective is available after rescue")
	game.quests.start_quest_battle(quest,stage,0)
	game.encounter.done = true
	game._step_encounter(0.0)
	await process_frame
	await process_frame
	game = current_scene
	game.set_process(false)
	drain(game)
	game.quests.step_battle(0.0)
	var mewtwo: Enemy = game.quests.boss()
	if not check(mewtwo != null and mewtwo.species_id == "mewtwo","Actual Mewtwo event opponent spawns"):return finish()
	check(mewtwo.stats == SpeciesDB.stats_at("mewtwo",mewtwo.level,mewtwo.ivs),"Mewtwo uses common battle stats")
	mewtwo.dead = true
	game.world.enemies.erase(mewtwo)
	mewtwo.queue_free()
	game.defeated += 1
	game.quests.step_battle(0.0)
	drain(game)
	game = await settle()
	# Returning to the objective shows the victory/ending outro before commit.
	drain(game)
	game.quests.arrive()
	drain(game)
	check(game.events.has("quest_mewtwo_final_complete"),"Mewtwo outro commits final quest")
	check(game.events.has("campaign_true_ending"),"Actual callback records true ending")
	check(SaveData.load_saved().events.has("campaign_true_ending"),"True ending persists in isolated save")
	await bad_ending_flow()
	finish()

func bad_ending_flow() -> void:
	current_scene.free()
	SaveData.clear()
	var parent := Player.new()
	parent.setup_player("charmander",26,["scratch","ember"],Individual.method1(42543))
	SaveData.store(parent,[],"viridian_city_gym",Vector2(7,8)*Arena.TILE)
	parent.free()
	for flag in Director.CLUES + ["visited_area_saffron_city","quest_daycare_courtship_stage_0","quest_daycare_courtship_stage_1"]:SaveData.store_progress("events",flag)
	Game.carry = {}
	Game.destination = {"map":"arena_giovanni_gym"}
	Game.arena_trip = {"trainer":"leader_giovanni","arena":"arena_giovanni_gym","back":{"map":"viridian_city_gym","pos":Vector2(7,8)*Arena.TILE}}
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	game._trainer_defeated()
	drain(game)
	game = await settle()
	if game.state != "talk":game.quests.campaign.step(0.0)
	check(not game.events.has("daycare_egg_left"),"Partial daycare progress is not inheritance")
	drain(game)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.name == "Title","Actual no-egg ending returns to title")
	check(SaveData.load_saved().events.has("campaign_bad_ending"),"Bad ending persists in isolated save")
	check(not SaveData.load_saved().events.has("campaign_cycle_2"),"Partial courtship never begins child cycle")

func finish() -> void:
	if current_scene != null:current_scene.free()
	SaveData.clear()
	SaveData.path = previous_path
	SaveData.slot_pattern = previous_slot_pattern
	SaveData.allow_migrate = previous_allow_migrate
	OS.set_environment("BOT",previous_bot)
	OS.set_environment("DUNGEON",previous_dungeon)
	Game.carry = {};Game.destination = {};Game.arena_trip = {};Game.bot_events = [];Game.bot_beaten = []
	Director.bot_campaign = {}
	print("Campaign scene flow: %d checks, %d failures"%[checks,failures])
	quit(1 if failures > 0 else 0)

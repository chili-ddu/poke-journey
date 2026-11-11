extends GutTest
const Game = preload("res://scripts/game.gd")

var previous_beaten: Array=[]

func before_each() -> void:
	previous_beaten=Game.bot_beaten.duplicate()

func open_game(place: String, trainer: String="") -> Node:
	var old_bot:=OS.get_environment("BOT")
	var old_map:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1")
	OS.set_environment("DUNGEON",place)
	Game.destination={}
	Game.arena_trip={} if trainer=="" else {"trainer":trainer,"arena":place,"back":{"map":"mt_moon_b1f"}}
	var game=load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	game.set_process(false)
	OS.set_environment("BOT",old_bot)
	OS.set_environment("DUNGEON",old_map)
	return game

func after_each() -> void:
	Game.bot_beaten=previous_beaten
	Game.arena_trip={}
	Game.destination={}
	Game.carry={}
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())

func test_green_first_battle_has_counter_starter_pidgey_and_rattata() -> void:
	for starter in ["charmander","squirtle","bulbasaur"]:
		var party: Array=TrainerDB.get_trainer(TrainerDB.rival_for(starter)).party
		assert_eq(party.size(),3)
		assert_eq(party[1],["pidgey",5,["tackle","sand_attack"]])
		assert_eq(party[2],["rattata",5,["tackle","tail_whip","quick_attack"]])
		assert_true(MonSprite.load_set(16,false).has("Walk"))
		assert_true(MonSprite.load_set(16,true).has("Walk"))

func test_eastern_exit_starts_duo_intro_then_hands_off_to_cave_arena() -> void:
	var game=open_game("mt_moon_b1f")
	game.beaten.clear()
	game.world.player.position=Arena.tile_center(Vector2i(45,4))
	game.warp_armed=true
	game.state="fight"
	var before: int=game.world.npcs.size()
	game._check_warp()
	assert_eq(game.state,"talk","The exit starts graduation dialogue before changing maps")
	assert_eq(game.world.npcs.size(),before+2,"Both Jessie and James appear")
	assert_eq(game.world.bystanders.size(),1,"Meowth waits between them from the field introduction")
	for n in game.world.npcs.slice(before):
		assert_false(Arena.solid_at(Arena.tile_of(n.position).x,Arena.tile_of(n.position).y))
	for i in 20:
		if game.state!="talk":break
		game._talk_next()
	assert_eq(game.state,"encounter")
	assert_eq(Game.arena_trip.trainer,Game.MOON_GRADUATION)
	assert_eq(Game.arena_trip.arena,"arena_mt_moon")
	assert_eq(Game.arena_trip.back.map,"mt_moon_b1f")
	assert_eq(Game.arena_trip.back.pos,Arena.tile_center(Vector2i(45,4)))
	assert_false(game.beaten.has(Game.MOON_GRADUATION),"Meeting the duo does not record a victory")

func test_graduation_only_blocks_unbeaten_eastern_exit() -> void:
	var game=open_game("mt_moon_b1f")
	game.beaten.clear()
	assert_false(game._check_moon_graduation({"to":"mt_moon_b2f"}),"Internal ladders remain available")
	game.beaten.append(Game.MOON_GRADUATION)
	assert_false(game._check_moon_graduation({"to":"route4"}),"Winning prevents a repeat challenge")
	game.beaten.clear()
	DungeonDB.set_current("mt_moon_1f")
	assert_false(game._check_moon_graduation({"to":"route4"}),"The western entrance remains open for retreat")

func test_duo_party_rewards_and_sprites_are_ready() -> void:
	var duo:=TrainerDB.get_trainer(Game.MOON_GRADUATION)
	assert_eq(duo.party,[["ekans",14],["koffing",14],["meowth",14]])
	assert_eq(TrainerDB.arena_of(Game.MOON_GRADUATION),"arena_mt_moon")
	assert_true(ResourceLoader.exists("res://assets/npcs/%s.png"%duo.sprite))
	assert_true(ResourceLoader.exists("res://assets/npcs/%s.png"%duo.partner_sprite))
	assert_false(TrainerDB.berry_rewards(Game.MOON_GRADUATION).is_empty())
	for member in duo.party:
		var dex:=int(SpeciesDB.get_species(member[0]).dex)
		assert_true(MonSprite.load_set(dex,false).has("Walk"))
		assert_true(MonSprite.load_set(dex,true).has("Walk"))

func test_arena_releases_all_added_party_members_and_records_graduation_win() -> void:
	for fixture in [["arena_route1","rival_green_squirtle"],["arena_mt_moon",Game.MOON_GRADUATION]]:
		var game=open_game(fixture[0],fixture[1])
		if fixture[1]==Game.MOON_GRADUATION:
			assert_eq(game.world.npcs.size(),2,"Both trainers stand in the graduation arena")
		var party: Array=TrainerDB.get_trainer(fixture[1]).party
		for member in party:
			game._send_next()
			assert_eq(game.battle.mon.species_id,member[0])
			assert_eq(game.battle.mon.level,member[1])
			game._drop_ball()
			game.sendout={}
		assert_eq(game.battle.idx,party.size())
		if fixture[1]==Game.MOON_GRADUATION:
			game._trainer_defeated()
			assert_true(game.beaten.has(Game.MOON_GRADUATION))
			game._carry_out()
			assert_true(Game.carry.trainers.has(Game.MOON_GRADUATION),"Victory travels back to the cave with the player")

func test_rocket_lineup_keeps_meowth_between_trainers_and_outside_combat() -> void:
	var game=open_game("arena_mt_moon",Game.MOON_GRADUATION)
	var meowth: Enemy=game.rocket_meowth
	assert_lt(game.arena_trainer.position.x,meowth.position.x)
	assert_lt(meowth.position.x,game.rocket_james.position.x)
	assert_almost_eq(meowth.position.y+meowth.feet_offset(),game.arena_trainer.position.y,0.001)
	assert_eq(game.world.bystanders,[meowth])
	assert_false(game.world.enemies.has(meowth))
	assert_false(game.world.opponents(Mon.TEAM_PLAYER).has(meowth))
	assert_eq(game.world.remaining(),0,"A waiting Meowth is not an active opponent")

func test_each_rocket_member_throws_their_own_pokemon() -> void:
	var game=open_game("arena_mt_moon",Game.MOON_GRADUATION)
	for fixture in [[game.arena_trainer,"jessie","ekans"],[game.rocket_james,"james","koffing"]]:
		game._send_next()
		var ball: ThrownBall=game.sendout.ball
		assert_eq(game.battle.mon.species_id,fixture[2])
		assert_eq(ball.from,fixture[0].throw_hand_world())
		assert_eq(game.sendout.trainer_at,fixture[0].position)
		assert_eq(game.dialog_text,Lang.t("sent_out",[Lang.t(fixture[1]),game.battle.mon.display_name()]))
		assert_true(game.world.bystanders.has(game.rocket_meowth),"Meowth keeps waiting during the other two turns")
		game._drop_ball()
		game.sendout={}

func test_meowth_walks_into_battle_without_ball_pop_or_duplicate_actor() -> void:
	var game=open_game("arena_mt_moon",Game.MOON_GRADUATION)
	var meowth: Enemy=game.rocket_meowth
	var start:=meowth.position
	game.battle.idx=2
	var effects_before: int=game.world.fxs.size()
	game._send_next()
	assert_eq(game.battle.mon,meowth,"The waiting Meowth becomes the actual combatant")
	assert_true(game.world.bystanders.is_empty())
	assert_eq(game.world.enemies.count(meowth),1)
	assert_null(game.sendout.ball)
	assert_eq(meowth.position,start,"Starting the turn does not teleport Meowth")
	assert_eq(meowth.appear,1.0,"Meowth never uses the ball reveal scale")
	assert_false(game.can_advance(),"The entrance cannot be dismissed before Meowth arrives")
	var target: Vector2=game.sendout.focus
	game._step_sendout(Game.SEND_PAN+0.25)
	assert_gt(meowth.position.distance_to(start),0.0)
	assert_lt(meowth.position.distance_to(start),target.distance_to(start))
	assert_gt(meowth.vel.length(),0.0,"The entrance uses a walking animation")
	assert_null(game.sendout.ball)
	game._step_sendout(float(game.sendout.ready_at)-float(game.sendout.t))
	assert_true(game.can_advance())
	assert_almost_eq(meowth.position.distance_to(target),0.0,0.001)
	assert_eq(meowth.vel,Vector2.ZERO)
	assert_eq(game.world.fxs.size(),effects_before,"No ball opening burst is emitted")
	game._sendout_back()
	game._step_sendout(Game.ARENA_SEND_BACK)
	assert_eq(game.state,"fight")
	assert_true(game.sendout.is_empty())
	assert_eq(game.battle.mon,meowth)
	assert_eq(game.world.enemies.count(meowth),1)

func test_trainer_ball_rests_at_the_monsters_feet_before_opening() -> void:
	var game = open_game("arena_route1","rival_green_squirtle")
	game._send_next()
	var ball: ThrownBall = game.sendout.ball
	var mon: Enemy = game.sendout.mon
	assert_eq(ball.to,BallRelease.support_of(mon))
	game._step_sendout(Game.SEND_THROW_AT + Game.SEND_THROW + BallRelease.REST*0.5)
	assert_eq(ball.k,1.0)
	assert_false(game.sendout.popped)
	assert_eq(mon.appear,0.0)
	game._step_sendout(BallRelease.REST*0.5 + 0.001)
	assert_true(game.sendout.popped)
	assert_null(game.sendout.ball)
	assert_eq(mon.release_fx.position,ball.to)
	assert_false(mon.release_fx.starter_table)
	game._step_sendout(BallRelease.GROWN)
	assert_eq(mon.appear,1.0)

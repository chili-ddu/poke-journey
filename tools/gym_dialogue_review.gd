extends "res://tools/story_trainer_review.gd"
func run() -> void:
	await CaptureWindow.park(self)
	out="res://docs/gym_dialogue_review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	SaveData.path="user://save_gym_dialogue_review.cfg"
	OS.set_environment("BOT","1");OS.set_environment("GOD","1")
	var script=load("res://scripts/game.gd")
	script.bot_beaten=[];script.bot_events=[LevelProgression.config().unlock_event]
	script.skip_opening=true
	for place in ["pewter_gym","cerulean_city_gym"]:
		script.arena_trip={};script.destination={};script.carry={}
		OS.set_environment("DUNGEON",place)
		game=load("res://scenes/main.tscn").instantiate()
		root.add_child(game);current_scene=game
		game.set_process(false);game.view3d.set_process(false);game.bot=false;game.banner_t=0.0
		assert(game.trainers.size()==1)
		for npc in game.world.npcs:
			if npc.talk!="gym_surprised":continue
			game.world.player.position=Arena.tile_center(npc.talk_tile)
			for i in 20:await frame(false)
			await shot(npc.id+"_01_visible")
			game._talk(npc)
			for i in 6:await frame(false)
			await shot(npc.id+"_02_surprised")
			while game.state=="talk":game._talk_next()
			assert(game.battle.is_empty() and script.arena_trip.is_empty())
		game._talk(game.trainers[0])
		while game.state=="talk":game._talk_next()
		assert(game.state=="encounter")
		assert(script.arena_trip.trainer==game.trainers[0].trainer_id)
		game.free();await process_frame
	script.arena_trip={};script.destination={};script.carry={}
	print("Gym dialogue passed: Liam, Luis and Diana only speak; Brock and Misty start leader battles")
	quit()

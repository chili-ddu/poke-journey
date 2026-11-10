extends "res://tools/story_trainer_review.gd"

func run() -> void:
	await CaptureWindow.park(self)
	out="res://docs/rocket_entrance_review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	SaveData.path="user://save_rocket_entrance_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","7")
	OS.set_environment("DUNGEON","arena_mt_moon")
	var script=load("res://scripts/game.gd")
	script.arena_trip={"trainer":"mt_moon_jessie_james","arena":"arena_mt_moon","back":{"map":"mt_moon_b1f"}}
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.set_process(false)
	game.view3d.set_process(false)
	game.bot=false
	game.banner_t=0.0
	for i in 15:await frame(false)
	assert(game.world.bystanders.has(game.rocket_meowth))
	assert(game.arena_trainer.position.x<game.rocket_meowth.position.x and game.rocket_meowth.position.x<game.rocket_james.position.x)
	await shot("01_lineup_jessie_meowth_james")
	var meowth_id: int=game.rocket_meowth.get_instance_id()
	for member in ["ekans","koffing","meowth"]:
		if member=="ekans":
			var guard:=0
			while game.sendout.is_empty() and guard<600:
				await frame()
				guard+=1
		else:
			# Preview the next authored entrance without damage, experience or save changes.
			game.battle.mon.dead=true
			game._send_next()
		assert(game.battle.mon.species_id==member)
		if member!="meowth":
			var sender: Npc=game.arena_trainer if member=="ekans" else game.rocket_james
			assert(game.sendout.ball.from==sender.position+Vector2(0,-Arena.TILE*0.4))
			while float(game.sendout.t)<0.4:await frame()
			await shot("02_"+member+"_owner_throw")
		else:
			assert(game.sendout.ball==null)
			assert(game.battle.mon.get_instance_id()==meowth_id)
			assert(game.world.bystanders.is_empty())
			while float(game.sendout.t)<game.SEND_PAN+0.5:await frame()
			assert(game.battle.mon.vel.length()>0)
			await shot("03_meowth_walks_forward")
		while not game.can_advance():await frame()
		await shot("04_"+member+"_ready")
		game._talk_next()
		var guard:=0
		while not game.sendout.is_empty() and guard<600:
			await frame()
			guard+=1
		assert(game.sendout.is_empty() and game.state=="fight")
		for i in 10:await frame(false)
		await shot("05_"+member+"_fight")
	print("Rocket entrances passed: Jessie owns Ekans, James owns Koffing, the waiting Meowth walks into battle with no ball or duplicate")
	game.free()
	await process_frame
	script.arena_trip={}
	quit()

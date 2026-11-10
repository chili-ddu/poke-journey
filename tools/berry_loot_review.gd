extends "res://tools/kanto_expansion_review.gd"
const OUT_BERRY := "res://docs/berry_loot_review/"
const Pool = preload("res://scripts/data/road_trainer_db.gd")
const Pursuit = preload("res://scripts/battle/road_pursuit.gd")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_BERRY))
	await CaptureWindow.park(self)
	SaveData.path="user://save_berry_loot_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","7")
	await open_fixture("viridian_forest")
	game.world.player.position=Arena.tile_center(Vector2i(5,16))
	walker.target=game.world.player.position
	assert(game.trainers.is_empty(),"No fixed exit trainer")
	for id in Pool.POOLS.viridian_forest:
		var pursuit = Pursuit.new()
		var excluded: Array=Pool.POOLS.viridian_forest.duplicate()
		excluded.erase(id)
		assert(pursuit.spawn(game.world,game.view3d,excluded),"Pool spawn "+id)
		assert(pursuit.actor.trainer_id==id)
		assert(TrainerDB.get_trainer(id).party==Pool.TRAINERS[id].party,"Original party "+id)
		results.append({"pool":id,"party":TrainerDB.get_trainer(id).party})
		pursuit.clear(game.world)
		await process_frame
	# Start the ordinary forest arena path, using the pool's Sammy (one Weedle Lv9).
	var pursuit = Pursuit.new()
	var excluded: Array=Pool.POOLS.viridian_forest.duplicate()
	excluded.erase("bug_catcher_sammy")
	assert(pursuit.spawn(game.world,game.view3d,excluded))
	game._start_intro(pursuit.actor)
	await pump_until(func():return game.state=="encounter",1200)
	assert(game.state=="encounter")
	await follow_scene()
	assert(DungeonDB.current=="arena_viridian_forest")
	await pump_until(func():return game.state=="fight" and not game.battle.is_empty() and game.battle.mon!=null,1800)
	var enemy: Enemy=game.battle.mon
	assert(enemy.species_id=="weedle" and enemy.level==9)
	await shot("sammy_original_party")
	var reward := TrainerDB.berry_rewards("bug_catcher_sammy")
	var before: Dictionary = game.world.player.bag.duplicate()
	var reserve_before: Dictionary = game.world.player.reward_reserve.duplicate()
	game.world.god=true
	game.world.damage(enemy,9999)
	await pump_until(func():return game.battle.is_empty() and game.state=="talk",2400)
	game.bot=false # Hold ordinary dialogue while observing the reward animation.
	for id in reward:
		assert(int(game.world.player.bag.get(id,0))+int(game.world.player.reward_reserve.get(id,0))==int(before.get(id,0))+int(reserve_before.get(id,0))+int(reward[id]),"Reward granted once "+id)
	assert(not game.world.player.known_moves().has("dig"),"No TM reward")
	for i in 10:game.advance(1.0/60.0)
	await shot("sammy_berry_reward_flight")
	for i in 40:game.advance(1.0/60.0)
	while game.state=="talk":game._talk_next()
	await follow_scene()
	assert(DungeonDB.current=="viridian_forest")
	assert(game.rival_exit.is_empty() and game.trainers.is_empty(),"No scripted Sammy flee or exit blocker")
	for child in game.world.get_children():assert(not child is GroundItem,"No legacy TM ball")
	results.append({"sammy_battle":true,"no_tm":true,"no_exit_event":true,"berry_reward":reward})
	# Other trainer rewards also use the same path, without teaching any move.
	await open_fixture("pewter_gym")
	var brock: Npc=game.trainers.filter(func(n):return n.trainer_id=="leader_brock")[0]
	var moves: Array = game.world.player.known_moves().duplicate()
	game.battle={"trainer":brock,"resume":"town"}
	game._trainer_defeated()
	game.bot=false
	assert(game.world.player.known_moves()==moves)
	assert(int(game.world.player.bag.get("lum_berry",0))>0)
	for i in 12:game.advance(1.0/60.0)
	await shot("brock_berry_reward")
	results.append({"brock_berries":true,"moves_unchanged":true})
	# Wild Weedle: real defeat -> chance roll -> falling berry -> curved pickup.
	await open_fixture("viridian_forest")
	game.world.player.position=Arena.tile_center(Vector2i(5,16))
	walker.target=game.world.player.position
	game.world.player.bag.clear()
	game.world.player.reward_reserve.clear()
	var wild := Enemy.new()
	wild.setup_enemy("weedle",9,game.world.rng)
	wild.position=Arena.resolve(game.world.player.position+Vector2.DOWN*24,wild.radius)
	game.world.add_child(wild);game.world.enemies.append(wild)
	var probe := RandomNumberGenerator.new()
	var seed_value := -1
	for i in 1000:
		probe.seed=i
		var loot := BerryLoot.roll("weedle",9,probe,wild.cds.keys())
		if loot.has("pecha_berry") and loot.size()>1:seed_value=i;break
	assert(seed_value>=0)
	game.world.rng.seed=seed_value
	game.world.damage(wild,9999)
	assert(game.world.drops.size()>=2,"Actual wild drop roll")
	await shot("wild_berry_fall")
	game.world._step_drops(0.4)
	assert(game.world.player.bag.has("pecha_berry"),"Poison-curing berry acquired")
	var item: LootItem=game.world.drops[0]
	game.world.step_loot_visual(0.15)
	await shot("wild_berry_pickup")
	var sprite: Sprite3D=game.view3d._sprites[item.get_instance_id()].sprite
	assert(is_equal_approx(sprite.basis.x.length(),sprite.basis.y.length()),"Pickup icon is not stretched")
	var count: int=game.world.player.bag.pecha_berry
	game.world.step_loot_visual(0.5)
	assert(game.world.drops.is_empty())
	assert(game.world.player.bag.pecha_berry==count,"No duplicate pickup")
	await shot("wild_berry_received")
	results.append({"wild_defeat_drop":true,"matching_status_cure":true,"pickup_flight":true,"once_only":true})
	var file := FileAccess.open(OUT_BERRY+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"));file.close()
	print("BERRY LOOT REVIEW PASSED")
	quit()
func pump_until(condition: Callable,frames: int) -> void:
	for i in frames:
		if condition.call():return
		game.advance(1.0/60.0)
		if i%8==0:await process_frame
	assert(condition.call(),"Battle flow timed out: "+game.state)
func follow_scene() -> void:
	var previous=game
	for i in 1800:
		if current_scene!=previous and current_scene!=null:
			game=current_scene
			setup_controller()
			await process_frame
			return
		if is_instance_valid(previous):previous.advance(1.0/60.0)
		await process_frame
	assert(false,"Scene transition timed out")
func shot(label: String) -> void:
	game._update_dialogue_focus()
	game.queue_redraw()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_BERRY+label+".png")

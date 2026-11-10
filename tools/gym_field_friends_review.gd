extends "res://tools/gym_leaders_review.gd"
const REVIEW_OUT="res://docs/gym_field_friends/"
const SAVE="user://save_gym_field_friends_review.cfg"
var reports: Array=[]

func configure() -> void:
	super.configure();game.bot=false
	game.world.player.repel_steps=99999;game.lure_t=99999
	game.road_pursuit.clear(game.world)

func open_fixture(place: String,bot: bool=false) -> void:
	if is_instance_valid(game):game.queue_free();await process_frame
	OS.set_environment("DUNGEON",place);OS.set_environment("BOT","1" if bot else "0")
	Game.destination={};Game.carry={};Game.arena_trip={}
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	configure();OS.set_environment("DUNGEON","");OS.set_environment("BOT","0")
	await render()

func shot(name: String) -> void:
	game._update_dialogue_focus()
	for i in 8:await render()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(REVIEW_OUT+name+".png")

func space() -> void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true
	game._unhandled_input(key)

func shore(area: String) -> bool:
	for tile in Arena._water:
		if Arena.area_at(Arena.tile_center(tile))!=area:continue
		for d in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var land: Vector2i=tile+d;var at:=Arena.tile_center(land)
			if Arena.is_water(land) or Arena.area_at(at)!=area or Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1:continue
			if Arena.resolve(Arena.tile_center(tile),game.world.player.radius,false,2).distance_to(Arena.tile_center(tile))>0.1:continue
			game.world.player.position=at;game.world.player.facing=-Vector2(d);return true
	return false

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_OUT))
	SaveData.path=SAVE
	OS.set_environment("GOD","1");OS.set_environment("SEED","11")
	for entry in [["cerulean_city_gym","leader_misty","surf","라프라스"],["vermilion_city_gym","leader_lt_surge","flash","피카츄"]]:
		SaveData.clear();Game.starter="charmander";Game.bot_beaten=[];Game.bot_events=[]
		await open_fixture(entry[0],true)
		var cfg: Dictionary=Data.GYMS[entry[0]]
		var p: Player=game.world.player
		p.setup("charmander",12,Mon.TEAM_PLAYER);p.exp_total=SpeciesDB.exp_for_level(12,SpeciesDB.get_species("charmander").growth)
		var leader: Npc=game.trainers[0]
		p.position=Arena.tile_center(leader.tile+Vector2i.DOWN);p.facing=Vector2.UP
		game.world.cam.position=p.position;game.view3d._cam_ready=false
		game.dialog_text="";game.dialog_t=0;game._save_here()
		assert(game.npc_in_reach()==leader)
		assert(not game.events.has(Game.FieldHMs.SOURCES[entry[2]]))
		space();await shot(entry[2]+"_01_challenge");finish_talk()
		assert(game.state=="encounter")
		if not await transition(cfg.arena):quit(1);return
		var experience: int=game.world.player.exp_total
		var seen: Array=[]
		for tick in 4000:
			if game.battle.is_empty():break
			if game.state=="talk" and game.can_advance():space()
			game.advance(DT)
			if game.battle.has("mon") and is_instance_valid(game.battle.mon) and not game.battle.mon.dead and game.sendout.is_empty() and game.state=="fight":
				var enemy: Enemy=game.battle.mon
				assert(enemy.max_hp==int(SpeciesDB.stats_at(enemy.species_id,enemy.level,enemy.ivs).hp))
				assert(game.world.exp_gain(enemy)==0)
				seen.append({"species":enemy.species_id,"level":enemy.level})
				game.world.damage(enemy,enemy.hp)
			if tick%6==0:await render()
		assert(game.battle.is_empty() and game.beaten.has(entry[1]))
		assert(game.world.player.exp_total==experience)
		assert(SaveData.load_saved().events.has(Game.FieldHMs.SOURCES[entry[2]]))
		var captured_intro:=false;var captured_joined:=false
		for i in 60:
			if game.state!="talk":break
			if game.dialog_text.contains(entry[3]):
				if not captured_intro:await shot(entry[2]+"_02_friend_intro");captured_intro=true
				elif not captured_joined:await shot(entry[2]+"_03_friend_unlocked");captured_joined=true
			space()
		assert(captured_intro and captured_joined)
		if not await transition(entry[0]):quit(1);return
		assert(game.events.has(Game.FieldHMs.SOURCES[entry[2]]))
		if entry[2]=="surf":
			await open_fixture("kanto_world")
			assert(game.world.npcs.filter(func(n):return n.talk in ["fuchsia_lapras_escape","route10_pikachu_rescue"] or n.id.begins_with("lapras_staff_")).is_empty())
			assert(game.world.bystanders.filter(func(m):return m.species_id in ["lapras","pikachu","magnemite","voltorb"]).is_empty())
			assert(shore("cerulean_city"))
			game.dialog_text="";game.dialog_t=0;game.world.cam.position=game.world.player.position;game.view3d._cam_ready=false
			space();assert(game.state=="lapras_event")
			for i in 75:game.advance(DT);await render()
			assert(game.world.player.travel_terrain==2 and game.lapras_escape.mounted)
			assert(game.lapras_escape.helper.species_id=="lapras")
			await shot("surf_04_lapras_on_water")
		else:
			await open_fixture("rock_tunnel_1f")
			for i in 50:game.advance(DT);await render()
			assert(game.pikachu_rescue.helper.species_id=="pikachu")
			assert(game.pikachu_rescue.brightness==1.0)
			await shot("flash_04_pikachu_in_tunnel")
		reports.append({"leader":entry[1],"move":entry[2],"party":seen,"exp_gain":0,"normal_stats":true,"friend_saved_before_return":true,"field_support_after_real_victory":true})
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	FileAccess.open(REVIEW_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"window":"384x216","actual_scene_transitions":transitions,"rewards":reports,"validation":"Normal interaction and complete party sendouts; controlled damage through normal faint callbacks, victory, saving and return. Difficulty was not tested."},"  "))
	game.queue_free();await process_frame
	SaveData.clear();Game.destination={};Game.carry={};Game.arena_trip={}
	print("Gym field friends: Misty -> Lapras Surf, Lt. Surge -> Pikachu Flash; four real battle transitions and both field helpers passed")
	quit()

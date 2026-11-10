extends GutTest
const Game=preload("res://scripts/game.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
const PATH="user://save_bird_event_test.cfg"
var old_path: String
var old_events: Array
var old_starter: String

class Pilot:
	extends RefCounted
	var direction:=Vector2.ZERO
	func move_dir(_w):return direction
	func aim_point(w):return w.player.position+direction*80.0
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func before_each() -> void:
	old_path=SaveData.path;SaveData.path=PATH
	old_events=Game.bot_events.duplicate();Game.bot_events=["visited_area_saffron_city"]
	old_starter=Game.starter;Game.starter="charmander"
	SaveData.clear()

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path
	Game.bot_events=old_events;Game.starter=old_starter
	Game.destination={};Game.arena_trip={};Game.carry={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture(place: String="kanto_south", human: bool=false):
	var keep_bot:=OS.get_environment("BOT");var keep_place:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0" if human else "1");OS.set_environment("DUNGEON",place)
	if human:SaveData.store_progress("events","visited_area_saffron_city")
	Game.destination={};Game.arena_trip={};Game.carry={}
	var game=load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",keep_bot);OS.set_environment("DUNGEON",keep_place)
	game.world.god=true;game.world.player.controller=Pilot.new()
	game.dialog_text="";game.dialog_t=0.0
	return game

func space(game, echo: bool=false) -> void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true;key.echo=echo
	game._unhandled_input(key)

func finish_talk(game) -> void:
	for _i in 40:
		if game.state!="talk":break
		game._talk_next()

func ready_battle(game) -> void:
	game.advance(0.9);finish_talk(game)
	assert_eq(game.state,"fight")

func hop(game) -> void:
	game.world.player.position=Arena.tile_center(Arena.area_tile("pallet_town",Vector2i(11,9)))
	game.world._start_hop(game.world.player.position+Vector2.UP*24.0)

func clear_chicks(game) -> void:
	for _i in Bird.COUNT:
		game.bird_event.step_battle(Bird.INTERVAL)
		game.world._step_spawns(1.0)
		for enemy in game.world.alive_enemies():game.world.damage(enemy,enemy.hp)
		game.world.step_visual(1.5)

func test_native_art_audio_and_circular_story_stage() -> void:
	var game=fixture(Bird.ARENA)
	assert_eq(game.mode,"arena")
	assert_null(game.arena_trainer)
	assert_true(game.battle.is_empty())
	assert_true(game.is_event_battle())
	assert_true(View3D.supported("res://assets/maps/"+Bird.ARENA))
	assert_false(Arena.solid_at(12,12));assert_true(Arena.solid_at(5,5))
	for species in ["pidgey","pidgeotto","pidgeot"]:
		assert_false(MonSprite.load_set(int(SpeciesDB.get_species(species).dex)).is_empty())
		assert_true(ResourceLoader.exists("res://assets/audio/cry/"+species+".wav"))
	ready_battle(game)
	assert_eq(game.total_enemies,13)
	assert_eq(game.world.bystanders.size(),6,"The flock remains visible when combat begins")

func test_only_fresh_second_airborne_space_triggers_kidnapping() -> void:
	var game=fixture()
	space(game)
	assert_eq(game.bird_event.phase,"idle","Ground Space keeps its normal jump / interaction meaning")
	hop(game)
	space(game,true)
	assert_eq(game.bird_event.phase,"idle","Holding Space cannot trigger the event")
	space(game)
	assert_eq(game.state,"bird_event");assert_eq(game.bird_event.phase,"swoop")
	assert_true(game.world.player.dash.is_empty())
	assert_eq(game.bird_event.helper.species_id,"pidgeotto")
	var actor: Mon=game.bird_event.helper
	space(game)
	assert_same(game.bird_event.helper,actor,"Repeated Space never creates duplicate birds")
	game.advance(0.8)
	assert_eq(game.state,"talk")
	finish_talk(game)
	assert_eq(game.bird_event.phase,"carry_out")

func test_nest_delivery_flings_player_forward_and_parent_leaves_before_battle() -> void:
	var game=fixture(Bird.ARENA)
	var bird=game.bird_event
	var p: Player=game.world.player
	var landing: Vector2=bird.origin
	var hp:=p.hp;var pp:=p.pp.duplicate();var exp_before:=p.exp_total
	assert_true(p.get_meta("carried",false),"The first visit begins in the parent's talons")
	game.advance(Bird.NEST_PASS_TIME*0.5)
	assert_eq(bird.nest_stage,"carried");assert_eq(p.lift,Bird.NEST_THROW_HEIGHT)
	assert_almost_eq(bird.helper.lift-p.lift,bird.carry_gap,0.001)
	game.advance(Bird.NEST_PASS_TIME*0.5+0.05)
	assert_true(bird.nest_released);assert_false(p.get_meta("carried",false))
	assert_eq(bird.nest_stage,"thrown")
	assert_gt(p.lift,Bird.NEST_THROW_HEIGHT,"The throw rises briefly before falling")
	assert_gt((p.position-bird.nest_from).dot(bird.direction),0.0,"The throw carries the player forward")
	var high:=p.lift;var thrown_at:=p.position
	assert_gt(bird.helper.lift-p.lift,bird.carry_gap,"The parent separates and peels upward")
	game.advance(Bird.NEST_THROW_TIME*0.5)
	assert_lt(p.lift,high);assert_gt((p.position-thrown_at).dot(bird.direction),0.0)
	assert_eq(game.world.cam.position,bird.nest_center().round(),"Frame the actual bowl center instead of the offset landing point")
	game.advance(Bird.NEST_THROW_TIME*0.5-0.05+0.005)
	assert_true(bird.nest_landed);assert_eq(bird.nest_stage,"impact")
	assert_eq(p.position,landing);assert_eq(p.lift,0.0)
	assert_gt(p.landing_t,0.0,"Absorb the impact with the native foot-anchored landing recoil")
	assert_eq(game.world.fxs.filter(func(f):return f.landing_dust).size(),4,"Impact dust is emitted once")
	game.advance(Bird.NEST_SETTLE_TIME+0.01)
	assert_eq(bird.nest_stage,"settled");assert_eq(bird.phase,"nest_intro")
	assert_null(bird.helper);assert_eq(game.world.bystanders.size(),6)
	assert_eq(game.state,"talk");assert_eq(game.world.remaining(),0,"The nest introduction precedes the battle")
	assert_eq(p.hp,hp);assert_eq(p.pp,pp);assert_eq(p.exp_total,exp_before)

func test_nest_bowl_and_roosts_share_a_center_independent_of_the_landing_point() -> void:
	var game=fixture(Bird.ARENA)
	var bird=game.bird_event
	var center: Vector2=bird.nest_center()
	assert_eq(center,Vector2(12,12)*Arena.TILE)
	assert_ne(center,Arena.center(),"The landing point is south of the visual bowl center")
	var floor_height:=Arena.ground_height(center)
	assert_lt(floor_height,-0.7,"The straw lining is recessed below the support branches")
	for d in [Vector2.LEFT,Vector2.UP,Vector2.RIGHT,Vector2.DOWN]:
		assert_gt(Arena.ground_height(center+d*Arena.TILE*8.25)-floor_height,1.2,"The woven lip rises around all sides of the hollow")
	var feet: Array=[]
	for mon in game.world.bystanders:
		if not mon.get_meta("nest_spectator",false):continue
		var at: Vector2=mon.position+Vector2(0,mon.feet_offset())
		feet.append(at)
		assert_lt(at.distance_to(center),Arena.TILE*5.8,"Every waiting chick stands inside the lining")
		assert_false(Arena.solid_at(Arena.tile_of(at).x,Arena.tile_of(at).y))
	assert_eq(feet.size(),6)
	ready_battle(game)
	for index in Bird.COUNT:
		if index<6:game.world.player.position=feet[index]-Vector2(0,bird.nest_chick_feet_offset)
		bird.spawned=index;bird._queue_chick()
		var at: Vector2=game.world.pending_spawns[-1].pos
		var ground:=at+Vector2(0,bird.nest_chick_feet_offset)
		assert_lt(ground.distance_to(center),Arena.TILE*5.8,"Later entries also originate inside the bowl")
		assert_false(Arena.solid_at(Arena.tile_of(at).x,Arena.tile_of(at).y))
		if index<6:assert_almost_eq(at.distance_to(feet[index]-Vector2(0,bird.nest_chick_feet_offset)),0.0,0.01,"Waiting chicks join from their original roost, without teleporting")
	assert_false(game.world.bystanders.any(func(mon):return mon.get_meta("nest_spectator",false)))

func test_dodge_skills_indoor_caves_and_menus_cannot_call_a_bird() -> void:
	var game=fixture()
	hop(game);game.world.player.dash["hop"]=false
	assert_false(game.bird_event.press_space())
	game.world.player.dash["hop"]=true;game.state="menu"
	assert_false(game.bird_event.press_space())
	game.state="fight";game.world.player.dead=true
	assert_false(game.bird_event.press_space())
	game.world.player.dead=false
	for place in ["oaks_lab","mt_moon_1f",Bird.ARENA]:
		DungeonDB.set_current(place)
		assert_false(game.bird_event.press_space(),place)

func test_source_is_exact_jump_origin_and_narration_does_not_consume_call() -> void:
	var game=fixture();hop(game)
	var from: Vector2=game.world.player.position
	game.world.player.position+=Vector2.UP*9.0
	game.dialog_text="narration";game.dialog_t=1.0
	space(game)
	assert_eq(game.state,"bird_event")
	assert_eq(game.bird_event.safe_at,from)

func test_snatch_contacts_once_then_hauls_the_player_up_before_dialogue() -> void:
	var game=fixture();hop(game)
	var p: Player=game.world.player
	var at:=p.position;var hp_before:=p.hp
	var exp_before:=p.exp_total;var pp_before:=p.pp.duplicate()
	space(game)
	var bird=game.bird_event
	assert_false(p.get_meta("carried",false),"The talons must make contact before attaching the passenger")
	game.advance(Bird.DIVE_TIME*0.5)
	assert_eq(p.position,at,"Approaching the player cannot drag them prematurely")
	assert_false(bird.gripped)
	assert_gt(bird.helper.facing.dot(bird.direction),0.7,"The bird faces its flight tangent, without reversing at the catch")
	game.advance(Bird.DIVE_TIME*0.5+0.01)
	assert_eq(bird.pickup_stage,"grip")
	assert_true(bird.gripped);assert_true(p.get_meta("carried",false))
	assert_eq(bird.helper.attack_anim,"Attack","The native talon strike replaces the repeated flap at contact")
	assert_gt(p.hurt_t,0.0,"The passenger visibly reacts without losing HP")
	assert_eq(game.world.fxs.filter(func(f):return f.get_meta("bird_snatch_contact",false)).size(),1)
	game.advance(Bird.GRIP_TIME+Bird.PULL_TIME*0.5)
	assert_eq(game.state,"bird_event","The grab and upward pull play through before the dialogue pauses")
	assert_gt(p.lift,bird.contact_lift+20.0)
	assert_gt((p.position-at).dot(bird.direction),10.0)
	assert_eq(bird.helper.attack_anim,"Double")
	game.advance(Bird.PULL_TIME)
	assert_eq(game.state,"talk");assert_eq(bird.phase,"caught")
	assert_gt(p.lift,30.0,"The player is already dangling from the talons when crying out")
	var height:=p.lift
	finish_talk(game);game.advance(0.01)
	assert_gte(p.lift,height,"Departure preserves catch height instead of dropping the passenger to 8px")
	assert_eq(bird.safe_at,at,"The pull never changes the original return location")
	assert_eq(p.hp,hp_before);assert_eq(p.exp_total,exp_before);assert_eq(p.pp,pp_before)

func test_friendly_pickup_and_large_carrier_keep_the_same_grip_without_damage() -> void:
	var game=fixture();game.events.append(Bird.FRIEND)
	game.world.player.setup_player("blastoise",36,[],{})
	hop(game)
	var hp_before: int=game.world.player.hp
	space(game)
	assert_eq(game.menu,"fly")
	game.bird_event.choose_destination("pallet_town")
	game.advance(Bird.DIVE_TIME+0.02)
	assert_eq(game.bird_event.helper.species_id,"pidgeot")
	assert_eq(game.bird_event.pickup_stage,"grip")
	assert_eq(game.world.player.hurt_t,0.0,"A friendly pickup does not use the startled reaction")
	game.advance(Bird.GRIP_TIME+Bird.PULL_TIME)
	assert_eq(game.state,"bird_event");assert_eq(game.bird_event.phase,"fly_depart")
	assert_eq(game.world.player.hp,hp_before)
	assert_gt(game.world.player.lift,30.0)

func test_talon_contact_has_no_snap_from_different_native_foot_anchors() -> void:
	var game=fixture();hop(game);space(game)
	game.advance(Bird.DIVE_TIME-0.001)
	var at: Vector2=game.bird_event.helper.position
	var height: float=game.bird_event.helper.lift
	game.advance(0.001)
	assert_true(game.bird_event.gripped)
	assert_lt(game.bird_event.helper.position.distance_to(at),1.0,"Native foot offsets cannot cause a teleport at contact")
	assert_almost_eq(game.bird_event.helper.lift,height,1.0)

func test_friendly_flyby_keeps_diagonal_speed_through_contact_and_holds_camera() -> void:
	for species in ["charmander","blastoise"]:
		var game=fixture();game.events.append(Bird.FRIEND)
		game.world.player.setup_player(species,5 if species=="charmander" else 36,[],{})
		hop(game);game.advance(0.13)
		var p: Player=game.world.player
		var source:=p.dash.from as Vector2
		var hp:=p.hp;var pp:=p.pp.duplicate();var exp_before:=p.exp_total
		var camera: Vector2=game.world.cam.position
		space(game)
		assert_eq(game.menu,"fly","%s: state=%s phase=%s hop=%s"%[species,game.state,game.bird_event.phase,p.hop_t])
		if game.menu!="fly":game.free();continue
		game.events.append(FlyDestinations.visit_flag("route24"));game.events.append(RoadAccess.SAFFRON_VISITED)
		game.bird_event.choose_destination("route24")
		var bird=game.bird_event
		assert_true(bird.camera_locked)
		assert_gt(bird.direction.x,0.0);assert_lt(bird.direction.y,0.0,"Enter from lower left toward upper right")
		var dt:=1.0/120.0
		game.advance(Bird.DIVE_TIME-2.0*dt)
		var before: Vector2=bird.helper.position
		game.advance(dt)
		var last: Vector2=bird.helper.position
		var incoming: Vector2=(last-before)/dt
		game.advance(2.0*dt)
		var outgoing: Vector2=(bird.helper.position-last)/(2.0*dt)
		assert_true(bird.gripped)
		assert_almost_eq(outgoing.length()/incoming.length(),1.0,0.03,"Catching the passenger cannot brake the bird")
		assert_gt(outgoing.normalized().dot(incoming.normalized()),0.999,"Contact preserves the flight tangent")
		game.advance(Bird.GRIP_TIME+Bird.PULL_TIME)
		assert_eq(bird.phase,"fly_depart")
		var depart_at:=p.position
		game.advance(0.05)
		assert_almost_eq(p.position.distance_to(depart_at)/0.05,incoming.length(),1.0,"Keep cruising toward the upper-right edge")
		assert_eq(game.world.cam.position,camera,"The camera cannot follow the bird back into the centre")
		assert_eq(bird.safe_at,source);assert_eq(p.hp,hp);assert_eq(p.pp,pp);assert_eq(p.exp_total,exp_before)
		game.free()

func test_sideways_carrier_anchors_its_torso_instead_of_its_beak() -> void:
	var anim: Dictionary=MonSprite.load_set(17).Double
	var time:=MonSprite.frame_start(anim,7)
	var visual:=MonSprite.visual_frame(anim,2,time,true)
	assert_eq(visual.body_center,Vector2(37,13),"The native black head marker stays unchanged for ordinary actions")
	assert_eq(MonSprite.flight_anchor(anim,2,time,visual),Vector2(25,17),"The green torso marker keeps the talons over the passenger")

func test_landing_carriers_use_intact_shoot_frames_and_keep_talon_contact() -> void:
	for species in ["charmander","blastoise"]:
		var game=fixture("kanto_south")
		game.world.player.setup_player(species,10,[],{})
		game.bird_event.arrive("pallet_town")
		var helper: Mon=game.bird_event.helper
		var pose: Dictionary=helper._sprites.Double
		var sprites: Dictionary=MonSprite.load_set(int(SpeciesDB.get_species(helper.species_id).dex))
		assert_eq(pose.source_animation,"Shoot")
		assert_eq(pose.tex,sprites.Shoot.tex,"Use the original Shoot image, without cutting or compositing any body pixels")
		assert_eq(pose.fw,sprites.Shoot.fw);assert_eq(pose.fh,sprites.Shoot.fh)
		assert_eq(pose.durations.size(),2,"Loop only the forward-facing stroke, without turning or attack lunges")
		assert_true(pose.has("pose_order"))
		assert_true(pose.get("native_frames",false),"Optical-flow warping must not move the carrier's face between wing poses")
		assert_eq(MonSprite.visual_frame(pose,0,1.0/30.0,true).tex,pose.tex)
		var claw_heights: Array=[]
		for frame in 2:
			var time:=MonSprite.frame_start(pose,frame)
			var visual:=MonSprite.visual_frame(pose,0,time,true)
			var anchor:=MonSprite.flight_anchor(pose,0,time,visual)
			claw_heights.append(game.bird_event._central_edge(visual,anchor.x,false)-anchor.y)
		assert_eq(claw_heights[0],claw_heights[1],"Native Shoot keys keep the talons at the same height when aligned to the torso")
		assert_gt(game.bird_event.landing_overlap,0.0,"The talons overlap the passenger's head slightly")
		assert_eq(sprites.Double.durations.size(),16,"Ordinary Double attacks keep their original animation")
		assert_eq(sprites.Shoot.durations.size(),11,"Ordinary Shoot attacks keep their original animation")
		var at:=helper.position
		for _i in 12:
			game.advance(0.08)
			assert_eq(helper.position,at,"The carrier descends at a fixed ground position")
		game.free()

func test_chicks_stream_pauses_and_pidgeotto_arrives_after_all_twelve() -> void:
	var game=fixture(Bird.ARENA);ready_battle(game)
	game.state="menu";game.advance(20.0)
	assert_eq(game.bird_event.spawned,0)
	game.state="fight"
	for _i in Bird.COUNT:game.bird_event.step_battle(Bird.INTERVAL)
	game.world._step_spawns(1.0)
	assert_eq(game.world.alive_enemies().size(),Bird.COUNT)
	assert_true(game.world.bystanders.is_empty(),"The waiting chicks have all joined the fight")
	game.bird_event.step_battle(5.0)
	assert_false(game.bird_event.boss_spawned)
	for enemy in game.world.alive_enemies():
		assert_eq(enemy.level,16)
		assert_true(enemy.cds.has("peck"));assert_false(enemy.cds.has("sand_attack"))
		game.world.damage(enemy,enemy.hp)
	game.bird_event.step_battle(0.1)
	assert_eq(game.bird_event.phase,"boss_arrival")
	game.advance(0.9)
	assert_eq(game.state,"talk")
	assert_string_contains(game.dialog_text,Lang.t("bird_angry"))
	assert_eq(game.world.remaining(),0,"The parent speaks before becoming an enemy")
	finish_talk(game);game.world._step_spawns(1.0)
	assert_not_null(game.bird_event.boss())
	assert_eq(game.bird_event.boss().level,25)

func test_all_thirteen_defeats_give_no_exp_and_save_won_before_friendship() -> void:
	var game=fixture(Bird.ARENA,true);ready_battle(game)
	Game.arena_trip={"event":Bird.ID,"back":{"map":"kanto_south","pos":Vector2(444,555)}}
	var exp_before: int=game.world.player.exp_total
	var level_before: int=game.world.player.level
	clear_chicks(game)
	game.bird_event.step_battle(0.1);game.advance(0.9);finish_talk(game)
	game.world._step_spawns(1.0)
	var boss: Enemy=game.bird_event.boss()
	assert_not_null(boss);assert_eq(game.world.exp_gain(boss),0)
	game.world.damage(boss,boss.hp);game.bird_event.step_battle(0.1)
	assert_false(game.events.has(Bird.WON),"The parent finishes falling before the speaking actor appears")
	assert_null(game.bird_event.helper,"The parent never appears twice during its faint animation")
	game.world.step_visual(1.5);game.bird_event.step_battle(0.1)
	assert_eq(game.world.player.exp_total,exp_before);assert_eq(game.world.player.level,level_before)
	assert_true(game.pending_learns.is_empty());assert_true(game.status_messages.is_empty())
	assert_true(game.events.has(Bird.WON));assert_false(game.events.has(Bird.FRIEND))
	assert_string_contains(game.dialog_text,Lang.t("bird_strong"))
	var saved:=SaveData.load_saved()
	assert_true(saved.events.has(Bird.WON));assert_false(saved.events.has(Bird.FRIEND))
	assert_eq(saved.map,"kanto_south");assert_eq(saved.pos,Vector2(444,555))
	finish_talk(game);assert_eq(game.bird_event.phase,"take_home")

func test_return_reward_resumes_after_reload_and_friendship_is_permanent() -> void:
	Game.bot_events=[Bird.WON]
	var game=fixture("kanto_south",true)
	# Human saves, rather than bot fixtures, own the interrupted reward.
	game.events.append(Bird.WON);game.bird_event.arrive()
	assert_eq(game.bird_event.phase,"returning")
	var at: Vector2=game.world.player.position
	game.advance(1.1)
	assert_eq(game.world.player.position,at);assert_eq(game.world.player.lift,0.0)
	assert_string_contains(game.dialog_text,Lang.t("bird_home"))
	game._talk_next();assert_string_contains(game.dialog_text,Lang.t("bird_dream"))
	game._talk_next();assert_string_contains(game.dialog_text,Lang.t("bird_fan"))
	game._talk_next();assert_string_contains(game.dialog_text,Lang.t("bird_promise"))
	finish_talk(game);game.advance(0.9);finish_talk(game)
	assert_true(game.events.has(Bird.FRIEND))
	assert_true(SaveData.load_saved().events.has(Bird.FRIEND))
	assert_eq(game.bird_event.phase,"idle")
	game.bird_event.arrive();assert_eq(game.bird_event.phase,"idle","The one-time reward does not replay")

func test_losing_cannot_unlock_friend_or_advance_battle() -> void:
	var game=fixture(Bird.ARENA);ready_battle(game)
	game.world.god=false;game.world.damage(game.world.player,99999)
	game.bird_event.step_battle(50.0)
	assert_eq(game.bird_event.spawned,0)
	assert_false(game.events.has(Bird.WON));assert_false(game.events.has(Bird.FRIEND))

func test_map_confirmation_picks_up_and_arrives_without_pp_or_exp() -> void:
	var game=fixture();game.events.append(Bird.FRIEND);hop(game)
	var pp: Array=game.world.player.pp.duplicate()
	var exp_before: int=game.world.player.exp_total
	var hp_before: int=game.world.player.hp
	space(game)
	assert_eq(game.menu,"fly");assert_true(game.fly_screen.visible)
	assert_null(game.bird_event.helper,"The map opens before a bird is summoned")
	game.events.append(FlyDestinations.visit_flag("route24"));game.events.append(RoadAccess.SAFFRON_VISITED)
	game.bird_event.choose_destination("route24")
	assert_eq(game.bird_event.phase,"calling");assert_false(game.fly_screen.visible)
	game.advance(0.8);assert_eq(game.bird_event.phase,"fly_depart")
	space(game);assert_eq(game.bird_event.phase,"fly_depart","Space cannot cancel a confirmed trip midway")
	# Arrival in the loaded field is covered here; the review tool tests real reloads.
	game.bird_event.arrive("pallet_town")
	assert_eq(game.bird_event.phase,"fly_arrive")
	game.advance(Bird.ARRIVE_TIME+0.01);game.advance(Bird.RELEASE_TIME+0.01);game.advance(Bird.LEAVE_TIME+0.01)
	assert_eq(game.bird_event.phase,"idle");assert_eq(game.world.player.lift,0.0)
	assert_false(game.world.player.get_meta("carried",false))
	assert_eq(game.world.player.pp,pp);assert_eq(game.world.player.exp_total,exp_before);assert_eq(game.world.player.hp,hp_before)
	assert_true(game.bird_event.can_land(game.world.player.position))

func test_large_starters_get_pidgeot_and_small_starters_get_pidgeotto() -> void:
	for species in ["charmander","bulbasaur","squirtle","charmeleon","charizard","venusaur","blastoise"]:
		var p:=Mon.new();p.setup(species,20,Mon.TEAM_PLAYER)
		assert_eq(Bird.carrier(p),"pidgeotto" if p.size_tier<4 else "pidgeot",species)
		p.free()

func test_invalid_destination_is_ignored_and_arrival_rechecks_live_npcs() -> void:
	var game=fixture("kanto_south",true);game.events.append(Bird.FRIEND)
	game.events.erase("visited_area_saffron_city") # Keep an actually unvisited destination.
	hop(game)
	space(game)
	game.bird_event.choose_destination("saffron_city")
	assert_eq(game.menu,"fly");assert_null(game.bird_event.helper)
	game.bird_event.choose_destination("pallet_town")
	var preferred:=FlyDestinations.position_of(FlyDestinations.find("pallet_town"))
	var npc:=Npc.new();npc.setup({"id":"landing_test","sprite":"bill","tile":Arena.tile_of(preferred)})
	game.world.add_child(npc);game.world.npcs.append(npc)
	game.bird_event.arrive("pallet_town")
	assert_ne(game.world.player.position,preferred,"A live NPC cannot be landed on")
	assert_eq(Arena.area_at(game.world.player.position),"pallet_town")
	assert_true(game.bird_event.can_land(game.world.player.position))
	var safe: Vector2=game.world.player.position
	game.world.player.position=Vector2(-100,-100)
	game._save_here();assert_eq(SaveData.load_saved().pos,safe)
	assert_false(game.bird_event.can_land(Vector2.ZERO))

func test_flight_arrival_finishes_without_an_extra_key() -> void:
	var game=fixture("kanto_east");game.events.append(Bird.FRIEND)
	game.bird_event.arrive("route6")
	assert_eq(game.bird_event.phase,"fly_arrive")
	for _i in int(ceil((Bird.ARRIVE_TIME+Bird.RELEASE_TIME+Bird.LEAVE_TIME+0.1)*60.0)):game.advance(1.0/60.0)
	assert_eq(game.bird_event.phase,"idle")
	assert_eq(Arena.area_at(game.world.player.position),"route6")
	assert_eq(game.world.player.lift,0.0)

func test_story_peck_does_not_change_regular_wild_pidgey_or_its_exp() -> void:
	var game=fixture()
	var wild:=Enemy.new();wild.setup_enemy("pidgey",4,game.world.rng)
	assert_true(wild.cds.has("tackle"));assert_false(wild.cds.has("peck"))
	assert_gt(game.world.exp_gain(wild),0)
	wild.free()

func test_water_trees_ledges_and_doors_are_not_landing_places() -> void:
	var game=fixture()
	var checked_water:=false;var checked_solid:=false;var checked_ledge:=false
	for y in int(Arena.map.height):
		for x in int(Arena.map.width):
			var tile:=Vector2i(x,y)
			if not checked_water and Arena.is_water(tile):
				assert_false(game.bird_event.can_land(Arena.tile_center(tile)));checked_water=true
			if not checked_solid and Arena.solid_at(x,y):
				assert_false(game.bird_event.can_land(Arena.tile_center(tile)));checked_solid=true
			if not checked_ledge and Arena.ledge_at(x,y)!=0:
				assert_false(game.bird_event.can_land(Arena.tile_center(tile)));checked_ledge=true
		if checked_water and checked_solid and checked_ledge:break
	assert_true(checked_water);assert_true(checked_solid);assert_true(checked_ledge)
	for warp in Arena.warps():
		assert_false(game.bird_event.can_land(Arena.tile_center(Vector2i(int(warp.x),int(warp.y)))))

func test_new_nest_discovery_waits_for_saffron_but_old_friend_can_still_fly() -> void:
	Game.bot_events=[]
	var game=fixture()
	hop(game)
	space(game)
	assert_eq(game.bird_event.phase,"idle")
	assert_false(game.events.has(Bird.WON))
	game.events.append(Bird.FRIEND)
	hop(game)
	space(game)
	assert_eq(game.bird_event.phase,"selecting","Existing friends keep their travel help")

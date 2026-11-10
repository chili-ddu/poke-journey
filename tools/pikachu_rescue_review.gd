extends "res://tools/forest_rescue_review.gd"
const Pikachu=preload("res://scripts/story/pikachu_rescue.gd")
const PIKA_OUT="res://docs/pikachu_rescue/"

func shot(name: String) -> void:
	game._update_dialogue_focus()
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PIKA_OUT+name+".png")

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_pikachu_rescue_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	Game.bot_events=[];Game.arena_trip={};Game.carry={};Game.destination={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PIKA_OUT))
	await open_place("rock_tunnel_1f")
	assert(game.pikachu_rescue.helper==null)
	await shot("01_cave_before_rescue")
	await open_place("kanto_south")
	var city_links: Array=Arena.warps().filter(func(w):return w.get("rock_pass_link",false) and int(w.index)==3009)
	assert(city_links.size()==1)
	game.world.player.position=Arena.tile_center(Vector2i(int(city_links[0].x),int(city_links[0].y)))
	game.warp_armed=true;game._check_warp()
	await arrive(Pikachu.PLACE)
	await shot("01b_route9_entry")
	var corner:=Arena.area_rect("route10").position+Vector2i(15,4)
	game.world.player.position=Arena.tile_center(corner)-Vector2(0,game.world.player.feet_offset())
	game.world.player.facing=Vector2.RIGHT
	game.view3d._cam_ready=false
	game.dialog_text="";game.dialog_t=0.0
	await shot("02_fence_corner")
	game.advance(DT)
	assert(game.state=="talk")
	game._talk_next()
	await shot("03_recharging_at_power_plant")
	game._talk_next();game._talk_next()
	await shot("04_electricity_extortion")
	finish_talk()
	await arrive(Pikachu.ARENA)
	finish_talk()
	game.world._step_spawns(1.0)
	assert(game.world.alive_enemies().size()==2)
	var exp_before: int=game.world.player.exp_total
	for enemy in game.world.enemies:enemy.frozen=true
	await shot("05_two_bullies")
	for enemy in game.world.alive_enemies():game.world.damage(enemy,enemy.hp)
	game.pikachu_rescue.step_battle(DT)
	assert(game.events.has(Pikachu.WON) and not game.events.has(Pikachu.FRIEND))
	finish_talk()
	await arrive(Pikachu.PLACE)
	assert(game.pikachu_rescue.phase=="thanks")
	game._talk_next()
	await shot("06_promise")
	finish_talk()
	assert(game.events.has(Pikachu.FRIEND))
	assert(game.world.player.exp_total==exp_before)
	# Use the actual entrance warp; both floor changes use the normal game transition.
	var entrance:=Arena.area_rect("route10").position+Vector2i(8,19)
	game.world.player.position=Arena.tile_center(entrance);game.warp_armed=true
	game._check_warp()
	await arrive("rock_tunnel_1f")
	game.world.player.repel_steps=99999
	for i in 50:game.advance(DT);await process_frame
	assert(game.pikachu_rescue.helper!=null and game.pikachu_rescue.brightness==1.0)
	await shot("07_flash_follower_1f")
	var helper: Mon=game.pikachu_rescue.helper
	var from:=Arena.tile_of(helper.position+Vector2(0,helper.feet_offset()))
	var at:=from
	for y in range(maxi(0,from.y-5),mini(int(Arena.map.height),from.y+6)):
		for x in range(maxi(0,from.x-5),mini(int(Arena.map.width),from.x+6)):
			var to:=Vector2i(x,y)
			if game.pikachu_rescue.pathfinder.is_point_solid(to):continue
			var path: PackedVector2Array=game.pikachu_rescue.pathfinder.get_point_path(from,to)
			if path.size()>=5 and path.size()<9:at=to;break
	game.world.player.position=Arena.tile_center(at)-Vector2(0,game.world.player.feet_offset())
	for i in 160:game.advance(DT);await process_frame
	assert(helper.position.distance_to(game.world.player.position)<Arena.TILE*2.0,"Native follower catches up along cave floor")
	await shot("08_following_around_walls")
	game.view3d.visible=false
	game.pikachu_rescue.update_light()
	await shot("09_flat_view_flash")
	game.view3d.visible=true
	var stairs:=Arena.warp_tile("rock_tunnel_1f",1)
	game.world.player.position=Arena.tile_center(stairs);game.warp_armed=true;game._check_warp()
	await arrive("rock_tunnel_b1f")
	for i in 50:game.advance(DT);await process_frame
	assert(game.pikachu_rescue.helper!=null)
	assert(game.world.bystanders.filter(func(m):return m.get_meta("flash_helper",false)).size()==1)
	await shot("10_flash_follower_b1f")
	var exit:=Arena.warp_tile("rock_tunnel_b1f",0)
	game.world.player.position=Arena.tile_center(exit);game.warp_armed=true;game._check_warp()
	await arrive("rock_tunnel_1f")
	for i in 30:game.advance(DT);await process_frame
	assert(game.world.bystanders.filter(func(m):return m.get_meta("flash_helper",false)).size()==1)
	await shot("11_reentry_one_helper")
	var door:=Arena.warp_tile("rock_tunnel_1f",5)
	game.world.player.position=Arena.tile_center(door);game.warp_armed=true;game._check_warp()
	await arrive(Pikachu.PLACE)
	assert(game.pikachu_rescue.helper==null and game.pikachu_rescue.veil==null)
	await shot("12_south_exit")
	FileAccess.open(PIKA_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({
		"actual_scene_transitions":7,"bullies":["magnemite","voltorb"],"friend":game.events.has(Pikachu.FRIEND),
		"both_cave_floors":true,"reentry_duplicate_helpers":false,"outside_helper":false,"player_exp_unchanged":true,
		"combat_validation":"Fast-forward through normal damage and defeat callbacks; enemies frozen only for the combat screenshot."},"  "))
	print("Pikachu rescue: real rescue round trip, both cave floors, follower paths, 2D/3D light and clean exit passed")
	game.free();await process_frame;SaveData.clear();quit()

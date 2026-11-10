extends "res://tools/lapras_escape_review.gd"

const HMs=Game.FieldHMs
const Cut=preload("res://scripts/story/forest_rescue.gd")
const Flash=preload("res://scripts/story/pikachu_rescue.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
const HM_OUT="res://docs/direct_field_hms/"
var results: Array=[]
var transitions: Array=[]
var failed:=false

func check(ok: bool,message: String) -> bool:
	if not ok:failed=true;push_error(message)
	return ok

func configure() -> void:
	super.configure();game.road_pursuit.cooldown=10000.0
	check(DisplayServer.window_get_size()==Vector2i(384,216),"Minimum 1x test window after every load")

func profile(species: String,place: String,flags: Array) -> void:
	SaveData.clear();Game.starter=species;Game.bot_events=flags.duplicate()
	Game.destination={};Game.carry={};Game.arena_trip={}
	for flag in flags:SaveData.store_progress("events",flag)
	OS.set_environment("BOT","1")
	await open_place(place)
	OS.set_environment("BOT","0")
	game.dialog_text="";game.dialog_t=0.0;game.status_message_active=false
	game.world.cam.position=game.world.player.position;game.view3d._cam_ready=false

func shot(name: String) -> void:
	game._update_dialogue_focus();game.world.cam.position=game.world.player.position
	game.view3d._cam_ready=false
	for i in 8:
		if game.pikachu_rescue!=null:game.pikachu_rescue.update_light()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(HM_OUT+name+".png")

func tick() -> void:
	game.advance(DT)
	if game.pikachu_rescue!=null:game.pikachu_rescue.update_light()

func changed(previous,reason: String) -> bool:
	var from:=DungeonDB.current
	for i in 700:
		if current_scene!=null and current_scene!=previous:break
		await create_timer(0.005).timeout
	if not check(current_scene!=null and current_scene!=previous,"Actual scene reload: "+reason):return false
	game=current_scene;configure()
	transitions.append({"from":from,"to":DungeonDB.current,"reason":reason})
	return true

func tree_near() -> Npc:
	for tree: Npc in game.field_friends.trees:
		var at:=Vector2.INF
		for d in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
			var point:=Arena.tile_center(tree.tile+d)
			if not Arena.is_water(Arena.tile_of(point)) and Arena.resolve(point,game.world.player.radius).distance_to(point)<0.1:at=point;break
		if at==Vector2.INF:continue
		game.world.player.position=at;game.world.player.facing=(tree.position-at).normalized()
		if game.npc_in_reach()==tree:return tree
	return null

func run() -> void:
	await CaptureWindow.park(self);AudioServer.set_bus_mute(0,true)
	SaveData.path="user://save_direct_hms_review.cfg"
	OS.set_environment("GOD","1");OS.set_environment("SEED","17");OS.set_environment("LANG_CODE","ko")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HM_OUT))
	for species in ["charmander","squirtle"]:
		await profile(species,"kanto_world",[Cut.FRIEND])
		var tree:=tree_near()
		if not check(tree!=null,"Reachable Cut tree"):quit(1);return
		var id:=tree.id;var tile:=tree.tile;var at: Vector2=game.world.player.position;var pp: Array=game.world.player.pp.duplicate()
		space()
		var direct: bool=species=="charmander"
		if not check(game.field_friends.phase==("self_cut" if direct else "calling"),"Correct Cut actor"):quit(1);return
		var captured:=false
		for frame in 480:
			if game.state!="field_cut":break
			tick()
			if direct and not check(not is_instance_valid(game.field_friends.helper),"Self Cut never spawns Scyther"):quit(1);return
			if not captured and ((direct and game.field_friends.cut) or (not direct and game.field_friends.phase=="cutting")):
				await shot(species+"_cut");captured=true
			if frame%6==0:await process_frame
		if not check(game.field_friends.phase=="idle" and not Arena.solid_at(tile.x,tile.y) and game.world.player.position==at and game.world.player.pp==pp,"Cut opens the tree without moving the player or spending PP"):quit(1);return
		if not check(SaveData.load_saved().events.has(id),"Cut obstacle progress saved"):quit(1);return
		results.append({"move":"cut","species":species,"self":direct,"pp_unchanged":true,"obstacle_saved":true,"normal_space_input":true})
		print("Field HM native passed: ",species," Cut / self=",direct)
	for species in ["squirtle","charmander"]:
		await profile(species,"kanto_world",[Data.FRIEND])
		game.world.player.position=Arena.tile_center(Arena.area_rect("route19").position+Data.BEACH_PLAYER)
		game.world.player.facing=Vector2.DOWN
		var pp: Array=game.world.player.pp.duplicate();space()
		var direct: bool=species=="squirtle"
		if not check(game.lapras_escape.phase==("self_surf" if direct else "calling"),"Correct Surf actor"):quit(1);return
		for frame in 180:
			tick()
			if game.lapras_escape.phase=="idle":break
			if frame%6==0:await process_frame
		if not check(game.world.player.travel_terrain==2 and Arena.is_water(Arena.tile_of(game.world.player.position)) and game.world.player.pp==pp,"Surf enters real water without spending PP"):quit(1);return
		if not check(is_instance_valid(game.lapras_escape.helper)!=direct and game.world.player.has_meta("lapras_ride")!=direct,"Only incompatible species ride Lapras"):quit(1);return
		game.world.player.controller.moving=Vector2.DOWN
		for frame in 18:tick()
		game.world.player.controller.moving=Vector2.ZERO
		await shot(species+"_surf")
		var resumed:=false
		if direct:
			game._save_here();var saved_at: Vector2=game.world.player.position
			Game.destination={};Game.carry={};Game.arena_trip={}
			var previous=game
			if not check(reload_current_scene()==OK,"Reload saved water scene"):quit(1);return
			if not await changed(previous,"self Surf save resume"):quit(1);return
			tick()
			resumed=game.world.player.position.distance_to(saved_at)<0.1 and game.world.player.travel_terrain==2 and game.world.player.known_moves().has("surf") and not is_instance_valid(game.lapras_escape.helper)
			if not check(resumed,"Saved self Surf restores water position and no carrier"):quit(1);return
			await shot("squirtle_surf_resumed")
		results.append({"move":"surf","species":species,"self":direct,"water_movement":true,"pp_unchanged":true,"saved_water_resumed":resumed,"normal_space_input":true})
		print("Field HM native passed: ",species," Surf / self=",direct)
	for species in ["bulbasaur","charmander"]:
		await profile(species,"rock_tunnel_1f",[Flash.FRIEND])
		var event=game.pikachu_rescue;var direct: bool=species=="bulbasaur"
		for frame in 50:
			tick()
			if frame%6==0:await process_frame
		if not check(event.self_flash==direct and is_instance_valid(event.helper)!=direct and event.brightness==1.0,"Correct Flash source"):quit(1);return
		await shot(species+"_flash")
		var source: Mon=game.world.player if direct else event.helper
		var projected: Vector2=event._screen(source)
		if not check((event.veil.material as ShaderMaterial).get_shader_parameter("helper_center").distance_to(projected)<0.002,"Vision follows the actual light source"):quit(1);return
		var entry: Dictionary=game.view3d._sprites[source.get_instance_id()]
		if not check(entry.has("flash_lamp") and entry.flash_lamp.visible and entry.flash_lamp.omni_range==6.5,"3D light follows the same actor"):quit(1);return
		results.append({"move":"flash","species":species,"self":direct,"vision_and_2d_3d_lights_centered":true})
		print("Field HM native passed: ",species," Flash / self=",direct)
	for species in ["charizard","blastoise"]:
		await profile(species,"kanto_world",[Bird.FRIEND,FlyDestinations.visit_flag("route24")])
		game.world.player.position=Arena.tile_center(Arena.area_rect("pallet_town").position+Vector2i(11,9))
		game.world._start_hop(game.world.player.position+Vector2.UP*24);space()
		if not check(game.menu=="fly","Normal second airborne Space opens the map"):quit(1);return
		game.bird_event.choose_destination("route24")
		var direct: bool=species=="charizard"
		if not check(game.bird_event.self_flight==direct and is_instance_valid(game.bird_event.helper)!=direct,"Correct Fly actor"):quit(1);return
		await shot(species+"_fly_departure")
		var prior=game
		for frame in 600:
			if game.state=="warp":break
			tick()
			if frame%6==0:await process_frame
		if not await changed(prior,"Fly to Route24"):quit(1);return
		if not check(game.bird_event.self_flight==direct and is_instance_valid(game.bird_event.helper)!=direct,"Arrival retains the same travel mode"):quit(1);return
		for frame in 600:
			if game.bird_event.phase=="idle":break
			tick()
			if frame%6==0:await process_frame
		if not check(game.bird_event.phase=="idle" and Arena.area_at(game.world.player.position)=="route24" and game.world.player.lift==0.0,"Flight lands at its visited destination"):quit(1);return
		await shot(species+"_fly_arrival")
		results.append({"move":"fly","species":species,"self":direct,"normal_airborne_space_and_map_input":true,"actual_scene_transition":true,"landed":true})
		print("Field HM native passed: ",species," Fly / self=",direct)
	FileAccess.open(HM_OUT+"native_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"window_size":DisplayServer.window_get_size(),"cases":results,"actual_scene_transitions":transitions,"validation":"Normal Space/map interactions, compatible self actions and incompatible friend fallbacks, saved obstacle and underwater resume, source-centered 2D/3D Flash, actual Fly scene reload and landing. Existing animation frames and FX are reused."},"  "))
	SaveData.clear();Game.destination={};Game.carry={};Game.arena_trip={}
	quit(1 if failed else 0)

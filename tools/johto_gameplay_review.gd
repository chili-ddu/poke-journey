extends SceneTree
const Game = preload("res://scripts/game.gd")
const Johto = preload("res://scripts/data/johto_maps.gd")
const Travel = preload("res://scripts/johto/region_travel.gd")
const OUT := "res://docs/johto_gameplay/"
const DT := 1.0/60.0
var game: Node
var results: Array=[]
var transitions: Array=[]

class Walker:
	extends RefCounted
	var target := Vector2.ZERO
	var active := false
	func move_dir(w):
		var delta: Vector2=target-w.player.position
		return delta.normalized()*minf(1.0,delta.length()/5.0) if active and delta.length()>0.6 else Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*48
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void: run.call_deferred()

func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		FileAccess.open(OUT+"failure.txt",FileAccess.WRITE).store_string(message)
		quit(1)
	return ok

func configure() -> void:
	game.set_process(false)
	game.bot=true
	game.view3d.set_process(false)
	game.world.player.controller=Walker.new()
	game.banner_t=0
	game.dialog_text="";game.last_small_message=""

func frame(tick: bool=true) -> void:
	if tick: game.advance(DT)
	game.view3d._process(DT)
	await process_frame

func shot(label: String) -> void:
	game.view3d._cam_ready=false
	for i in 12:await frame(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
	check(root.size==Vector2i(384,216),"Minimum 1x window retained")
	results.append({"shot":label,"map":DungeonDB.current,"pos":[game.world.player.position.x,game.world.player.position.y],"native":Arena.is_native(),"chunks":game.view3d.native_renderer.chunks.size() if game.view3d.native_renderer!=null else 0})

func open_fixture(place: String, at: Vector2=Vector2.INF) -> void:
	if is_instance_valid(game):game.free();await process_frame
	OS.set_environment("DUNGEON",place)
	Game.destination={};Game.carry={};Game.arena_trip={}
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	configure()
	OS.set_environment("DUNGEON","")
	if at.is_finite():game.world.player.position=at
	game.world.cam_pos=game.world.player.position
	for i in 20:await frame(false)

func arrive(place: String) -> bool:
	var old=game
	for i in 160:
		await create_timer(0.01).timeout
		if current_scene!=old:break
	if not check(current_scene!=old,"Scene transition finishes: "+place):return false
	game=current_scene;configure()
	if not check(DungeonDB.current==place,"Correct destination: "+place):return false
	for i in 20:await frame(false)
	transitions.append(place)
	return true

func walk_to(goal: Vector2) -> bool:
	var walker=game.world.player.controller
	walker.target=goal;walker.active=true
	for i in 360:
		if game.world.player.position.distance_to(goal)<1.5:break
		game.world.step(DT)
		await frame(false)
	walker.active=false
	if game.world.player.position.distance_to(goal)>=2.0:
		print("Walk failure at ",game.world.player.position," target ",goal," velocity ",game.world.player.vel," radius ",game.world.player.radius," clear goal ",Arena.resolve(goal,game.world.player.radius))
		await shot("walk_failure")
	return check(game.world.player.position.distance_to(goal)<2.0,"Actual walking reaches "+str(goal))

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	SaveData.path="user://johto_gameplay_review_only.cfg"
	SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("LANG_CODE","ko")
	Game.skip_opening=true;Game.bot_events=[];Game.bot_beaten=[]
	# New scenes use human controls until the reviewer installs its walker.
	# BOT would sometimes eat a healing berry before arrive() resumes.
	OS.set_environment("BOT","0")
	# Enter through the real ferry interaction, including cancellation.
	await open_fixture("vermilion_harbor",Travel.destination_for("johto").pos)
	var sailor: Npc
	for npc in game.world.npcs:
		if npc.talk=="johto_ferry":sailor=npc
	if not check(sailor!=null,"Ferry sailor exists in the existing harbour"):return
	game.world.player.position=Arena.tile_center(sailor.talk_tile)
	game._talk(sailor)
	for i in 10:
		if game.state!="talk":break
		game._talk_next()
	if not check(game.menu=="johto_ferry","Talking opens boarding choice"):return
	await shot("01_kanto_ferry")
	game._resolve_menu(1)
	if not check(game.state=="fight" and Game.destination.is_empty(),"Cancel keeps the player in Kanto"):return
	game.world.player.hp=7
	game.world.player.bag["oran_berry"]=17
	game.region_travel.open_menu();game._resolve_menu(0)
	if not await arrive("johto_330"):return
	if not check(game.world.player.hp==7 and game.world.player.bag.oran_berry==17,"Ferry preserves HP and items (HP=%d, berries=%d)" % [game.world.player.hp,game.world.player.bag.oran_berry]):return
	if not check(Arena.tile_of(game.world.player.position)==Vector2i(16,19),"Arrives at the harbour, not an unrelated spawn"):return
	await shot("02_olivine_port")
	game.region_travel.open_menu();game._resolve_menu(0)
	if not await arrive("vermilion_harbor"):return
	if not check(game.world.player.hp==7 and game.world.player.bag.oran_berry==17,"Return ferry preserves the same player"):return
	await shot("03_kanto_return")
	# Real World movement into and out of Elm's lab, not a direct scene picker.
	await open_fixture("johto_060",Arena.tile_center(Vector2i(684,395)))
	await shot("04_new_bark")
	if not await walk_to(Arena.tile_center(Vector2i(684,393))):return
	game.warp_armed=true;game._check_warp()
	if not await arrive("johto_061"):return
	await shot("05_elms_lab")
	var door:=Arena.warp_tile("johto_061",0)
	if not await walk_to(Arena.tile_center(door+Vector2i.UP)):return
	if not await walk_to(Arena.tile_center(door)):return
	game.warp_armed=true;game._check_warp()
	if not await arrive("johto_060"):return
	for i in 30:await frame()
	if not check(game.state!="warp","Arrival latch prevents an immediate return bounce"):return
	# Additional native terrain profiles with actual Game rendering.
	for sample in [["06_goldenrod",76,Vector2(358.5,366.5)],["07_ilex_forest",117,Vector2(20.5,68.5)],["08_union_cave",99,Vector2(19.5,48.5)],["09_ecruteak",78,Vector2.INF]]:
		await open_fixture(Johto.id(sample[1]),sample[2]*Arena.TILE)
		await shot(sample[0])
	# Store and reload a non-default position with the normal save format.
	game.bot=false;game._save_here()
	var saved:=SaveData.load_saved()
	if not check(saved.map==DungeonDB.current and saved.pos.distance_to(game.world.player.position)<0.01,"Native map/position use the existing save format"):return
	var expected: Vector2=game.world.player.position
	game.free();await process_frame
	OS.set_environment("BOT","0")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	configure()
	if not check(DungeonDB.current==saved.map and game.world.player.position.distance_to(expected)<0.1,"Normal Game reload restores the native location"):return
	await shot("10_saved_resume")
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"fixtures":results,"transitions":transitions,"save_roundtrip":true,"isolated_save":SaveData.path,"window":[384,216]},"  "))
	game.free();await process_frame;SaveData.clear()
	print("Johto actual Game review passed: ferry roundtrip, real lab walking/doors, 4 region profiles, save/resume, 384x216")
	quit()

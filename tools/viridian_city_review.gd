extends SceneTree
const OUT := "res://docs/viridian_city_review/"
var game: Node
var results: Array = []
class Walk:
	extends RefCounted
	var target := Vector2.ZERO
	func move_dir(w) -> Vector2: return (target-w.player.position).normalized() if target.distance_to(w.player.position)>0.8 else Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position+Vector2.UP*80
	func want_skill(_i,_w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false
var walker: Walk
func _init() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await CaptureWindow.park(self)
	SaveData.path = "user://save_viridian_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","1")
	await open_fixture("kanto_south")
	game.hud.visible = false
	for entry in [["south",Vector2(25.5,151.5)],["center",Vector2(26.5,148.5)],["mart",Vector2(36.5,141.5)],["school",Vector2(25.5,140.5)],["gym",Vector2(36.5,132.5)],["north",Vector2(25.5,126.5)],["west",Vector2(12.5,142.5)]]:
		game.world.player.position = Arena.resolve(entry[1]*Arena.TILE,game.world.player.radius)
		walker.target = game.world.player.position
		game.view3d._cam_ready = false
		for frame in 15:
			game.world.step_visual(1.0/60)
			await process_frame
		await shot("outdoor_"+entry[0])
	# Exercise both public interiors from the outdoor road using real movement/warps.
	game.world.player.position = Vector2(26.5,148.5)*Arena.TILE
	walker.target = game.world.player.position
	await walk_to(Vector2i(26,146),true)
	await arrive("viridian_center","center_entry")
	await walk_to(Vector2i(7,4))
	var nurse: Npc = game.npc_in_reach()
	assert(nurse != null)
	var returned: Vector2 = game.world.player.position
	game.world.player.hp = 1
	game.world.player.pp[0] = 0
	game._talk(nurse)
	assert(game.state=="talk")
	var first_text: String = game.dialog_text
	game.bot = false
	for i in 120: game.advance(1.0/60)
	game.bot = true
	assert(game.state=="talk" and game.dialog_text==first_text,"NPC dialogue waits for input")
	for i in 20:
		if game.state!="talk": break
		game._talk_next()
	assert(game.state=="heal")
	for i in 900:
		game.advance(1.0/60)
		if i==90: await shot("center_healing")
		if game.state!="heal": break
	assert(game.world.player.hp==game.world.player.max_hp and game.world.player.pp[0]>0)
	assert(game.world.player.position.distance_to(returned)<0.1)
	for i in 20:
		if game.state!="talk": break
		game._talk_next()
	assert(game.state=="town")
	results.append({"nurse_manual_dialogue":true,"healing_and_return":true})
	await walk_to(Vector2i(7,8),true)
	await arrive("kanto_south","center_exit")
	await walk_to(Vector2i(36,139),true)
	await arrive("viridian_mart","mart_entry")
	await walk_to(Vector2i(4,3))
	var clerk: Npc = game.npc_in_reach()
	assert(clerk != null,"Clerk reachable")
	game._talk(clerk)
	for i in 20:
		if game.state!="talk": break
		game._talk_next()
	await shot("mart_shop")
	results.append({"clerk_reachable":true,"shop_state":game.state,"menu":game.menu})
	game.panel.visible = false
	game.state = "town"
	await walk_to(Vector2i(3,7),true)
	await arrive("kanto_south","mart_exit")
	# North/south road connections and the existing gym event.
	await walk_to(Vector2i(21,121))
	await walk_to(Vector2i(24,159))
	results.append({"north_south_roads":true})
	for locked in [Vector2i(25,131),Vector2i(25,138)]:
		assert(Arena.solid_at(locked.x,locked.y),"Unsupported interiors stay locked")
	await walk_to(Vector2i(36,131))
	game.world.player.position = Arena.tile_center(Vector2i(36,130))
	game.warp_armed = true
	game._check_warp()
	assert(game.state=="giovanni","Gym event starts")
	for i in 1800:
		game.advance(1.0/60)
		if game.state=="fight" and game.gio.is_empty(): break
	assert(game.state=="fight" and game.events.has(game.GIO_EVENT),"Gym event finishes")
	assert(Arena.solid_at(36,130),"Gym closes after event")
	results.append({"gym_event":true,"house_school_locked_by_design":true})
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("Viridian review passed: ",results)
	game.queue_free()
	await process_frame
	quit()
func setup_controller() -> void:
	game.set_process(false)
	walker = Walk.new()
	walker.target = game.world.player.position
	game.world.player.controller = walker
	game.stream.clear()
	game.banner_t = 0
func open_fixture(place: String) -> void:
	if game != null:
		game.queue_free()
		await process_frame
	OS.set_environment("DUNGEON",place)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	setup_controller()
	await process_frame
	OS.set_environment("DUNGEON","")
func walk_to(goal: Vector2i, warp := false) -> void:
	var start := Arena.tile_of(game.world.player.position)
	var queue: Array[Vector2i] = [start]
	var parents := {start:start}
	var cursor := 0
	while cursor<queue.size() and not parents.has(goal):
		var at := queue[cursor]
		cursor += 1
		for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var n: Vector2i = at+d
			if parents.has(n) or Arena.solid_at(n.x,n.y): continue
			var center := Arena.tile_center(n)
			if center.distance_to(Arena.resolve(center,game.world.player.radius))>0.1: continue
			if n!=goal and not Arena.warp_at(center).is_empty(): continue
			parents[n]=at
			queue.append(n)
	assert(parents.has(goal),"Route exists to "+str(goal))
	var path: Array[Vector2i] = []
	var cell := goal
	while cell!=start:
		path.push_front(cell)
		cell=parents[cell]
	for tile in path:
		walker.target = Arena.tile_center(tile)
		for i in 180:
			game.advance(1.0/60)
			if game.state=="warp":
				assert(warp and tile==goal,"Only planned door triggers")
				return
			if game.world.player.position.distance_to(walker.target)<=0.8: break
			if i%4==0: await process_frame
		assert(game.world.player.position.distance_to(walker.target)<=0.8,"Walk reaches "+str(tile))
	assert(not warp,"Door should trigger transition")
func arrive(place: String,label: String) -> void:
	for i in 180:
		await create_timer(0.01).timeout
		if current_scene!=game: break
	assert(current_scene!=game,"Scene reload completes")
	game=current_scene
	setup_controller()
	await process_frame
	assert(DungeonDB.current==place,"Correct arrival map")
	var mat: ShaderMaterial = game.look_rect.material
	var indoor := DungeonDB.is_indoor(place)
	assert(is_equal_approx(float(mat.get_shader_parameter("blur_px")),3.0 if indoor else 9.0))
	assert(not mat.get_shader_parameter("dialogue_focus_enabled"))
	for i in 30:
		game.advance(1.0/60)
		await process_frame
	assert(game.state!="warp","No automatic door bounce")
	var ent: Dictionary = game.view3d._sprites[game.world.player.get_instance_id()]
	assert(not ent.has("occlusion_cue"), "No x-ray overlay")
	results.append({"arrival":place,"tile":str(Arena.tile_of(game.world.player.position)),"no_bounce":true,"indoor":indoor})
	await shot(label)
func shot(label: String) -> void:
	game._update_dialogue_focus()
	game.queue_redraw()
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")

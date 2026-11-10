extends SceneTree
const OUT := "res://docs/kanto_expansion_review/"
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
	SaveData.path = "user://save_kanto_expansion_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","1")
	# Load every added location with its real renderer and collision patches.
	for place in DungeonDB.Expansion.DUNGEONS:
		print("LOAD ",place)
		await open_fixture(place)
		assert(game.view3d != null, "HD-2D active: "+place)
		for warp in Arena.warps():
			if not DungeonDB.WARP_MAPS.has(warp.to): continue
			var tile := Vector2i(int(warp.x),int(warp.y))
			assert(not Arena.solid_at(tile.x,tile.y),"Open doorway: "+place+str(tile))
			assert(Arena.resolve(Arena.tile_center(tile),game.world.player.radius).distance_to(Arena.tile_center(tile))<0.1,"Door has room for player: "+place+str(tile))
		if place in ["kanto_north","kanto_east"]:
			var area_id := "cerulean_city" if place=="kanto_north" else "vermilion_city"
			for area in Arena._areas:
				if area.id==area_id:
					game.world.player.position = Arena.resolve(Arena.tile_center(area.rect.position+Vector2i(21,22)),game.world.player.radius)
					walker.target=game.world.player.position
					game.view3d._cam_ready=false
		if DungeonDB.is_indoor(place) or String(place).begins_with("mt_moon"):
			var here := Arena.tile_of(game.world.player.position)
			for step in [Vector2i(0,-2),Vector2i(0,-1),Vector2i(1,0)]:
				var next: Vector2i = here+step
				if not Arena.solid_at(next.x,next.y) and Arena.warp_at(Arena.tile_center(next)).is_empty():
					game.world.player.position=Arena.resolve(Arena.tile_center(next),game.world.player.radius)
					walker.target=game.world.player.position
					game.view3d._cam_ready=false
					break
		game.ui_root.visible=false
		await shot(place)
		results.append({"loaded":place,"warps":Arena.warps().size()})
	# Actual scene transitions: cave stairs, tunnel and public facilities.
	var cases := [["kanto_north","mt_moon_1f"],["mt_moon_1f","mt_moon_b1f"],["mt_moon_b1f","mt_moon_b2f"],["mt_moon_b1f","route4"],["kanto_north","underground_path_north_entrance"],["underground_path_north_entrance","underground_path_north_south_tunnel"],["underground_path_north_south_tunnel","underground_path_south_entrance"],["underground_path_south_entrance","route6"],["kanto_north","cerulean_city_pokemon_center_1f"],["cerulean_city_pokemon_center_1f","cerulean_city"],["kanto_north","cerulean_city_mart"],["kanto_east","vermilion_city_pokemon_center_1f"],["vermilion_city_pokemon_center_1f","vermilion_city"],["kanto_east","vermilion_city_mart"]]
	for pair in cases:
		print("WARP ",pair)
		await open_fixture(pair[0])
		var selected: Dictionary = {}
		for warp in Arena.warps():
			if warp.to==pair[1]: selected=warp;break
		assert(not selected.is_empty(),"Warp exists: "+str(pair))
		game.world.player.position=Arena.tile_center(Vector2i(int(selected.x),int(selected.y)))
		walker.target=game.world.player.position
		game.warp_armed=true
		game._check_warp()
		assert(game.state=="warp")
		await arrive(DungeonDB.WARP_MAPS[pair[1]],"travel_%02d" % results.size())
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("Kanto expansion: all location loads, door clearances and 14 scene transitions passed")
	game.queue_free()
	await process_frame
	quit()
func reachable() -> Dictionary:
	var start := Arena.tile_of(game.world.player.position)
	var seen := {start:true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor<queue.size():
		var tile := queue[cursor]
		cursor += 1
		for dir in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next: Vector2i = tile+dir
			if seen.has(next) or Arena.solid_at(next.x,next.y): continue
			var at := Arena.tile_center(next)
			if at.distance_to(Arena.resolve(at,game.world.player.radius))>0.01: continue
			seen[next]=true
			queue.append(next)
	return seen
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
	assert(DungeonDB.current==place or (DungeonDB.current in ["kanto_south","kanto_north"] and place in ["kanto_south","kanto_north"]),"Correct arrival map")
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

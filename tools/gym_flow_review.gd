extends SceneTree
const OUT := "res://docs/pewter_facilities_review/"
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
	SaveData.path = "user://save_gym_flow_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","1")
	await open_fixture("pewter_gym")
	await walk_to(Vector2i(6,13))
	await walk_to(Vector2i(6,6))
	await shot("gym_leader_approach")
	await walk_to(Vector2i(6,14),true)
	await arrive("kanto_south","gym_returned")
	print("Gym leader approach and exit passed")
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

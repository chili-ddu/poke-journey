extends SceneTree
# Walk through the actual World movement/collision path. No save writes or warp handling.
var OUT := "res://docs/indoor_occlusion/"
const DT := 1.0 / 60.0
const ROUTES := [
	["shelf-front", "players_house_2f", Vector2(3.5,3.5), Vector2(6.5,3.5)],
	["rail-front", "players_house_2f", Vector2(7.5,4.5), Vector2(10.5,4.5)],
	["rail-side", "players_house_2f", Vector2(7.5,4.5), Vector2(7.5,2.5)],
	["stairs-side", "players_house_1f", Vector2(10.5,4.5), Vector2(10.5,3.5)],
	["counter-front", "viridian_center", Vector2(3.5,4.5), Vector2(11.5,4.5)],
	["counter-left", "viridian_center", Vector2(3.5,4.5), Vector2(3.5,2.5)],
	["counter-right", "pewter_center", Vector2(11.5,4.5), Vector2(11.5,2.5)],
]
class Walk:
	extends RefCounted
	var target := Vector2.ZERO
	func move_dir(w) -> Vector2:
		return (target-w.player.position).normalized() if target.distance_to(w.player.position)>0.8 else Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.DOWN*80
	func want_skill(_i, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false
func _init() -> void:
	call_deferred("run")
func run() -> void:
	if OS.get_environment("OCCLUSION_OUT") != "":
		OUT = OS.get_environment("OCCLUSION_OUT").trim_suffix("/") + "/"
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","1")
	SaveData.path = "user://save_occlusion_review.cfg"
	var results: Array = []
	for route in ROUTES:
		OS.set_environment("DUNGEON",route[1])
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		await process_frame
		OS.set_environment("DUNGEON","")
		game.banner_t = 0
		game.stream.clear()
		var walker := Walk.new()
		game.world.player.controller = walker
		var start: Vector2 = route[2]*Arena.TILE
		var end: Vector2 = route[3]*Arena.TILE
		game.world.player.position = Arena.resolve(start,game.world.player.radius)
		var start_error: float = start.distance_to(game.world.player.position)
		walker.target = game.world.player.position
		for i in 40:
			game.world.step_visual(DT)
			await process_frame
		var reached := true
		var samples := 0
		for point in 5:
			walker.target = start.lerp(end,point/4.0)
			for frame in 240:
				if game.world.player.position.distance_to(walker.target)<=0.8:
					break
				game.world.step(DT)
				game.world.step_visual(DT)
				samples += 1
				await process_frame
			reached = reached and game.world.player.position.distance_to(walker.target)<=0.8
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+route[0]+"_"+str(point)+".png")
		results.append({"route":route[0],"map":route[1],"reached_all":reached,"movement_frames":samples,"start_error":start_error,"end_error":game.world.player.position.distance_to(end)})
		print(results.back())
		game.queue_free()
		await process_frame
	FileAccess.open(OUT+"review.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("Occlusion review complete")
	quit()

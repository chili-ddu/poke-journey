extends SceneTree

# 연막 진입·이탈: 실제 이동 입력으로 아래/위 통과, 음영 수치와 화면 기록.
#   godot --path . -s tools/smoke_moving_review.gd -- <출력디렉터리>
const DT := 1.0 / 60.0
var out := "."
var game: Node

class Still:
	extends RefCounted
	var moving := false
	func move_dir(_w) -> Vector2: return direction if moving else Vector2.ZERO
	var direction := Vector2.RIGHT
	func aim_point(w) -> Vector2: return w.player.position + direction * 80.0
	func want_skill(_i: int, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	OS.set_environment("BOT", "1"); OS.set_environment("GOD", "1"); OS.set_environment("SEED", "1")
	await CaptureWindow.park(self)
	OS.set_environment("DUNGEON", "kanto_south")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON", "")
	var w = game.world
	var p: Player = w.player
	p.controller = Still.new()
	game.banner_t = 0.0
	game.stream.clear()
	p.position = Arena.tile_center(Vector2i(23, 209))
	p.facing = Vector2.RIGHT
	await _settle(30)
	for direction in [Vector2.DOWN,Vector2.UP]:
		p.position = Arena.tile_center(Vector2i(23,209)) + (Vector2(0,100) if direction==Vector2.UP else Vector2.ZERO)
		p.controller.direction = direction
		p.controller.moving = false
		await _settle(30)
		var center: Vector2 = p.position+direction*35.0
		w._smoke_cloud_custom(center,36.0,p.radius)
		p.controller.moving = true
		var previous := 0.0
		var peak := 0.0
		var largest_step := 0.0
		var start := p.position
		var records := []
		for frame in 100:
			w.step(DT)
			var shade: float = w.smoke_body_shade(p.position)
			peak=maxf(peak,shade)
			largest_step=maxf(largest_step,absf(shade-previous))
			previous=shade
			records.append({"frame":frame,"x":p.position.x,"y":p.position.y,"shade":shade})
			await process_frame
			if frame%2==0: await _shot(("down" if direction==Vector2.DOWN else "up")+"_%03d"%frame)
		var label := "down" if direction==Vector2.DOWN else "up"
		FileAccess.open(out+"/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
		print(label," distance=",p.position.distance_to(start)," peak=",peak," max_step=",largest_step," final=",previous)
		p.controller.moving=false
	print("smoke movement review OK")
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])

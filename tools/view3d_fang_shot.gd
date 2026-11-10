extends SceneTree

# 불꽃엄니 3D 캡처: 벌어진 송곳니 / 닫힌 송곳니와 불길 / 사라지는 송곳니.
# godot --path . -s tools/view3d_fang_shot.gd -- <출력디렉터리>
const DT := 1.0 / 60.0
var out := "."
var game: Node

class Walker:
	extends RefCounted
	var dir := Vector2.ZERO
	func move_dir(_w) -> Vector2: return dir
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 80.0
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
	var c := Walker.new()
	p.controller = c
	game.banner_t = 0.0
	game.stream.clear()
	print("view3d: ", game.view3d != null)
	p.position = Arena.tile_center(Vector2i(23, 209))
	p.facing = Vector2.DOWN
	await _settle(30)
	for spec in [["fang-open", 0.02], ["fang-closed", 0.14], ["fang-fade", 0.43]]:
		for f in w.fxs:
			f.queue_free()
		w.fxs.clear()
		var at: Vector2 = p.position + Vector2(0, -p.radius * 0.5)
		var f = w.add_fx("fang", at, {"size": p.radius * 2.2, "lifetime": 0.5})
		f.age = spec[1]
		if spec[0] == "fang-closed":
			for flame in [false, true]:
				var fire = w.add_fx("fangfire", at, {"size": p.radius * 1.6, "lifetime": 0.45, "text": "flame" if flame else ""})
				fire.age = 0.16
		await _shot(spec[0])
	print("fang capture OK")
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])

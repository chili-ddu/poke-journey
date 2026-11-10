extends SceneTree

# 접지·Hop·높이 한 칸·착지 그림자 캡처.
# godot --path . -s tools/view3d_shadow_shot.gd -- <출력디렉터리>
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
	await _shot("grounded")
	p.play_hop()
	for i in 12:
		w.step_visual(DT)
		await process_frame
	print("hop shadow height=", View3D.shadow_height(p))
	await _shot("hop")
	await _settle(50)
	p.lift = Arena.TILE
	await _shot("raised")
	p.lift = 0.0
	await _shot("landed")
	print("shadow capture OK")
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])

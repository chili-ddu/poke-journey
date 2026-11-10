extends SceneTree

# HD-2D 2단계 시제품 캡처(창 필요, View3D 2026-11-02): 태초마을에서 2D 지도 / 3D 로 세운 지도를 같은 자리에서 한 장씩,
# 그리고 3D 에서 몇 걸음 걸은 뒤와 불꽃세례 쏘는 순간. → <출력>/<이름>.png
#   godot --path . -s tools/view3d_shot.gd -- <출력디렉터리>
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
	for v in [false, true]:
		Look.view3d = v
		game._apply_look()
		await _settle(30)
		await _shot("pallet-" + ("3d" if v else "2d"))
	# 3D 에서 위로 걸어 집 앞까지
	c.dir = Vector2.UP
	for i in 50:
		w.step(DT)
		await process_frame
	c.dir = Vector2.ZERO
	await _settle(30)
	await _shot("pallet-3d-walk")
	p.facing = Vector2.UP
	w.cast(p, "ember", Vector2.UP, p.position + Vector2(0, -80))
	print("npcs ", w.npcs.size())
	for i in int(0.22 / DT):
		w.step(DT)
		await process_frame
	await _shot("pallet-3d-ember")
	print("view3d shot OK")
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])

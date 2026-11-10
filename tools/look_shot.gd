extends SceneTree

# 화면 느낌 비교 캡처(창 필요, Look 2026-11-02): 같은 장면을 flat / hd2d 로 한 장씩.
#   1번도로(낮) · 상록숲(그늘) · 상록숲에서 불꽃세례(꼬리불·불꽃 조명) → <출력>/<장면>-<모드>.png
#   godot --path . -s tools/look_shot.gd -- <출력디렉터리>
const DT := 1.0 / 60.0
var out := "."
var game: Node

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 80.0
	func want_skill(_i: int, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	OS.set_environment("BOT", "1"); OS.set_environment("GOD", "1"); OS.set_environment("SEED", "1")
	await CaptureWindow.park(self)
	await _open("kanto_south")
	game.world.player.position = Arena.tile_center(Vector2i(24, 172))
	game.world.player.facing = Vector2.UP
	await _settle(20)
	await _both("route1")
	await _open("viridian_forest")
	await _settle(20)
	await _both("forest")
	# 불꽃세례: 허수아비 캐터피에게 — 날아가는 순간
	var w = game.world
	var p: Player = w.player
	p.facing = Vector2.RIGHT
	var dummy := Enemy.new()
	dummy.setup_enemy("caterpie", 5, w.rng)
	dummy.max_hp = 9999; dummy.hp = 9999
	dummy.facing = Vector2.LEFT
	dummy.frozen = true
	dummy.cds = {"tackle": 999.0, "string_shot": 999.0}
	dummy.position = Arena.resolve(p.position + Vector2(60, 0), dummy.radius)
	w.add_child(dummy)
	w.enemies.append(dummy)
	await _settle(4)
	for mode in ["flat", "hd2d"]:
		Look.mode = mode
		game._apply_look()
		w.cast(p, "ember", Vector2.RIGHT, dummy.position)
		for i in int(0.18 / DT):
			w.step(DT)
			await process_frame
		await _shot("ember-" + mode)
		for i in 60:
			w.step(DT)
			await process_frame
	Look.mode = Look.DEFAULT_MODE
	print("look shot OK")
	quit()

func _open(where: String) -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
		await process_frame
	OS.set_environment("DUNGEON", where)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON", "")
	game.world.player.controller = Still.new()
	game.banner_t = 0.0
	game.stream.clear()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _both(name: String) -> void:
	for mode in ["flat", "hd2d"]:
		Look.mode = mode
		game._apply_look()
		await _settle(3)
		await _shot(name + "-" + mode)

func _shot(name: String) -> void:
	for i in 2:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])

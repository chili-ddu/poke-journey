extends SceneTree

# 3D 화면의 효과 캡처(창 필요, View3D 2026-11-02): 할퀴기 호(바닥 오버레이)·피해 숫자(3D 글자)·불꽃세례 적중·연막 점선 고리.
#   godot --path . -s tools/view3d_fx_shot.gd -- <출력디렉터리>
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
	var dummy := Enemy.new()
	dummy.setup_enemy("rattata", 4, w.rng)
	dummy.max_hp = 9999; dummy.hp = 9999
	dummy.facing = Vector2.LEFT
	dummy.frozen = true
	for k in dummy.cds:
		dummy.cds[k] = 999.0
	w.add_child(dummy)
	w.enemies.append(dummy)
	await _settle(30)
	var plan := [["scratch", 24, 0.2, "fx-scratch"], ["ember", 50, 0.4, "fx-ember"], ["smoke_screen", 64, 0.3, "fx-smoke"]]
	for item in plan:
		p.position = Arena.tile_center(Vector2i(23, 209))
		dummy.position = p.position + Vector2(float(item[1]), 0)
		dummy.knock = Vector2.ZERO; dummy.hitstop_t = 0.0; dummy.flinch_t = 0.0
		var mv: String = item[0]
		w.cast(p, mv, Vector2.RIGHT, dummy.position)
		var m := MoveDB.get_move(mv)
		p.play_attack(String(m.get("anim", "Attack")), 0.0, bool(m.get("lunge", false)))
		var t := 0.0
		while t < float(item[2]):
			w.step(DT)
			t += DT
			await process_frame
		await _shot(item[3])
		for i in 60:
			w.step(DT)
			await process_frame
	print("view3d fx shot OK")
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])

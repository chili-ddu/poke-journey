extends SceneTree

# 할퀴기 커스텀 HD-2D 적중: 네 방향·발톱 자국과 섬광 캡처.
#   godot --path . -s tools/scratch_hd2d_review.gd -- <출력디렉터리>
const DT := 1.0 / 60.0
var out := "."
var game: Node

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
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
	FxStyle.set_mode("custom")
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
	dummy.position = p.position + Vector2(50,0)
	dummy.facing = Vector2.LEFT
	dummy.frozen = true
	for k in dummy.cds:
		dummy.cds[k] = 999.0
	w.add_child(dummy)
	w.enemies.append(dummy)
	await _settle(30)
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		var label := str(int(direction.x))+"_"+str(int(direction.y))
		dummy.position = p.position + direction*30
		p.facing = direction
		p.controller.direction = direction
		p.play_attack("Attack",0.4)
		await _settle(4)
		w.cast(p,"fire_fang",direction,dummy.position)
		for frame in 60:
			w.step(DT)
			await process_frame
			if frame in [0,6,8,10,12,16,20,22,24,26,28,30,36]: await _shot(label+"_"+str(frame))
		for i in 40:
			w.step(DT)
			await process_frame
	print("fire fang HD-2D review OK")
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])

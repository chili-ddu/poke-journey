extends SceneTree

# 구멍파기 연출 캡처(창 필요): 가라앉기 / 땅속(그림자·흙) / 솟구침 / 후딜 — 시험용 풀밭에서 파이리가 허수아비 캐터피에게.
#   godot --path . -s tools/dig_shot.gd -- <출력디렉터리>
const DT := 1.0 / 60.0
var out := "."

class NullController:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 80.0
	func want_skill(_i: int, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false
func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	OS.set_environment("BOT", "1"); OS.set_environment("GOD", "1"); OS.set_environment("SEED", "1"); OS.set_environment("DUNGEON", "test_meadow")
	await CaptureWindow.park(self)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.bot = false
	game.hud.visible = false
	for i in 3:
		await process_frame
	var w = game.world
	var p: Player = w.player
	p.controller = NullController.new()
	game.stream.clear()
	game.banner_t = 0.0
	p.position = Vector2(300, 190)
	p.facing = Vector2.RIGHT
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	w.add_child(cam)
	cam.make_current()
	cam.position = p.position.round()
	var dummy := Enemy.new()
	dummy.setup_enemy("caterpie", 5, w.rng)
	dummy.max_hp = 9999; dummy.hp = 9999
	dummy.position = p.position + Vector2(26, 0)
	dummy.facing = Vector2.LEFT
	dummy.frozen = true
	dummy.cds = {"tackle": 999.0, "string_shot": 999.0}
	w.add_child(dummy)
	w.enemies.append(dummy)
	for i in 6:
		await process_frame         # 카메라가 자리 잡게
	w.cast(p, "dig", Vector2.RIGHT, dummy.position)
	p.play_attack("Rotate", 0.25)
	var shots := {0.12: "dig-1-sink", 1.0: "dig-2-under", 2.3: "dig-3-emerge", 2.7: "dig-4-recover"}
	var t := 0.0
	var done := {}
	while t < 3.2:
		w.step(DT)
		t += DT
		for k in shots:
			if t >= float(k) and not done.has(k):
				done[k] = true
				for i in 2:
					await process_frame
				root.get_texture().get_image().save_png("%s/%s.png" % [out, shots[k]])
		await process_frame
	quit()

extends SceneTree

# 기술 연출 원작/커스텀 비교 캡처(창 필요, FxStyle 2026-11-02). MoveShapes.CUSTOM_FX 의 기술을 두 모드로 한 번씩 써서
# 같은 시각의 장면을 나란히 저장한다: <출력>/<기술>-<모드>-<n>.png
#   godot --path . -s tools/fx_compare_shot.gd -- <출력디렉터리>
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

# [기술, 상대 거리(px, 0 이면 헛손질·사거리 끝까지), 조준 거리(px), 찍을 시각들]
const PLAN := [
	["scratch", 24, 24, [0.16, 0.24]],
	["scratch", 0, 30, [0.16]],
	["ember", 52, 52, [0.3, 0.4, 0.5]],
	["ember", 0, 90, [0.6]],
	["smoke_screen", 70, 70, [0.4, 0.62, 0.9]],
]

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
	var home := Vector2(300, 190)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	w.add_child(cam)
	cam.make_current()
	cam.position = (home + Vector2(30, -6)).round()
	w.hold_cam = true
	var dummy := Enemy.new()
	dummy.setup_enemy("caterpie", 5, w.rng)
	dummy.max_hp = 9999; dummy.hp = 9999
	dummy.facing = Vector2.LEFT
	dummy.frozen = true
	dummy.cds = {"tackle": 999.0, "string_shot": 999.0}
	w.add_child(dummy)
	w.enemies.append(dummy)
	for i in 6:
		await process_frame
	var n := 0
	for item in PLAN:
		n += 1
		for mode in ["original", "custom"]:
			FxStyle.set_mode(mode)
			for f in w.fxs:
				f.queue_free()
			w.fxs.clear()
			p.position = home
			p.facing = Vector2.RIGHT
			p.knock = Vector2.ZERO; p.hitstop_t = 0.0; p.recover_t = 0.0; p.attack_anim_t = 0.0; p.acc_stage = 0
			var near := float(item[1]) > 0.0
			dummy.position = home + Vector2(float(item[1]) if near else 400.0, 0)
			dummy.knock = Vector2.ZERO; dummy.hitstop_t = 0.0; dummy.flinch_t = 0.0; dummy.hurt_t = 0.0; dummy.acc_stage = 0
			var aim := home + Vector2(float(item[2]), 0)
			var mv: String = item[0]
			var m := MoveDB.get_move(mv)
			var charge := float(m.get("cast_delay", 0.0))
			if charge > 0.0:
				w.pending_casts.append({"mon": p, "move": mv, "t": charge})
				p.play_attack(String(m.get("anim", "Charge")), charge + 0.05)
				w.aim_point = aim
			else:
				w.cast(p, mv, Vector2.RIGHT, aim)
				p.play_attack(String(m.get("anim", "Attack")), 0.0, bool(m.get("lunge", false)))
			var times: Array = item[3]
			var t := 0.0
			var k := 0
			while k < times.size() and t < 2.0:
				w.aim_point = aim
				w.step(DT)
				t += DT
				if t >= float(times[k]):
					for i in 2:
						await process_frame
					root.get_texture().get_image().save_png("%s/%02d-%s-%s-%d.png" % [out, n, mv, mode, k])
					k += 1
				await process_frame
			for i in 40:
				w.step(DT)
				await process_frame
	FxStyle.set_mode(FxStyle.DEFAULT_MODE)
	print("fx compare OK")
	quit()

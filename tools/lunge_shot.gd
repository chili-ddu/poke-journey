extends SceneTree

# 근접기 달려들기 캡처(창 필요): 할퀴기(Strike)·몸통박치기(Attack)를 쓰는 동안 / 멈춘 자세 / 끝난 뒤 — 도트 반 재생과 자리 옮김 확인.
#   godot --path . -s tools/lunge_shot.gd -- <출력디렉터리>

const DT := 1.0 / 60.0

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 40.0
	func want_skill(_i: int, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	OS.set_environment("BOT", "1"); OS.set_environment("GOD", "1"); OS.set_environment("SEED", "1"); OS.set_environment("DUNGEON", "test_meadow")
	await CaptureWindow.park(self)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); current_scene = game; game.set_process(false); game.bot = false
	game.hud.visible = false
	for i in 3:
		await process_frame
	var w = game.world
	var p: Player = w.player
	p.controller = Still.new()
	game.stream.clear(); game.banner_t = 0.0
	p.position = Vector2(300, 190); p.facing = Vector2.RIGHT
	var cam := Camera2D.new(); cam.zoom = Vector2(3, 3); w.add_child(cam); cam.make_current(); cam.position = p.position.round()
	for i in 6:
		await process_frame
	for mv in ["scratch", "tackle"]:
		var x0 := p.position.x
		var an: Dictionary = p._sprites[MoveDB.get_move(mv)["anim"]]
		var row := MonSprite.row_for(an, p.facing)
		var mid := MonSprite.lunge_mid(an, row)
		print("%s: 가장 앞 프레임 %d/%d, 옮김 %s" % [mv, mid, an["durations"].size(), MonSprite.lunge_offset(an, row, mid) * p.sprite_scale])
		p.position = Vector2(300, 190)
		w.cast(p, mv, Vector2.RIGHT, p.position + Vector2(40, 0))
		p.play_attack(String(MoveDB.get_move(mv).get("anim", "Attack")), 0.0, true)
		var t := 0.0
		var shots := {0.08: "%s-1" % mv, 0.3: "%s-2-hold" % mv, 0.7: "%s-3-after" % mv}
		var done := {}
		while t < 0.8:
			w.step(DT); t += DT
			for k in shots:
				if t >= float(k) and not done.has(k):
					done[k] = true
					for i in 2:
						await process_frame
					root.get_texture().get_image().save_png("%s/%s.png" % [out, shots[k]])
			await process_frame
		print("%s: 자리 %.1f → %.1f" % [mv, x0, p.position.x])
	quit()

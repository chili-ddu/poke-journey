extends SceneTree

# 최신 습득표로 들어온 기술 연출 캡처(창 필요, 2026-11-02 A안): 용의숨결·전기자석파·구르기·땅고르기·록커트·벌레먹음·돌떨구기.
# 시험용 풀밭에서 파이리가 허수아비 캐터피에게. 플래티넘 파티클 텍스처(tools/plat_fx.py)를 쓴 모양이 맞는지 눈으로 본다.
#   godot --path . -s tools/latest_shot.gd -- <출력디렉터리>
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
	var home := Vector2(300, 190)
	p.position = home
	p.facing = Vector2.RIGHT
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	w.add_child(cam)
	cam.make_current()
	cam.position = home.round()
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
	# [기술, 상대 거리(px), {시각: 파일 이름}]
	var plan := [
		["dragon_breath", 48, {0.22: "breath-1-fly", 0.42: "breath-2-hit"}],
		["thunder_wave", 40, {0.3: "twave-1-ring", 0.55: "twave-2-bolts"}],
		["rollout", 44, {0.12: "rollout-1-dash", 0.3: "rollout-2-hit"}],
		["bulldoze", 26, {0.1: "bulldoze-1-stomp", 0.3: "bulldoze-2-hit"}],
		["rock_polish", 60, {0.2: "polish-1"}],
		["bug_bite", 24, {0.22: "bugbite-1"}],
		["rock_throw", 56, {0.2: "rock-1-fly", 0.45: "rock-2-hit"}],
	]
	for item in plan:
		var mv: String = item[0]
		p.position = home
		p.facing = Vector2.RIGHT
		p.knock = Vector2.ZERO; p.hitstop_t = 0.0; p.recover_t = 0.0; p.attack_anim_t = 0.0; p.dash = {}
		dummy.position = home + Vector2(float(item[1]), 0)
		dummy.knock = Vector2.ZERO; dummy.hitstop_t = 0.0; dummy.flinch_t = 0.0; dummy.slow_t = 0.0; dummy.hurt_t = 0.0; dummy.spe_stage = 0
		w.cast(p, mv, Vector2.RIGHT, dummy.position)
		var shots: Dictionary = item[2]
		var t := 0.0
		var done := {}
		while t < 1.2:
			w.step(DT)
			t += DT
			for k in shots:
				if t >= float(k) and not done.has(k):
					done[k] = true
					for i in 2:
						await process_frame
					root.get_texture().get_image().save_png("%s/%s.png" % [out, shots[k]])
			await process_frame
		print("%s: 상대 HP %d, slow %.1f, spe %d, 내 spe %d" % [mv, dummy.hp, dummy.slow_t, dummy.spe_stage, p.spe_stage])
	quit()

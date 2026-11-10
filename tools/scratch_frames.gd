extends SceneTree

# 할퀴기 동작 프레임 캡처(창 필요): 시험 풀밭에서 파이리가 허수아비에게 할퀴기 — 2프레임마다 한 장, 자리·동작·프레임 정보 출력.
#   godot --path . -s tools/scratch_frames.gd -- <출력디렉터리> [move]
const DT := 1.0 / 60.0

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 80.0
	func want_skill(_i: int, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var mv: String = args[1] if args.size() > 1 else "scratch"
	OS.set_environment("BOT", "1"); OS.set_environment("GOD", "1"); OS.set_environment("SEED", "1"); OS.set_environment("DUNGEON", "test_meadow")
	await CaptureWindow.park(self)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.hud.visible = false
	for i in 3:
		await process_frame
	var w = game.world
	var p: Player = w.player
	p.controller = Still.new()
	game.stream.clear()
	game.banner_t = 0.0
	p.position = Vector2(300, 190)
	p.facing = Vector2.RIGHT
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	w.add_child(cam)
	cam.make_current()
	cam.position = Vector2(320, 185)
	w.hold_cam = true
	var dummy := Enemy.new()
	dummy.setup_enemy("rattata", 5, w.rng)
	dummy.max_hp = 9999; dummy.hp = 9999
	dummy.facing = Vector2.LEFT
	dummy.frozen = true
	for k in dummy.cds:
		dummy.cds[k] = 999.0
	dummy.position = p.position + Vector2(36, 0)
	w.add_child(dummy)
	w.enemies.append(dummy)
	for i in 10:
		w.step(DT)
		await process_frame
	var x0 := p.position.x
	var m := MoveDB.get_move(mv)
	w.cast(p, mv, Vector2.RIGHT, dummy.position)
	p.play_attack(String(m.get("anim", "Attack")), 0.0, bool(m.get("lunge", false)))
	if m["shape"] == "arc":
		p.recover_t = maxf(p.recover_t, p.attack_anim_t)
		p.vel = Vector2.ZERO
	for f in 40:
		w.step(DT)
		await process_frame
		if f % 2 == 0:
			await process_frame
			root.get_texture().get_image().save_png("%s/f%02d.png" % [out, f])
			print("f%02d t=%.3f x+%.1f anim=%s frame_t=%.3f anim_t_left=%.3f glide=%s hitstop=%.2f lunge_shift=%s" % [f, f * DT, p.position.x - x0, p._anim_name,
				p.anim_t - p._anim_start, p.attack_anim_t, str(p.glide.get("left", 0.0)), p.hitstop_t, str(p._lunge_shift())])
	quit()

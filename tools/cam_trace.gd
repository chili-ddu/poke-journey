extends SceneTree

# 공격 중 3D 카메라 경로 기록(헤드리스): 1번도로에서 파이리가 꼬렛에게 할퀴기·몸통박치기 —
# 프레임마다 몸 자리·cam_anchor·옛 방식(position 을 프레임마다 0.15 로 따라감)을 x(px)로 출력(헤드리스라 3D 카메라는 nan — 창 캡처는 tackle_shots.gd). 기본 시험 풀밭(WHERE=장소).
#   godot --headless --path . -s tools/cam_trace.gd -- [move]
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
	var mv: String = args[0] if args.size() > 0 else "scratch"
	OS.set_environment("BOT", "1"); OS.set_environment("GOD", "1"); OS.set_environment("SEED", "1"); OS.set_environment("DUNGEON", OS.get_environment("WHERE") if OS.get_environment("WHERE") != "" else "test_meadow")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	for i in 3:
		await process_frame
	var w = game.world
	var p: Player = w.player
	p.controller = Still.new()
	game.stream.clear()
	game.banner_t = 0.0
	p.position = Arena.tile_center(Vector2i(16, 209)) if Arena.has_map() else Vector2(300, 190)
	p.facing = Vector2.RIGHT
	var dummy := Enemy.new()
	dummy.setup_enemy("rattata", 5, w.rng)
	dummy.max_hp = 9999; dummy.hp = 9999
	dummy.frozen = true
	for k in dummy.cds:
		dummy.cds[k] = 999.0
	dummy.position = p.position + Vector2(36, 0)
	w.add_child(dummy)
	w.enemies.append(dummy)
	var v3 = game.view3d
	for i in 20:
		w.step(DT)
		await process_frame
	var x0 := p.position.x
	var old := p.position.x
	var m := MoveDB.get_move(mv)
	w.cast(p, mv, Vector2.RIGHT, dummy.position)
	p.play_attack(String(m.get("anim", "Attack")), 0.0, bool(m.get("lunge", false)))
	if m["shape"] == "arc":
		p.recover_t = maxf(p.recover_t, p.attack_anim_t)
		p.vel = Vector2.ZERO
	for f in 60:
		w.step(DT)
		await process_frame
		old = lerpf(old, p.position.x, 0.15)
		var cur: float = (v3._cam_target.x * Arena.TILE) if v3 != null else NAN
		print("f%02d pos=%6.2f anchor=%6.2f cam=%6.2f old=%6.2f glide=%s vel=%s knock=%s hs=%.2f anim=%s t=%.2f" % [f, p.position.x - x0, p.cam_anchor().x - x0, cur - x0, old - x0,
			str(p.glide), str(p.vel), str(p.knock), p.hitstop_t, p._anim_name, p.attack_anim_t])
	quit()

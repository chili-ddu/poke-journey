extends SceneTree

# 적이 내 포켓몬에게 몸통박치기할 때 둘의 자리 기록(헤드리스, 시험 풀밭) — 적이 '제자리로 돌아가는지' 확인용.
#   godot --headless --path . -s tools/enemy_tackle_trace.gd -- [종] [기술]
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
	var sp: String = args[0] if args.size() > 0 else "rattata"
	var mv: String = args[1] if args.size() > 1 else "tackle"
	OS.set_environment("BOT", "1"); OS.set_environment("SEED", "1"); OS.set_environment("DUNGEON", "test_meadow")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	for i in 3:
		await process_frame
	var w = game.world
	var p: Player = w.player
	p.controller = Still.new()
	p.max_hp = 9999; p.hp = 9999
	game.stream.clear()
	game.banner_t = 0.0
	p.position = Vector2(300, 200)
	var e := Enemy.new()
	e.setup_enemy(sp, 5, w.rng)
	e.position = p.position + Vector2(-30, 0)
	e.facing = Vector2.RIGHT
	w.add_child(e)
	w.enemies.append(e)
	for k in e.cds:
		e.cds[k] = 999.0
	e.cds[mv] = 0.0
	var e0 := e.position
	for f in 90:
		w.step(DT)
		await process_frame
		if f % 2 == 0:
			print("f%02d enemy=%6.1f anchor=%6.1f player=%6.1f anim=%s t=%.2f glide=%s knock=%s vel=%s" % [f, e.position.x - e0.x, e.cam_anchor().x - e0.x, p.position.x - e0.x,
				e._anim_name, e.attack_anim_t, str(e.glide.get("left", "-")), str(e.knock), str(e.vel)])
	quit()

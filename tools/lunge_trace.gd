extends SceneTree

# 몸통박치기 같은 근접기를 종마다 써 보고(헤드리스, 시험 풀밭) 얼마나 나아갔다가 어디서 멈추는지 기록한다.
#   godot --headless --path . -s tools/lunge_trace.gd -- [move] [종,종,…]
# 출력: 종 · 방향 · 최대 전진(몸 그림 기준, px) · 끝난 뒤 자리 이동(px) · 미끄러진 거리 · 도트의 lunge_mid/프레임 수
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
	var mv: String = args[0] if args.size() > 0 else "tackle"
	var list: Array = (args[1] if args.size() > 1 else "charmander,bulbasaur,squirtle,rattata,pidgey,caterpie,weedle,pikachu,geodude,onix").split(",")
	OS.set_environment("BOT", "1"); OS.set_environment("GOD", "1"); OS.set_environment("SEED", "1"); OS.set_environment("DUNGEON", "test_meadow")
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
	p.position = Vector2(80, 80)
	for sp in list:
		for dir in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			var a := Enemy.new()
			a.setup_enemy(sp, 10, w.rng)
			a.frozen = true
			for k in a.cds:
				a.cds[k] = 999.0
			a.position = Vector2(300, 200)
			a.facing = dir
			w.add_child(a)
			w.enemies.append(a)
			for i in 3:
				w.step(DT)
			var start := a.position
			var m := MoveDB.get_move(mv)
			w.cast(a, mv, dir, a.position + dir * 100.0)
			a.play_attack(String(m.get("anim", "Attack")), 0.0, bool(m.get("lunge", false)))
			var best := 0.0
			var glided := 0.0
			var anim := a.attack_anim
			for f in 90:
				var before := a.position
				w.step(DT)
				best = maxf(best, (a.cam_anchor() - start).dot(dir))
				if not a.glide.is_empty() or f < 2:
					glided = (a.position - start).dot(dir)
			var end := (a.position - start).dot(dir)
			var an: Dictionary = a._sprites.get(anim, {})
			var row := MonSprite.row_for(an, dir) if not an.is_empty() else 0
			print("%-10s %-6s anim=%-7s max=%5.1f end=%5.1f glide=%5.1f lunge_mid=%d" % [sp, str(dir), anim, best, end, glided,
				MonSprite.lunge_mid(an, row) if not an.is_empty() else -1])
			w.enemies.erase(a)
			a.queue_free()
			await process_frame
	quit()

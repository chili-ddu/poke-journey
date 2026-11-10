extends SceneTree

# 몸통박치기 3D 화면 연속 캡처(창 필요): 1번도로 빈터에서 ATTACKER=enemy(기본)면 적(SPECIES, 기본 꼬렛)이 내 포켓몬을,
# ATTACKER=player 면 내 포켓몬이 적을 친다. 2프레임마다 한 장 + 자리 출력. → <출력>/fNN.png
#   godot --path . -s tools/tackle_shots.gd -- <출력디렉터리> [기술]
const DT := 1.0 / 60.0

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.LEFT * 80.0
	func want_skill(_i: int, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var mv: String = args[1] if args.size() > 1 else "tackle"
	var sp := OS.get_environment("SPECIES") if OS.get_environment("SPECIES") != "" else "rattata"
	var enemy_attacks := OS.get_environment("ATTACKER") != "player"
	OS.set_environment("BOT", "1"); OS.set_environment("SEED", "1"); OS.set_environment("DUNGEON", "kanto_south")
	await CaptureWindow.park(self)
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
	p.position = Arena.tile_center(Vector2i(24, 182))
	p.facing = Vector2.LEFT
	var e := Enemy.new()
	e.setup_enemy(sp, 5, w.rng)
	e.max_hp = 9999; e.hp = 9999
	if OS.get_environment("KILL") != "":          # 쓰러뜨리는 타(쓰러짐 동작 확인)
		e.hp = 1
	e.position = p.position + Vector2(-34, 0)
	e.facing = Vector2.RIGHT
	w.add_child(e)
	w.enemies.append(e)
	for k in e.cds:
		e.cds[k] = 999.0
	for i in 30:
		w.step(DT)
		await process_frame
	var e0 := e.position
	var p0 := p.position
	if enemy_attacks:
		e.cds[mv] = 0.0
		e.frozen = false
	else:
		e.frozen = true
		var m := MoveDB.get_move(mv)
		w.cast(p, mv, Vector2.LEFT, e.position)
		p.play_attack(String(m.get("anim", "Attack")), 0.0, bool(m.get("lunge", false)))
		p.recover_t = maxf(p.recover_t, p.attack_anim_t)
	var frames := 110 if OS.get_environment("KILL") != "" else 50
	for f in frames:
		w.step(DT)
		await process_frame
		if f % (6 if frames > 50 else 2) == 0:
			root.get_texture().get_image().save_png("%s/f%02d.png" % [out, f])
			var camx: float = game.view3d._cam_target.x * Arena.TILE - p0.x if game.view3d != null else NAN
			print("f%02d enemy=%6.1f(anchor %6.1f) player=%6.1f(anchor %6.1f) cam3d=%6.1f e_anim=%s p_anim=%s" % [f, e.position.x - e0.x, e.cam_anchor().x - e0.x,
				p.position.x - p0.x, p.cam_anchor().x - p0.x, camx, e._anim_name, p._anim_name])
	quit()

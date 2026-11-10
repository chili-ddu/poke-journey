extends SceneTree

# 봇이 한 판을 끝까지 돌려 보는 스모크 테스트. 실시간을 기다리지 않고 고정 dt 로 pump 한다.
# 웨이브 진행·레벨업·진화·보스 처치·게임오버가 오류 없이 흘러가는지 본다(밸런스 확인용 수치도 찍음).
#
#   godot --headless --path . -s tools/smoke.gd -- <시드> <최대 초>
#   GOD=1 을 주면 플레이어가 죽지 않아 10웨이브·진화까지 흐름을 끝까지 밟는다.

const DT := 1.0 / 60.0

func _init() -> void:
	var argv := OS.get_cmdline_user_args()
	var seed_value: int = int(argv[0]) if argv.size() > 0 else 1
	var max_sec: float = float(argv[1]) if argv.size() > 1 else 900.0
	OS.set_environment("BOT", "1")
	OS.set_environment("SEED", str(seed_value))
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame

	var t := 0.0
	var last_level := -1
	var last_state := ""
	var last_species := ""
	while t < max_sec:
		game.advance(DT)
		t += DT
		var p: Player = game.world.player
		if p.level != last_level:
			last_level = p.level
			print("%6.1fs  Lv.%d %s HP %d/%d  쓰러뜨림 %d/%d  기술 %s" % [t, p.level, p.display_name(), p.hp, p.max_hp, game.defeated, game.total_enemies, str(p.known_moves())])
		if p.species_id != last_species:
			if last_species != "":
				print("%6.1fs  진화 → %s (Lv.%d)" % [t, p.display_name(), p.level])
			last_species = p.species_id
		if game.state != last_state:
			last_state = game.state
			if last_state in ["gameover", "victory"]:
				break
		# 프레임마다 queue_free 된 노드를 실제로 치우게 한 번씩 넘긴다.
		if int(t / DT) % 30 == 0:
			await process_frame
	var p: Player = game.world.player
	print("결과 %s  %.1fs  쓰러뜨림 %d/%d  Lv.%d %s  HP %d/%d  기술 %s" % [
		game.state, t, game.defeated, game.total_enemies, p.level, p.display_name(), p.hp, p.max_hp,
		str(p.slots)])
	quit()

extends SceneTree

# 봇 플레이 화면을 몇 개 시점에서 PNG 로 뽑는다. 육안 검증용.
# 뷰포트 텍스처를 읽으려면 실제 렌더 패스가 필요해서 헤드리스로는 못 돈다(창이 잠깐 뜬다).
#
#   godot --path . -s tools/screenshot.gd -- <출력디렉터리> <시드> <초1> <초2> ...
#   GOD=1 을 같이 주면 뒤쪽 웨이브(진화 후)도 찍을 수 있다.
#   SHINY=1 이면 새로 뽑는 개체(내 포켓몬·야생)가 모두 이로치(Individual.force_shiny).
#   LEVELUP=1 을 주면 마지막 시각 뒤 첫 레벨업 창을 열어 둔 채로 한 장 더 찍는다.

const DT := 1.0 / 60.0

func _init() -> void:
	var argv := OS.get_cmdline_user_args()
	var out_dir: String = argv[0] if argv.size() > 0 else "."
	OS.set_environment("BOT", "1")
	OS.set_environment("SEED", argv[1] if argv.size() > 1 else "1")
	var marks: Array = []
	for i in range(2, argv.size()):
		marks.append(float(argv[i]))
	if marks.is_empty():
		marks = [5.0, 30.0, 70.0]
	# 창이 작게 뜨면 정수 배율 때문에 1배(640×360)로 그려진다. 항상 2배로 찍는다.
	await _windowed()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	# START_TILE=x,y[,dy] 를 주면 플레이어를 그 칸(+세로 dy px)에 놓고 찍는다(바깥 세계의 특정 자리). 봇은 멈춰 세운다.
	var st := OS.get_environment("START_TILE")
	if st != "":
		var xy := st.split(",")
		game.world.player.position = Arena.tile_center(Vector2i(int(xy[0]), int(xy[1]))) + Vector2(0, float(xy[2]) if xy.size() > 2 else 0.0)
		var ctl := StandStill.new()
		# WALK=dx,dy 를 같이 주면 그 방향으로 계속 걷는다(풀숲에 들어서는 순간 찍기 등).
		if OS.get_environment("WALK") != "":
			var wv := OS.get_environment("WALK").split(",")
			ctl.walk = Vector2(float(wv[0]), float(wv[1])).normalized()
		game.world.player.controller = ctl
	# BERRIES=n 시작 열매 수, HP=n 시작 HP(봇은 절반 아래면 열매를 먹는다 — 먹는 동작 찍기).
	if OS.get_environment("BERRIES") != "":
		game.world.player.berries = int(OS.get_environment("BERRIES"))
	if OS.get_environment("HP") != "":
		game.world.player.hp = int(OS.get_environment("HP"))
	# BAG=id:n,id:n 가방 내용. OPEN=talk|bag|menu 를 주면 첫 프레임 뒤 말 걸기(카운터 앞 사람)·가방 창·Esc 게임 메뉴를 연 채 찍는다.
	if OS.get_environment("BAG") != "":
		for kv in OS.get_environment("BAG").split(","):
			var pr := kv.split(":")
			game.world.player.add_item(pr[0], int(pr[1]))
	# LEARN=id,id 배운 기술 목록에 더한다(상태창 기술 쪽 찍기). SUM_PICK=n 그 줄을 집은 상태로.
	if OS.get_environment("LEARN") != "":
		for mid in OS.get_environment("LEARN").split(","):
			game.world.player.add_learned(mid)
	for i in 5:
		await process_frame
	match OS.get_environment("OPEN"):
		"talk":
			var n = game.npc_in_reach()
			if n != null:
				game._talk(n)
		"bag":
			game._open_bag()
		"menu":
			game._open_game_menu()
		"summary":
			# SUM_PAGE=0~2 쪽, SUM_MOVE=0~3 기술 쪽에서 고른 칸.
			game._menu_open("summary")
			game.summary_screen.open(game.world.player)
			game.summary_screen.page = int(OS.get_environment("SUM_PAGE")) if OS.get_environment("SUM_PAGE") != "" else 0
			if OS.get_environment("SUM_MOVE") != "":
				game.summary_screen.move_cursor = int(OS.get_environment("SUM_MOVE"))
			if OS.get_environment("SUM_PICK") != "":
				game.summary_screen.swap_from = int(OS.get_environment("SUM_PICK"))
	var t := 0.0
	for m in marks:
		while t < float(m) and not game.state in ["gameover", "victory"]:
			game.advance(DT)
			t += DT
			if int(t / DT) % 20 == 0:
				await process_frame
		await process_frame
		await process_frame
		_save(("%s/ms%05d.png" % [out_dir, int(round(t * 1000.0))]) if OS.get_environment("SHOT_MS") == "1" else ("%s/t%03d.png" % [out_dir, int(round(t))]), game, t)   # SHOT_MS=1: 밀리초 이름(1초 안에 여러 장)
	# WAIT=stat  능력치 창이 뜬 순간 / WAIT=say  대화창에 말이 뜬 순간 순간을 한 장 더 찍는다.
	var wait_for := OS.get_environment("WAIT")
	if wait_for != "":
		var guard := 0
		while guard < 60 * 300 and not game.state in ["gameover", "victory"]:
			game.advance(DT)
			t += DT
			guard += 1
			if wait_for == "stat" and not game.stat_box.is_empty() and game.stat_t < game.STAT_PHASE * 2.0 - 0.3:
				break
			# WAIT=spark  이로치 반짝임이 시작되고 SPARK_AT 초(기본 0.3) 지난 순간
			if wait_for == "spark":
				var at := float(OS.get_environment("SPARK_AT")) if OS.get_environment("SPARK_AT") != "" else 0.3
				var hit := false
				for f in game.world.fxs:
					if f.kind == "spark" and f.delay == 0.0 and f.age >= at:
						hit = true
				if hit:
					break
			if wait_for == "say" and game.dialog_text != "" and game.state != "evolve":
				break
			# 졸개가 웅크리고 있는 순간(돌진 예고선이 보임)
			# WAIT=ember  불꽃세례가 날아가는 순간(쏜 뒤 0.12초)
			if wait_for == "ember":
				var fly := false
				for pr in game.world.projectiles:
					if pr.style == "ember" and pr.age >= 0.12:
						fly = true
				if fly:
					break
			if wait_for == "windup":
				var found := false
				for e in game.world.alive_enemies():
					if e.windup_t > 0.25 and e.windup_move == "tackle":
						found = true
				if found:
					break
		await process_frame
		await process_frame
		_save("%s/wait_%s.png" % [out_dir, wait_for], game, t)
	if OS.get_environment("LEVELUP") == "1":
		# 봇이 자동으로 고르지 않게 잠깐 끄고 레벨업 창이 열릴 때까지 돌린다.
		game.bot = false
		var guard := 0
		while game.state != "choose" and guard < 60 * 120:
			game.advance(DT)
			guard += 1
		await process_frame
		await process_frame
		_save("%s/levelup.png" % out_dir, game, t)
	quit()

func _save(path: String, game: Node, t: float) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("%s  t=%.1f  state=%s  defeated=%d/%d" % [path, t, game.state, game.defeated, game.total_enemies])

# 캡처 창: 구석에 밀어 둔 포커스 없는 창, 384×216 × 4 (tools/capture.gd).
func _windowed() -> void:
	await CaptureWindow.park(self)


# START_TILE 로 세운 플레이어는 움직이지 않는다(정해진 자리 그대로 찍으려고).
class StandStill:
	extends RefCounted
	var walk := Vector2.ZERO
	func move_dir(_w) -> Vector2: return walk
	func aim_point(w) -> Vector2: return w.player.position + Vector2.DOWN * 40.0
	func want_dodge(_w) -> bool: return false
	func want_skill(_i, _w) -> bool: return false
	func want_item(w) -> bool: return w.player.hp_ratio() < 0.5   # HP= 로 낮춰 두면 서서 먹는 동작을 찍는다

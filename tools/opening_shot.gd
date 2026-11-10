extends SceneTree

# 새 게임 시작 이야기 확인·캡처(사용자 결정 2026-10-29): 검은 화면 독백 → 볼에 다가간 연구소 + 해설 → 흔들림마다 줌인 → 탈출(줌아웃,
# 오박사 "!") → 오박사 대사 → 출구로 도망(오박사가 쫓음) → 태초마을 연구소 문 앞에서 오박사 대사 → 조작 시작.
#   godot --path . -s tools/opening_shot.gd -- <출력디렉터리>      (창 — 장면마다 찍음)
#   godot --headless --path . -s tools/opening_shot.gd             (흐름만 확인)
#   STARTER=bulbasaur|squirtle|charmander(기본 파이리), LANG_CODE=ko
# BOT=1(저장 안 함, 대사는 0.4초마다 저절로 넘어감 — 찍을 땐 멈춰 둔다), OPENING=1(봇도 시작 연출).

const DT := 1.0 / 60.0
var game: Node
var out := "."
var headless := false

func _init() -> void:
	var argv := OS.get_cmdline_user_args()
	out = argv[0] if argv.size() > 0 else "."
	headless = DisplayServer.get_name() == "headless"
	OS.set_environment("BOT", "1")
	OS.set_environment("OPENING", "1")
	OS.set_environment("DUNGEON", "oaks_lab")
	if headless:
		await process_frame           # 루트가 트리에 들어간 뒤에 장면을 붙여야 _ready 가 바로 돈다(set_process(false) 가 먹힘)
	else:
		await CaptureWindow.park(self)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON", "")
	assert(game.state == "talk" and game.monologue, "새 게임은 검은 화면 독백부터(%s)" % game.state)
	assert(game.world.player.appear == 0.0, "볼에서 나오기 전엔 안 보인다")
	assert(game.world.cam.zoom == Vector2(2, 2), "볼에 2배로 다가가 있다")
	# 1) 독백
	await _hold_shot("story-1-monologue")
	await _pump_until(func(): return not game.monologue, 5.0)
	# 2) 밝아짐 + 해설
	await _pump(0.6, true)
	await _hold_shot("story-2-lab")
	await _pump_until(func(): return String(game.opening.get("phase", "")) == "wobble", 5.0)
	# 3) 흔들림(세 번째, 가장 다가간 때)
	var open_at: float = game._opening_open_at()
	await _pump_until(func(): return float(game.opening.get("t", 0.0)) >= open_at - float(game.WOBBLE_TIMES[2]) * 0.6, 5.0)
	await _shot("story-3-wobble")
	print("  흔들림 배율 %s" % str(game.world.cam.zoom))
	assert(game.world.cam.zoom.x >= 4.5, "흔들릴수록 다가간다")
	# 4) 탈출: 뛰어오르는 순간(빛과 함께 줌아웃 중, 오박사 "!")
	await _pump_until(func(): return float(game.opening.get("t", 0.0)) >= open_at + game.ESCAPE_JUMP * 0.45, 5.0)
	await _shot("story-4-escape")
	var oak: Npc = game._npc("prof_oak")
	assert(oak != null and oak.face == "right" and oak.emote_t > 0.0, "오박사가 놀라 볼 쪽을 돌아본다")
	# 5) 오박사 첫 마디
	await _pump_until(func(): return game.state == "talk", 5.0)
	assert(game.world.cam.zoom == Vector2(1, 1), "탈출하면 1배로 빠진다")
	await _hold_shot("story-5-oak")
	# 6) 도망 + 오박사 추격
	await _pump_until(func(): return String(game.opening.get("phase", "")) == "run" and bool(game.opening.get("called", false)), 5.0)
	# "!" 뒤에 큰 대화창으로 소리친다(사용자 결정 2026-10-30) — 그동안 내 포켓몬은 멈춰 돌아본다.
	await _pump_until(func(): return game.state == "talk" and String(game.dialog_text) == Lang.t("oak_wait"), 3.0)
	assert(game.state == "talk" and game.world.player.vel == Vector2.ZERO, "기다리거라! 는 대화창, 포켓몬은 멈춘다")
	await _hold_shot("story-6-wait")
	await _pump_until(func(): return game.state == "opening", 3.0)
	await _pump(0.5, false)
	await _shot("story-6-run")
	await _pump_until(func(): return game.state == "warp", 8.0)
	assert(Arena.tile_of(game.world.player.position) == game.LAB_EXIT, "출구로 달아났다")
	# 7) 연구소 문 앞
	await _follow()
	assert(DungeonDB.current == "kanto_south" and game.state == "opening", "태초마을 연구소 문 앞 장면(%s %s)" % [DungeonDB.current, game.state])
	await _pump_until(func(): return game.state == "talk", 5.0)
	await _pump_until(func(): return String(game.dialog_text) == Lang.t("oak_eyes").split("|")[0], 5.0)
	await _hold_shot("story-7-door")
	await _pump_until(func(): return game.state in ["fight", "town"], 10.0)
	var pt := Arena.tile_of(game.world.player.position)
	print("시작 자리 %s %s, 상태 %s, 배너 %s" % [DungeonDB.current, pt, game.state, game.banner_text])
	assert(game.state == "fight" and game._npc("prof_oak_out") == null, "오박사는 연구소로 돌아가고 조작 시작")
	assert(game.world.player.facing == Vector2.DOWN, "정면을 보며 시작")
	await _shot("story-8-start")
	assert(game.world.player.berries == 3, "오박사에게서 오랭열매 3개(%d)" % game.world.player.berries)
	print("opening OK")
	quit()

# 대사가 저절로 넘어가지 않게 멈춰 두고 찍은 뒤 다시 흐르게.
func _hold_shot(name: String) -> void:
	game._bot_talk_t = -1.0e9
	await _shot(name)
	game._bot_talk_t = 0.0

func _pump(sec: float, hold: bool) -> void:
	var t := 0.0
	while t < sec:
		if hold:
			game._bot_talk_t = -1.0e9
		game.advance(DT)
		t += DT
		await process_frame
	game._bot_talk_t = 0.0

func _pump_until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit and not cond.call():
		game.advance(DT)
		t += DT
		await process_frame

# 장면이 바뀔 때까지 옛 장면을 돌린다(암전 → reload_current_scene).
func _follow() -> void:
	var old = game
	for i in 600:
		if current_scene != null and current_scene != old and is_instance_valid(current_scene) and current_scene.get("world") != null:
			break
		if is_instance_valid(old):
			old.advance(DT)
		await process_frame
	game = current_scene
	game.set_process(false)
	await process_frame

func _shot(name: String) -> void:
	if headless:
		return
	for i in 2:
		await process_frame
	var path := "%s/%s.png" % [out, name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

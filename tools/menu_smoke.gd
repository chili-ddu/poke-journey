extends SceneTree

# Esc 게임 메뉴 스모크(사용자 요청 2026-10-29): 시작 화면 → 꼬북이로 시작 → Esc 메뉴(닫기·언어) → 저장하고 시작 화면으로
# → 커서가 꼬북이 칸, 세이브에 지금 자리 → 파이리로 새로 시작하면 파이리 칸(Lv5)으로 열린다.
#   godot --headless --path . -s tools/menu_smoke.gd
# 실제 세이브는 건드리지 않는다(칸 파일 이름을 menusmoke_*.cfg 로, 옛 세이브 옮기기 끔).

func _init() -> void:
	OS.set_environment("BOT", "")
	OS.set_environment("SEED", "5")
	SaveData.slot_pattern = "user://menusmoke_%s.cfg"
	SaveData.allow_migrate = false
	load("res://scripts/game.gd").skip_opening = true   # 시작 이야기는 tools/opening_shot.gd 가 본다
	ViewScale.window_ready = true
	for s in SaveData.STARTERS:
		SaveData.reset_slot(s)
	var lang0 := Lang.code
	# 1) 시작 화면에서 꼬북이.
	var title := await _title()
	title.start_game("squirtle")
	var game: Node = await _scene()
	assert(game.world.player.species_id == "squirtle" and SaveData.path == SaveData.slot_path("squirtle"), "꼬북이 칸으로 시작")
	game.set_process(false)
	# 2) Esc → 메뉴, 패널의 Esc → 닫힘.
	var resume: String = game.state
	_esc(game)
	assert(game.state == "menu" and game.menu == "game" and game.panel.visible, "Esc 로 게임 메뉴")
	_esc(game.panel)
	assert(game.state == resume and not game.panel.visible, "메뉴의 Esc 로 닫힘")
	# 3) 언어 카드: 바뀌고 메뉴는 열린 채(새 언어로 다시 그림).
	_esc(game)
	game._resolve_menu(1)
	assert(Lang.code != lang0 and game.menu == "game" and game.panel.visible, "언어 바꾸고 메뉴 유지")
	game._resolve_menu(1)
	assert(Lang.code == lang0)
	# 4) 저장하고 시작 화면으로.
	var p: Player = game.world.player
	p.position += Vector2(Arena.TILE, 0)
	var at: Vector2 = p.position
	var where: String = DungeonDB.current
	game._resolve_menu(0)
	game.set_process(true)
	var back: Node = await _scene()
	assert(back is TitleScreen, "시작 화면으로 돌아왔다")
	assert(back.cursor == SaveData.STARTERS.find("squirtle"), "커서는 하던 꼬북이 칸")
	var sv := SaveData.peek("squirtle")
	print("저장: %s %s (떠난 자리 %s %s)" % [sv.get("map"), sv.get("pos"), where, at])
	assert(String(sv["map"]) == where and (sv["pos"] as Vector2).is_equal_approx(at), "지금 자리 저장")
	var g = load("res://scripts/game.gd")
	assert(g.starter == "" and g.destination.is_empty() and SaveData.path == SaveData.PATH, "장면 사이 기록 비움")
	# 5) 이번엔 파이리(기록 없음) → 파이리 칸, Lv5.
	back.start_game("charmander")
	game = await _scene()
	assert(game.world.player.species_id == "charmander" and game.world.player.level == g.START_LEVEL, "파이리 새로 시작")
	assert(SaveData.path == SaveData.slot_path("charmander"))
	print("menu smoke OK")
	for s in SaveData.STARTERS:
		SaveData.reset_slot(s)
	quit()

func _title() -> Node:
	var t: Node = load("res://scenes/title.tscn").instantiate()
	root.add_child(t)
	current_scene = t
	await process_frame
	return t

# 장면이 바뀌고 자리 잡을 때까지.
func _scene() -> Node:
	for i in 40:
		await process_frame
	return current_scene

func _esc(target: Node) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	target._unhandled_input(ev)

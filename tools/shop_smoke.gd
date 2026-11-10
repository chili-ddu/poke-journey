extends SceneTree

# 센터·상점·가방 스모크(사용자 결정 2026-10-28): 간호순 회복 + 부활 자리, 점원 물물교환, 가방에서 도구 쓰기, 기력의조각, 동굴탈출로프, 스프레이.
#   godot --headless --path . -s tools/shop_smoke.gd
# 사람 플레이처럼 저장을 쓰므로 BOT 를 끄고 시험용 저장 파일을 쓴다.

const DT := 1.0 / 60.0
var game: Node

func _init() -> void:
	OS.set_environment("BOT", "")
	OS.set_environment("SEED", "5")
	SaveData.path = "user://save_shop_smoke.cfg"
	SaveData.clear()
	# 1) 포켓몬센터: 다치고 독에 걸린 채 간호순 앞에서 E.
	await _open("viridian_center")
	var p: Player = game.world.player
	var nurse: Npc = game.world.npcs[0]
	p.position = Arena.tile_center(nurse.talk_tile)
	p.hp = 3
	p.poison_t = 3.0
	p.pp[0] = 0
	assert(game.npc_in_reach() == nurse, "카운터 앞이면 말을 걸 수 있다")
	game._talk(nurse)
	# 간호순 대사(지나가던 포켓몬에게) 세 쪽을 넘기면 회복 연출(기계로 뛰어올라 잠깐 잠), 끝나면 회복·제자리 → 끝 인사 두 쪽.
	assert(game.state == "talk", "간호순이 말을 건다")
	for i in 8:
		if game.state != "talk":
			break
		print("간호순: %s" % String(game.dialog_text).replace("\n", " / "))
		game._talk_next()
	assert(game.state == "heal", "회복 연출 시작")
	var from_pos := p.position
	for i in 30:
		game.advance(DT)
	assert(p.position.distance_to(nurse.heal_spot) < 2.0 and p.sleep_t > 0.0, "기계 위에서 잔다(%s, 잠 %.1f)" % [p.position, p.sleep_t])
	for i in 600:
		if game.state != "heal":
			break
		game.advance(DT)
	assert(game.state == "talk" and p.position.distance_to(from_pos) < 1.0, "다 끝나면 제자리로 돌아와 끝 인사(%s)" % game.state)
	for i in 8:
		if game.state != "talk":
			break
		print("간호순: %s" % String(game.dialog_text).replace("\n", " / "))
		game._talk_next()
	assert(game.state == "town")
	var s := SaveData.load_saved()
	print("센터: HP %d/%d 독 %.1f PP %d, 부활 자리 %s %s" % [p.hp, p.max_hp, p.poison_t, p.pp[0], s["respawn_map"], s["respawn_pos"]])
	assert(p.hp == p.max_hp and p.poison_t == 0.0 and p.pp[0] > 0, "HP·상태·PP 모두 회복")
	assert(s["respawn_map"] == "viridian_center", "부활 자리 저장")
	# 2) 프렌들리숍: 교환품(오랭 5 + 전기구슬 1 = ₽200)으로 해독제(₽100)를 받는다.
	await _open("viridian_mart")
	p = game.world.player
	var clerk: Npc = game.world.npcs[0]
	p.position = Arena.tile_center(clerk.talk_tile)
	p.bag = {"oran_berry": 5, "light_ball": 1}
	game._talk(clerk)
	assert(game.state == "menu" and game.menu == "shop", "점원 → 교환 창")
	var idx: int = game.menu_ids.find("antidote")
	game._resolve_menu(idx)
	assert(game.menu == "shop_confirm", "무엇을 줄지 확인")
	print("상점 확인: 줄 것 %s" % str(game.shop_pay))
	assert(game.shop_pay == {"light_ball": 1}, "같은 값이면 개수 적은 쪽")
	game._resolve_menu(0)
	print("상점 교환 뒤 가방: %s" % str(p.bag))
	assert(p.bag.get("antidote", 0) == 1 and not p.bag.has("light_ball") and p.bag.get("oran_berry", 0) == 5)
	var pidx: int = game.menu_ids.find("potion")
	game._resolve_menu(pidx)
	assert(game.menu == "shop", "모자라면(₽100 < ₽300) 확인으로 안 넘어간다")
	game._close_menu()
	# 3) 가방: 독에 걸린 채 해독제 쓰기, 멀쩡할 때 상처약은 효과 없음.
	p.poison_t = 3.0
	p.bag["potion"] = 1
	game._open_bag()
	assert(game.bag_screen.visible)
	game._on_bag_used("antidote")
	print("가방 해독제: 독 %.1f, 가방 %s" % [p.poison_t, str(p.bag)])
	assert(p.poison_t == 0.0 and not p.bag.has("antidote"))
	game._open_bag()
	assert(game.bag_screen.visible)
	game._on_bag_used("potion")
	assert(p.bag.get("potion", 0) == 1, "HP 가득이면 상처약은 그대로")
	# 3-1) 가방 화면 키 조작: 처음엔 물건이 있는 첫 주머니(약), → 로 열매, ↓ 로 줄 이동, Enter 로 쓰기, Esc 로 닫기.
	p.bag = {"potion": 1, "oran_berry": 2}
	p.hp = 5
	game._open_bag()
	var bs: BagScreen = game.bag_screen
	assert(ItemDB.BAG_POCKETS[bs.pocket] == "medicine" and bs.selected_id() == "potion", "물건이 있는 첫 주머니")
	_key(KEY_RIGHT)
	_key(KEY_RIGHT)
	print("가방 화면: 주머니 %s, 고른 것 %s" % [ItemDB.BAG_POCKETS[bs.pocket], bs.selected_id()])
	assert(ItemDB.BAG_POCKETS[bs.pocket] == "berries" and bs.selected_id() == "oran_berry")
	_key(KEY_DOWN)
	assert(bs.selected_id() == BagScreen.CLOSE, "마지막 줄은 가방 닫기")
	_key(KEY_UP)
	_key(KEY_ENTER)
	print("가방 화면 Enter: HP %d, 열매 %d, 창 %s" % [p.hp, p.berries, str(bs.visible)])
	assert(p.hp == 15 and p.berries == 1 and not bs.visible and game.state != "menu", "Enter 로 쓰고 닫힘")
	game._open_bag()
	_key(KEY_ESCAPE)
	assert(bs.visible, "Esc 로는 닫히지 않는다")
	_key(KEY_B)
	assert(not bs.visible and game.state != "menu", "B 로 닫힘")
	assert(p.controller is Controllers.Human and p.controller.hold, "닫은 직후엔 마우스를 뗄 때까지 기술 안 씀")
	# 3-2) 상태창(C): 열면 멈추고, ←→ 로 쪽 넘기기, 기술 쪽 ↓ 로 고르기, Esc 는 고르기 끝 → 한 번 더 Esc 로 닫기.
	var ce := InputEventKey.new()
	ce.physical_keycode = KEY_C
	ce.pressed = true
	game._unhandled_input(ce)
	var ss: SummaryScreen = game.summary_screen
	assert(game.state == "menu" and ss.visible and ss.page == 0, "C → 상태창(정보)")
	_skey(KEY_RIGHT)
	_skey(KEY_RIGHT)
	_skey(KEY_DOWN)
	print("상태창: 쪽 %s, 고른 기술 %d" % [SummaryScreen.PAGES[ss.page], ss.move_cursor])
	assert(SummaryScreen.PAGES[ss.page] == "moves" and ss.move_cursor == 0)
	# 기술 바꾸기(네 칸 Q·W·E·R, 2026-11-02): 끼우지 않은 기술을 고르고 Enter → 모달 → Q 를 누르면 Q 칸에 끼운다.
	# PP 가 가득이 아닌 칸은 막힌다.
	for m in ["scratch", "growl", "ember", "smoke_screen"]:
		p.add_learned(m)
	for i in Player.SLOT_COUNT:
		p.equip(i, ["scratch", "growl", "ember", "smoke_screen"][i])
	p.add_learned("dragon_rage")
	assert(p.spare_moves() == ["dragon_rage"], "끼우지 않은 기술 하나(%s)" % str(p.spare_moves()))
	p.pp[0] = MoveDB.pp_of(p.slots[0]) - 1
	ss.move_cursor = Player.SLOT_COUNT     # 네 칸 아래 줄 = 끼우지 않은 첫 기술
	_skey(KEY_ENTER)                       # 모달
	assert(ss.modal == Player.SLOT_COUNT, "끼우기 모달이 열린다")
	_skey(KEY_Q)                           # Q 칸 → PP 가 줄어 있어 막힘
	print("교체(PP 부족): 칸 %s, 안내 %s" % [str(p.slots), ss.notice])
	assert(p.slots[0] != "dragon_rage" and ss.notice_t > 0.0, "PP 가 가득이 아니면 못 바꾼다")
	p.pp[0] = MoveDB.pp_of(p.slots[0])
	ss.modal = -1
	ss.move_cursor = Player.SLOT_COUNT
	_skey(KEY_ENTER)
	_skey(KEY_Q)
	print("교체(PP 가득): 칸 %s, 남은 배운 기술 %s" % [str(p.slots), str(p.spare_moves())])
	assert(p.slots[0] == "dragon_rage" and p.spare_moves() == ["scratch"], "가득이면 바꿔 끼운다")
	# 끼운 기술끼리: Q 칸을 고르고 Enter → R 이면 맞바꾼다.
	ss.move_cursor = 0
	_skey(KEY_ENTER)
	_skey(KEY_R)
	assert(p.slots[3] == "dragon_rage" and p.slots[0] == "smoke_screen", "Q ↔ R 맞바꿈(%s)" % str(p.slots))
	_skey(KEY_ESCAPE)
	assert(ss.visible and ss.move_cursor == -1, "Esc 는 먼저 고르기만 끝낸다")
	_skey(KEY_ESCAPE)
	assert(ss.visible, "Esc 로는 닫히지 않는다")
	_skey(KEY_C)
	assert(not ss.visible and game.state != "menu", "C 로 닫힘")
	# 4) 기력의조각: 쓰러지는 순간 HP 절반으로.
	p.bag["revive"] = 1
	game.world.damage(p, 9999)
	print("기력의조각: HP %d/%d, 쓰러짐 %s" % [p.hp, p.max_hp, str(p.dead)])
	assert(not p.dead and p.hp == p.max_hp / 2 and not p.bag.has("revive"))
	# 5) 쓰러지면 마지막 센터로.
	p.invuln_t = 0.0
	game.world.damage(p, 9999)
	_pump(0.1)
	assert(game.state == "gameover")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	ev.pressed = true
	game._unhandled_input(ev)
	await _settle()
	print("부활: %s 칸 %s HP %d/%d" % [DungeonDB.current, Arena.tile_of(game.world.player.position), game.world.player.hp, game.world.player.max_hp])
	assert(DungeonDB.current == "viridian_center" and Arena.tile_of(game.world.player.position) == Vector2i(7, 4), "마지막으로 회복한 센터 카운터 앞")
	# 6) 스프레이: 1번도로에서 걸음 동안 야생이 안 나온다.
	await _open("kanto_south")
	p = game.world.player
	p.bag["repel"] = 1
	game._open_bag()
	assert(game.bag_screen.visible)
	game._on_bag_used("repel")
	assert(p.repel_steps == 100)
	p.position = Arena.tile_center(Arena.area_tile("route1", Vector2i(10, 18)))
	_pump(12.0)
	print("스프레이 12초: 야생 %d, 남은 걸음 %d" % [game.world.remaining(), p.repel_steps])
	assert(game.world.remaining() == 0)
	# 7) 동굴탈출로프: 던전에서만, 바깥 세계 자리로.
	await _open("test_meadow")      # 남은 던전은 시험용 아레나뿐(상록숲은 바깥 세계)
	p = game.world.player
	p.bag["escape_rope"] = 1
	game._open_bag()
	assert(game.bag_screen.visible)
	game._on_bag_used("escape_rope")
	assert(game.state == "warp")
	await _settle()
	print("동굴탈출로프: %s" % DungeonDB.current)
	assert(DungeonDB.is_hub(DungeonDB.current))
	SaveData.clear()
	print("OK")
	quit()

func _open(where: String) -> void:
	if game != null:
		game.queue_free()
		await process_frame
	OS.set_environment("DUNGEON", where)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON", "")

# 장면 바뀜(암전 트윈은 실제 시간 0.3초 — 헤드리스는 프레임이 빨라 40프레임 안에 안 끝날 때가 있다)을 기다린다.
func _settle() -> void:
	var old = game
	for i in 600:
		await process_frame
		if i >= 40 and current_scene != null and current_scene != old and is_instance_valid(current_scene) and current_scene.get("world") != null:
			break
	game = current_scene
	game.set_process(false)
	await process_frame

func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	game.bag_screen._unhandled_input(ev)

func _skey(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	game.summary_screen._unhandled_input(ev)

func _pump(sec: float) -> void:
	var t := 0.0
	while t < sec:
		game.advance(DT)
		t += DT

extends SceneTree

# 1번도로 라이벌 그린 스모크(사용자 요청·승인 2026-10-30): 실제 게임 흐름으로
#   1번도로 북쪽 끝 통로에 들어서면 "!" → 라이벌 곡 → 그린이 남쪽에서 뛰어와 바로 뒤에 선다 → 대사(승인 문구) → 인카운트 연출
#   → 1번도로 경기장(파이리면 꼬부기 Lv5) → 이기면 돌아와 그린이 북쪽으로 뛰어가 사라진다 → 다시 들어서도 안 나온다.
#   godot --headless --path . -s tools/rival_smoke.gd
# BOT=1 이라 저장하지 않는다(대사는 봇이 0.4초마다 넘김). 스타팅은 기본 파이리.

const DT := 1.0 / 60.0
var game: Node

func _init() -> void:
	OS.set_environment("BOT", "1")
	OS.set_environment("SEED", "7")
	await _open("kanto_south")
	var gs = load("res://scripts/game.gd")
	var id: String = TrainerDB.rival_for(gs.starter if gs.starter != "" else "charmander")
	assert(not game.beaten.has(id), "아직 그린을 이기지 않았다")
	game.world.player.position = Arena.tile_center(Vector2i(23, 163))
	game.world.player.controller = Walk.new(Vector2.UP)
	_pump_until(func(): return game.state == "rival", 3.0)
	assert(game.state == "rival" and game.world.player.emote_t > 0.0, "통로에 들어서면 내 머리 위 \"!\"(상태 %s)" % game.state)
	assert(Bgm.now() == "seq_the_riv", "라이벌 등장 곡(%s)" % Bgm.now())
	var green: Npc = game.rival["npc"]
	assert(green.position.distance_to(game.world.player.position) > Arena.TILE * 4.5, "그린은 화면 밖 남쪽에서")
	game.world.player.controller = Walk.new(Vector2.ZERO)
	_pump_until(func(): return game.state == "talk", 6.0)
	print("그린: 선 자리 %s, 나 %s" % [Arena.tile_of(green.position), Arena.tile_of(game.world.player.position)])
	assert(green.position.y > game.world.player.position.y and green.position.distance_to(game.world.player.position) <= Arena.TILE + 1.0, "바로 뒤 칸까지 뛰어온다")
	assert(game.dialog_text == TrainerDB.pages(id, "intro")[0], "첫 대사(%s)" % game.dialog_text)
	_pump_until(func(): return game.state == "encounter", 12.0)
	assert(game.state == "encounter" and Bgm.now() == "seq_ba_rival", "대사 뒤 인카운트 연출 + 라이벌 배틀 곡(%s)" % Bgm.now())
	await _follow_scene(func(): game.advance(DT))
	assert(DungeonDB.current == "arena_route1" and game.mode == "arena", "1번도로 경기장(지금 %s)" % DungeonDB.current)
	_pump_until(func(): return not game.battle.is_empty() and game.battle["mon"] != null, 4.0)
	var e: Enemy = game.battle["mon"]
	print("그린의 포켓몬: %s Lv%d" % [e.species_id, e.level])
	assert(e.level == 5 and e.species_id == String(TrainerDB.get_trainer(id)["party"][0][0]), "상성 스타팅 Lv5")
	assert(game.dialog_text == Lang.t("sent_out", [TrainerDB.display_name(id), e.display_name()]), "라이벌 그린은 …를 내보냈다!")
	_pump_until(func(): return game.state == "fight", 4.0)
	game.world.god = true
	game.world.damage(e, 9999)
	_pump_until(func(): return game.state == "warp", 20.0)
	assert(game.beaten.has(id), "그린을 이겼다")
	await _follow_scene(func(): pass)
	assert(DungeonDB.current == "kanto_south", "1번도로로 돌아온다")
	assert(game.world.player.known_moves().has("protect"), "그린을 이기면 TM17 방어를 바로 배운다(%s)" % str(game.world.player.known_moves()))
	assert(game.world.player.berries == 2, "그린에게서 오랭열매 2개(%d)" % game.world.player.berries)
	assert(not game.rival_exit.is_empty(), "진 그린이 떠난다")
	var leaving: Npc = game.rival_exit["npc"]
	var y0 := leaving.position.y
	_pump_until(func(): return game.rival_exit.is_empty(), 6.0)
	assert(game.rival_exit.is_empty() and not is_instance_valid(leaving) or leaving.is_queued_for_deletion(), "북쪽으로 뛰어가 사라진다")
	game.world.player.position = Arena.tile_center(Vector2i(23, 163))
	game.world.player.controller = Walk.new(Vector2.UP)
	_pump(1.0)
	assert(game.state == "fight", "이긴 뒤엔 다시 나오지 않는다(%s)" % game.state)
	print("떠난 자리 y %.0f → 사라짐, 다시 지나가도 그대로" % y0)
	print("rival smoke OK")
	quit()

func _open(where: String) -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
		await process_frame
	OS.set_environment("DUNGEON", where)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON", "")
	game.world.player.controller = Walk.new(Vector2.ZERO)

# 장면이 바뀔 때까지(연출·암전 뒤 reload_current_scene). tick 은 기다리는 동안 한 프레임마다 할 일.
func _follow_scene(tick: Callable) -> void:
	var old = game
	for i in 600:
		if current_scene != null and current_scene != old and is_instance_valid(current_scene) and current_scene.get("world") != null:
			break
		if is_instance_valid(old):
			tick.call()
		await process_frame
	game = current_scene
	game.set_process(false)
	await process_frame
	game.world.player.controller = Walk.new(Vector2.ZERO)

func _pump(sec: float) -> void:
	var t := 0.0
	while t < sec:
		game.advance(DT)
		t += DT

func _pump_until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit and not cond.call():
		game.advance(DT)
		t += DT

class Walk:
	extends RefCounted
	var mv := Vector2.ZERO
	func _init(d: Vector2) -> void:
		mv = d
	func move_dir(_w) -> Vector2: return mv
	func aim_point(w) -> Vector2: return w.player.position + Vector2.DOWN * 40.0
	func want_dodge(_w) -> bool: return false
	func want_skill(_i, _w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

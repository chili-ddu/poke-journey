extends SceneTree

# 진화 화면 스모크(사용자 요청 2026-10-30: 플래티넘 진화 화면 + B 취소): 실제 게임 흐름으로
#   상록숲에서 파이리 Lv16 → 진화 화면(장소 곡은 멈추고 SEQ_SHINKA) → 교대 중 B → "어라…? 파이리의 변화가 멈췄다!" → 필드, 파이리 그대로,
#   장소 곡 다시 → 같은 레벨에선 다시 묻지 않음 → Lv17 → 다시 진화 화면 → 끝까지 → 리자드, 장소 곡 다시 →
#   리자드가 Lv17 에 배우는 용의분노를 필드에서 이어서 배움(기술 대기열).
#   godot --headless --path . -s tools/evolution_smoke.gd
# BOT=1 이라 저장하지 않는다.

const DT := 1.0 / 60.0
var game: Node

func _init() -> void:
	OS.set_environment("BOT", "1")
	OS.set_environment("SEED", "11")
	OS.set_environment("DUNGEON", "viridian_forest")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON", "")
	game.world.player.controller = Still.new()
	game.world.player.evolution_declined_level = 0
	await _pump(1.0)
	var p: Player = game.world.player
	var place: String = Bgm.now()
	assert(p.species_id == "charmander" and place != "", "시작: 파이리, 장소 곡 %s" % place)

	# 1) Lv16 → 진화 화면 → 교대 중 B
	p.set_level(16)
	await _pump_until(func(): return game.state == "evolve", 2.0)
	assert(game.state == "evolve", "Lv16 이면 진화 화면")
	var scr: EvolutionScreen = game.evolution_screen
	await _pump_until(func(): return scr.phase == "alternate", 8.0)
	assert(Bgm.now() == Bgm.EVOLVING, "교대 전에 SEQ_SHINKA")
	await _pump(0.5)
	var b := InputEventKey.new()
	b.physical_keycode = KEY_B
	b.pressed = true
	game._unhandled_input(b)
	await _pump_until(func(): return scr.phase == "cancel_text", 3.0)
	assert(scr.text == Lang.t("evolve_stopped", [Lang.species_name("charmander")]), "멈춤 대사: " + scr.text)
	await _pump_until(func(): return game.state != "evolve", 6.0)
	assert(game.state == "fight" and p.species_id == "charmander", "취소 뒤 필드, 파이리 그대로")
	assert(Bgm.now() == place, "장소 곡 다시: " + Bgm.now())
	await _pump(1.0)
	assert(game.state == "fight", "같은 레벨에선 다시 묻지 않는다")
	print("취소 OK")

	# 2) Lv17 → 끝까지 → 리자드 + 용의분노
	p.set_level(17)
	game._queue_learns(p.species_id, p.level)
	await _pump_until(func(): return game.state == "evolve", 2.0)
	assert(game.state == "evolve", "레벨이 오르면 다시 진화하려 한다")
	await _pump_until(func(): return scr.phase == "congrats", 15.0)
	assert(p.species_id == "charmeleon", "축하 대사 때 종족이 바뀐다")
	assert(scr.text == Lang.t("evolved", [Lang.species_name("charmander"), Lang.species_name("charmeleon")]), scr.text)
	await _pump_until(func(): return game.state != "evolve", 15.0)
	assert(game.state == "fight", "진화 뒤 필드")
	assert(Bgm.now() == place, "장소 곡 다시: " + Bgm.now())
	# 최신 표(2026-11-02)에선 리자드 Lv17 에 배우는 게 없다 — Lv19 불꽃엄니로 '진화 뒤에도 이어서 배운다' 를 본다.
	p.set_level(19)
	game._queue_learns(p.species_id, p.level)
	await _pump_until(func(): return p.known_moves().has("fire_fang"), 3.0)
	assert(p.known_moves().has("fire_fang"), "리자드 Lv19 불꽃엄니를 이어서 배운다")
	print("진화 OK  ", p.display_name(), " Lv.", p.level, " ", p.known_moves(), " / ", game.dialog_text)
	print("evolution smoke OK")
	quit()

func _pump(sec: float) -> void:
	var t := 0.0
	while t < sec:
		game.advance(DT)
		t += DT
		await process_frame

func _pump_until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit and not cond.call():
		game.advance(DT)
		t += DT
		await process_frame

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.UP * 40.0
	func want_dodge(_w) -> bool: return false
	func want_skill(_i, _w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

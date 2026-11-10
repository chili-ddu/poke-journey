extends SceneTree

# 진화 화면 캡처(창 필요): 상록숲에서 파이리를 Lv16 으로 올려 실제 게임 흐름으로 진화 화면을 연다.
#   evolution-1-what      "어…? 파이리의 상태가…!"(원작 배경 그대로)
#   evolution-2-alternate 위아래 띠 + 흰 실루엣 교대(옛 모습 ↔ 새 모습) + 빛줄기·별
#   evolution-3-flash     교대 끝: 색 구슬이 터지고 배경이 하얗게
#   evolution-4-done      "축하합니다! 파이리는 리자드로 진화했다!"
#   evolution-cancel      다시 연 뒤 교대 중 B → "어라…? 파이리의 변화가 멈췄다!"
#   godot --path . -s tools/evolution_shot.gd -- <출력디렉터리>
#   LANG_CODE=ko 한국어
# BOT=1(저장 안 함).

const DT := 1.0 / 60.0
var game: Node
var out := "."

func _init() -> void:
	var argv := OS.get_cmdline_user_args()
	out = argv[0] if argv.size() > 0 else "."
	OS.set_environment("BOT", "1")
	OS.set_environment("SEED", "11")
	await CaptureWindow.park(self)
	await _open_and_level()
	var scr: EvolutionScreen = game.evolution_screen
	await _pump_until(func(): return scr.phase == "wait_what", 4.0)
	await _pump(0.3)
	await _shot("evolution-1-what")
	await _pump_until(func(): return scr.phase == "alternate", 6.0)
	await _pump_until(func(): return scr.scale_new >= 208 and scr.shrink_delta == 16, 4.0)
	await _shot("evolution-2-alternate")
	await _pump_until(func(): return scr.phase == "clamp_out", 6.0)
	await _pump(10.0 * DT)
	await _shot("evolution-3-flash")
	await _pump_until(func(): return scr.phase == "congrats", 8.0)
	await _pump(0.2)
	await _shot("evolution-4-done")
	await _pump_until(func(): return game.state != "evolve", 10.0)
	print("진화 뒤: ", game.world.player.species_id, " state=", game.state)
	# 취소: 새로 열어 교대 중 B(실제 입력 경로 Game._unhandled_input).
	await _open_and_level()
	scr = game.evolution_screen
	await _pump_until(func(): return scr.phase == "alternate", 8.0)
	await _pump(0.8)
	var b := InputEventKey.new()
	b.physical_keycode = KEY_B
	b.pressed = true
	game._unhandled_input(b)
	await _pump_until(func(): return scr.phase == "cancel_text", 4.0)
	await _pump(0.2)
	await _shot("evolution-cancel")
	await _pump_until(func(): return game.state != "evolve", 6.0)
	print("취소 뒤: ", game.world.player.species_id, " state=", game.state)
	quit()

func _open_and_level() -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
		await process_frame
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
	game.world.player.set_level(16)

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

func _shot(name: String) -> void:
	for i in 2:
		await process_frame
	var path := "%s/%s.png" % [out, name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, " state=", game.state, " phase=", game.evolution_screen.phase)

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.UP * 40.0
	func want_dodge(_w) -> bool: return false
	func want_skill(_i, _w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

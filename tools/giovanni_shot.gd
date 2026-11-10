extends SceneTree

# 상록시티 체육관 앞 비주기 캡처(창 필요): 부딪힘("!") / 첫 대사 / 변함없는돌을 받음 / "그 다짐을…" / 떠나는 비주기 / 가방의 변함없는돌 / 지닌 뒤 상태창.
#   godot --path . -s tools/giovanni_shot.gd -- <출력디렉터리>
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
	await _open("kanto_south")
	var p: Player = game.world.player
	p.position = Arena.tile_center(Vector2i(36, 132))
	await _pump(2.2)
	game.world.player.controller = Walk.new(Vector2.UP)
	await _pump_until(func(): return game.state == "giovanni", 3.0)
	game.world.player.controller = Still.new()
	await _pump_until(func(): return String(game.gio.get("phase", "")) == "shove", 2.0)
	await _pump(0.1)
	await _shot("giovanni-bump")
	await _pump_until(func(): return String(game.gio.get("phase", "")) == "notice", 2.0)
	await _pump(0.15)
	await _shot("giovanni-notice")
	_hold(true)
	await _pump_until(func(): return game.state == "talk", 4.0)
	await _pump(0.2)
	await _shot("giovanni-talk")
	var got := Lang.t("got_from", [p.display_name(), Lang.t("giovanni"), ItemDB.name_of("everstone")])
	while game.state == "talk" and game.dialog_text != got:
		game._talk_next()
		await process_frame
	await _pump(0.1)
	await _shot("giovanni-everstone")
	while game.state == "talk" and game.dialog_text != Lang.t("gio_7"):
		game._talk_next()
		await process_frame
	await _pump(0.1)
	await _shot("giovanni-resolve")
	_hold(false)
	await _pump_until(func(): return game.state == "fight", 6.0)
	await _pump(0.9)
	await _shot("giovanni-leave")
	await _pump_until(func(): return game.rival_exit.is_empty(), 12.0)
	game._open_bag()
	await _pump(0.2)
	await _shot("giovanni-bag")
	game._on_bag_used("everstone")
	await _pump(0.2)
	game._menu_open("summary")
	game.summary_screen.open(p)
	await _pump(0.2)
	await _shot("giovanni-held")
	quit()

func _hold(on: bool) -> void:
	game._bot_talk_t = -1.0e9 if on else 0.0

# 장면이 바뀔 때까지 옛 장면을 돌린다(연출 끝 → reload_current_scene).
func _follow() -> void:
	var old = game
	for i in 600:
		if current_scene != null and current_scene != old and is_instance_valid(current_scene) and current_scene.get("world") != null:
			break
		if is_instance_valid(old) and old.state != "warp":
			old.advance(DT)
		await process_frame
	game = current_scene
	game.set_process(false)
	for i in 3:
		await process_frame
	game.world.player.controller = Still.new()
	await _pump(0.4)

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
	game.world.player.controller = Still.new()

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
	print("saved ", path, " state=", game.state)

class Walk:
	extends RefCounted
	var mv := Vector2.ZERO
	func _init(d: Vector2) -> void:
		mv = d
	func move_dir(_w) -> Vector2: return mv
	func aim_point(w) -> Vector2: return w.player.position + Vector2.UP * 40.0
	func want_dodge(_w) -> bool: return false
	func want_skill(_i, _w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.UP * 40.0
	func want_dodge(_w) -> bool: return false
	func want_skill(_i, _w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

# 배틀 장면: 상대 쪽을 보며 왼쪽 칸 기술을 가끔 쓴다(연출이 보이게).
class Fight:
	extends RefCounted
	var t := 0.0
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2:
		var es: Array = w.alive_enemies()
		return es[0].position if not es.is_empty() else w.player.position + Vector2.UP * 40.0
	func want_dodge(_w) -> bool: return false
	func want_skill(i, _w) -> bool:
		t += 1.0 / 60.0
		return i == 0 and fmod(t, 1.2) < 0.05
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

extends SceneTree

# 상록시티 체육관 앞 비주기 스모크(사용자 요청·승인 대사 A안 2026-10-30): 실제 게임 흐름으로
#   체육관 문 칸에 올라서면 비주기가 나와 부딪힘(둘 다 "!") → 옆으로 밀려남(아래 줄은 언덕) → 비주기가 문 앞 칸으로 → 대사 → 변함없는돌(가방에만, 지니지 않음)
#   → 떠나서 사라짐 → 다시 문에 서면 잠긴 문뿐. 가방에서 변함없는돌을 고르면 지니기(진화 안 함) ↔ 돌려받기.
#   godot --headless --path . -s tools/giovanni_smoke.gd
# BOT=1 이라 저장하지 않는다(대사는 봇이 0.4초마다 넘김).

const DT := 1.0 / 60.0
var game: Node

func _init() -> void:
	OS.set_environment("BOT", "1")
	OS.set_environment("SEED", "7")
	await _open("kanto_south")
	var p: Player = game.world.player
	p.position = Arena.tile_center(Vector2i(36, 132))
	game.world.player.controller = Walk.new(Vector2.UP)
	_pump_until(func(): return game.state == "giovanni", 3.0)
	assert(game.state == "giovanni", "체육관 문 칸에 올라서면 비주기(상태 %s)" % game.state)
	var gio: Npc = game.gio["npc"]
	assert(p.emote_t <= 0.0 and String(game.gio["phase"]) == "recoil", "문에서 튕겨 나온다(\"!\"는 아직)")
	_pump_until(func(): return String(game.gio.get("phase", "")) == "shove", 2.0)
	assert(gio.walking() or Arena.tile_of(gio.position) == Vector2i(36, 131), "문에서 나온 비주기에게 밀린다")
	game.world.player.controller = Walk.new(Vector2.ZERO)
	_pump_until(func(): return String(game.gio.get("phase", "")) == "notice", 2.0)
	assert(p.emote_t > 0.0 and gio.emote_t > 0.0 and p.facing.x < -0.5 and gio.face == "right", "마주 보며 둘 다 \"!\"")
	_pump_until(func(): return game.state == "talk", 4.0)
	print("비주기 %s, 나 %s" % [Arena.tile_of(gio.position), Arena.tile_of(p.position)])
	assert(Arena.tile_of(p.position) == Vector2i(37, 131) and Arena.tile_of(gio.position) == Vector2i(36, 131), "옆 한 칸으로 밀려나고(아래 줄은 언덕) 비주기는 문 앞 칸")
	assert(game.dialog_text == Lang.t("gio_1"), "첫 대사(%s)" % game.dialog_text)
	var got := Lang.t("got_from", [p.display_name(), Lang.t("giovanni"), ItemDB.name_of("everstone")])
	_pump_until(func(): return game.dialog_text == got, 10.0)
	assert(game.dialog_text == got and int(p.bag.get("everstone", 0)) == 1 and p.hold == "", "\"%s\" — 가방에만, 지니지 않음" % got)
	_pump_until(func(): return String(game.gio.get("phase", "")) == "leave", 10.0)
	assert(game.events.has("giovanni_everstone") and not game.rival_exit.is_empty() and game.state == "giovanni", "이벤트 기록 + 비주기가 떠나는 동안 내 포켓몬은 멈춰 있다")
	_pump_until(func(): return game.state == "fight", 6.0)
	var gpos := Arena.tile_of(gio.position) if is_instance_valid(gio) else Vector2i(-1, -1)
	print("비주기가 지나간 뒤 풀림: 비주기 %s" % gpos)
	assert(game.state == "fight", "멀어지면 움직일 수 있다")
	_pump_until(func(): return game.rival_exit.is_empty(), 12.0)
	assert(game.rival_exit.is_empty() and not game.world.npcs.has(gio), "멀어지면 사라진다")
	p.position = Arena.tile_center(Vector2i(36, 131))      # 문 앞 칸으로
	game.world.player.controller = Walk.new(Vector2.UP)
	_pump(1.0)
	assert(game.state == "fight" and game.gio.is_empty(), "다시 문으로 가도 이벤트 없음(%s)" % game.state)
	assert(Arena.solid_at(36, 130) and Arena.tile_of(p.position) == Vector2i(36, 131), "닫힌 체육관은 문 칸 자체가 막힌다(%s)" % Arena.tile_of(p.position))
	assert(Arena.solid_at(25, 131) and Arena.solid_at(25, 138), "갈 곳 없는 집·학교 문도 막혀 있다")
	game.world.player.controller = Walk.new(Vector2.ZERO)
	# 가방에서 지니기 ↔ 돌려받기, 진화 막힘.
	p.set_level(16)
	assert(p.evolution_target() == "charmeleon", "Lv16 파이리는 진화 대상")
	game._on_bag_used("everstone")
	assert(p.hold == "everstone" and int(p.bag.get("everstone", 0)) == 1, "지니면 가방에도 그대로")
	assert(p.evolution_target() == "", "변함없는돌을 지니면 진화하지 않는다")
	assert(String(game.toasts[-1]["text"]) == Lang.t("hold_on", [p.display_name(), ItemDB.name_of("everstone")]), "지녔다 알림")
	game._on_bag_used("everstone")
	assert(p.hold == "" and p.evolution_target() == "charmeleon", "돌려받으면 다시 진화 대상")
	print("giovanni smoke OK")
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

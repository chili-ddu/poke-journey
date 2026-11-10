extends SceneTree

# 장소별 3D 화면 캡처(창 필요, View3D 2026-11-02): 바깥(꽃·수풀·문)·건물 안·숲. → <출력>/<이름>.png
#   godot --path . -s tools/view3d_places.gd -- <출력디렉터리>   (ONLY=이름,이름 이면 그것만)
const DT := 1.0 / 60.0
var out := "."
var game: Node

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 80.0
	func want_skill(_i: int, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

# [이름, 장소, 칸(없으면 지도 시작 자리)]
const PLACES := [
	["plant-left", "rivals_house", Vector2i(1, 7)],
	["plant-right", "players_house_1f", Vector2i(11, 6)],
	["plant-pewter", "pewter_house1", Vector2i(1, 6)],
	["stairs-1f", "players_house_1f", Vector2i(10, 3)],
	["stairs-2f", "players_house_2f", Vector2i(10, 3)],
	["rail-front", "players_house_2f", Vector2i(8, 4)],
	["rail-behind-probe", "players_house_2f", Vector2i(8, 2)],
	["rail-side", "players_house_2f", Vector2i(7, 3)],
	["home-wall", "players_house_1f", Vector2i(6, 3)],
	["rival-wall", "rivals_house", Vector2i(6, 3)],
	["pewter-house1", "pewter_house1", Vector2i(5, 3)],
	["pewter-house2", "pewter_house2", Vector2i(5, 3)],
	["house-roof", "kanto_south", Vector2i(19, 205)],
	["house-side", "kanto_south", Vector2i(15, 206)],
	["pallet-flowers", "kanto_south", Vector2i(21, 211)],
	["lab-out", "kanto_south", Vector2i(28, 216)],
	["lab-back", "kanto_south", Vector2i(27, 207)],
	["viridian-center-out", "kanto_south", Vector2i(26, 149)],
	["viridian-gym-out", "kanto_south", Vector2i(34, 134)],
	["viridian-mart-out", "kanto_south", Vector2i(35, 142)],
	["pewter-museum-out", "kanto_south", Vector2i(20, 9)],
	["pewter-gym-out", "kanto_south", Vector2i(15, 19)],
	["route2-gate-out", "kanto_south", Vector2i(18, 94)],
	["pallet-house", "kanto_south", Vector2i(19, 210)],
	["pallet-house-back", "kanto_south", Vector2i(23, 203)],
	["route1-grass", "kanto_south", Vector2i(22, 186)],
	["route1-in-grass", "kanto_south", Vector2i(26, 187)],
	["route1-rustle", "kanto_south", Vector2i(26, 187)],
	["oaks-lab", "oaks_lab", Vector2i(6, 8)],
	["oaks-lab-table", "oaks_lab", Vector2i(9, 6)],
	["oaks-lab-desk", "oaks_lab", Vector2i(4, 4)],
	["oaks-lab-at-desk", "oaks_lab", Vector2i(4, 2)],
	["center", "viridian_center", Vector2i(7, 6)],
	["center-wall", "viridian_center", Vector2i(7, 3)],
	["pewter-center", "pewter_center", Vector2i(7, 6)],
	["house-1f", "players_house_1f", null],
	["house-2f", "players_house_2f", null],
	["house-2f-bed", "players_house_2f", Vector2i(4, 6)],
	["rival-house", "rivals_house", null],
	["mart", "viridian_mart", null],
	["museum", "pewter_museum_1f", null],
	["museum-cases", "pewter_museum_1f", Vector2i(5, 9)],
	["gym", "pewter_gym", null],
	["forest-gate", "forest_gate_south", null],
	["forest", "viridian_forest", null],
	["forest-stack", "viridian_forest", Vector2i(14, 57)],
]

func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	OS.set_environment("BOT", "1"); OS.set_environment("GOD", "1"); OS.set_environment("SEED", "1")
	await CaptureWindow.park(self)
	var only := OS.get_environment("ONLY")         # 쉼표로 이름 몇 개만(예: ONLY=oaks-lab,oaks-lab-table)
	for pl in PLACES:
		if only != "" and not (pl[0] in only.split(",")):
			continue
		await _open(pl[1])
		if pl[2] != null:
			game.world.player.position = Arena.tile_center(pl[2])
			if String(pl[0]).ends_with("rustle"):       # 야생 출현 풀 흔들림을 오른쪽 두 칸에
				game.world.add_fx("rustle", Arena.tile_center(pl[2] + Vector2i(2, 0)), {"lifetime": 30.0})
			if String(pl[0]).ends_with("at-desk"):     # 책상에 바싹 붙인다(벽 쪽으로 밀 수 있는 데까지)
				var pp: Mon = game.world.player
				pp.position = Arena.resolve(pp.position + Vector2(0, -12), pp.radius)
		game.world.player.facing = Vector2.DOWN
		for i in 40:
			game.world.step_visual(DT)
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [out, pl[0]])
		print(pl[0], " view3d=", game.view3d != null)
	print("places OK")
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
	game.world.player.controller = Still.new()
	game.banner_t = 0.0
	game.stream.clear()
	if OS.get_environment("CAP_NO_SHADOWS") == "1" and game.view3d != null:
		# Diagnostic only: preserve lighting, disable static geometry shadow casting.
		for child in game.view3d.root3d.get_children():
			if child is GeometryInstance3D:
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


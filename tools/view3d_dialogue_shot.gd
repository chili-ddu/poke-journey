extends SceneTree

# 대화 초점 비교 및 상태 해제 검증(창 필요). 먼 위치에서 직접 대화를 호출한다.
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

# godot --path . -s tools/view3d_dialogue_shot.gd -- docs
func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	OS.set_environment("BOT", "1")
	OS.set_environment("GOD", "1")
	OS.set_environment("SEED", "1")
	await CaptureWindow.park(self)
	await _open("oaks_lab")
	game.world.player.position = Arena.tile_center(Vector2i(6, 8))
	for i in 40:
		game.world.step_visual(DT)
		await process_frame
	var oak = game._npc("prof_oak")
	assert(oak != null)
	game._talk(oak)
	game.queue_redraw()
	await _shot("dialogue_focus_before")
	game._update_dialogue_focus()
	var mat = game.look_rect.material
	assert(mat.get_shader_parameter("dialogue_focus_enabled"))
	await _shot("dialogue_focus_after")
	while game.state == "talk":
		game._talk_next()
	game._update_dialogue_focus()
	assert(not mat.get_shader_parameter("dialogue_focus_enabled"))
	game._talk(oak)
	game.view3d.visible = false
	game._update_dialogue_focus()
	assert(not mat.get_shader_parameter("dialogue_focus_enabled"))
	game.view3d.visible = true
	oak.visible = false
	game._update_dialogue_focus()
	assert(not mat.get_shader_parameter("dialogue_focus_enabled"))
	oak.visible = true
	game._say_pages(game._pages(["Story speaker|Second page"], oak) + ["Narration"])
	game._update_dialogue_focus()
	assert(mat.get_shader_parameter("dialogue_focus_enabled"))
	game._talk_next()
	game._update_dialogue_focus()
	assert(mat.get_shader_parameter("dialogue_focus_enabled"))
	game._talk_next()
	game._update_dialogue_focus()
	assert(not mat.get_shader_parameter("dialogue_focus_enabled"))
	game._talk_next()
	await _open("viridian_center")
	for i in 20:
		await process_frame
	var nurse: Npc = null
	for npc in game.world.npcs:
		if npc.talk == "nurse":
			nurse = npc
	assert(nurse != null)
	game._finish_heal(nurse)
	game._update_dialogue_focus()
	assert(game.talk_focus.get_ref() == nurse)
	assert(game.look_rect.material.get_shader_parameter("dialogue_focus_enabled"))
	print("dialogue focus: active, ended, 2D, hidden, story pages, narration, healed greeting OK")
	game.queue_free()
	await process_frame
	await process_frame
	quit()

func _shot(label: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, label])

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

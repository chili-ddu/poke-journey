extends SceneTree

# 상태창 캡처(창 필요): 정보 쪽(큰 탭) / 기술 쪽의 끼우기 모달.
#   godot --path . -s tools/summary_shot.gd -- <출력디렉터리>

const DT := 1.0 / 60.0

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	OS.set_environment("BOT", "1"); OS.set_environment("SEED", "3"); OS.set_environment("DUNGEON", "test_meadow")
	await CaptureWindow.park(self)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); current_scene = game; game.set_process(false)
	for i in 3:
		await process_frame
	var p: Player = game.world.player
	p.set_level(12)
	p.add_learned("ember"); p.add_learned("smoke_screen"); p.add_learned("growl")
	game._menu_open("summary")
	game.summary_screen.open(p)
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(out + "/summary-tabs.png")
	game.summary_screen.page = 1
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(out + "/summary-skills.png")
	game.summary_screen.page = 2
	game.summary_screen.move_cursor = 3
	game.summary_screen._pick()
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(out + "/summary-modal.png")
	quit()

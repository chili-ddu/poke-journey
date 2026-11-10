extends SceneTree
const SAVE := "user://save_mobile_desktop_review.cfg"
const OUT := "res://docs/touch_controls/active_gamepad/"
func _init() -> void:call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path = SAVE;SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON","kanto_world");OS.set_environment("LANG_CODE","ko")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game);current_scene = game
	game.set_process(false);game.view3d.set_process(false)
	game.bot = false;game.world.player.controller = Controllers.Human.new()
	game.world.player.setup_player("charmander",12,["scratch","growl","ember","smoke_screen"])
	game.banner_t = 0;game.dialog_text = "";game.dialog_t = 0;game.last_small_message = ""
	game.touch_controls.refresh()
	assert(not root.get_node("MobileScreen").active and not ViewScale.mobile_mode(self))
	assert(game.get_parent()==root and game.get_viewport()==root)
	assert(not game.touch_controls.visible and not game.touch_controls.available())
	game.hud._layout()
	var hud: Hud = game.hud
	assert(hud.MSG==Rect2(hud.W-Hud.MSG_W,hud.H-Hud.MSG_H-2,Hud.MSG_W,Hud.MSG_H))
	assert(hud.PLAYER_BOX.position==Vector2(hud.W-Hud.HB_W,hud.MSG.position.y-55))
	for i in 4:
		game.view3d._process(1.0/60.0);await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"desktop_384x216.png")
	game._open_game_menu()
	assert(not game.menu_ids.has("touch"))
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	FileAccess.open(OUT+"desktop_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"window":"384x216","mobile_host_inactive":true,"game_stays_direct_root_child":true,"no_pad":true,"original_hud_geometry":true,"original_menu":true},"  "))
	game.queue_free();await process_frame;SaveData.clear()
	print("Desktop UI unchanged: no mobile frame or stick, original HUD and game menu")
	quit()

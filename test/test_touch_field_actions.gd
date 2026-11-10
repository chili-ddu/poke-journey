extends GutTest

const Game = preload("res://scripts/game.gd")
const SAVE := "user://save_touch_field_actions_test.cfg"

func test_mobile_gamepad_preserves_hud_and_original_game_menu() -> void:
	var old_path := SaveData.path
	var old_bot := OS.get_environment("BOT")
	var old_place := OS.get_environment("DUNGEON")
	SaveData.path = SAVE;SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON","kanto_south")
	Game.destination = {};Game.arena_trip = {};Game.carry = {}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",old_bot);OS.set_environment("DUNGEON",old_place)
	game.bot = false;game.world.player.controller = Controllers.Human.new()
	var ui = game.touch_controls
	ui.control_area = Rect2(0,110,384,106)
	ui.mobile_override = 0;ui.refresh()
	assert_false(ui.visible)
	game.hud._layout()
	var original := [game.hud.PLAYER_BOX,game.hud.MSG,game.hud.STAT_BOX,game.hud.BUTTONS.duplicate(),game.hud.HOTBAR.duplicate()]
	ui.mobile_override = 1;ui.refresh()
	assert_true(ui.visible)
	game.hud._layout()
	assert_eq([game.hud.PLAYER_BOX,game.hud.MSG,game.hud.STAT_BOX,game.hud.BUTTONS.duplicate(),game.hud.HOTBAR.duplicate()],original)
	assert_eq(ui.get_child_count(),0)
	var hotbar: Array = game.world.player.hotbar.duplicate()
	game._on_hotbar_set(1,BagScreen.CLOSE)
	assert_eq(game.world.player.hotbar,hotbar,"The bag close row cannot become a quick-slot item")
	var event := InputEventKey.new();event.pressed = true;event.physical_keycode = KEY_F6
	game._unhandled_input(event)
	assert_true(ui.visible,"F6 no longer changes device-specific controls")
	game._open_game_menu();ui.refresh()
	assert_false(game.menu_ids.has("touch"))
	assert_true(ui.visible,"Gamepad stays usable while the original menu is open")
	ui.router.navigate(KEY_UP)
	assert_not_null(game.get_viewport().gui_get_focus_owner(),"Original cards receive visible controller focus")
	var back: Vector2 = ui.deck.hits.cancel.get_center()
	ui.pointer(5,back,"press");ui.pointer(5,back,"release")
	assert_true(game.state in ["fight","town"])
	game._open_game_menu();ui.refresh()
	var confirm: Vector2 = ui.deck.hits.action.get_center()
	ui.pointer(6,confirm,"press");ui.pointer(6,confirm,"release")
	assert_true(game.state in ["fight","town"],"A confirms the existing safe close card")
	Game.destination = {};Game.arena_trip = {};Game.carry = {}
	SaveData.clear();SaveData.path = old_path

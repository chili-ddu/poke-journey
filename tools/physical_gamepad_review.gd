extends SceneTree

const Game = preload("res://scripts/game.gd")
const OUT := "res://docs/touch_controls/active_gamepad/"
const SAVE_PATTERN := "user://physical_gamepad_review_%s.cfg"
var driver: GamepadControls
var game: Node
var checks: Array = []

func _init() -> void:call_deferred("run")

func button(index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new();event.device = 7;event.button_index = index;event.pressed = pressed
	root.push_input(event,true)

func axis(index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new();event.device = 7;event.axis = index;event.axis_value = value
	root.push_input(event,true)

func tap(index: int) -> void:
	button(index,true);button(index,false)
	driver.refresh_target()

func wait_content(path: String) -> Node:
	for i in 240:
		await process_frame
		var scene := MobileGameFrame.unwrap(current_scene)
		if is_instance_valid(scene) and scene.scene_file_path==path:
			await process_frame;return scene
	assert(false,"Scene did not arrive: "+path)
	return null

func control_game() -> void:
	game.set_process(false);game.view3d.set_process(false)
	game.bot = false;game.world.player.controller = Controllers.Human.new()
	game.world.player.setup_player("charmander",12,["scratch","growl","ember","smoke_screen"])
	driver.refresh_target()

func run() -> void:
	await CaptureWindow.park(self)
	create_timer(180).timeout.connect(func():push_error("Physical gamepad review timed out");quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	driver = root.get_node("GamepadInput")
	driver.track_window_focus = false;driver.set_focused(true)
	ViewScale.index = 0
	SaveData.slot_pattern = SAVE_PATTERN;SaveData.allow_migrate = false
	SaveData.path = SaveData.slot_path("charmander")
	for starter in SaveData.STARTERS:SaveData.reset_slot(starter)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("DUNGEON","kanto_world");OS.set_environment("LANG_CODE","ko")
	Game.skip_opening = true;Game.starter = "charmander";Game.carry = {};Game.destination = {};Game.arena_trip = {}
	TitleScreen.last = "";TitleScreen.last_records = {}
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title);current_scene = title;await process_frame
	driver.refresh_target()
	axis(JOY_AXIS_LEFT_X,-1.0);assert(title.cursor==0)
	axis(JOY_AXIS_LEFT_X,0.0);axis(JOY_AXIS_LEFT_X,1.0);assert(title.cursor==1)
	axis(JOY_AXIS_LEFT_X,0.0)
	tap(JOY_BUTTON_A);assert(title.menu_open)
	tap(JOY_BUTTON_A)
	game = await wait_content("res://scenes/main.tscn")
	for i in 50:
		await process_frame
		if root.get_node_or_null("TitleGameTransition")==null:break
	control_game()
	checks.append({"case":"root_joy_events_title_selection_and_start","passed":true})
	var c: Controllers.Human = game.world.player.controller
	game.world.player.facing = Vector2.UP
	axis(JOY_AXIS_LEFT_X,1.0)
	var primary: Vector2 = game.world.move_override.call(Vector2.RIGHT) if game.world.move_override.is_valid() else Vector2.RIGHT
	assert((c.aim_point(game.world)-game.world.player.position).normalized().dot(primary.normalized())>0.99)
	axis(JOY_AXIS_RIGHT_Y,-1.0)
	assert(c.pad_move.x>0.99 and c.pad_aim==Vector2.ZERO)
	var expected: Vector2 = primary
	assert((c.aim_point(game.world)-game.world.player.position).normalized().dot(expected.normalized())>0.99)
	var pp: int = game.world.player.pp[2]
	button(JOY_BUTTON_LEFT_SHOULDER,true);game.world._step_player(1.0/60)
	assert(game.world.player.pp[2]==pp-1)
	button(JOY_BUTTON_LEFT_SHOULDER,false);axis(JOY_AXIS_RIGHT_Y,0.0)
	assert((c.aim_point(game.world)-game.world.player.position).normalized().dot(primary.normalized())>0.99)
	axis(JOY_AXIS_LEFT_X,0.0)
	assert(c.pad_move==Vector2.ZERO and c.pad_aim==Vector2.ZERO)
	checks.append({"case":"l_movement_r_unbound_and_shoulder_skill_cast","passed":true})
	checks.append({"case":"l_stick_aim_unaffected_by_r_motion_or_release","passed":true})
	game.world.player.add_item("oran_berry",2);game.world.player.hp = 5
	button(JOY_BUTTON_DPAD_UP,true);game.world.step(1.0/60)
	var berries: int = game.world.player.berries
	for i in 5:game.world.step(1.0/60)
	assert(berries==1 and game.world.player.berries==1 and game.world.player.hp>5)
	button(JOY_BUTTON_DPAD_UP,false)
	checks.append({"case":"dpad_item_once_per_press","passed":true})
	for entry in [[JOY_AXIS_TRIGGER_LEFT,"bag"],[JOY_AXIS_TRIGGER_RIGHT,"summary"]]:
		axis(entry[0],0.8);assert(game.state=="menu" and game.menu==entry[1])
		axis(entry[0],0.95);assert(game.state=="menu" and game.menu==entry[1])
		axis(entry[0],0.0)
		if entry[1]=="bag":
			var selected: String = game.bag_screen.selected_id()
			var cursor: int = game.bag_screen.cursor
			assert(selected!="" and selected!=BagScreen.CLOSE)
			axis(JOY_AXIS_TRIGGER_RIGHT,0.8);tap(JOY_BUTTON_DPAD_RIGHT);axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
			assert(game.world.player.hotbar[1]==selected and game.bag_screen.cursor==cursor)
			checks.append({"case":"bag_rt_dpad_assigns_hotbar_without_navigation","passed":true})
		if entry[1]=="summary":
			var page: int = game.summary_screen.page
			tap(JOY_BUTTON_DPAD_RIGHT);assert(game.summary_screen.page!=page)
		tap(JOY_BUTTON_B);assert(game.state in ["fight","town"])
	checks.append({"case":"trigger_bag_summary_menu_b_back","passed":true})
	game._say_pages(["물리 패드 A로 대화합니다.","A로도 다음 쪽을 확인합니다."])
	driver.refresh_target()
	tap(JOY_BUTTON_A)
	tap(JOY_BUTTON_A)
	assert(game.state in ["fight","town"])
	tap(JOY_BUTTON_START);assert(game.state=="menu")
	axis(JOY_AXIS_LEFT_Y,-1.0);assert(game.get_viewport().gui_get_focus_owner()!=null)
	axis(JOY_AXIS_LEFT_Y,0.0);tap(JOY_BUTTON_B);assert(game.state in ["fight","town"])
	tap(JOY_BUTTON_START);tap(JOY_BUTTON_A);assert(game.state in ["fight","town"])
	checks.append({"case":"a_dialogue_b_back_and_start_menu_focus","passed":true})
	tap(JOY_BUTTON_BACK)
	assert(game.menu=="town_map" and game.fly_screen.browse_only)
	var position_before: Vector2=game.world.player.position
	tap(JOY_BUTTON_DPAD_DOWN);tap(JOY_BUTTON_A)
	assert(game.state in ["fight","town"] and game.world.player.position==position_before)
	tap(JOY_BUTTON_BACK);tap(JOY_BUTTON_B)
	assert(game.state in ["fight","town"])
	checks.append({"case":"select_town_map_view_confirm_close_and_b_cancel","passed":true})
	axis(JOY_AXIS_LEFT_X,1.0);button(JOY_BUTTON_Y,true)
	driver.set_focused(false);assert(c.pad_move==Vector2.ZERO and c.pad_keys.is_empty())
	driver.set_focused(true);axis(JOY_AXIS_LEFT_X,0.0);button(JOY_BUTTON_Y,false)
	axis(JOY_AXIS_LEFT_X,1.0);driver.connection_changed(7,false)
	assert(c.pad_move==Vector2.ZERO and c.pad_keys.is_empty())
	checks.append({"case":"focus_loss_disconnect_and_release_cleanup","passed":true})
	game.state = "gameover";driver.refresh_target()
	var old_id: int = game.get_instance_id()
	tap(JOY_BUTTON_A)
	game = await wait_content("res://scenes/main.tscn")
	assert(game.get_instance_id()!=old_id);control_game()
	checks.append({"case":"a_retry_actual_scene_reload","passed":true})
	root.get_node("MobileScreen").activate();await process_frame;await process_frame
	assert(current_scene is MobileGameFrame)
	game = MobileGameFrame.unwrap(current_scene);control_game()
	game._open_game_menu();driver.refresh_target()
	pp = game.world.player.pp[0]
	tap(JOY_BUTTON_A);assert(game.state in ["fight","town"])
	game.world._step_player(1.0/60)
	assert(game.world.player.pp[0]==pp,"A menu confirm in the embedded viewport must not also cast")
	axis(JOY_AXIS_RIGHT_X,1.0);assert(game.world.player.controller.pad_aim==Vector2.ZERO)
	axis(JOY_AXIS_RIGHT_X,0.0)
	checks.append({"case":"physical_events_in_mobile_embedded_viewport_no_double_cast","passed":true})
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	FileAccess.open(OUT+"physical_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"checks":checks,"window":"384x216","synthetic_standard_joy_events":true,"physical_hardware_tested":false,"connected_devices":Array(Input.get_connected_joypads())},"  "))
	driver.connection_changed(7,false)
	current_scene.queue_free();await process_frame
	for starter in SaveData.STARTERS:SaveData.reset_slot(starter)
	print("Physical gamepad event review passed: title, sticks, skills, tools, menus, retry and embedded viewport")
	quit()

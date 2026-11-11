extends SceneTree

const Game = preload("res://scripts/game.gd")
const OUT := "res://docs/touch_controls/active_gamepad/"
const SAVE_PATTERN := "user://mobile_screen_review_%s.cfg"
var game: Node
var checks: Array = []

func _init() -> void:call_deferred("run")

func wait_content(path: String) -> Node:
	for i in 240:
		await process_frame
		var wrapper := current_scene
		if wrapper is MobileGameFrame:
			var content := MobileGameFrame.unwrap(wrapper)
			if is_instance_valid(content) and content.scene_file_path==path:
				await process_frame
				return content
	assert(false,"Scene did not arrive: "+path)
	return null

func client_point(frame: MobileGameFrame, point: Vector2) -> Vector2:
	return frame.layout.display.position + point/Vector2(frame.logical_size)*frame.layout.display.size

func tap(at: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 0;event.position = at;event.pressed = pressed
		Input.parse_input_event(event);Input.flush_buffered_events()
		await process_frame

func snapshot_surface(surface: SubViewport, name: String) -> void:
	for i in 5:
		game.view3d._process(1.0/60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png(OUT+name+".png")

func pad_tap(pad: TouchControls, command: String, id: int = 5) -> void:
	pad.refresh()
	var point: Vector2 = pad.deck.hits[command].get_center()
	pad.pointer(id,point,"press")
	pad.pointer(id,point,"release")
	pad.refresh()

func run() -> void:
	await CaptureWindow.park(self)
	get_tree_watchdog()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	ViewScale.index = 0
	SaveData.slot_pattern = SAVE_PATTERN;SaveData.allow_migrate = false
	SaveData.path = SaveData.slot_path("charmander")
	for starter in SaveData.STARTERS:SaveData.reset_slot(starter)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("DUNGEON","kanto_world");OS.set_environment("LANG_CODE","ko")
	Game.skip_opening = true;Game.starter = "charmander";Game.carry = {};Game.destination = {};Game.arena_trip = {}
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title);current_scene = title
	var host := root.get_node("MobileScreen")
	host.activate()
	title = await wait_content("res://scenes/title.tscn")
	assert(current_scene is MobileGameFrame and title.get_viewport() is SubViewport)
	await tap(current_scene.pad.deck.hits.action.get_center())
	assert(title.menu_open)
	await tap(current_scene.pad.deck.hits.action.get_center())
	game = await wait_content("res://scenes/main.tscn")
	for i in 50:
		await process_frame
		if root.get_node_or_null("TitleGameTransition")==null:break
	game.set_process(false);game.view3d.set_process(false)
	var frame: MobileGameFrame = current_scene
	assert(frame.get_parent()==root and game.get_parent()==frame.client)
	assert(frame.scene_file_path=="res://scenes/main.tscn")
	assert(game.get_viewport().get_visible_rect().size==Vector2(384,216))
	assert(game.view3d.vp.size==frame.client.size)
	assert(game.view3d.ov.world_2d==frame.client.world_2d)
	checks.append({"case":"title_to_main_original_loading_transition","passed":true})
	# Reload uses the ordinary SceneTree API while a root proxy owns the game.
	game.bot = false;game.world.player.controller = Controllers.Human.new()
	frame.pad.refresh()
	var down_root := InputEventScreenTouch.new();down_root.index = 0;down_root.position = frame.pad.stick_center;down_root.pressed = true
	Input.parse_input_event(down_root);Input.flush_buffered_events()
	Input.action_press("move_click")
	OS.set_environment("BOT","0")
	var previous: int = game.get_instance_id()
	assert(reload_current_scene()==OK)
	game = await wait_content("res://scenes/main.tscn")
	game.set_process(false);game.view3d.set_process(false)
	assert(game.get_instance_id()!=previous)
	var c = game.world.player.controller
	assert(c is Controllers.Human and c.hold)
	assert(c.move_dir(game.world)==Vector2.ZERO and not c.has_target)
	Input.action_release("move_click")
	var release_root: InputEventScreenTouch = down_root.duplicate();release_root.pressed = false
	Input.parse_input_event(release_root);Input.flush_buffered_events()
	c.move_dir(game.world)
	assert(not c.hold)
	OS.set_environment("BOT","1")
	checks.append({"case":"held_primary_touch_reload_no_click_walk","passed":true})
	assert(change_scene_to_file("res://scenes/title.tscn")==OK)
	title = await wait_content("res://scenes/title.tscn")
	title.start_game("charmander")
	game = await wait_content("res://scenes/main.tscn")
	for i in 50:
		await process_frame
		if root.get_node_or_null("TitleGameTransition")==null:break
	game.set_process(false);game.view3d.set_process(false)
	checks.append({"case":"stock_reload_main_title_main","passed":true})
	game.bot = false;game.world.player.controller = Controllers.Human.new()
	game.state = "gameover";current_scene.pad.refresh()
	var retry_id: int = game.get_instance_id()
	await tap(current_scene.pad.deck.hits.action.get_center())
	game = await wait_content("res://scenes/main.tscn")
	game.set_process(false);game.view3d.set_process(false)
	assert(game.get_instance_id()!=retry_id)
	checks.append({"case":"lower_pad_retry_key_actual_scene_reload","passed":true})
	game.bot = false;game.world.player.controller = Controllers.Human.new()
	current_scene.pad.refresh()
	game._open_game_menu();await process_frame
	var close_button: Control = game.panel._buttons[game.panel._close_index]
	var logical_point: Vector2 = close_button.get_global_transform_with_canvas()*(close_button.size/2)
	await tap(client_point(current_scene,logical_point))
	assert(game.state!="menu","Native top-display touch reaches the existing menu")
	checks.append({"case":"native_client_touch_original_menu","passed":true})
	var blank_frame: MobileGameFrame = current_scene
	var blank: Vector2 = blank_frame.pad.control_area.position+Vector2(4,4)
	var idle_at: Vector2 = game.world.player.position
	var blank_down := InputEventScreenTouch.new();blank_down.index = 0;blank_down.position = blank;blank_down.pressed = true
	Input.parse_input_event(blank_down);Input.flush_buffered_events()
	game.world.step(1.0/60)
	assert(not game.world.player.controller.has_target and game.world.player.position.distance_to(idle_at)<0.1)
	var blank_up: InputEventScreenTouch = blank_down.duplicate();blank_up.pressed = false
	Input.parse_input_event(blank_up);Input.flush_buffered_events()
	game.world.step(1.0/60)
	assert(not game.world.player.controller.has_target and game.world.player.position.distance_to(idle_at)<0.1)
	checks.append({"case":"blank_lower_panel_touch_never_walks","passed":true})
	# Larger phone images are offscreen only. The actual window remains 384x216.
	var surface := SubViewport.new();surface.size = Vector2i(390,844)
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	var phone := MobileGameFrame.new();phone.use_display_safe_area = false;surface.add_child(phone)
	phone.set_game_size(Vector2i(384,216));await process_frame
	var original_root_game := game
	game = load("res://scenes/main.tscn").instantiate()
	phone.client.add_child(game);game.set_process(false);game.view3d.set_process(false)
	game.bot = false;game.world.player.setup_player("charmander",12,["scratch","growl","ember","smoke_screen"])
	game.world.player.controller = Controllers.Human.new()
	game.banner_t = 0;game.dialog_text = "";game.dialog_t = 0;game.last_small_message = ""
	game.status_messages.clear();game.timed_dialog_pages.clear();game.status_message_active = false
	phone.adopt(game,Vector2i(384,216))
	game.world.cam.position = game.world.player.position;game.view3d._cam_ready = false
	for entry in [[Vector2i(390,844),"portrait_390x844"],[Vector2i(360,800),"portrait_360x800"],[Vector2i(844,390),"landscape_844x390"]]:
		surface.size = entry[0];await process_frame;phone.fit();await process_frame
		assert(game.get_viewport().get_visible_rect().size==Vector2(384,216))
		assert(not phone.layout.display.intersects(phone.pad.control_area))
		assert(phone.pad.stick_center.y>phone.layout.display.end.y)
		assert(game.view3d.vp.size==phone.client.size)
		await snapshot_surface(surface,entry[1])
		checks.append({"case":entry[1],"display":str(phone.layout.display),"controls":str(phone.layout.controls),"passed":true})
	# Native touch ownership and movement in the lower area of the offscreen phone.
	surface.size = Vector2i(390,844);await process_frame;phone.fit();await process_frame
	var center: Vector2 = phone.pad.stick_center
	var down := InputEventScreenTouch.new();down.index = 0;down.position = center;down.pressed = true
	surface.push_input(down,true)
	var drag := InputEventScreenDrag.new();drag.index = 0;drag.position = center+Vector2.RIGHT*phone.pad.stick_radius()
	surface.push_input(drag,true)
	assert(game.world.player.controller.touch_move.x>0.99)
	var primary_aim: Vector2 = game.world.move_override.call(Vector2.RIGHT) if game.world.move_override.is_valid() else Vector2.RIGHT
	assert((game.world.player.controller.aim_point(game.world)-game.world.player.position).normalized().dot(primary_aim.normalized())>0.99)
	var aim_down := InputEventScreenTouch.new();aim_down.index = 2;aim_down.pressed = true;aim_down.position = phone.pad.aim_center
	surface.push_input(aim_down,true)
	var aim_drag := InputEventScreenDrag.new();aim_drag.index = 2;aim_drag.position = phone.pad.aim_center+Vector2.UP*phone.pad.aim_radius()
	surface.push_input(aim_drag,true)
	var aim_direction: Vector2 = game.world.player.controller.aim_point(game.world)-game.world.player.position
	var expected_aim: Vector2 = primary_aim
	assert(game.world.player.controller.touch_aim==Vector2.ZERO)
	assert(aim_direction.normalized().dot(expected_aim.normalized())>0.99)
	var before_pp: int = game.world.player.pp[2]
	var attack := InputEventScreenTouch.new();attack.index = 1;attack.pressed = true;attack.position = phone.pad.deck.hits.skill_2.get_center()
	surface.push_input(attack,true)
	game.world._step_player(1.0/60)
	assert(game.world.player.pp[2]==before_pp-1 and game.world.player.controller.touch_move.x>0.99)
	var aim_up: InputEventScreenTouch = aim_down.duplicate();aim_up.pressed = false;surface.push_input(aim_up,true)
	assert(game.world.player.controller.touch_aim==Vector2.ZERO)
	assert((game.world.player.controller.aim_point(game.world)-game.world.player.position).normalized().dot(primary_aim.normalized())>0.99)
	var attack_up: InputEventScreenTouch = attack.duplicate();attack_up.pressed = false;surface.push_input(attack_up,true)
	var up := InputEventScreenTouch.new();up.index = 0;up.position = drag.position;up.pressed = false
	surface.push_input(up,true)
	assert(game.world.player.controller.touch_move==Vector2.ZERO)
	checks.append({"case":"lower_pad_touch_does_not_reach_game_display","passed":true})
	checks.append({"case":"two_finger_move_and_skill_cast","passed":true})
	checks.append({"case":"r_stick_feedback_preserved_without_aim_and_shoulder_cast","passed":true})
	checks.append({"case":"l_stick_aim_unaffected_by_r_motion_or_release","passed":true})
	game.world._step_player(1.0/60)
	game.world.player.add_item("potion",1)
	for command in ["bag","summary"]:
		pad_tap(phone.pad,command)
		assert(game.state=="menu" and game.menu==command)
		if command=="bag":
			var selected: String = game.bag_screen.selected_id()
			assert(selected!="" and selected!=BagScreen.CLOSE)
			var rt: Vector2 = phone.pad.deck.hits.summary.get_center()
			phone.pad.pointer(30,rt,"press");pad_tap(phone.pad,"item_1",31)
			phone.pad.pointer(30,rt,"release")
			assert(game.world.player.hotbar[1]==selected)
		pad_tap(phone.pad,"cancel",6)
		assert(game.state in ["fight","town"])
	game._say_pages(["패드로 대화를 넘겨 보세요.","모든 키가 하단에 있습니다."])
	phone.pad.refresh()
	for i in 2:
		pad_tap(phone.pad,"action",7+i)
	assert(game.state in ["fight","town"])
	checks.append({"case":"pad_bag_summary_back_and_dialogue","passed":true})
	assert(not phone.pad.deck.hits.has("dodge") and not phone.pad.deck.hits.has("extras"))
	game._open_game_menu();phone.pad.refresh()
	pad_tap(phone.pad,"item_0",23)
	assert(phone.client.gui_get_focus_owner()!=null)
	var nav_center: Vector2 = phone.pad.stick_center
	phone.pad.pointer(20,nav_center,"press")
	phone.pad.pointer(20,nav_center+Vector2.UP*phone.pad.stick_radius(),"drag")
	assert(phone.client.gui_get_focus_owner()!=null)
	phone.pad.pointer(20,nav_center,"release")
	pad_tap(phone.pad,"cancel",21)
	assert(game.state in ["fight","town"])
	game._open_game_menu();phone.pad.refresh()
	pad_tap(phone.pad,"action",22)
	assert(game.state in ["fight","town"],"Default menu confirmation chooses safe close")
	checks.append({"case":"controller_dpad_stick_and_ab_menu_navigation","passed":true})
	pad_tap(phone.pad,"town_map",32)
	assert(game.menu=="town_map" and game.fly_screen.browse_only)
	await snapshot_surface(surface,"town_map_390x844")
	pad_tap(phone.pad,"cancel",33)
	assert(game.state in ["fight","town"])
	checks.append({"case":"select_town_map_and_b_close","passed":true})
	surface.queue_free();await process_frame;game = original_root_game
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"window":"384x216","phone_images_offscreen":true,"checks":checks,"physical_device_tested":false},"  "))
	current_scene.queue_free();await process_frame
	for starter in SaveData.STARTERS:SaveData.reset_slot(starter)
	print("Mobile controller review passed: action/cancel, four skills, town map and phone ratios")
	quit()

func get_tree_watchdog() -> void:
	create_timer(180).timeout.connect(func():push_error("Mobile review timed out");quit(1))

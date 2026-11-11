extends GutTest

class DialogueGame:
	extends "res://scripts/game.gd"
	func _ready() -> void: pass
	func _process(_dt: float) -> void: pass

func before_all() -> void: Controllers.ensure_input_map()

func after_each() -> void:
	for action in Controllers.ACTIONS: Input.action_release(action)
	await get_tree().process_frame

func fixture():
	DungeonDB.set_current("test_meadow");Arena.configure(DungeonDB.theme())
	var game := DialogueGame.new()
	add_child_autofree(game)
	game.world = World.new();game.add_child(game.world)
	game.world.setup(7,"charmander",12,["scratch"],Controllers.Human.new())
	game.world.player.position = Arena.center()
	game.state = "fight"
	return game

func mouse(game, pressed: bool = true, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button;event.pressed = pressed
	game._unhandled_input(event)

func space(game) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE;event.pressed = true
	game._unhandled_input(event)

func test_left_click_advances_exactly_one_spoken_page() -> void:
	var game = fixture()
	var speaker := Npc.new();game.add_child(speaker)
	game._say_pages(game._pages(["first|second"],speaker))
	mouse(game)
	assert_eq(game.dialog_text,"second")
	assert_eq(game.state,"talk")
	mouse(game,false)
	assert_eq(game.dialog_text,"second","Releasing a click never skips another page")

func test_closing_space_is_not_reused_as_a_jump() -> void:
	var game = fixture()
	game._say_pages(["last page"])
	Input.action_press("jump")
	space(game)
	assert_eq(game.state,"fight")
	game.world.step(1.0/60.0)
	assert_eq(game.world.player.hop_t,0.0,"The space which closed dialogue cannot jump")
	assert_true(game.world.player.dash.is_empty())

func test_releasing_and_pressing_space_again_still_jumps_normally() -> void:
	var game = fixture()
	game._say_pages(["last page"])
	Input.action_press("jump");space(game)
	for frame in 3:
		game.world.step(1.0/60.0)
		assert_eq(game.world.player.hop_t,0.0)
		await get_tree().process_frame
	Input.action_release("jump")
	game.world.step(1.0/60.0)
	await get_tree().process_frame
	Input.action_press("jump")
	game.world.step(1.0/60.0)
	assert_gt(game.world.player.hop_t,0.0,"A fresh Space remains the normal jump command")

func test_fast_space_press_release_in_the_closing_frame_does_not_jump() -> void:
	var game = fixture()
	game._say_pages(["last page"])
	Input.action_press("jump");space(game);Input.action_release("jump")
	game.world.step(1.0/60.0)
	assert_eq(game.world.player.hop_t,0.0)

func test_right_click_wheel_release_and_key_echo_do_not_skip_pages() -> void:
	var game = fixture()
	game._say_pages(["first","second"])
	for button in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:mouse(game,true,button)
	mouse(game,false)
	var echo := InputEventKey.new();echo.pressed = true;echo.echo = true;echo.physical_keycode = KEY_SPACE
	game._unhandled_input(echo)
	assert_eq(game.dialog_text,"first")

func test_click_preserves_the_sendout_animation_gate() -> void:
	var game = fixture()
	game._say_pages(["cannot skip","next page"])
	game.sendout = {"phase":"show","t":0.0,"ready_at":1.0}
	mouse(game);assert_eq(game.dialog_text,"cannot skip")
	space(game);assert_eq(game.dialog_text,"cannot skip")
	game.sendout.t = 1.0
	mouse(game);assert_eq(game.dialog_text,"next page")

func test_click_advances_narration_without_waiting_for_its_timer() -> void:
	var game = fixture()
	game._say_pages(["first narration","second narration"])
	assert_gt(game.dialog_t,0.0)
	mouse(game)
	assert_eq(game.dialog_text,"second narration")

func test_click_dismisses_timed_notice_without_creating_click_movement() -> void:
	var game = fixture()
	game._say("notice")
	var from: Vector2 = game.world.player.position
	game.world.aim_override = func() -> Vector2: return from+Vector2(70,0)
	Input.action_press("move_click");mouse(game)
	assert_true(game.dialog_text.is_empty())
	game.world.step(1.0/60.0)
	assert_eq(game.world.player.position,from)
	assert_false(game.world.player.controller.has_target)
	Input.action_release("move_click")
	game.world.step(1.0/60.0)
	await get_tree().process_frame
	Input.action_press("move_click")
	game.world.step(1.0/60.0)
	assert_gt(game.world.player.position.x,from.x,"Fresh clicks still move after dismissal")

func test_space_dismissing_timed_notice_cannot_jump() -> void:
	var game = fixture()
	game._say("notice")
	Input.action_press("jump");space(game)
	assert_true(game.dialog_text.is_empty())
	game.world.step(1.0/60.0)
	assert_eq(game.world.player.hop_t,0.0)

func test_one_click_cannot_skip_a_new_dialogue_opened_by_the_callback() -> void:
	var game = fixture()
	game._say_pages(["last"],func(): game._say_pages(["new first","new second"]))
	mouse(game)
	assert_eq(game.dialog_text,"new first")
	mouse(game,false)
	assert_eq(game.dialog_text,"new first")
	mouse(game)
	assert_eq(game.dialog_text,"new second")

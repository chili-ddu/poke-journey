extends SceneTree
func _init() -> void:
	call_deferred("run")
func key(game, code: int) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	game._unhandled_input(event)
func run() -> void:
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","1")
	OS.set_environment("DUNGEON","viridian_center")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.bot = false
	var nurse: Npc = game.world.npcs[0]
	game._say_pages(game._pages(["spoken one","spoken two"],nurse)+["narration"])
	for i in 240: game.advance(1.0/60)
	assert(game.dialog_text=="spoken one","Spoken dialogue never auto advances")
	key(game,KEY_ENTER)
	key(game,KEY_KP_ENTER)
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	game._unhandled_input(mouse)
	assert(game.dialog_text=="spoken one","Only Space advances speech")
	key(game,KEY_SPACE)
	assert(game.dialog_text=="spoken two")
	key(game,KEY_SPACE)
	assert(game.dialog_text=="narration" and game.dialog_t>0.0)
	for i in 180: game.advance(1.0/60)
	assert(game.state!="talk","Narration auto advances")
	game._say_pages(["sendout notice"],Callable())
	game.sendout = {"phase":"show","t":0.0}
	key(game,KEY_SPACE)
	assert(game.dialog_text=="sendout notice","Cannot skip unfinished sendout")
	game.sendout.clear()
	key(game,KEY_SPACE)
	assert(game.state!="talk")
	game.state = "fight"
	game.dialog_text = ""
	game._queue_status_message("first status")
	assert(game.dialog_text=="first status")
	game._queue_status_message("second status")
	assert(game.dialog_text=="second status","New event appears immediately")
	key(game,KEY_SPACE)
	assert(game.dialog_text.is_empty(),"Space dismisses combat notice")
	game._queue_status_message("auto notice")
	for i in 180: game.advance(1.0/60)
	assert(game.dialog_text.is_empty(),"Combat notices retain auto advance")
	print("Dialogue input review passed")
	game.free()
	quit()

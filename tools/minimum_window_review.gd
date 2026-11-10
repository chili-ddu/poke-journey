extends SceneTree
const Game=preload("res://scripts/game.gd")
const OUT="res://docs/minimum_test_window/"

func _init() -> void:call_deferred("run")

func run() -> void:
	var launch_size:=DisplayServer.window_get_size()
	await CaptureWindow.park(self)
	SaveData.path="user://save_minimum_window_review.cfg";SaveData.clear()
	OS.set_environment("BOT","0");OS.set_environment("DUNGEON","pokemon_tower_1f")
	Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={}
	var sizes: Array=[]
	for i in 2:
		var game=load("res://scenes/main.tscn").instantiate()
		root.add_child(game);current_scene=game;game.set_process(false)
		for frame in 6:await process_frame
		sizes.append(DisplayServer.window_get_size())
		game.free();current_scene=null
	var ok:=launch_size==CaptureWindow.VIEW and sizes.all(func(s):return s==CaptureWindow.VIEW)
	ok=ok and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) and ViewScale.window_ready
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":ok,"launch_size":launch_size,
		"after_game_initialization":sizes,"minimum_scale":CaptureWindow.SCALE,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)},"  "))
	SaveData.clear()
	print("Minimum review window: launch %s; game scenes %s; passed %s"%[launch_size,sizes,ok])
	quit(0 if ok else 1)

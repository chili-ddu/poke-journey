extends SceneTree

const Game = preload("res://scripts/game.gd")
const DT := 1.0/60.0

func _init() -> void:
	run.call_deferred()

func run() -> void:
	await CaptureWindow.park(self)
	var args := OS.get_cmdline_user_args()
	var lab := args[0] in StarterBalls.TILES
	var out := args[1]
	DirAccess.make_dir_recursive_absolute(out)
	SaveData.path = "user://ball_release_review_only.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	if lab:
		OS.set_environment("STARTER",args[0])
		OS.set_environment("OPENING","1")
		OS.set_environment("DUNGEON","oaks_lab")
	else:
		var arena := "arena_route1" if args[0]=="green" else "arena_pewter_gym"
		OS.set_environment("DUNGEON",arena)
		Game.arena_trip = {"trainer":"rival_green_squirtle" if args[0]=="green" else "leader_brock","arena":arena,"back":{"map":"kanto_world"}}
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var view: View3D = game.view3d
	if view != null: view.set_process(false)
	game.banner_t = 0.0
	if lab:
		while game.monologue: game._talk_next()
		game._talk_next()
		assert(game.opening.get("phase") == "wobble")
	else:
		game._talk_next()
		game._send_next()
	var count := 236 if lab else 106
	var opening_frame := -1
	for i in count:
		if lab:
			game._step_opening(DT)
		else:
			game._step_sendout(DT)
		if view != null and view.visible: view._process(DT)
		await process_frame
		await RenderingServer.frame_post_draw
		if i%2==0:
			var viewport: Viewport = view.vp if view != null and view.visible else root
			assert(viewport.get_texture().get_image().save_png(out.path_join("%03d.png"%i)) == OK)
		if opening_frame<0 and (game.balls.taken if lab else game.sendout.popped):
			opening_frame=i
			var mon: Mon=game.world.player if lab else game.sendout.mon
			assert(is_instance_valid(mon.release_fx) and mon.release_fx.starter_table==lab)
	assert(opening_frame>0)
	if lab:
		assert(game.world.player.position==StarterBalls.floor_of(game.starter) and game.world.player.lift==0.0)
	else:
		assert(game.sendout.mon.appear==1.0 and game.can_advance())
	print("Release OK ",args[0]," opened at frame ",opening_frame," of ",count)
	game.free()
	Game.arena_trip={}
	quit()

extends SceneTree
const DT := 1.0/60.0
var game: Node
var out := "res://docs/arena_camera_review"
func _init() -> void: call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","7")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var script = load("res://scripts/game.gd")
	for fixture in [["arena_pewter_gym","leader_brock"],["arena_viridian_forest","bug_catcher_sammy"],["arena_route1","rival_green_squirtle"]]:
		script.arena_trip={"trainer":fixture[1],"arena":fixture[0],"back":{"map":"pewter_gym"}}
		OS.set_environment("DUNGEON",fixture[0])
		game=load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene=game
		game.set_process(false)
		game.view3d.set_process(false)
		game.bot=false # Keep the normal automatic narration duration, with no bot shortcuts.
		game.banner_t=0.0
		assert(game.state=="talk" and game.battle.mon==null,"Trainer introduction precedes throw")
		for i in 15: await frame(false)
		await shot(fixture[0]+"_01_dialogue")
		var guard := 0
		while game.sendout.is_empty() and guard<500:
			await frame()
			guard+=1
		assert(not game.sendout.is_empty(),"Throw starts after introduction")
		var health: float=game.world.player.hp
		while float(game.sendout.t)<0.4: await frame()
		var ball: ThrownBall=game.sendout.ball
		assert(ball!=null and ball.visible,"Ball is visible mid-flight")
		assert(game.view3d._sprites.has(ball.get_instance_id()),"Ball has a 3D sprite")
		var ball_sprite: Sprite3D=game.view3d._sprites[ball.get_instance_id()].sprite
		assert(ball_sprite.region_enabled and ball_sprite.region_rect == BallRelease.BALL_RECT,"Whole round ball texture is rendered")
		var ball_screen: Vector2 = game.view3d.cam.unproject_position(ball_sprite.position)
		assert(ball_screen.y>0 and ball_screen.y<float(game.view3d.vp.size.y)*0.68,"Thrown ball stays above dialogue")
		await shot(fixture[0]+"_02_throw")
		while not game.sendout.is_empty() and game.sendout.phase=="show": await frame()
		assert(game.battle.mon.appear==1.0,"Monster is fully revealed before rising")
		await shot(fixture[0]+"_03_rise")
		while not game.sendout.is_empty(): await frame()
		assert(game.state=="fight","Fight starts after camera return")
		assert(game.world.player.hp==health,"Combat stayed paused during throw and reveal")
		for i in 20: await frame(false)
		await shot(fixture[0]+"_04_fight")
		var view: View3D=game.view3d
		for mon in [game.world.player,game.battle.mon]:
			var sprite: Sprite3D=view._sprites[mon.get_instance_id()].sprite
			var foot := view.cam.unproject_position(sprite.position)
			assert(foot.y>0 and foot.y<float(view.vp.size.y)*0.68,"Both combatants stay above dialogue HUD")
		var field: Array=Arena.map.arena.field
		for z in [float(field[1]),float(field[1]+field[3])]:
			var left := view.cam.unproject_position(Vector3(float(field[0]),0,z))
			var edge_right := view.cam.unproject_position(Vector3(float(field[0]+field[2]),0,z))
			assert(absf(left.y-edge_right.y)<0.1,"Both court boundaries stay horizontal")
		assert(view.cam.projection==Camera3D.PROJECTION_FRUSTUM,"Court has perspective depth")
		var top_left := view.cam.unproject_position(Vector3(float(field[0]),0,float(field[1])))
		var top_right := view.cam.unproject_position(Vector3(float(field[0]+field[2]),0,float(field[1])))
		var bottom_left := view.cam.unproject_position(Vector3(float(field[0]),0,float(field[1]+field[3])))
		var bottom_right := view.cam.unproject_position(Vector3(float(field[0]+field[2]),0,float(field[1]+field[3])))
		assert(bottom_right.x-bottom_left.x>top_right.x-top_left.x,"Near edge is wider than far edge, not a sheared parallelogram")
		var right := view.screen_move_world(Vector2.RIGHT)
		var at := view.cam.unproject_position(View3D.to3d(game.world.player.position))
		var moved := view.cam.unproject_position(View3D.to3d(game.world.player.position+right*Arena.TILE))
		assert(moved.x>at.x and absf(moved.y-at.y)<0.1,"Right input moves horizontally on screen")
		assert(view.ground_at_screen(at).distance_to(game.world.player.position)<0.1,"Mouse projection matches the shifted camera")
		var up := view.screen_move_world(Vector2.UP)
		var moved_up := view.cam.unproject_position(View3D.to3d(game.world.player.position+up*Arena.TILE))
		assert(moved_up.y<at.y and absf(moved_up.x-at.x)<0.1,"Up input stays vertical with the shifted lens")
		print(fixture[0],": dialogue -> throw -> reveal -> rise -> fight passed")
		game.free()
		await process_frame
	script.arena_trip={}
	quit()
func frame(advance: bool=true) -> void:
	if advance: game.advance(DT)
	game.view3d._process(DT)
	await process_frame
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+label+".png")

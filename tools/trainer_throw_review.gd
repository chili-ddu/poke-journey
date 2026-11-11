extends SceneTree

const OpeningPreview = preload("res://tools/trainer_throw_preview/ball_release/preview.gd")
const Game = preload("res://scripts/game.gd")
const POSE_TIMES := [0.0,0.035,0.075,0.115,0.175,0.20,0.265,0.34]
const BROCK_HANDS := [Vector2(10,24), Vector2(7,23), Vector2(6,21), Vector2(7,19),
	Vector2(6,21), Vector2(7,24), Vector2(11,25), Vector2(11,25)]

const GREEN_HANDS := [Vector2(10,25), Vector2(8,24), Vector2(6,22), Vector2(5,20),
	Vector2(5,22), Vector2(6,24), Vector2(9,25), Vector2(11,25)]

var hands := BROCK_HANDS
var opening: OpeningPreview
var sheet: Texture2D
var release := Vector3.ZERO

func _init() -> void:
	run.call_deferred()

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path = "user://trainer_throw_review_only.cfg"
	OS.set_environment("BOT","1")
	var args := OS.get_cmdline_user_args()
	var green := args.size() > 2 and args[2] == "green"
	var arena := "arena_route1" if green else "arena_pewter_gym"
	OS.set_environment("DUNGEON",arena)
	OS.set_environment("SEED","7")
	Game.arena_trip = {"trainer":"rival_green_squirtle" if green else "leader_brock", "arena":arena,
		"back":{"map":"kanto_world" if green else "pewter_gym"}}
	var foot_aligned := args[0] == "release_at_feet"
	var grounded := foot_aligned or args[0] == "release_ground"
	var release_comparison := grounded or args[0] in ["release_before","release_after"]
	var preview := args[0] == "preview" or release_comparison
	if grounded or args[0] == "release_after":
		opening = OpeningPreview.new()
		opening.grounded = grounded
		opening.foot_aligned = foot_aligned
	hands = GREEN_HANDS if green else BROCK_HANDS
	var name := "green" if green else "brock"
	sheet = ImageTexture.create_from_image(Image.load_from_file("res://tools/trainer_throw_preview/%s.png" % name))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var view: View3D = game.view3d
	view.set_process(false)
	game.banner_t = 0.0
	game.ui_layer.hide()
	game._talk_next()
	game._send_next()
	const LEAD_FRAMES := 10
	const REST_FRAMES := 9
	var landing_frame := LEAD_FRAMES-1 + roundi((Game.SEND_THROW_AT+Game.SEND_THROW)*60)
	for i in (114 if release_comparison else 65):
		var resting := grounded and i >= landing_frame and i < landing_frame+REST_FRAMES
		if resting:
			game.sendout.ball.k = 1.0
		elif i >= LEAD_FRAMES:
			game._step_sendout(1.0/60.0)
		var age := float(game.sendout.t) - Game.SEND_THROW_AT - Game.SEND_THROW
		if opening != null and game.sendout.popped:
			game.sendout.mon.appear = smoothstep(0.045,0.235,age)
			game.sendout.mon.queue_redraw()
		view._process(1.0/60.0)
		if preview: draw_preview(game,view)
		if opening != null and game.sendout.popped: opening.draw(game,view,maxf(age,0.0))
		await process_frame
		await RenderingServer.frame_post_draw
		if i % 2 == 0:
			var err := view.vp.get_texture().get_image().save_png(args[1].path_join("%02d.png" % i))
			if err != OK:
				quit(1)
				return
	print("Trainer tile ", Arena.tile_of(game.arena_trainer.position), " reveal ", game.sendout.popped, " species ", game.sendout.mon.species_id)
	game.free()
	Game.arena_trip = {}
	quit()

func draw_preview(game: Node, view: View3D) -> void:
	var t := float(game.sendout.t)
	var pose := 0
	for i in POSE_TIMES.size():
		if t >= POSE_TIMES[i]: pose = i
	if t >= 0.44: pose = 0
	var body: Sprite3D = view._sprites[game.arena_trainer.get_instance_id()].sprite
	var visual := Look.selout_frame(sheet,Rect2(32*pose,0,32,32),View3D.sky_kind(DungeonDB.current))
	body.texture = visual.tex
	body.region_rect = visual.src
	var ball: ThrownBall = game.sendout.ball
	if ball == null: return
	var sprite: Sprite3D = view._sprites[ball.get_instance_id()].sprite
	var bounds := Rect2(3,5,10,10) # Opaque bounds in the original 16px ball.
	sprite.region_enabled = true
	sprite.region_rect = bounds
	sprite.pixel_size *= 0.60
	sprite.visible = true
	var palm := view.sprite_pixel_position(body,hands[pose]+Vector2(0.5,-1.0))
	palm += view.cam.global_basis.z * 0.04
	if ball.k <= 0.00001:
		sprite.position = palm
		return
	if release == Vector3.ZERO: release = view.sprite_pixel_position(body,hands[5]+Vector2(0.5,-1.0)) + view.cam.global_basis.z*0.04
	var end := opening.ball_center(view,ball.to,game.sendout.mon) if opening != null else View3D.to3d(ball.to,0.35)
	sprite.position = release.lerp(end,ball.k) + Vector3.UP * (ball.height / Arena.TILE * 4.0 * ball.k * (1.0-ball.k))
	if opening != null and opening.grounded: opening.draw_shadow(view,sprite.position)

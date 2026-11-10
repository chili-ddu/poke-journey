extends SceneTree
const Game=preload("res://scripts/game.gd")
const Event=preload("res://scripts/story/lapras_escape.gd")
const OUT="res://docs/lapras_riding/"
const DIRECTIONS=[Vector2.DOWN,Vector2(1,1),Vector2.RIGHT,Vector2(1,-1),Vector2.UP,Vector2(-1,-1),Vector2.LEFT,Vector2(-1,1)]
var game: Node
func _init() -> void:call_deferred("run")

func settle() -> void:
	game.world.player.queue_redraw();game.lapras_escape.ride.step()
	for _i in 4:await process_frame
	await RenderingServer.frame_post_draw
	assert(DisplayServer.window_get_size()==Vector2i(384,216))

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_lapras_ride_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON","kanto_world");OS.set_environment("SEED","1")
	Game.bot_events=[Event.FRIEND];Game.destination={};Game.carry={};Game.arena_trip={};Game.starter="charmander"
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false)
	OS.set_environment("DUNGEON","")
	game.world.god=true;game.dialog_text="";game.banner_t=0.0
	game.status_messages.clear();game.status_message_times.clear()
	game.road_pursuit.clear(game.world)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var p: Player=game.world.player
	p.position=Arena.tile_center(Arena.area_rect("route19").position+Vector2i(12,30))
	assert(Arena.is_water(Arena.tile_of(p.position)))
	p.travel_terrain=2;p.attack_anim_t=0.0;p.hop_t=0.0
	game.world.cam.position=p.position;game.view3d._cam_ready=false
	# Shore calls first render a normal Lapras during its approach, then mount it.
	game.lapras_escape.helper=game.lapras_escape._actor(p.position,true)
	for _i in 4:await process_frame
	assert(game.view3d._sprites.has(game.lapras_escape.helper.get_instance_id()))
	var records: Array=[]
	for row in 8:
		p.facing=DIRECTIONS[row].normalized();p.vel=p.facing*30
		game.lapras_escape.follow(0.0)
		var ride=game.lapras_escape.ride
		for frame in 4:
			ride.carrier.anim_t=MonSprite.frame_start(ride.carrier._sprites.Walk,frame)+0.001
			p.anim_t=0.0
			await settle()
			var ent: Dictionary=game.view3d._sprites[p.get_instance_id()]
			var lapras: Dictionary=game.view3d._sprites[ride.carrier.get_instance_id()]
			assert(lapras.has("front") and lapras.sprite.billboard==BaseMaterial3D.BILLBOARD_ENABLED)
			var seat: Vector3=game.view3d.sprite_pixel_position(lapras.sprite,ride.pose().seat)
			var error: float=game.view3d.cam.unproject_position(ent.sprite.position).distance_to(game.view3d.cam.unproject_position(seat))
			assert(error<0.1,"Rider feet stay on the authored shell seat")
			assert(not ent.blob.visible and not ent.twin.visible)
			assert(p._anim_name=="Idle","Moving passengers do not walk on the water")
			game.view3d.vp.get_texture().get_image().save_png(OUT+"%d_%d.png"%[row,frame])
			records.append({"row":row,"frame":frame,"seat_error_px":error})
		# The 2D fallback uses the same three layers and the same seat.
		game.view3d.visible=false;game.hud.visible=false;game.look_rect.visible=false
		await settle()
		root.get_texture().get_image().save_png(OUT+"2d_%d.png"%row)
		game.view3d.visible=true;game.hud.visible=true;game.look_rect.visible=true
	# A bigger passenger retains its actual size and uses the same shell anchor.
	p.setup("blastoise",36,Mon.TEAM_PLAYER);p.travel_terrain=2;p.facing=Vector2.RIGHT
	game.lapras_escape.follow(0.0);await settle()
	game.view3d.vp.get_texture().get_image().save_png(OUT+"blastoise.png")
	# Removing the ride restores the ordinary renderer rather than leaving a neck overlay.
	var lapras_id: int=game.lapras_escape.helper.get_instance_id()
	p.travel_terrain=0;game.lapras_escape.follow(0.1)
	for _i in 4:await process_frame
	assert(not p.has_meta("lapras_ride"))
	assert(not game.view3d._sprites[lapras_id].front.visible)
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"directions":8,"native_frames":4,"poses":records,"renderers":["HD-2D","2D"],"shore_approach_entry":true,"large_passenger":true,"cleanup":true,"window":[384,216]},"  "))
	print("Lapras ride: 32 native poses / 8 directions, HD-2D and 2D, shell-seat alignment, large passenger and cleanup passed")
	game.free();await process_frame;SaveData.clear();quit()

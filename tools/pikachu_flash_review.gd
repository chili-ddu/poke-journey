extends "res://tools/forest_rescue_review.gd"
const Pikachu=preload("res://scripts/story/pikachu_rescue.gd")
var flash_out: String
var before: bool
var checks: Array=[]

func shot(name: String) -> void:
	for _i in 20:await process_frame
	game.pikachu_rescue.update_light()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(flash_out+name+".png")
	if before:return
	var event=game.pikachu_rescue
	var material: ShaderMaterial=event.veil.material
	var center: Vector2=material.get_shader_parameter("helper_center")
	var expected: Vector2
	if game.view3d.visible:
		expected=game.view3d.mon_focus_bounds(event.helper).position
	else:
		var helper: Mon=event.helper
		var body: Vector2=helper.position+helper.stat_overlay.xform*helper.stat_overlay.dst.get_center()
		expected=(game.world.get_canvas_transform()*body)/game.get_viewport_rect().size
	assert(center.distance_to(expected)<0.00001,"Flash is centered on Pikachu's rendered body")
	checks.append({"view":name,"center":[center.x,center.y],"center_error_uv":center.distance_to(expected)})

func run() -> void:
	await CaptureWindow.park(self)
	before="--before" in OS.get_cmdline_user_args()
	flash_out="res://docs/pikachu_flash/"+("before/" if before else "after/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(flash_out))
	SaveData.path="user://save_pikachu_flash_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	Game.bot_events=[Pikachu.FRIEND];Game.arena_trip={};Game.carry={};Game.destination={}
	for place in Pikachu.CAVES:
		await open_place(place)
		finish_talk();game.ui_root.visible=false
		var event=game.pikachu_rescue
		event.brightness=1.0
		var feet: Vector2=event.helper.position+Vector2(0,event.helper.feet_offset())
		var start:=Arena.tile_of(feet)
		# A short, reachable separation makes the actual light source clear.
		for dx in [3,2,-2,-3]:
			var goal:=start+Vector2i(dx,0)
			if not event.pathfinder.is_in_boundsv(goal) or event.pathfinder.is_point_solid(goal):continue
			var path: PackedVector2Array=event.pathfinder.get_point_path(start,goal)
			if path.size()<3 or path.size()>5:continue
			game.world.player.position=Arena.tile_center(goal)-Vector2(0,game.world.player.feet_offset());break
		game.world.player.repel_steps=99999
		game.world.cam.position=game.world.player.position
		game.view3d._cam_ready=false
		await shot(place+"_3d")
		game.view3d.visible=false
		await shot(place+"_2d")
		if not before:
			var material: ShaderMaterial=event.veil.material
			var old_center: Vector2=material.get_shader_parameter("helper_center")
			for _i in 20:event.follow(DT)
			await shot(place+"_2d_follow")
			var new_center: Vector2=material.get_shader_parameter("helper_center")
			assert(new_center.distance_to(old_center)>0.01,"The light moves with Pikachu while the player stands still")
	if not before:FileAccess.open(flash_out+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("Pikachu Flash: 2D/3D captures on both cave floors saved to ",flash_out)
	game.free();await process_frame;SaveData.clear();quit()

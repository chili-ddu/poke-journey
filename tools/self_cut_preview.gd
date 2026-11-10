extends "res://tools/direct_field_hms_review.gd"

const PREVIEW_OUT="res://docs/direct_field_hms/self_cut_preview/"
const PREVIEW_DT=0.02
const PREVIEW_FRAMES=200

func output_dir() -> String:return PREVIEW_OUT
func frame_count() -> int:return PREVIEW_FRAMES
func capture_notes() -> Dictionary:return {}

func side_tree() -> Npc:
	for tree: Npc in game.field_friends.trees:
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var at:=Arena.tile_center(tree.tile+direction)
			if Arena.is_water(Arena.tile_of(at)) or Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1:continue
			game.world.player.position=at;game.world.player.facing=(tree.position-at).normalized()
			if game.npc_in_reach()==tree:return tree
	return null

func run() -> void:
	await CaptureWindow.park(self);AudioServer.set_bus_mute(0,true)
	SaveData.path="user://save_self_cut_preview.cfg"
	OS.set_environment("GOD","1");OS.set_environment("SEED","17");OS.set_environment("LANG_CODE","ko")
	var preview_out:=output_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(preview_out))
	var frames_root:="/tmp/poke-self-cut-preview-"+str(OS.get_process_id())
	var captures: Array=[]
	for species in ["charmander","bulbasaur"]:
		await profile(species,"kanto_world",[Cut.FRIEND])
		var tree:=side_tree()
		assert(tree!=null)
		var tile:=tree.tile;var id:=tree.id;var tree_at:=tree.position
		var p: Player=game.world.player
		var initial: Vector2=p.position;var pp: Array=p.pp.duplicate()
		var camera_at: Vector2=initial.lerp(tree_at,0.5)
		game.ui_layer.hide();game.world.hold_cam=true
		game.world.cam.position=camera_at;game.view3d._cam_ready=false
		for i in 12:await process_frame
		var frames_dir: String=frames_root+"/"+species
		DirAccess.make_dir_recursive_absolute(frames_dir)
		var cut_time:=-1.0;var anim:=""
		for frame in frame_count():
			if frame==25:
				space()
				assert(game.field_friends.phase=="self_cut")
				anim=p.attack_anim
			game.advance(PREVIEW_DT)
			game.dialog_text="";game.dialog_t=0.0
			game.world.cam.position=camera_at
			if cut_time<0.0 and game.field_friends.cut:cut_time=frame*PREVIEW_DT
			assert(not is_instance_valid(game.field_friends.helper))
			assert(p.position==initial and p.pp==pp)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(frames_dir+"/%03d.png"%frame)
		assert(not Arena.solid_at(tile.x,tile.y) and game.field_friends.phase=="idle")
		captures.append({"species":species,"frames_dir":frames_dir,"frames":frame_count(),"fps":50,"duration_seconds":frame_count()*PREVIEW_DT,"command_seconds":0.5,"impact_seconds":cut_time,"animation":anim,"tree_id":id,"same_camera":true,"normal_space_input":true,"player_stationary":true,"no_helper":true,"pp_unchanged":true})
		print("Self Cut preview captured: ",species," / ",anim," / actual speed")
	var report: Dictionary={"window_size":[384,216],"art_source":"existing","runtime_animation_modified":false,"captures":captures}
	report.merge(capture_notes(),true)
	FileAccess.open(preview_out+"capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.free();await process_frame;SaveData.clear();quit()

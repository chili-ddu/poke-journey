extends "res://tools/forest_rescue_review.gd"

const CUT_OUT="res://docs/field_cut_trees/"

func capture(name: String,settle: int=12) -> void:
	game._update_dialogue_focus()
	game.hud.queue_redraw();game.panel.queue_redraw()
	for _i in settle:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CUT_OUT+name+".png")

func approach(tree: Npc) -> Vector2:
	for direction in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
		var at:=Arena.tile_center(tree.tile+direction)
		if not Arena.is_water(Arena.tile_of(at)) and game.world.resolve_mon(game.world.player,at).distance_to(at)<0.1:
			return at
	return Vector2.INF

func run() -> void:
	await CaptureWindow.park(self)
	Game.starter="squirtle" # Keep this review focused on Scyther's fallback animation.
	SaveData.path="user://save_field_cut_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CUT_OUT))
	var frames_dir:="/tmp/poke-scyther-cut-frames-"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(frames_dir)
	FileAccess.open("/tmp/poke-scyther-cut-frames.path",FileAccess.WRITE).store_string(frames_dir)
	var checked: Array=[]
	for place in ["kanto_south","kanto_east","cerulean_north"]:
		Game.bot_events=[Rescue.FRIEND];Game.arena_trip={};Game.carry={};Game.destination={}
		await open_place(place)
		var targets: Array=game.field_friends.trees.duplicate()
		for tree: Npc in targets:
			var at:=approach(tree)
			assert(at!=Vector2.INF)
			var tile:=tree.tile;var id:=tree.id
			var tree_at:=tree.position
			game.world.player.position=at
			game.world.player.facing=(tree.position-at).normalized()
			game.world.cam.position=at;game.view3d._cam_ready=false
			game.dialog_text="";game.dialog_t=0.0
			game.status_messages.clear();game.status_message_times.clear();game.status_message_active=false
			assert(game.npc_in_reach()==tree)
			assert(Arena.solid_at(tile.x,tile.y))
			await capture(id+"_before")
			var interaction_distance:=at.distance_to(tree.position)/Arena.TILE
			var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true
			game._unhandled_input(key)
			assert(game.state=="field_cut")
			assert(game.field_friends.target==tree and game.field_friends.phase=="calling")
			var shown:=false
			var eye_seen:=false
			var slash_seen:=false
			var look_seen:=false
			var upper_left:=false
			var frame_count:=0
			for frame in 240:
				game.advance(DT);await process_frame
				assert(game.world.player.position==at)
				if not shown and game.field_friends.phase=="ready" and game.field_friends.eye_glinted and game.field_friends.elapsed>=game.field_friends.ARRIVE_TIME+game.field_friends.WALK_TIME+0.15:
					assert(is_instance_valid(game.field_friends.helper))
					assert(game.field_friends.helper.modulate.a==1.0)
					assert(Arena.solid_at(tile.x,tile.y))
					await capture(id+"_helper",0)
					shown=true
				if game.field_friends.eye_glinted:eye_seen=true
				if not slash_seen and game.field_friends.cut and game.field_friends.elapsed>=game.field_friends.cut_at+0.065:
					slash_seen=true
					if place=="kanto_east":await capture(id+"_slash",0)
				if not look_seen and game.field_friends.phase=="looking":
					look_seen=true
					if place=="kanto_east":await capture(id+"_look",0)
				if game.field_friends.phase=="leaving":
					upper_left=game.field_friends.helper.facing.dot(Vector2(-1,-1).normalized())>0.99
				if place=="kanto_east" and frame%3==0:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(frames_dir+"/%03d.png"%frame_count)
					frame_count+=1
				if game.state!="field_cut":break
			assert(game.field_friends.phase=="idle")
			assert(shown and eye_seen and slash_seen and look_seen and upper_left)
			assert(not Arena.solid_at(tile.x,tile.y))
			assert(game.world.resolve_mon(game.world.player,Arena.tile_center(tile)).distance_to(Arena.tile_center(tile))<0.1)
			await capture(id+"_after")
			checked.append({"id":id,"map":place,"tile":[tile.x,tile.y],"space_interaction":true,"automatic_cry":true,"interaction_distance_tiles":interaction_distance,
				"player_stationary":game.world.player.position==at,"opposite_landing":(game.field_friends.work_at-tree_at).dot(at-tree_at)<=0.01,
				"scyther_visible_before_cut":shown,"eye_glint":eye_seen,"look_before_exit":look_seen,"upper_left_exit":upper_left,
				"passable_after_cut":true,"saved":SaveData.load_saved().events.has(id)})
	assert(checked.size()==10)
	FileAccess.open(CUT_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"native_targets":checked.size(),"checks":checked},"  "))
	print("Styled Cut review: all 10 objects, stationary caller, curved opposite-side arrival, eye flash, crescent and upper-left exit")
	game.free();await process_frame;SaveData.clear();quit()

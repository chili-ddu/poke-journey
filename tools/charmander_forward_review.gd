extends "res://tools/material_hit_fx_review.gd"

const SampleWorld = preload("res://tools/samples/charmander_forward_world.gd")
const SampleArt = preload("res://tools/samples/charmander_forward_art.gd")
const DIR := "res://docs/charmander_forward_casts/"
const CLIPS := {"scratch":54,"slash":54,"fire_fang":54,"smoke_screen":84,"dragon_breath":54,"flamethrower":54,"fire_spin":120,"inferno":54,"flare_blitz":54}

class DirectedInput extends ReviewInput:
	var direction := Vector2.RIGHT
	func aim_point(w) -> Vector2:
		return w.player.position+direction*48.0

func review_folder() -> String:
	return DIR

func new_art():
	return SampleArt.new()

func new_world():
	return SampleWorld.new()

func run() -> void:
	var output := review_folder()
	var visual := DisplayServer.get_name() != "headless"
	if visual: await CaptureWindow.park(self)
	SaveData.path="user://save_charmander_forward_review.cfg"
	var config:={"BOT":"1","GOD":"1","SEED":"7","STARTER":"charmander","DUNGEON":"kanto_south"}
	for key in config: OS.set_environment(key,config[key])
	var args:=OS.get_cmdline_user_args()
	var direction:=Vector2.RIGHT
	var folder:=""
	if "--left" in args:
		direction=Vector2.LEFT
		folder="left/"
	elif "--up" in args:
		direction=Vector2.UP
		folder="up/"
	if "--offset-pair" in args:
		folder="offset-pair/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output+folder))
	var rows:=[]
	for id: String in CLIPS:
		if args.size()>0 and not id in args: continue
		FxStyle.set_mode("custom")
		seed(7)
		var game
		var w: SampleWorld=new_world()
		var art=new_art()
		var input:=DirectedInput.new()
		input.direction=direction
		if visual:
			game=load("res://scenes/main.tscn").instantiate()
			root.add_child(game)
			current_scene=game
			game.set_process(false)
			game.stream.clear()
			game.ui_root.visible=false
			game.view3d.set_process(false)
			var old: World=game.world
			game.add_child(w)
			game.world=w
			game.view3d.world=w
			old.free()
		else:
			DungeonDB.set_current("test_meadow")
			Arena.configure(DungeonDB.theme())
			root.add_child(w)
		w.setup(7,"charmander",40,[id],input)
		w.configure(id)
		w.focused=true
		w.crowd_damage=true
		w.visibility_layer |= Look.GROUND_LAYER
		w.player.position=open_cross()-Vector2.RIGHT*30 if visual else Arena.center()
		w.player.facing=direction
		w.player.repel_steps=100000
		if visual:
			game.view3d._cam_ready=false
			art.setup(game.view3d,w,id)
		else:
			var positions: Array = [Vector2(31,0),Vector2(54,0)]
			if "--offset-pair" in args: positions = [Vector2(25,-8),Vector2(44,8)]
			for offset: Vector2 in positions:
				var foe:=Enemy.new()
				foe.setup_enemy("chansey",45,w.rng)
				foe.frozen=true
				for cd in foe.cds: foe.cds[cd]=9999
				foe.position=w.player.position+offset
				w.add_child(foe)
				w.enemies.append(foe)
		var start:=w.player.position
		var before:=int(w.player.pp[0])
		var spent:=false
		var path:=output+folder+"native/"+id+"/"
		if visual: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
		for frame in int(CLIPS[id]):
			if frame==6: input.requested=true
			w.step(1.0/30)
			spent=spent or w.player.pp[0]<before
			if visual:
				assert(w.enemies.is_empty())
				game.view3d._process(1.0/30)
				art.render(1.0/30)
				await process_frame
				await RenderingServer.frame_post_draw
				assert(root.size==Vector2i(384,216))
				root.get_texture().get_image().save_png(path+"%03d.png"%frame)
		var row:={"move":id,"spent":spent,"frames":CLIPS[id],"enemies":w.enemies.size(),"advance":w.player.position.distance_to(start),"art_frames":art.shown_frames}
		if not visual: row["contacts"]=w.enemies.map(func(e):return [e.max_hp-e.hp,e.acc_stage])
		rows.append(row)
		print(row)
		if not spent or (visual and art.shown_frames<2):
			push_error("Missing cast: "+id)
			quit(1)
			return
		if visual: game.free()
		else: w.free()
		await process_frame
	var summary:=output+folder+("native.json" if visual else "contacts.json")
	if not args.is_empty() and FileAccess.file_exists(summary):
		var saved: Array=JSON.parse_string(FileAccess.get_file_as_string(summary))
		var updated:=rows.map(func(row):return row.move)
		rows.append_array(saved.filter(func(row):return row.move not in updated))
	FileAccess.open(summary,FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()

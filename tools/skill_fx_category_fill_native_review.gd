extends "res://tools/ember_hit_variants_native_review.gd"

const CATEGORY_DEST := "res://docs/skill_fx_bases/category_fill/native/"
const CATEGORY_CASES := {
	"wisp":{"move":"will_o_wisp","distance":48.0,"role":"target","kind":"cast_visual_only"},
	"punch":{"move":"thunder_punch","distance":32.0,"role":"target","kind":"damage"}}


func load_category(kind: String,layer: String) -> Array[Texture2D]:
	var out: Array[Texture2D]=[]
	if kind=="punch" and layer=="back":return out
	var id := "fill-r3-"+kind+"-"+layer
	var folder := "res://docs/skill_fx_bases/category_fill/round3/local-review/"+id+"/"
	var meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+id+".json"))
	var image := Image.load_from_file(folder+id+".png")
	for entry in meta.frames:
		var r: Dictionary=entry.frame
		out.append(ImageTexture.create_from_image(image.get_region(Rect2i(int(r.x),int(r.y),int(r.w),int(r.h)))))
	return out

func draw_category(world: World,view: View3D,actor: Mon,nodes: Dictionary,kind: String,age: float) -> void:
	if age>=0:
		for fx in world.fxs:
			if fx.dead or fx.kind in ["text","light"] or fx.position.distance_to(actor.position)>45:continue
			if view._sprites.has(fx.get_instance_id()):
				for node in view._sprites[fx.get_instance_id()].values():
					if node is VisualInstance3D:node.visible=false
		if kind=="petal":
			for zone in world.zones:
				if zone.kind=="petal":zone.visible=false
	var duration := 2.7 if kind=="petal" else 1.0
	if age<0 or age>=duration:
		for sprite in nodes.values():sprite.visible=false
		return
	var body: Sprite3D=view._sprites[actor.get_instance_id()].sprite
	var span: float=actor._sprites.get("reference_span",32.0)
	var pixels := span*body.pixel_size*absf(body.scale.x)*1.20/40.0
	var vertical := view.cam.global_basis.y if body.billboard==BaseMaterial3D.BILLBOARD_ENABLED else Vector3.UP
	var right := view.cam.global_basis.x
	var normal := right.cross(vertical).normalized()
	var center := view.sprite_pixel_position(body,visible_body_center(body))+vertical*pixels*2
	if kind=="wisp":
		var source_body: Sprite3D=view._sprites[world.player.get_instance_id()].sprite
		var source := view.sprite_pixel_position(source_body,visible_body_center(source_body))+right*pixels*5
		var u := clampf(age/0.35,0,1)
		u=u*u*(3-2*u)
		center=source.lerp(center,u)+vertical*sin(u*PI)*pixels*3
	if kind=="petal":
		pixels=1.6/23.0 # 1.6 tiles is the existing petal zone radius.
		center=View3D.to3d(actor.position,0.30)
	for layer in ["front","back"]:
		var sprite: Sprite3D=nodes[layer]
		var textures: Array=hit_frames[kind+"-"+layer]
		if textures.is_empty():sprite.visible=false;continue
		sprite.texture=textures[mini(int(age*30),textures.size()-1)]
		sprite.visible=true;sprite.pixel_size=pixels;sprite.modulate=Color.WHITE
		sprite.position=center+normal*(0.035 if layer=="front" else -0.045)
		sprite.basis=Basis(right,vertical,normal)
		assert(not sprite.no_depth_test)

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_skill_fx_category_fill_review.cfg"
	for kind in CATEGORY_CASES:
		for layer in ["front","back"]:hit_frames[kind+"-"+layer]=load_category(kind,layer)
	var report := []
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):filter=arg.trim_prefix("--kind=")
	if filter!="" and FileAccess.file_exists(CATEGORY_DEST+"checks.json"):
		for row in JSON.parse_string(FileAccess.get_file_as_string(CATEGORY_DEST+"checks.json")):
			if row.style!=filter:report.append(row)
	for kind in CATEGORY_CASES:
		if filter!="" and filter!=kind:continue
		var spec: Dictionary=CATEGORY_CASES[kind]
		var reference_trace := []
		var matched_event := -1
		for variant in ["current","sample"]:
			seed(7)
			OS.set_environment("STARTER","squirtle" if kind in ["tail","shell"] else "charmander")
			var game=load("res://scenes/main.tscn").instantiate()
			root.add_child(game);current_scene=game
			game.set_process(false);game.view3d.set_process(false)
			game.stream.clear();game.banner_t=0;game.ui_root.visible=false
			var world: World=game.world
			world.player.position=Arena.tile_center(Vector2i(23,209))
			world.player.add_learned(spec.move);world.player.equip(0,spec.move)
			world.no_skills=false;world.player.repel_steps=100000
			var target := Enemy.new()
			target.setup_enemy("chansey",25,world.rng)
			target.position=world.player.position+Vector2.RIGHT*float(spec.distance)
			target.frozen=true
			for move in target.cds:target.cds[move]=99999.0
			world.add_child(target);world.enemies.append(target)
			var input := ReviewInput.new()
			input.target=target;world.player.controller=input
			game.view3d._cam_ready=false
			for i in 12:
				world.step_visual(1.0/60);game.view3d._process(1.0/60)
				await process_frame
			var output: String=CATEGORY_DEST+kind+"/"+variant+"/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
			var nodes := hit_nodes(game.view3d)
			var event := -1
			var seen_attack := false
			var hp := target.hp
			var trace := []
			var centers := []
			var frame_count := 104 if kind=="petal" else 66
			for frame in frame_count:
				if frame==4:input.requested=true
				var pending_before := not world.pending_casts.is_empty()
				world.step(1.0/30);game.view3d._process(1.0/30)
				seen_attack=seen_attack or world.player.attack_anim_t>0
				var activated: bool=target.hp<hp
				if spec.kind=="cast_visual_only":activated=pending_before and world.pending_casts.is_empty()
				elif spec.kind=="buff":activated=world.player.def_stage>0
				elif spec.kind=="sleep":activated=target.sleep_t>0
				elif spec.kind=="paralyze":activated=target.para_t>0
				elif spec.kind=="zone":
					for zone in world.zones:
						if zone.kind=="petal" and not zone.dead:activated=true
				if activated and event<0:event=frame
				var actor: Mon=world.player if spec.role=="self" else target
				if variant=="sample":draw_category(world,game.view3d,actor,nodes,kind,float(frame-event)/30.0 if event>=0 else -1.0)
				var body: Sprite3D=game.view3d._sprites[actor.get_instance_id()].sprite
				var center: Vector2=game.view3d.cam.unproject_position(game.view3d.sprite_pixel_position(body,visible_body_center(body)))
				if kind=="wisp":
					var source_body: Sprite3D=game.view3d._sprites[world.player.get_instance_id()].sprite
					var source_center: Vector2=game.view3d.cam.unproject_position(game.view3d.sprite_pixel_position(source_body,visible_body_center(source_body)))
					center=(center+source_center)*0.5
				centers.append([center.x,center.y])
				trace.append([target.hp,target.sleep_t,target.para_t,world.player.def_stage,target.burn_t])
				await process_frame;await RenderingServer.frame_post_draw
				assert(DisplayServer.window_get_size()==Vector2i(384,216))
				root.get_texture().get_image().save_png(output+"%03d.png"%frame)
			assert(seen_attack and event>=0,"No real cast or effect: "+kind)
			if variant=="current":reference_trace=trace;matched_event=event
			else:assert(trace==reference_trace and event==matched_event,"Gameplay mismatch: "+kind)
			assert(not nodes.front.visible and not nodes.back.visible)
			if kind=="wisp":assert(target.hp==hp and target.burn_t==0.0,"Visual study must not inflict burn")
			report.append({"style":kind,"move":spec.move,"category":MoveDB.get_move(spec.move).cat,"variant":variant,
				"event_frame":event,"damage":hp-target.hp,"max_hp":target.max_hp,"distance":spec.distance,"actor_role":spec.role,
				"event_basis":spec.kind,"explicit_shape":MoveDB.is_shaped(spec.move),"burn_applied":target.burn_t>0,"centers":centers,"trace":trace,"source_attack":seen_attack,"frames":frame_count,"window":[384,216],"production_changes":false})
			print("CATEGORY FX ",kind," ",variant," event ",event," damage ",hp-target.hp)
			game.free();current_scene=null;await process_frame
		FileAccess.open(CATEGORY_DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()

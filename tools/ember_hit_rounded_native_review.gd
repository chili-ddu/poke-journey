extends "res://tools/ember_pixelfx_native_review.gd"

const ALT_DEST := "res://docs/ember_hit_rounded/native/"
var hit_frames := {}
var visible_centers := {}

func visible_body_center(sprite: Sprite3D) -> Vector2:
	var key := "%d:%s"%[sprite.texture.get_instance_id(),str(sprite.region_rect)]
	if visible_centers.has(key):return visible_centers[key]
	var image: Image=sprite.texture.get_image()
	if image.is_compressed():image.decompress()
	image=image.get_region(Rect2i(sprite.region_rect))
	var used := image.get_used_rect()
	var total := Vector2.ZERO
	var weight := 0.0
	for y in range(used.position.y,used.end.y):
		for x in range(used.position.x,used.end.x):
			var alpha := image.get_pixel(x,y).a
			if alpha<0.5:continue
			total+=(Vector2(x,y)+Vector2(0.5,0.5))*alpha
			weight+=alpha
	var center := total/maxf(weight,1.0)
	visible_centers[key]=center
	return center

func load_hit_frames(style: String,layer: String) -> Array[Texture2D]:
	var round := "8" if style=="wrap" else "3"
	var id := "ember-hit-r"+round+"-"+style+"-"+layer
	var base := "res://docs/ember_hit_rounded/" if style=="wrap" else "res://docs/ember_hit_variants/"
	var folder := base+"round"+round+"/local-review/"+id+"/"
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+id+".json"))
	var image := Image.load_from_file(folder+id+".png")
	var out: Array[Texture2D]=[]
	for entry in metadata.frames:
		var r: Dictionary=entry.frame
		out.append(ImageTexture.create_from_image(image.get_region(Rect2i(int(r.x),int(r.y),int(r.w),int(r.h)))))
	return out

func hit_nodes(view: View3D) -> Dictionary:
	var nodes := {}
	for layer in ["front","back"]:
		var sprite: Sprite3D=view._new_sprite(BaseMaterial3D.BILLBOARD_DISABLED)
		sprite.region_enabled=false;sprite.shaded=false
		sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.no_depth_test=false;sprite.visible=false
		nodes[layer]=sprite
	return nodes

func draw_hit(world: World,view: View3D,target: Mon,nodes: Dictionary,style: String,age: float) -> bool:
	for fx in world.fxs:
		if fx.dead or fx.text!="g4_flame" or not (fx.ember_coat or fx.grounded_flame):continue
		if view._sprites.has(fx.get_instance_id()):
			var ent: Dictionary=view._sprites[fx.get_instance_id()]
			if ent.has("sprite"):(ent.sprite as Sprite3D).visible=false
	if age<0 or age>=0.85:
		for sprite in nodes.values():sprite.visible=false
		return false
	if not view._sprites.has(target.get_instance_id()):return false
	var body: Sprite3D=view._sprites[target.get_instance_id()].sprite
	var span: float=target._sprites.get("reference_span",32.0)
	var pixels := span*body.pixel_size*absf(body.scale.x)*1.20/40.0
	# Match the actor's vertical billboard plane. Camera-facing quads can
	# intersect an upright actor, putting nominally rear flames over its face.
	var vertical := view.cam.global_basis.y if body.billboard==BaseMaterial3D.BILLBOARD_ENABLED else Vector3.UP
	var right := view.cam.global_basis.x
	var normal := right.cross(vertical).normalized()
	var center := view.sprite_pixel_position(body,visible_body_center(body))+vertical*pixels*4.0
	for layer in ["front","back"]:
		var sprite: Sprite3D=nodes[layer]
		var textures: Array=hit_frames[style+"-"+layer]
		sprite.texture=textures[mini(int(age*30.0),textures.size()-1)]
		sprite.visible=true;sprite.pixel_size=pixels
		sprite.position=center+normal*(0.035 if layer=="front" else -0.045)
		sprite.basis=Basis(right,vertical,normal)
		var alpha := (0.62 if style=="wrap" else 0.88) if layer=="front" else 0.95
		sprite.modulate=Color(1,1,1,alpha)
		assert(not sprite.no_depth_test)
	return true

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("STARTER","charmander");OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_ember_hit_rounded_review.cfg"
	flight_frames=frames("flight");coat_frames=frames("coat")
	for style in ["wrap","sweep"]:
		for layer in ["front","back"]:hit_frames[style+"-"+layer]=load_hit_frames(style,layer)
	var only_wrap := "--only-wrap" in OS.get_cmdline_user_args()
	var only_new := "--only-new" in OS.get_cmdline_user_args()
	var prior_report: Array=[]
	if (only_wrap or only_new) and FileAccess.file_exists(ALT_DEST+"checks.json"):
		prior_report=JSON.parse_string(FileAccess.get_file_as_string(ALT_DEST+"checks.json"))
	var report := []
	for row in prior_report:
		if only_new:
			if row.variant not in ["wrap","sweep"]:report.append(row)
		elif row.variant!="wrap":report.append(row)
	for distance in [72.0,48.0]:
		var variants: Array=["current","previous","wrap","sweep"] if distance==72.0 else ["wrap","sweep"]
		if only_wrap:variants=["wrap"]
		if only_new:variants=["wrap","sweep"]
		var matched_damage := -1
		for row in prior_report:
			if float(row.distance)==distance:matched_damage=int(row.damage);break
		for variant in variants:
			var game=load("res://scenes/main.tscn").instantiate()
			root.add_child(game);current_scene=game
			game.set_process(false);game.view3d.set_process(false)
			game.stream.clear();game.banner_t=0;game.ui_root.visible=false
			var world: World=game.world
			world.player.position=Arena.tile_center(Vector2i(23,209))
			world.player.add_learned("ember");world.player.equip(0,"ember")
			world.no_skills=false;world.player.repel_steps=100000
			var target := Enemy.new()
			target.setup_enemy("chansey",25,world.rng)
			target.position=world.player.position+Vector2.RIGHT*distance
			target.frozen=true
			for move in target.cds:target.cds[move]=99999.0
			world.add_child(target);world.enemies.append(target)
			var input := ReviewInput.new()
			input.target=target;world.player.controller=input
			game.view3d._cam_ready=false
			for i in 12:
				world.step_visual(1.0/60.0);game.view3d._process(1.0/60.0)
				await process_frame
			var output: String=ALT_DEST+str(int(distance))+"/"+variant+"/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
			var nodes := hit_nodes(game.view3d)
			var hit_start := -1
			var seen_attack := false
			var seen_hit := false
			var hp := target.hp
			for frame in 54:
				if frame==4:input.requested=true
				world.step(1.0/30.0);game.view3d._process(1.0/30.0)
				seen_attack=seen_attack or world.player.attack_anim_t>0.0
				if target.hp<hp and hit_start<0:hit_start=frame
				if variant=="previous":apply_preview(world,game.view3d)
				elif variant in ["wrap","sweep"]:
					var age := float(frame-hit_start)/30.0 if hit_start>=0 else -1.0
					seen_hit=draw_hit(world,game.view3d,target,nodes,variant,age) or seen_hit
				await process_frame
				await RenderingServer.frame_post_draw
				assert(DisplayServer.window_get_size()==Vector2i(384,216))
				root.get_texture().get_image().save_png(output+"%03d.png"%frame)
			var damage: int=hp-target.hp
			assert(seen_attack and damage>0)
			if matched_damage<0:matched_damage=damage
			else:assert(damage==matched_damage)
			if variant in ["wrap","sweep"]:
				assert(seen_hit and not nodes.front.visible and not nodes.back.visible)
			report.append({"distance":distance,"variant":variant,"damage":damage,"max_hp":target.max_hp,
				"hit_frame":hit_start,"source_attack":seen_attack,"new_hit":seen_hit,
				"window":[384,216],"depth_test":true,"production_changes":false})
			print("EMBER HIT ",distance," ",variant," hit ",hit_start," damage ",damage," HP ",target.hp,"/",target.max_hp)
			game.free();current_scene=null;await process_frame
	FileAccess.open(ALT_DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()

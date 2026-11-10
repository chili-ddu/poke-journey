extends "res://tools/ember_hit_variants_native_review.gd"

const BATCH_DEST := "res://docs/skill_fx_bases/batch1/native/"
const CASES := {"fire":"ember","water":"water_gun","electric":"thunder_shock","grass":"razor_leaf"}

class LeafReviewInput:
	extends ReviewInput
	func aim_point(w) -> Vector2:
		return w.player.position+(target.position-w.player.position).rotated(deg_to_rad(12.0))

func load_base(kind: String,layer: String) -> Array[Texture2D]:
	var round := "4" if kind=="fire" else "3"
	var id := "base-r"+round+"-"+kind+"-"+layer
	var folder := "res://docs/skill_fx_bases/batch1/round"+round+"/local-review/"+id+"/"
	var meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+id+".json"))
	var image := Image.load_from_file(folder+id+".png")
	var out: Array[Texture2D]=[]
	for entry in meta.frames:
		var r: Dictionary=entry.frame
		out.append(ImageTexture.create_from_image(image.get_region(Rect2i(int(r.x),int(r.y),int(r.w),int(r.h)))))
	return out

func draw_base(world: World,view: View3D,target: Mon,nodes: Dictionary,kind: String,age: float) -> void:
	# Review-only hide of cosmetic hit sprites. Projectiles, lights, tint and
	# body reaction remain the actual production cast. No World mutation.
	if age>=0:
		for fx in world.fxs:
			if fx.dead or fx.kind in ["text","light"] or fx.position.distance_to(target.position)>40:continue
			if view._sprites.has(fx.get_instance_id()):
				var ent: Dictionary=view._sprites[fx.get_instance_id()]
				for node in ent.values():
					if node is VisualInstance3D:node.visible=false
	if age<0 or age>=0.9:
		for sprite in nodes.values():sprite.visible=false
		return
	var body: Sprite3D=view._sprites[target.get_instance_id()].sprite
	var span: float=target._sprites.get("reference_span",32.0)
	var pixels := span*body.pixel_size*absf(body.scale.x)*1.20/40.0
	var vertical := view.cam.global_basis.y if body.billboard==BaseMaterial3D.BILLBOARD_ENABLED else Vector3.UP
	var right := view.cam.global_basis.x
	var normal := right.cross(vertical).normalized()
	var center := view.sprite_pixel_position(body,visible_body_center(body))+vertical*pixels*(0 if kind=="water" else 4)
	for layer in ["front","back"]:
		var sprite: Sprite3D=nodes[layer]
		var textures: Array=hit_frames[kind+"-"+layer]
		sprite.texture=textures[mini(int(age*30),textures.size()-1)]
		sprite.visible=true;sprite.pixel_size=pixels
		sprite.position=center+normal*(0.035 if layer=="front" else -0.045)
		sprite.basis=Basis(right,vertical,normal)
		sprite.modulate=Color.WHITE
		assert(not sprite.no_depth_test)

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("STARTER","charmander");OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_skill_fx_batch1_review.cfg"
	for kind in CASES:
		for layer in ["front","back"]:hit_frames[kind+"-"+layer]=load_base(kind,layer)
	var report := []
	var refresh := "--refresh" in OS.get_cmdline_user_args()
	var grass_only := "--grass-only" in OS.get_cmdline_user_args()
	var prior: Array=[]
	if refresh or grass_only:
		prior=JSON.parse_string(FileAccess.get_file_as_string(BATCH_DEST+"checks.json"))
		for row in prior:
			if grass_only:
				if row.type!="grass":report.append(row)
			elif not (row.variant=="sample" and row.type in ["fire","water"]):report.append(row)
	for kind in CASES:
		if refresh and kind not in ["fire","water"]:continue
		if grass_only and kind!="grass":continue
		var matched_damage := -1
		var matched_hit := -1
		for row in prior:
			if refresh and row.type==kind and row.variant=="current":matched_damage=int(row.damage);matched_hit=int(row.hit_frame)
		for variant in ["current","sample"]:
			if refresh and variant=="current":continue
			var game=load("res://scenes/main.tscn").instantiate()
			root.add_child(game);current_scene=game
			game.set_process(false);game.view3d.set_process(false)
			game.stream.clear();game.banner_t=0;game.ui_root.visible=false
			var world: World=game.world
			world.player.position=Arena.tile_center(Vector2i(23,209))
			world.player.add_learned(CASES[kind]);world.player.equip(0,CASES[kind])
			world.no_skills=false;world.player.repel_steps=100000
			var target := Enemy.new()
			target.setup_enemy("chansey",25,world.rng)
			var distance := 48.0 if kind=="grass" else 72.0
			target.position=world.player.position+Vector2.RIGHT*distance
			target.frozen=true
			for move in target.cds:target.cds[move]=99999.0
			world.add_child(target);world.enemies.append(target)
			var input: RefCounted=LeafReviewInput.new() if kind=="grass" else ReviewInput.new()
			input.target=target;world.player.controller=input
			game.view3d._cam_ready=false
			for i in 12:
				world.step_visual(1.0/60);game.view3d._process(1.0/60)
				await process_frame
			var output: String=BATCH_DEST+kind+"/"+variant+"/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
			var nodes := hit_nodes(game.view3d)
			var hit_start := -1
			var seen_attack := false
			var hp := target.hp
			for frame in 66:
				if frame==4:input.requested=true
				world.step(1.0/30);game.view3d._process(1.0/30)
				seen_attack=seen_attack or world.player.attack_anim_t>0
				if target.hp<hp and hit_start<0:hit_start=frame
				if variant=="sample":
					var age := float(frame-hit_start)/30 if hit_start>=0 else -1.0
					draw_base(world,game.view3d,target,nodes,kind,age)
				await process_frame;await RenderingServer.frame_post_draw
				assert(DisplayServer.window_get_size()==Vector2i(384,216))
				root.get_texture().get_image().save_png(output+"%03d.png"%frame)
			var damage: int=hp-target.hp
			assert(seen_attack and hit_start>=0 and damage>0)
			if matched_damage<0:matched_damage=damage;matched_hit=hit_start
			else:assert(damage==matched_damage and hit_start==matched_hit)
			assert(not nodes.front.visible and not nodes.back.visible)
			report.append({"type":kind,"move":CASES[kind],"variant":variant,"damage":damage,"max_hp":target.max_hp,
				"hit_frame":hit_start,"distance":distance,"source_attack":seen_attack,"window":[384,216],"depth_test":true,"expired":true,"production_changes":false})
			print("BASE FX ",kind," ",variant," hit ",hit_start," damage ",damage)
			game.free();current_scene=null;await process_frame
	FileAccess.open(BATCH_DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()

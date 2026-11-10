extends "res://tools/ember_hit_variants_native_review.gd"

const DIR_DEST := "res://docs/directional_special_fx/native/"
const DIRECTIONS := {"right":Vector2.RIGHT,"left":Vector2.LEFT,"front":Vector2.UP,"back":Vector2.DOWN}
const SPECIALS := {"fire":"ember","water":"water_gun"}

class ContactDummy:
	extends Enemy
	var contacts := []
	func play_hit_feedback(type: String,category: String,direction: Vector2) -> void:
		super.play_hit_feedback(type,category,direction)
		var w: World=get_parent()
		var candidates := []
		# Called synchronously inside World.apply_hit before the active projectile
		# is marked dead. Require exactly one eligible colliding projectile.
		for p in w.projectiles:
			if p.dead or p.team==team:continue
			if p.position.distance_to(position+Vector2(0,-radius*0.2))<p.hit_radius()+radius:
				candidates.append({"velocity":p.vel,"id":p.get_instance_id(),"position":p.position})
		assert(candidates.size()==1,"Ambiguous hit projectile: "+str(candidates.size()))
		contacts.append({"velocity":candidates[0].velocity,"normal":direction,"candidates":candidates.size()})

func open_cross() -> Vector2:
	var origin := Vector2i(23,209)
	for r in range(10):
		for y in range(-r,r+1):
			for x in range(-r,r+1):
				if maxi(absi(x),absi(y))!=r:continue
				var center := Arena.tile_center(origin+Vector2i(x,y))
				var valid := true
				for dir in DIRECTIONS.values():
					for distance in range(0,49,8):
						var p: Vector2=center-dir*distance
						if Arena.blocks(p,12.0) or absf(Arena.ground_height(p)-Arena.ground_height(center))>0.01:valid=false
				if valid:return center
	assert(false,"No open four-way fixture")
	return Vector2.ZERO

func load_direction(kind: String,direction: String,layer: String) -> Array[Texture2D]:
	var id := "dir-r4-"+kind+"-"+direction+"-"+layer
	var folder := "res://docs/directional_special_fx/round4/local-review/"+id+"/"
	var meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+id+".json"))
	var image := Image.load_from_file(folder+id+".png")
	var out: Array[Texture2D]=[]
	for entry in meta.frames:
		var r: Dictionary=entry.frame
		out.append(ImageTexture.create_from_image(image.get_region(Rect2i(int(r.x),int(r.y),int(r.w),int(r.h)))))
	return out

func contact_style(view: View3D,target: Mon,velocity: Vector2) -> String:
	var motion := Vector3(velocity.x,0,velocity.y).normalized()
	var horizontal := motion.dot(view.cam.global_basis.x)
	if absf(horizontal)>.7:return "right" if horizontal>0 else "left"
	var toward := view.cam.global_position-View3D.to3d(target.position)
	toward.y=0;toward=toward.normalized()
	return "back" if motion.dot(toward)>0 else "front"

func draw_direction(world: World,view: View3D,target: Mon,nodes: Dictionary,kind: String,direction: String,age: float) -> void:
	if age>=0:
		for fx in world.fxs:
			if fx.dead or fx.kind in ["text","light"] or fx.position.distance_to(target.position)>38:continue
			if view._sprites.has(fx.get_instance_id()):
				for node in view._sprites[fx.get_instance_id()].values():
					if node is VisualInstance3D:node.visible=false
	if age<0 or age>=1.0:
		for sprite in nodes.values():sprite.visible=false
		return
	var body: Sprite3D=view._sprites[target.get_instance_id()].sprite
	var span: float=target._sprites.get("reference_span",32.0)
	var pixels := span*body.pixel_size*absf(body.scale.x)*1.2/40.0
	var vertical := view.cam.global_basis.y if body.billboard==BaseMaterial3D.BILLBOARD_ENABLED else Vector3.UP
	var right := view.cam.global_basis.x
	var normal := right.cross(vertical).normalized()
	var center := view.sprite_pixel_position(body,visible_body_center(body))+vertical*pixels*(-6 if kind=="water" else 3)
	for layer in ["front","back"]:
		var sprite: Sprite3D=nodes[layer]
		var textures: Array=hit_frames[kind+"-"+direction+"-"+layer]
		sprite.texture=textures[mini(int(age*30),textures.size()-1)]
		sprite.visible=true;sprite.pixel_size=pixels;sprite.modulate=Color.WHITE
		sprite.position=center+normal*(0.035 if layer=="front" else -0.045)
		sprite.basis=Basis(right,vertical,normal)
		assert(not sprite.no_depth_test)

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("STARTER","charmander");OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_directional_special_review.cfg"
	for kind in SPECIALS:
		for direction in DIRECTIONS:
			for layer in ["front","back"]:hit_frames[kind+"-"+direction+"-"+layer]=load_direction(kind,direction,layer)
	var report := []
	var filter := ""
	var samples_only := "--samples-only" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):filter=arg.trim_prefix("--case=")
	if (filter!="" or samples_only) and FileAccess.file_exists(DIR_DEST+"checks.json"):
		for row in JSON.parse_string(FileAccess.get_file_as_string(DIR_DEST+"checks.json")):
			if samples_only:
				if row.variant=="current":report.append(row)
			elif row.case!=filter:report.append(row)
	for kind in SPECIALS:
		for direction in DIRECTIONS:
			var case_id: String=kind+"-"+direction
			if filter!="" and case_id!=filter:continue
			var reference_trace := []
			var reference_hit := -1
			for row in report:
				if samples_only and row.case==case_id and row.variant=="current":reference_trace=row.trace;reference_hit=int(row.hit_frame)
			for variant in ["current","sample"]:
				if samples_only and variant=="current":continue
				seed(7)
				var game=load("res://scenes/main.tscn").instantiate()
				root.add_child(game);current_scene=game
				game.set_process(false);game.view3d.set_process(false)
				game.stream.clear();game.banner_t=0;game.ui_root.visible=false
				var world: World=game.world
				var at := open_cross()
				world.player.position=at-DIRECTIONS[direction]*48.0
				world.player.add_learned(SPECIALS[kind]);world.player.equip(0,SPECIALS[kind])
				world.no_skills=false;world.player.repel_steps=100000
				var target := ContactDummy.new()
				target.setup_enemy("chansey",25,world.rng)
				target.position=at;target.frozen=true
				for move in target.cds:target.cds[move]=99999.0
				world.add_child(target);world.enemies.append(target)
				var input := ReviewInput.new()
				input.target=target;world.player.controller=input
				game.view3d._cam_ready=false
				for i in 12:
					world.step_visual(1.0/60);game.view3d._process(1.0/60);await process_frame
				var output: String=DIR_DEST+case_id+"/"+variant+"/"
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
				var nodes := hit_nodes(game.view3d)
				var hit_start := -1
				var seen_attack := false
				var hp := target.hp
				var trace := []
				var centers := []
				var measured := ""
				var incoming := Vector2.ZERO
				for frame in 60:
					if frame==4:input.requested=true
					world.step(1.0/30);game.view3d._process(1.0/30)
					seen_attack=seen_attack or world.player.attack_anim_t>0
					if target.hp<hp and hit_start<0:
						hit_start=frame;assert(not target.contacts.is_empty())
						incoming=target.contacts[0].velocity
						measured=contact_style(game.view3d,target,incoming)
						assert(measured==direction,"Unexpected camera direction "+measured+" / "+direction)
					if variant=="sample":draw_direction(world,game.view3d,target,nodes,kind,measured,float(frame-hit_start)/30 if hit_start>=0 else -1.0)
					var body: Sprite3D=game.view3d._sprites[target.get_instance_id()].sprite
					var center: Vector2=game.view3d.cam.unproject_position(game.view3d.sprite_pixel_position(body,visible_body_center(body)))
					centers.append([center.x,center.y]);trace.append([float(target.hp),target.sleep_t,target.para_t,target.burn_t])
					await process_frame;await RenderingServer.frame_post_draw
					assert(DisplayServer.window_get_size()==Vector2i(384,216))
					root.get_texture().get_image().save_png(output+"%03d.png"%frame)
				assert(seen_attack and hit_start>=0)
				if variant=="current":reference_trace=trace;reference_hit=hit_start
				else:assert(trace==reference_trace and hit_start==reference_hit)
				assert(not nodes.front.visible and not nodes.back.visible)
				report.append({"case":case_id,"kind":kind,"direction":direction,"measured_direction":measured,"variant":variant,
					"hit_frame":hit_start,"damage":hp-target.hp,"max_hp":target.max_hp,"velocity":[incoming.x,incoming.y],
					"projectile_candidates":target.contacts[0].candidates,"fixture":[at.x,at.y],"trace":trace,"centers":centers,
					"window":[384,216],"source_attack":seen_attack,"expired":true,"production_changes":false})
				print("DIRECTIONAL FX ",case_id," ",variant," hit ",hit_start," damage ",hp-target.hp," velocity ",incoming)
				game.free();current_scene=null;await process_frame
			FileAccess.open(DIR_DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()

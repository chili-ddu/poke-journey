extends "res://tools/material_hit_fx_review.gd"

# Isolated cast/travel study. The already-selected reaction renderer is shared
# by both variants. No production scripts or combat data are modified.
const Subject = preload("res://tools/samples/reference_reaction_enemy.gd")
const Feedback = preload("res://tools/samples/status_motion_preview.gd")
const DELIVERY_MOVES := {"fire":"ember","water":"water_gun","electric":"thunder_shock","leaf":"razor_leaf","wind":"gust","psychic":"confusion"}
const CASTERS := {"fire":"charmander","water":"squirtle","electric":"pikachu","leaf":"bulbasaur","wind":"pidgey","psychic":"abra"}
const STYLES := {"fire":"material","water":"ribbon","electric":"ribbon","leaf":"material","wind":"ribbon","psychic":"quiet"}
const FLOW := {"right":Vector2.RIGHT,"left":Vector2.LEFT,"up":Vector2.UP,"down":Vector2.DOWN}
const WIDTHS := {"fire":36.0,"water":38.0,"electric":34.0,"leaf":40.0,"wind":46.0,"psychic":38.0}
var textures := {}
var preview_round := 2
var offsets := {}
var delivery_nodes := {}
var light_defaults := {}

# Hooks let a separate study reuse the identical fixture/feedback without
# overwriting an earlier set of samples.
func study_moves() -> Dictionary: return DELIVERY_MOVES
func study_variants() -> Array: return ["existing","sample"]
func study_destination() -> String: return "res://docs/skill_delivery_study/native-r%d/"%preview_round
func study_save_path() -> String: return "user://save_skill_delivery_study.cfg"
func study_frame_count() -> int: return 60
func study_distance(_kind: String="") -> float: return 48.0
func study_prepare(_world: World,_target: Mon,_direction: Vector2) -> void: pass
func study_reset(_variant: String) -> void: pass
func study_metrics() -> Dictionary: return {}
func draw_reference(_view: View3D,_world: World,_kind: String,_cast: Sprite3D,_age: float) -> void: pass
func draw_variant(_variant: String,view: View3D,world: World,kind: String,cast: Sprite3D,age: float) -> int:
	return draw_delivery(view,world,kind,cast,age)

func load_study(kind: String,stage: String) -> Array[Texture2D]:
	var id := "delivery-r%d-%s-%s-%s" % [preview_round,kind,STYLES[kind],stage]
	var folder := "res://docs/skill_delivery_study/round%d/local-review/%s/" % [preview_round,id]
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+id+".json"))
	var image:=Image.load_from_file(folder+id+".png")
	var result: Array[Texture2D]=[]
	for cell in metadata.frames:
		var r: Dictionary=cell.frame
		result.append(ImageTexture.create_from_image(image.get_region(Rect2i(int(r.x),int(r.y),int(r.w),int(r.h)))))
	return result

func emitter_point(view: View3D,mon: Mon,kind: String,direction: Vector2) -> Vector3:
	var body: Sprite3D=view._sprites[mon.get_instance_id()].sprite
	var image: Image=body.texture.get_image()
	if image.is_compressed():image.decompress()
	var region:=Rect2i(body.region_rect) if body.region_enabled else Rect2i(Vector2i.ZERO,image.get_size())
	var used:=image.get_region(region).get_used_rect()
	var fraction: float={"fire":.30,"water":.38,"electric":.35,"leaf":.18,"wind":.46,"psychic":.25}[kind]
	var point:=Vector2(used.get_center().x,used.position.y+used.size.y*fraction)
	var forward: Vector3=view.to3d(mon.position+direction,0)-view.to3d(mon.position,0)
	var amount: float=-.22 if kind=="leaf" else .2 if kind=="wind" else .55
	return view.sprite_pixel_position(body,point)+forward*mon.radius*amount

func sprite_node(view: View3D) -> Sprite3D:
	var sprite:=view._new_sprite(BaseMaterial3D.BILLBOARD_DISABLED)
	sprite.region_enabled=false;sprite.shaded=false;sprite.visible=false;sprite.no_depth_test=false
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite

func draw_delivery(view: View3D,world: World,kind: String,cast_node: Sprite3D,cast_age: float) -> int:
	for sprite: Sprite3D in delivery_nodes.values():sprite.visible=false
	var seen:=0
	for p: Projectile in world.projectiles:
		if p.dead or not view._sprites.has(p.get_instance_id()):continue
		var ent: Dictionary=view._sprites[p.get_instance_id()]
		# Hide only the existing flight geometry; preserve native hit/state FX.
		for node in ent.values():
			if node is GeometryInstance3D:node.visible=false
		var id:=p.get_instance_id()
		if not delivery_nodes.has(id):delivery_nodes[id]=sprite_node(view)
		var sprite: Sprite3D=delivery_nodes[id]
		var frames: Array=textures[kind+"-flight"]
		sprite.texture=frames[int(p.age*30.0)%frames.size()]
		var base:=view.to3d(p.position+Vector2(0,6),6.0/Arena.TILE*view.k)
		if not offsets.has(id):
			var start:=view.to3d(p.launch_position+Vector2(0,6),6.0/Arena.TILE*view.k)
			offsets[id]=emitter_point(view,world.player,kind,p.vel.normalized())-start
		var progress:=clampf(1.0-p.range_left/maxf(.001,p.range_full),0.0,1.0)
		sprite.position=base+(offsets[id] as Vector3)*(1.0-progress)
		var flow:=view.to3d(p.position+p.vel.normalized(),0)-view.to3d(p.position,0)
		var angle:=atan2(flow.dot(view.cam.global_basis.y),flow.dot(view.cam.global_basis.x))
		sprite.basis=view.cam.global_basis*Basis(Vector3.BACK,angle)
		sprite.pixel_size=float(WIDTHS[kind])/48.0/Arena.TILE
		sprite.modulate=Color.WHITE;sprite.visible=true
		if ent.has("light"):
			ent.light.position=sprite.position
			if not light_defaults.has(id):light_defaults[id]=ent.light.light_energy
			# Preserve a local travelling light without bleaching the ground.
			if preview_round>=3 and kind=="electric":ent.light.light_energy=float(light_defaults[id])*.22
		assert(not sprite.no_depth_test)
		seen+=1
	cast_node.visible=cast_age>=0.0 and cast_age<0.4
	if cast_node.visible:
		var frames: Array=textures[kind+"-cast"]
		cast_node.texture=frames[mini(int(cast_age*30.0),frames.size()-1)]
		cast_node.position=emitter_point(view,world.player,kind,world.player.facing)
		cast_node.basis=view.cam.global_basis
		cast_node.pixel_size=26.0/48.0/Arena.TILE
	return seen

func snapshot(world: World,target: Mon) -> Array:
	var state:=state_trace(target)
	state.append_array([target.confuse_t,target.hurt_t,target.hitstop_t,target.position.x,target.position.y,world.player.attack_anim_t,world.player.pp.duplicate(),str(world.rng.state)])
	var projectiles:=[]
	for p: Projectile in world.projectiles:
		projectiles.append([p.style,p.position.x,p.position.y,p.vel.x,p.vel.y,p.radius,p.grow,p.range_left,p.age,p.dead])
	state.append(projectiles)
	return state

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("DUNGEON","kanto_south")
	SaveData.path=study_save_path()
	var filter:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--round="):preview_round=int(arg.trim_prefix("--round="))
		if arg.begins_with("--dir="):filter=arg.trim_prefix("--dir=")
	var moves:=study_moves()
	for kind: String in moves:
		for stage in ["cast","flight"]:textures[kind+"-"+stage]=load_study(kind,stage)
	var dest:=study_destination()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest))
	var report:=[]
	for kind: String in moves:
		for direction: String in FLOW:
			if filter!="" and direction!=filter:continue
			var reference:=[];var reference_hit:=-1
			for variant in study_variants():
				seed(7)
				OS.set_environment("STARTER",CASTERS[kind])
				var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
				game.set_process(false);game.view3d.set_process(false)
				game.stream.clear();game.banner_t=0;game.ui_root.visible=false
				var world: World=game.world
				var at:=open_cross()
				world.player.setup_player(CASTERS[kind],20,[moves[kind]])
				world.player.position=at-(FLOW[direction] as Vector2)*study_distance(kind)
				world.no_skills=false;world.player.repel_steps=100000
				var target=Subject.new();target.reference_preview=true
				target.setup_enemy("chansey",25,world.rng);target.position=at;target.frozen=true
				for move in target.cds:target.cds[move]=99999.0
				world.add_child(target);world.enemies.append(target)
				study_prepare(world,target,FLOW[direction])
				var input:=ReviewInput.new();input.target=target;world.player.controller=input
				game.view3d._cam_ready=false
				for i in 12:
					world.step_visual(1.0/60);game.view3d._process(1.0/60);await process_frame
				var feedback=Feedback.new(game.view3d);feedback.observe(target,0.0)
				var cast:=sprite_node(game.view3d)
				offsets={};delivery_nodes={};light_defaults={}
				study_reset(variant)
				var folder: String=dest+kind+"-"+direction+"/"+variant+"/"
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
				var trace:=[];var centers:=[];var target_visible:=[];var seen_ids:={}
				var hp: int=target.hp;var hit_frame:=-1;var cast_start:=-100.0;var count:=0
				for frame in study_frame_count():
					var now:=float(frame)/30.0
					if frame==4:input.requested=true;cast_start=now
					world.step(1.0/30.0)
					if target.hp<hp:
						feedback.hit(now);hp=target.hp
						if hit_frame<0:hit_frame=frame
					feedback.observe(target,now)
					game.view3d._process(1.0/30.0)
					if hit_frame>=0:feedback.hide_old_fx(world,game.view3d,target)
					var body: Sprite3D=game.view3d._sprites[target.get_instance_id()].sprite
					var pixel:=visible_body_center(body)
					var center: Vector2=game.view3d.cam.unproject_position(game.view3d.sprite_pixel_position(body,pixel))
					feedback.draw(game.view3d,target,pixel,now)
					if variant=="existing":draw_reference(game.view3d,world,kind,cast,now-cast_start)
					else:count+=draw_variant(variant,game.view3d,world,kind,cast,now-cast_start)
					for p: Projectile in world.projectiles:seen_ids[p.get_instance_id()]=true
					trace.append(snapshot(world,target));centers.append([center.x,center.y]);target_visible.append(body.visible)
					await process_frame;await RenderingServer.frame_post_draw
					assert(DisplayServer.window_get_size()==Vector2i(384,216))
					root.get_texture().get_image().save_png(folder+"%03d.png"%frame)
				assert(hit_frame>=0 and target.hp<target.max_hp,"Real skill must hit")
				if variant=="existing":reference=trace;reference_hit=hit_frame
				else:
					assert(trace==reference and hit_frame==reference_hit,"Cast/travel preview changed combat state or trajectories")
					assert(count>0 and not cast.visible)
					assert(delivery_nodes.values().all(func(s):return not s.visible),"No flight ghost after the projectile is gone")
				report.append({"kind":kind,"move":moves[kind],"caster":CASTERS[kind],"direction":direction,"variant":variant,"hit_frame":hit_frame,"damage":target.max_hp-target.hp,
					"projectile_count":seen_ids.size(),"trace":trace,"target_visible":target_visible,"centers":centers,"window":[384,216],"production_changes":false,"hit_feedback_shared":true})
				report[-1]["material_metrics"]=study_metrics()
				print("DELIVERY ",kind," ",direction," ",variant," hit ",hit_frame," damage ",target.max_hp-target.hp)
				game.free();current_scene=null;await process_frame
		FileAccess.open(dest+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()

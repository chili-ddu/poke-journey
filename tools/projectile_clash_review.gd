extends "res://tools/ranged_origin_review.gd"

const ClashWorld=preload("res://tools/samples/projectile_clash_world.gd")
const StopWorld=preload("res://tools/samples/clash_stop_world.gd")
const MeleeCut=preload("res://tools/samples/clash_melee_cut.gd")
const CLOSE_CASES=["even_melee","strong_melee"]
const CLASH_PATH="res://docs/projectile_clash/"
const POWER_CASES={"water_wins":[30,50],"equal":[50,50],"fire_wins":[50,30]}
const TYPE_CASES=["full_water","base_subtract","type_subtract"]
const RECIPIENTS={"weak_recipient":"charmander","neutral_recipient":"castform"}
var vapor_sheet: Texture2D
var use_fragments:=false
var fragment_glint:=false
var fleck_variant:=""
var momentum_study:=false
var residual_study:=false
var shimmer_study:=false
var broken_only:=false
var color_review:=false
var original_palette:=false
var scaled_cuts:=false
var momentum_art: Dictionary={}
var rebound_study:=false
var stop_study:=false
var cells: Array
var failures: Array[String]=[]

func run() -> void:
	SaveData.path="user://projectile_clash_preview_private.cfg"
	for pair in [["BOT","1"],["SEED","7"],["STARTER","charmander"],["DUNGEON","kanto_south"]]:
		OS.set_environment(pair[0],pair[1])
	await CaptureWindow.park(self)
	var fleck_study:="--flecks" in OS.get_cmdline_user_args()
	var melee_only:="--caster-cuts" in OS.get_cmdline_user_args()
	scaled_cuts="--scaled-cuts" in OS.get_cmdline_user_args()
	color_review=scaled_cuts or "--element-colors" in OS.get_cmdline_user_args()
	broken_only=color_review or "--broken-only" in OS.get_cmdline_user_args()
	shimmer_study=broken_only or "--shimmer" in OS.get_cmdline_user_args()
	residual_study=shimmer_study or "--residual-knock" in OS.get_cmdline_user_args()
	momentum_study=residual_study or melee_only or "--momentum" in OS.get_cmdline_user_args()
	rebound_study=momentum_study or fleck_study or "--rebound" in OS.get_cmdline_user_args()
	stop_study=rebound_study or "--hitstop" in OS.get_cmdline_user_args()
	fragment_glint=stop_study or "--fragment-glint" in OS.get_cmdline_user_args()
	use_fragments=fragment_glint or "--fragments" in OS.get_cmdline_user_args()
	var sheet_file:="fragments/sheet.png" if use_fragments else "quench.png"
	var frame_file:="fragments/cells.json" if use_fragments else "cells.json"
	vapor_sheet=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(CLASH_PATH+sheet_file)))
	cells=JSON.parse_string(FileAccess.get_file_as_string(CLASH_PATH+frame_file))
	var cases: Array=POWER_CASES.keys() if "--power" in OS.get_cmdline_user_args() else ["through","clash","offset"]
	if "--types" in OS.get_cmdline_user_args(): cases=TYPE_CASES
	if "--recipients" in OS.get_cmdline_user_args(): cases=RECIPIENTS.keys()
	if use_fragments: cases=["weak_recipient"]
	if stop_study: cases=["weak_recipient"]+CLOSE_CASES
	if momentum_study:
		load_fragment_art()
		cases=CLOSE_CASES if melee_only else ["weak_recipient"]+CLOSE_CASES
	if scaled_cuts:
		cases=CLOSE_CASES
	elif color_review:
		original_palette=true
		load_fragment_art()
		await duel("water_mirror")
		original_palette=false
		load_fragment_art()
		cases=["weak_recipient","water_mirror","even_melee"]
	if fleck_study:
		for variant in ["skim","settle"]:
			fleck_variant=variant
			for scene_id in ["weak_recipient","even_melee"]: await duel(scene_id)
	else:
		for scene_id in cases: await duel(scene_id)
	print("Review issues ",failures)
	quit(0 if failures.is_empty() else 1)

func load_fragment_art() -> void:
	for kind in ["normal","water","fire"]:
		var art:=CLASH_PATH+("residual_knock/art/" if residual_study else "momentum/art/")+String(kind)+"/"
		if shimmer_study: art=CLASH_PATH+"shimmer/art/"+String(kind)+"/"
		if broken_only: art=CLASH_PATH+"broken_only/art/"+String(kind)+"/"
		if color_review and not original_palette: art=CLASH_PATH+"element_colors/art/"+String(kind)+"/"
		momentum_art[kind]={
			"tex":ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(art+"sheet.png"))),
			"cells":JSON.parse_string(FileAccess.get_file_as_string(art+"cells.json"))}

func duel(scene_id: String) -> void:
	seed(7)
	FxStyle.set_mode("custom")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.set_process(false)
	game.stream.clear()
	game.ui_root.hide()
	var view: View3D=game.view3d
	view.set_process(false)
	var old: World=game.world
	var close:=scene_id in CLOSE_CASES
	var w: ClashWorld=StopWorld.new() if stop_study else ClashWorld.new()
	if rebound_study:
		(w as StopWorld).rebound_study=true
		(w as StopWorld).forward_cuts=momentum_study
		(w as StopWorld).residual_knock=residual_study
		var art:=CLASH_PATH+"rebound/art/"+("physical/" if close else "elemental/")
		if not fleck_variant.is_empty(): art=CLASH_PATH+"flecks/art/"+fleck_variant+("_claw/" if close else "_water/")
		vapor_sheet=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(art+"sheet.png")))
		cells=JSON.parse_string(FileAccess.get_file_as_string(art+"cells.json"))
	game.add_child(w)
	game.world=w
	view.world=w
	old.free()
	var input:=DirectionInput.new()
	var player_move:="water_gun" if scene_id=="water_mirror" else "ember"
	var species: String="squirtle" if scene_id=="water_mirror" else RECIPIENTS.get(scene_id,"charmander")
	w.setup(7,species,35,[player_move],input)
	w.cancel_shots=scene_id!="through"
	if scene_id in POWER_CASES:
		w.cast_damage={"ember":POWER_CASES[scene_id][0],"water_gun":POWER_CASES[scene_id][1]}
	if scene_id in TYPE_CASES:
		w.skill_power={"ember":30,"water_gun":50}
		w.matchup_at_clash=scene_id=="type_subtract"
	if scene_id in RECIPIENTS or scene_id=="water_mirror":
		w.skill_power={"ember":MoveDB.power("ember"),"water_gun":MoveDB.power("water_gun")}
		w.matchup_at_clash=true
		w.linear_size=true
	var claw:="slash" if scene_id=="strong_melee" else "scratch"
	if close:
		w.skill_power={"scratch":MoveDB.power("scratch"),"slash":MoveDB.power("slash")}
	w.god=false
	var center:=open_cross()
	var offset:=14 if scene_id=="offset" else 0
	var spacing:=26 if momentum_study and close else (17 if close else 36)
	w.player.position=center+Vector2(-spacing,-offset)
	w.player.facing=Vector2.RIGHT
	w.player.repel_steps=99999
	var foe:=Enemy.new()
	foe.setup_enemy("meowth" if close else "squirtle",35,w.rng)
	foe.frozen=true
	for cd in foe.cds: foe.cds[cd]=9999
	foe.position=center+Vector2(spacing,offset)
	foe.facing=Vector2.LEFT
	w.add_child(foe)
	w.enemies.append(foe)
	w.visibility_layer|=Look.GROUND_LAYER
	view._cam_ready=false
	var folder:="fragments/" if use_fragments else ""
	if fragment_glint: folder+="glint/"
	if stop_study: folder="hitstop/"
	if rebound_study: folder="rebound/"
	if not fleck_variant.is_empty(): folder="flecks/"+fleck_variant+"/"
	if momentum_study: folder="caster_cuts/" if close else "momentum/"
	if residual_study: folder="residual_knock/"
	if shimmer_study: folder="shimmer/"
	if broken_only: folder="broken_only/"
	if color_review: folder="element_colors/before/" if original_palette else "element_colors/"
	if scaled_cuts: folder="scaled_cuts/"
	var dest:=CLASH_PATH+folder+scene_id+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest))
	var player_hp:=w.player.hp
	var foe_hp:=foe.hp
	var vapor: Array[Dictionary]=[]
	var rows:=[]
	var damage_events:=0
	var measured_width: Array[float]=[]
	var claw_start:=0
	var foe_start:=0
	if close:
		# Start each authored animation so its actual contact frame falls on tick 72.
		var claw_delay:=w.player.lunge_timing("Strike").y
		var foe_delay:=foe.lunge_timing("Strike").y
		claw_start=72-roundi(120*(claw_delay+1.0/60 if claw_delay>0 else float(MoveDB.get_move(claw).hit_delay)))
		foe_start=72-roundi(120*(foe_delay+1.0/60 if foe_delay>0 else float(MoveDB.get_move("scratch").hit_delay)))
	var cuts: Array[MeleeCut]=[]
	var contact_frame:=-1
	var crossed_visible:=false
	var clash_ink:=Vector3.ZERO
	if momentum_study and close:
		for entry in [[claw,Vector2.RIGHT],["scratch",Vector2.LEFT]]:
			var cut:=MeleeCut.new()
			cut.prepare(view,w.player if cuts.is_empty() else foe,entry[0],entry[1])
			cuts.append(cut)
	for frame in 44:
		if frame==4 and scene_id!="full_water" and not close:
			w.player.play_attack("Charge",.15)
		if not close and frame==9:
			foe.play_attack("Shoot")
			if scene_id!="full_water": w.cast(w.player,player_move,Vector2.RIGHT,w.player.position+Vector2.RIGHT*100)
			w.cast(foe,"water_gun",Vector2.LEFT,foe.position+Vector2.LEFT*100)
		var previous:=w.contacts.size()
		for sub in 4:
			var tick:=4*frame+sub
			if close and tick==claw_start:
				w.player.play_attack("Strike",0,true)
				w.cast(w.player,claw,Vector2.RIGHT,foe.position)
			if close and tick==foe_start:
				foe.play_attack("Strike",0,true)
				w.cast(foe,"scratch",Vector2.LEFT,w.player.position)
			w.step(1.0/120)
		view._process(1.0/30)
		if not cuts.is_empty():
			if w.contacts.size()>previous: contact_frame=frame
			var gap:=INF
			if contact_frame>=0:
				gap=float(contact_frame-frame)/30
			elif w.pending_melee.size()==2:
				gap=maxf(w.pending_melee[0].t,w.pending_melee[1].t)
			for cut in cuts: cut.show_contact(gap)
			if w.contacts.size()>previous:
				var left:=cuts[0].screen_ink()
				var right:=cuts[1].screen_ink()
				var shared:=left.keys().filter(func(pixel):return right.has(pixel))
				if shared.is_empty():
					failures.append(scene_id+" no visible cut intersection")
				else:
					var center_px:=Vector2.ZERO
					for pixel in shared: center_px+=Vector2(pixel)
					center_px/=shared.size()
					var best: Vector2i=shared[0]
					for pixel in shared:
						if center_px.distance_squared_to(pixel)<center_px.distance_squared_to(best): best=pixel
					clash_ink=left[best]
			if scaled_cuts and contact_frame>=0 and clash_ink!=Vector3.ZERO:
				for cut in cuts:
					var original_width:=cut.sprite.basis.x.length()
					var fraction: float=(w as StopWorld).remaining_cut_scale[cut.caster]
					cut.shrink_at(clash_ink,-gap,fraction)
					if frame==contact_frame+2:
						var expected:=30.0/70 if scene_id=="strong_melee" and cut.caster==w.player else 0.0
						var shown:=cut.sprite.basis.x.length()/original_width if cut.sprite.visible else 0.0
						if not is_equal_approx(shown,expected): failures.append(scene_id+" residual visual size")
			if contact_frame<0 and cuts[0].sprite.visible and cuts[1].sprite.visible: crossed_visible=true
			if w.contacts.size()>previous and (not crossed_visible or not cuts.all(func(c):return c.sprite.visible)):
				failures.append(scene_id+" cut timing")
		if scene_id in RECIPIENTS and w.contacts.size()>0:
			for shot: Projectile in w.projectiles:
				if not shot.dead and shot.hit.move=="water_gun":
					measured_width.append(shot.hit_radius()/float(MoveDB.get_move("water_gun").radius))
		var visible_clash:=cuts.is_empty() or clash_ink!=Vector3.ZERO
		if visible_clash and (not close or rebound_study) and w.contacts.size()>previous:
			var at: Vector2=w.contacts.back()
			if vapor.is_empty() or frame-int(vapor.back().start)>=4 or at.distance_to(vapor.back().at)>8:
				for layer in (w.incoming if momentum_study else [{}]):
					if broken_only and not layer.broken: continue
					var sprite:=view._new_sprite(BaseMaterial3D.BILLBOARD_DISABLED)
					sprite.basis=view.cam.global_basis
					var art: Dictionary=momentum_art[layer.type] if momentum_study else {"tex":vapor_sheet,"cells":cells}
					sprite.texture=art.tex
					if momentum_study:
						var screen_from:=view.cam.unproject_position(View3D.to3d(at))
						var screen_to:=view.cam.unproject_position(View3D.to3d(at+Vector2(layer.dir)*Arena.TILE))
						sprite.basis=sprite.basis*Basis(Vector3.BACK,-(screen_to-screen_from).angle())
					if fragment_glint:
						var glint:=ShaderMaterial.new()
						glint.shader=preload("res://tools/samples/clash_fragment_glint.gdshader")
						if shimmer_study:
							glint.shader=preload("res://tools/samples/clash_chip_shimmer.gdshader")
							glint.set_shader_parameter("offset_phase",.23 if Vector2(layer.dir).x<0 else 0.0)
							var tint: Color={"normal":Color.WHITE,"fire":Color("#ffdf9e"),"water":Color("#c9f7ff")}[layer.type]
							if color_review and not original_palette and layer.type!="normal":
								glint.set_shader_parameter("colored_chip",true)
								tint=Color("#ffaf54") if layer.type=="fire" else Color("#69c9ff")
							glint.set_shader_parameter("shine_tint",tint)
						glint.set_shader_parameter("fragments",sprite.texture)
						if momentum_study and not shimmer_study: glint.set_shader_parameter("neutral",layer.type=="normal")
						sprite.material_override=glint
					sprite.shaded=false
					sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
					sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					sprite.pixel_size=.82/Arena.TILE
					sprite.position=View3D.to3d(at+Vector2.DOWN*6,6.0/Arena.TILE*view.k)+view.cam.global_basis.y*(3.0 if use_fragments else 5.0)*sprite.pixel_size
					if momentum_study: sprite.position+=view.cam.global_basis.z*.6-view.cam.global_basis.y*3*sprite.pixel_size
					if momentum_study and close: sprite.position=clash_ink+view.cam.global_basis.z*.08
					vapor.append({"node":sprite,"start":frame,"at":at,"cells":art.cells,"layer":layer})
		for effect in vapor:
			var age:=frame-int(effect.start)
			var sprite: Sprite3D=effect.node
			var frames: Array=effect.cells
			sprite.visible=age<frames.size()
			if sprite.visible:
				var cell: Dictionary=frames[age]
				sprite.region_rect=Rect2(cell.x,cell.y,cell.w,cell.h)
				if fragment_glint:
					var glint:=sprite.material_override as ShaderMaterial
					glint.set_shader_parameter("frame_px",Vector4(cell.x,cell.y,cell.w,cell.h))
					glint.set_shader_parameter("phase",float(age)/maxi(1,frames.size()-1))
		if not rows.is_empty() and (rows.back()[1]!=w.player.hp or rows.back()[2]!=foe.hp):
			damage_events+=1
		rows.append([w.contacts.size(),w.player.hp,foe.hp])
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.size==Vector2i(384,216))
		root.get_texture().get_image().save_png(dest+"%02d.png"%frame)
	FileAccess.open(dest+"frames.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
	if scene_id=="clash" and (w.contacts.is_empty() or w.player.hp!=player_hp): failures.append(scene_id)
	if scene_id=="offset" and (not w.contacts.is_empty() or foe.hp!=foe_hp or w.player.hp!=player_hp): failures.append(scene_id)
	if scene_id=="through" and (foe.hp>=foe_hp or w.player.hp>=player_hp): failures.append(scene_id)
	if scene_id in POWER_CASES:
		var diff:=int(w.cast_damage.water_gun)-int(w.cast_damage.ember)
		if player_hp-w.player.hp!=maxi(diff,0) or foe_hp-foe.hp!=maxi(-diff,0) or w.contacts.size()!=1 or damage_events!=int(diff!=0):
			failures.append(scene_id)
	if scene_id in TYPE_CASES:
		var expected: int={"full_water":50,"base_subtract":20,"type_subtract":35}[scene_id]
		var residual:=float(w.outcome.get("water_gun",50.0))
		var result:={"remaining":residual,"landed":w.landed,"size_ratio":sqrt(residual/50.0)}
		FileAccess.open(dest+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result))
		if residual!=expected or w.landed.size()!=1 or w.landed[0].fixed!=0 or w.landed[0].power!=expected or w.landed[0].type_mult!=2.0 or foe.hp!=foe_hp:
			failures.append(scene_id)
	if scene_id in RECIPIENTS:
		var expected_mult:=2.0 if scene_id=="weak_recipient" else 1.0
		if w.contacts.size()!=1 or w.outcome.get("water_gun")!=20.0 or w.outcome.get("ember")!=0.0 or w.landed.size()!=1 or w.landed[0].power!=20.0 or w.landed[0].type_mult!=expected_mult or w.landed[0].fixed!=0 or measured_width.is_empty() or not measured_width.all(func(r):return is_equal_approx(r,0.5)):
			failures.append(scene_id)
		var summary:={"landed":w.landed,"radius_ratio":measured_width.front() if not measured_width.is_empty() else 0.0}
		FileAccess.open(dest+"result.json",FileAccess.WRITE).store_string(JSON.stringify(summary))
	if broken_only:
		var expected_layers:=2 if scene_id in ["even_melee","water_mirror"] else 1
		if vapor.size()!=expected_layers:
			failures.append(scene_id+" broken layer count")
		elif scene_id=="water_mirror" and (not vapor.all(func(f):return f.layer.type=="water") or vapor[0].layer.dir.dot(vapor[1].layer.dir)>-.99 or w.contacts.size()!=1 or w.player.hp!=player_hp or foe.hp!=foe_hp):
			failures.append("expected two cancelled water guns")
		elif scene_id=="weak_recipient" and (vapor[0].layer.type!="fire" or vapor[0].layer.dir.x<=0):
			failures.append("expected only the incoming embers")
		elif scene_id=="strong_melee" and (vapor[0].layer.type!="normal" or vapor[0].layer.dir.x>=0):
			failures.append("expected only Meowth's incoming scratch")
		elif scene_id=="even_melee" and vapor[0].layer.dir.dot(vapor[1].layer.dir)>-.99:
			failures.append("expected both opposing scratches")
	if stop_study:
		var probe:=w as StopWorld
		if close:
			if w.contacts.size()!=1 or w.player.hp!=player_hp or probe.held_melee_steps==0: failures.append(scene_id)
			if rebound_study:
				var distances:=[]
				for push in probe.separation:
					var delta: Vector2=push.actor.position-push.start
					var travel:=delta.dot(push.axis)
					distances.append(travel)
					if residual_study and scene_id=="strong_melee":
						if push.actor==w.player and absf(travel)>.05: failures.append("winner moved")
						if push.actor==foe and (probe.full_knock_distance<=0 or absf(travel-probe.full_knock_distance*30.0/70.0)>2):
							failures.append("residual knock distance")
					if absf(travel-float(push.distance))>2.0 or absf(delta.cross(push.axis))>1: failures.append(scene_id+" travel")
				if distances.size()!=2: failures.append(scene_id+" impulse count")
				FileAccess.open(dest+"separation.json",FileAccess.WRITE).store_string(JSON.stringify(distances))
			if scene_id=="even_melee" and foe.hp!=foe_hp: failures.append(scene_id)
			if scene_id=="strong_melee" and (w.landed.size()!=1 or w.landed[0].power!=30): failures.append(scene_id)
		elif scene_id!="water_mirror" and probe.held_projectile_steps==0: failures.append(scene_id)
	print(scene_id," pairs=",w.contacts.size()," hp lost=",player_hp-w.player.hp," / ",foe_hp-foe.hp)
	game.free()
	await process_frame

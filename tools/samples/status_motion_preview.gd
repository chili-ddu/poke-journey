extends "res://tools/samples/reference_reaction_preview.gd"

# Study-only observer/renderer. Reads gameplay state; never writes Mon timers.
const EXTRA := "res://docs/status_motion_followup/source-extra/"
const RELEASE := "res://docs/status_motion_followup/fx-round3/local-review/"
var prior := {}
var events := []
var sleep_started := 0.0
var wake_started := -999.0
var release_started := -999.0
var reaction_started := -999.0
var reaction := ""
var clearing_kind := ""
var drawing_time := 0.0
var extra_cache := {}
var release_frames := {}
var release_nodes: Array[Sprite3D]=[]

func _init(view: View3D) -> void:
	super(view)
	for layer in ["front","back"]:
		var id: String="status-release-r3-"+layer
		var path: String=RELEASE+id+"/"+id
		var meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
		var image:=Image.load_from_file(path+".png")
		var frames: Array[Texture2D]=[]
		for cell in meta.frames:
			var r: Dictionary=cell.frame
			frames.append(ImageTexture.create_from_image(image.get_region(Rect2i(int(r.x),int(r.y),int(r.w),int(r.h)))))
		release_frames[layer]=frames
		var s:=view._new_sprite(BaseMaterial3D.BILLBOARD_DISABLED)
		s.region_enabled=false;s.shaded=false;s.visible=false;s.no_depth_test=false
		s.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED;s.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		release_nodes.append(s)

func snapshot(m: Mon) -> Dictionary:
	return {"sleep":m.sleep_t,"confuse":m.confuse_t,"paralyze":m.para_t,"poison":m.poison_t,"burn":m.burn_t,"lock":m.para_lock_t,"hp":m.hp}

func observe(m: Mon,now: float) -> void:
	var current:=snapshot(m)
	if prior.is_empty():prior=current;return
	for kind in ["sleep","confuse","paralyze","poison","burn"]:
		if float(prior[kind])<=0 and float(current[kind])>0:
			status(kind,now);events.append({"kind":"enter_"+kind,"at":now})
			if kind=="sleep":sleep_started=now
		elif float(prior[kind])>0 and float(current[kind])<=0:
			status_kind="";clearing_kind=kind;release_started=now
			if kind=="sleep":wake_started=now
			events.append({"kind":"clear_"+kind,"at":now})
	if m.para_lock_t>float(prior.lock)+0.01:
		reaction="paralysis_block";reaction_started=now;status("paralyze",now)
		events.append({"kind":reaction,"at":now})
	if int(current.hp)<int(prior.hp):
		if m.confuse_t>0 and m.hurt_t>0:
			reaction="confusion_self_hit";reaction_started=now;hit(now);status("confuse",now)
			events.append({"kind":reaction,"at":now})
		elif m.burn_t>0 or m.poison_t>0:
			reaction="burn_tick" if m.burn_t>0 else "poison_tick"
			reaction_started=now;status("burn" if m.burn_t>0 else "poison",now)
			events.append({"kind":reaction,"at":now})
	prior=current

func wake_info(m: Mon) -> Dictionary:
	# Normal-color source extras must never recolor a shiny during waking.
	if m.shiny:return {}
	var dex: int=SpeciesDB.get_species(m.appearance_id()).dex
	if extra_cache.has(dex):return extra_cache[dex]
	var folder:=EXTRA+"%04d/"%dex
	if not FileAccess.file_exists(folder+"Wake-Anim.png"):
		extra_cache[dex]={};return {}
	var metadata:=MonSprite._parse_anim_data(folder+"AnimData.xml")
	if not metadata.has("Wake"):extra_cache[dex]={};return {}
	var a: Dictionary=metadata.Wake
	var tex:=ImageTexture.create_from_image(Image.load_from_file(folder+"Wake-Anim.png"))
	var rows: int=tex.get_height()/int(a.fh)
	var info:={"tex":tex,"fw":int(a.fw),"fh":int(a.fh),"rows":rows,"durations":a.durations,"dex":dex,
		"native_frames":true,"polished_charmander":dex==4,"polished_pokemon":dex!=4,
		"centers":MonSprite._load_centers(folder+"Wake-Offsets.png",int(a.fw),int(a.fh),a.durations.size(),rows)}
	extra_cache[dex]=info
	return info

func draw_pose(view: View3D,m: Mon,now: float) -> Dictionary:
	var action:="Idle"
	var elapsed:=m.anim_t
	var loop:=true
	var anim: Dictionary=m._sprites.get("Idle",m._sprites.Walk)
	if m.sleep_t>0:
		action="Sleep";anim=m._sprites.Sleep;elapsed=now-sleep_started
	elif now-wake_started<0.7:
		var wake:=wake_info(m)
		if not wake.is_empty():
			var dex: int=SpeciesDB.get_species(m.appearance_id()).dex
			var first: int={4:1,5:3,25:1,23:2}.get(dex,maxi(0,wake.durations.size()-2))
			var entry:=MonSprite.frame_start(wake,first)
			elapsed=entry+now-wake_started
			if elapsed<MonSprite.anim_length(wake):action="Wake";anim=wake;loop=false
	elif now-reaction_started<0.30 and reaction!="":
		# Authored bracing poses have no comic hit marks. Keep individual limbs.
		action="Charge";anim=m._sprites.Charge;elapsed=(now-reaction_started)*0.75;loop=false
	var row:=MonSprite.row_for(anim,m.facing)
	var visual:=MonSprite.display_frame(anim,row,elapsed,loop)
	var shaded:=Look.selout_frame(visual.tex,visual.src,view.sky_kind(DungeonDB.current))
	var body: Sprite3D=view._sprites[m.get_instance_id()].sprite
	body.texture=shaded.tex;body.region_rect=shaded.src;body.region_enabled=true
	var anchor: Vector2=m._sprites.get("anchor",Vector2.ZERO)
	body.offset=Vector2(-anchor.x,anchor.y+float(m._sprites.get("feet_dy",0.0))-1.0)
	if action=="Charge" and reaction=="paralysis_block":
		var jitter:=roundf(sin((now-reaction_started)*80.0))
		body.position+=view.cam.global_basis.x*jitter*body.pixel_size
	return {"action":action,"frame":MonSprite.frame_at(anim,elapsed,loop),"head":visual.body_center,"source_tex":visual.tex,"source_src":visual.src}

func draw(view: View3D,target: Mon,_center_pixel: Vector2,now: float) -> Dictionary:
	drawing_time=now
	var pose:=draw_pose(view,target,now)
	var body: Sprite3D=view._sprites[target.get_instance_id()].sprite
	var image: Image=body.texture.get_image()
	if image.is_compressed():image.decompress()
	image=image.get_region(Rect2i(body.region_rect))
	var center_pixel:=Vector2(image.get_used_rect().get_center())
	var span: float=target._sprites.get("reference_span",32.0)
	# A long body/wing reference must not make head icons enormous (Onix).
	var fx_scale:=clampf(48.0/maxf(span,1.0),0.55,1.0)
	if status_kind in ["sleep","confuse"] or (now-release_started<0.35 and clearing_kind in ["sleep","confuse"]):
		center_pixel=(pose.head as Vector2)+Vector2(0,span*8.0/36.0*fx_scale)
	var result:=super.draw(view,target,center_pixel,now)
	var effect_center:=view.sprite_pixel_position(body,center_pixel)
	for sprite in sprites:
		if sprite.visible:
			sprite.position=effect_center+(sprite.position-effect_center)*fx_scale
			sprite.pixel_size*=fx_scale
	var ent: Dictionary=view._sprites[target.get_instance_id()]
	if ent.has("twin"):
		var twin: Sprite3D=ent.twin
		twin.texture=body.texture;twin.region_rect=body.region_rect;twin.offset=body.offset;twin.scale=body.scale
	if Look.TAIL_FLAME.has(target.appearance_id()) and ent.has("light"):
		var flame:=Look.flame_point(pose.source_tex,pose.source_src)
		var on:=body.visible and flame.x>=0.0
		ent.light.visible=on;ent.halo.visible=on
		if on:
			var at:=view.sprite_pixel_position(body,flame)
			ent.light.position=at
			ent.light.omni_range=view.tail_light_range(maxf(.01,at.y-body.position.y),view.sky_kind(DungeonDB.current)=="indoor")
			ent.halo.position=at-(view.cam.global_position-at).normalized()*.015
	var vertical:=view.cam.global_basis.y if body.billboard==BaseMaterial3D.BILLBOARD_ENABLED else Vector3.UP
	var right:=view.cam.global_basis.x
	var normal:=right.cross(vertical).normalized()
	var center:=view.sprite_pixel_position(body,Vector2(image.get_used_rect().get_center()))
	var age:=now-release_started
	for i in 2:
		var s:=release_nodes[i];s.visible=age>=0 and age<0.65
		if not s.visible:continue
		var layer:="front" if i==0 else "back"
		var textures: Array=release_frames[layer]
		s.texture=textures[mini(textures.size()-1,int(age*30.0))]
		s.pixel_size=span*body.pixel_size*absf(body.scale.x)/36.0*fx_scale
		s.position=center+normal*(.04 if i==0 else -.05)
		s.basis=Basis(right,vertical,normal);s.modulate=Color.WHITE
	result["action"]=pose.action;result["frame"]=pose.frame
	result["release"]=age>=0 and age<0.65
	return result

func sv_particles(ticks: float) -> Array:
	var out:=super.sv_particles(ticks)
	var age:=drawing_time-release_started
	if age<0.0 or age>=0.35:return out
	var u:=age/.35
	var fade:=1.0-u
	match clearing_kind:
		"poison":
			for side in [-1,1]:out.append(["status_effect-1",side*(10.0+u*4.0),-4.0-u*8.0,5.0*fade,Color(.69,.37,.82,fade*.7),true])
		"burn":
			for side in [-1,1]:out.append(["status_effect-2",side*11.0,8.0-u*7.0,6.0*fade,Color(.85,.35,.08,fade*.7),true])
		"paralyze":
			if age<.2:
				for side in [-1,1]:out.append(["thunder_shock-"+str(int(age*60)%2),side*12.0,0.0,8.0*(1.0-age/.2),Color(.94,.86,.32,(1.0-age/.2)*.65),true])
		"sleep":out.append(["status_effect-12",11.0+u*4.0,-18.0-u*7.0,7.0*fade,Color(.66,.78,.98,fade*.75),true])
		"confuse":
			for i in 3:
				var a:=TAU*i/3.0+u
				out.append(["status_effect-4",cos(a)*(16.0+u*9.0),-16.0+sin(a)*4.0-u*3.0,6.5*fade,Color(1,1,1,fade*.8),sin(a)>=0])
	return out

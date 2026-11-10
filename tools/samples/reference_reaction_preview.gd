extends RefCounted

# Existing Platinum textures + a 2D study of SV's brief status symbols.
# No generated sprite, no gameplay state changes, no runtime game hookup.
const TEXTURES := "res://docs/blink_status_review/reference/textures/"
var sprites: Array[Sprite3D]=[]
var textures := {}
var tint_cache := {}
var status_kind := ""
var status_started := -999.0
var hit_started := -999.0
var status_events := 0
var hit_events := 0
var sv_style := true

func _init(view: View3D) -> void:
	for key in ["status_effect-1","status_effect-2","status_effect-4","status_effect-12","thunder_shock-0","thunder_shock-1"]:
		var image := Image.load_from_file(TEXTURES+key+".png")
		if key=="status_effect-2":
			var full := Image.create(image.get_width()*2,image.get_height(),false,Image.FORMAT_RGBA8)
			full.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i.ZERO)
			var mirror := image.duplicate();mirror.flip_x()
			full.blit_rect(mirror,Rect2i(Vector2i.ZERO,mirror.get_size()),Vector2i(image.get_width(),0))
			image=full
		if key=="status_effect-1":
			# Preserve the bubble shading/alpha; remove cyan before purple tint.
			for y in image.get_height():
				for x in image.get_width():
					var c:=image.get_pixel(x,y);var value:=maxf(c.r,maxf(c.g,c.b))
					image.set_pixel(x,y,Color(value,value,value,c.a))
		textures[key]=ImageTexture.create_from_image(image)
	for i in 16:
		var s := view._new_sprite(BaseMaterial3D.BILLBOARD_DISABLED)
		s.region_enabled=false;s.shaded=false;s.visible=false
		s.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
		s.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.no_depth_test=false
		sprites.append(s)

static func blink_visible(age: float) -> bool:
	# Task_FlickerBattler: delay=2 plus the toggle tick => 3 ticks, six toggles.
	if age<0.0 or age>=16.0/60.0:return true
	return int(floor(age*60.0+0.00001)/3)%2==1

func hit(now: float) -> void:
	hit_started=now;hit_events+=1

func status(kind: String,now: float) -> void:
	status_kind=kind;status_started=now;status_events+=1

func hide_old_fx(world: World,view: View3D,target: Mon) -> void:
	for fx in world.fxs:
		if fx.kind in ["text","light","tallgrass"] or fx.position.distance_to(target.position)>70.0:continue
		if view._sprites.has(fx.get_instance_id()):
			for node in view._sprites[fx.get_instance_id()].values():
				if node is VisualInstance3D:node.visible=false

func tint_body(body: Sprite3D,kind: String,ticks: float) -> void:
	# SV-inspired version: brief localized FX, no DS whole-body palette fade.
	if sv_style:return
	if kind not in ["poison","burn","paralyze"]:return
	var peak := 15 if kind=="paralyze" else 10
	var step := int(maxf(0.0,minf(ticks,float(peak*2)-ticks)))
	if step<=0:return
	var tint := Color(160.0/248.0,0,1) if kind=="poison" else Color.RED if kind=="burn" else Color.BLACK
	var key := "%d:%s:%s:%d"%[body.texture.get_instance_id(),str(body.region_rect),kind,step]
	if not tint_cache.has(key):
		var image: Image=body.texture.get_image()
		if image.is_compressed():image.decompress()
		image=image.get_region(Rect2i(body.region_rect))
		for y in image.get_height():
			for x in image.get_width():
				var c:=image.get_pixel(x,y)
				if c.a<=0.0:continue
				var next:=c.lerp(tint,float(step)/16.0);next.a=c.a
				image.set_pixel(x,y,next)
		tint_cache[key]=ImageTexture.create_from_image(image)
	body.texture=tint_cache[key]
	body.region_rect=Rect2(Vector2.ZERO,body.texture.get_size())

func draw(view: View3D,target: Mon,center_pixel: Vector2,now: float) -> Dictionary:
	for s in sprites:s.visible=false
	var ent: Dictionary=view._sprites[target.get_instance_id()]
	var body: Sprite3D=ent.sprite
	var vertical:=view.cam.global_basis.y if body.billboard==BaseMaterial3D.BILLBOARD_ENABLED else Vector3.UP
	var right:=view.cam.global_basis.x
	var normal:=right.cross(vertical).normalized()
	var center:=view.sprite_pixel_position(body,center_pixel)
	var span: float=target._sprites.get("reference_span",32.0)
	var unit:=span*body.pixel_size*absf(body.scale.x)/36.0
	var ticks: float=(now-status_started)*60.0
	var particles := []
	if sv_style:
		particles=sv_particles(ticks)
	elif ticks>=0.0:
		match status_kind:
			"burn":
				for i in 8:
					var a: float=ticks-i
					if a<0 or a>=14:continue
					var life:=a/14.0
					particles.append(["status_effect-2",sin(i*4.3)*13.0,10.0-life*19.0,8.0*(1.0-life)+1.0,Color(0.97,0.28+0.15*(1.0-life),0.02,1.0-life*.35),true])
			"poison":
				for i in 5:
					var a: float=ticks-i*3
					if a<0 or a>=20:continue
					var life:=a/20.0
					var grow:=minf(life/.25,(1.0-life)/.35)
					particles.append(["status_effect-1",sin(i*5.9)*12.0,8.0-life*22.0,maxf(1,7.0*minf(1,grow)),Color(.97,.32,.97,.90),true])
			"paralyze":
				for i in 12:
					var a: float=ticks-floor(i/1.5)*2
					if a<0 or a>=10:continue
					particles.append(["thunder_shock-"+str(int(a/2)%2),sin(i*6.7)*15.0,cos(i*4.1)*10.0,12.0*(1.0-a/20.0),Color(.97,.95,0,.95),true])
			"sleep":
				for i in 3:
					var a: float=ticks-i*14
					if a<0 or a>=30:continue
					var life:=a/30.0
					particles.append(["status_effect-12",9.0+life*6.0,-12.0-life*22.0,5.0+life*5.0,Color(.88,.75,.97,1.0-smoothstep(.75,1.0,life)),true])
			"confuse":
				if ticks<36:
					for i in 6:
						var angle:=TAU*i/6.0+ticks/36.0*TAU
						var grow:=minf(1.0,.3+ticks/8.0)
						particles.append(["status_effect-4",cos(angle)*17.0,-15.0+sin(angle)*4.5-ticks*.10,6.0*grow,Color(1,1,1,1.0-smoothstep(28.0,36.0,ticks)),sin(angle)>=0.0])
	for i in particles.size():
		var p: Array=particles[i];var s:=sprites[i]
		s.texture=textures[p[0]];s.pixel_size=unit*float(p[3])/s.texture.get_width()
		s.position=center+right*float(p[1])*unit-vertical*float(p[2])*unit+normal*(.04 if p[5] else -.05)
		s.basis=Basis(right,vertical,normal);s.modulate=p[4];s.visible=true
		s.flip_h=status_kind=="confuse" and float(p[1])<0.0
	tint_body(body,status_kind,ticks)
	body.modulate=Color.WHITE
	body.visible=blink_visible(now-hit_started)
	# Keep the ground shadow; body-only blink must not erase contact information.
	if ent.has("rank_overlay"):ent.rank_overlay.visible=false
	return {"visible":body.visible,"particles":particles.size(),"status_age_ticks":ticks}

func sv_particles(ticks: float) -> Array:
	var out:=[]
	if ticks<0:return out
	match status_kind:
		"poison":
			for i in 6:
				var a: float=ticks-i*4
				if a<0 or a>=28:continue
				var t:=a/28.0
				var size: float=(5.5+float(i%3)*1.2)*minf(1.0,a/4.0)
				out.append(["status_effect-1",sin(i*5.1)*13.0+sin(t*PI)*2.0,8.0-t*27.0,size,Color(.69,.37,.82,1.0-smoothstep(.65,1.0,t)),true])
		"burn":
			for i in 6:
				var a: float=ticks-i*4
				if a<0 or a>=22:continue
				var t:=a/22.0
				out.append(["status_effect-2",sin(i*4.7)*13.0,10.0-t*17.0,9.0*(1.0-t)+2.0,Color(.98,.50-.25*t,.07,.95*(1.0-t)),true])
		"paralyze":
			for i in 8:
				var a: float=ticks-i*3
				if a<0 or a>=9:continue
				out.append(["thunder_shock-"+str(int(a/2)%2),(1.0 if i%2==0 else -1.0)*(10.0+float(i%3)),sin(i*3.9)*8.0,13.0,Color(.94,.86,.32,1.0-a/9.0),true])
		"sleep":
			for i in 3:
				var a: float=ticks-i*11
				if a<0 or a>=35:continue
				var t:=a/35.0
				out.append(["status_effect-12",9.0+t*5.0,-12.0-t*20.0,5.0+t*4.0,Color(.66,.78,.98,1.0-smoothstep(.75,1.0,t)),true])
		"confuse":
			if ticks<48:
				for i in 3:
					var angle:=TAU*i/3.0+ticks/48.0*TAU*1.4
					out.append(["status_effect-4",cos(angle)*16.0,-16.0+sin(angle)*4.0,6.5,Color(1,1,1,minf(1,ticks/5.0)*(1.0-smoothstep(38.0,48.0,ticks))),sin(angle)>=0])
	return out

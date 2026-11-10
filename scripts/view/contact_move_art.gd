extends RefCounted
## Flame shapes share Ember's material. Simulation owns the field position and expiry.
const Heat = preload("res://scripts/view/ember_heat.gd")

static func layer(view, entry: Dictionary, index: int, texture: String) -> Sprite3D:
	if not entry.has(index):
		var s: Sprite3D=view._new_sprite(BaseMaterial3D.BILLBOARD_DISABLED)
		s.texture=Fx.sheet(texture)
		s.region_enabled=false
		s.shaded=false
		s.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
		s.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
		s.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.pixel_size=1.0/Arena.TILE
		entry[index]=s
	return entry[index]

static func sheet(s: Sprite3D, frame: int, cols: int, cell: Vector2, pivot: Vector2, center: Vector3, plane: Basis, scale: Vector2, alpha: float) -> void:
	s.region_enabled=true
	s.region_rect=Rect2(Vector2(frame%cols,frame/cols)*cell,cell)
	s.position=center+(plane.x*(cell.x*.5-pivot.x)*scale.x+plane.y*(pivot.y-cell.y*.5)*scale.y)/Arena.TILE
	s.basis=plane*Basis.from_scale(Vector3(scale.x,scale.y,1))
	s.modulate.a=alpha

static func ember(view,entry: Dictionary,i: int,center: Vector3,plane: Basis,size: Vector2,tilt: float,opacity: float,core: float,age: float) -> void:
	var s:=layer(view,entry,i,"g4_fire_puff" if i%4==1 else "g4_flame")
	s.visible=opacity>.02 and minf(size.x,size.y)>.5
	if not s.visible: return
	s.position=center
	s.basis=plane*Basis(Vector3.BACK,tilt)*Basis.from_scale(Vector3(size.x/s.texture.get_width(),size.y/s.texture.get_height(),1))
	s.flip_h=i%3==0
	s.modulate=Color(1,lerpf(.55,.90,core),lerpf(.15,.48,core),clampf(opacity,0,1))
	Heat.apply(s,age,i,1)

static func spin(view,z,entry: Dictionary) -> void:
	var cam: Basis=view.cam.global_basis
	var age: float=z.flight_age+z.age
	var opening:=lerpf(.19,1,smoothstep(0,.20,age))
	var fade:=1.0-smoothstep(z.turns*Mon.TURN-.42,z.turns*Mon.TURN,z.age)
	var point: Vector2=z.position+Vector2.DOWN*z.feet_offset
	if not z.landed:
		var gap_weight:=1.0-smoothstep(0,.12,z.flight_age)
		point+=z.direction*(float(z.hit.src.radius)+Projectile.RELEASE_GAP)*gap_weight if is_instance_valid(z.hit.src) else Vector2.ZERO
	var center:=View3D.to3d(point,.04+(1-opening)*.3)
	sheet(layer(view,entry,-1,"cast_fire_spin"),floori(age*30)%30,6,Vector2(104,96),Vector2(52,84),center,cam,Vector2(.70,.61)*opening,fade*.48)
	for i in 22:
		var u:=fposmod(i/22.0+age*.81,1)
		var a:=TAU*(2.12*u+age*.67)
		var r:=(10+12*u)*opening
		var ofs:=Vector2(cos(a)*r,2+36*u+sin(a)*r*.23)*opening
		var size:=(4+3*sin(PI*u))*opening
		ember(view,entry,i,center+(cam.x*ofs.x+cam.y*ofs.y)/Arena.TILE,cam,Vector2(.83,1.65)*size,-.64*cos(a),sin(PI*u)*fade,.35+.30*cos(a),age)

static func coat(view,f: Fx,entry: Dictionary) -> void:
	var cam: Basis=view.cam.global_basis
	var dir:=Vector3(f.dir.x,0,f.dir.y)
	var aim:=cam*Basis(Vector3.BACK,atan2(dir.dot(cam.y),dir.dot(cam.x)))
	if dir.dot(cam.x)<-.001: aim.y=-aim.y
	var mon:=f.follow as Mon
	var center:=View3D.to3d(mon.position+Vector2.DOWN*mon.feet_offset(),mon.radius/Arena.TILE)+cam.z*.12
	sheet(layer(view,entry,-1,"cast_flare_blitz"),clampi(floori(f.age*30),0,14),4,Vector2(116,86),Vector2(73,43),center,aim,Vector2.ONE*.77,.53)
	var strength:=smoothstep(0,.065,f.age)*(1-smoothstep(.30,.46,f.age))
	for i in 12:
		var a:=TAU*i/12+f.age*13
		var ofs:=Vector2(cos(a)*11,sin(a)*8)*strength
		ember(view,entry,i,center+(aim.x*ofs.x+aim.y*ofs.y)/Arena.TILE,aim,Vector2(6,10+5*(1-cos(a)))*strength,.9+.43*sin(a),strength*(.8+.16*cos(a)),.36,f.age)

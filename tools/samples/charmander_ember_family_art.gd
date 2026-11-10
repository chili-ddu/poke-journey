extends "res://tools/samples/charmander_sv_art.gd"

const EmberMaterial = preload("res://scripts/view/ember_heat.gd")
var flames: Array[Sprite3D] = []
var used := 0

func sheet_path(id: String) -> String:
	if id in ["scratch","slash"]:
		return "res://docs/charmander_ember_family/sheets/%s/sheet" % id
	return super.sheet_path(id)

func draw_cut(t: float, aim: Basis) -> void:
	var scratch := move=="scratch"
	# First point of the middle stroke in the PixelFX sheet. Pin it by the front paw.
	var near_end := Vector2(-23.5,18.5) if scratch else Vector2(-43,18.5)
	var paw := body_center()+aim.x*world.player.radius*.83/Arena.TILE
	draw_sheet(t,paw,aim,Vector2.ONE*(.62 if scratch else .66),1,origin+near_end)

func ember(point: Vector3, plane: Basis, size_px: Vector2, angle: float, opacity: float, phase: float, core: float = 0.0) -> void:
	if opacity<.02 or minf(size_px.x,size_px.y)<.5: return
	if used==flames.size():
		var tex:=Fx.sheet("g4_fire_puff" if used%4==1 else "g4_flame")
		flames.append(layer(tex))
	var flame:=flames[used]
	var width:=float(flame.texture.get_width())
	flame.pixel_size=1.0/Arena.TILE
	flame.position=point
	flame.basis=plane*Basis(Vector3.BACK,angle)*Basis.from_scale(Vector3(size_px.x/width,size_px.y/float(flame.texture.get_height()),1))
	flame.flip_h=used%3==0
	flame.modulate=Color(1,lerpf(.55,.90,core),lerpf(.15,.48,core),clampf(opacity,0,1))
	EmberMaterial.apply(flame,age,phase,1)
	flame.show()
	used+=1

# Called with the actual leading and trailing projectile positions from the SV review.
func draw_breath(anchor: Vector3, aim: Basis, span: float, dragon: bool) -> void:
	if dragon:
		super.draw_breath(anchor,aim,span,dragon)
		return
	var count:=maxi(2,ceili(span/4.8))
	for i in count:
		var u:=(float(i)+.5)/count
		var phase:=age*20.0-u*8
		var height:=lerpf(5,15,u)*(.92+.12*sin(phase))
		var length:=minf(span+3,lerpf(11,23,u))
		var offset:=aim.x*span*u+aim.y*sin(phase)*u*3.1
		var center:=anchor+offset/Arena.TILE
		var tilt:=-PI*.47+.14*sin(phase)
		ember(center,aim,Vector2(height*1.14,length),tilt,.98,phase)
		if i%2==0:
			ember(center+view.cam.global_basis.z*.025,aim,Vector2(height*.46,length*.93),tilt,.94,phase+.4,.90)

func render(dt: float) -> void:
	for flame in flames: flame.hide()
	used=0
	var elapsed:=age
	super.render(dt)
	if elapsed<0: return
	var cam:=view.cam.global_basis
	var ground:=floor_point(land,.04)
	match move:
		"fire_fang":
			sprite.hide()
			var t:=(elapsed-timing)/.36
			if t>=0 and t<1:
				for i in 7:
					var angle:=TAU*i/7+.2
					var pos:=Vector2(cos(angle),sin(angle)*.65)*(5+t*14)
					pos.y+=t*t*7
					var size:=(5+i%3)*sin(PI*t)
					ember(fang_anchor+(cam.x*pos.x+cam.y*pos.y)/Arena.TILE,cam,Vector2(size,size*1.5),-.32*cos(angle),1-t*t,angle,.42)
		"fire_spin":
			# Keep a dim, continuous helix underneath the rising ember clusters.
			sprite.modulate.a*=.48
			if elapsed<3:
				var opening:=smoothstep(0,.2,elapsed)
				var center:=muzzle_start.lerp(ground,opening)
				for i in 22:
					var u:=fposmod(i/22.0+elapsed*.81,1)
					var angle:=TAU*(2.12*u+elapsed*.67)
					var radius:=(10+12*u)*lerpf(.2,1,opening)
					var offset:=Vector2(cos(angle)*radius,2+36*u+sin(angle)*radius*.23)*opening
					var size:=(4+3*sin(PI*u))*lerpf(.32,1,opening)
					ember(center+(cam.x*offset.x+cam.y*offset.y)/Arena.TILE,cam,Vector2(size*.83,size*1.65),-.64*cos(angle),sin(PI*u)*(1-smoothstep(2.55,3,elapsed)),i,.35+.30*cos(angle))
		"inferno":
			sprite.modulate.a*=.36
			if elapsed<1:
				var envelope:=smoothstep(0,.21,elapsed)*(1-smoothstep(.62,1,elapsed))
				for i in 13:
					var x:=(i-6)*3.05
					var peak:=26+19*cos(x/14)+7*sin(i*3+elapsed*13)
					var height:=peak*envelope
					var offset:=Vector2(x*envelope,height*.41+2*sin(i*2))
					var size:=Vector2((13+5*sin(i))*envelope,height)
					ember(ground+(cam.x*offset.x+cam.y*offset.y)/Arena.TILE,cam,size,.22*sin(i+elapsed*8),envelope,i,.75*(1-absf(x)/22))
		"flare_blitz":
			sprite.modulate.a*=.53
			if elapsed<.46:
				var aim:=aimed_basis()
				var strength:=smoothstep(0,.065,elapsed)*(1-smoothstep(.30,.46,elapsed))
				var center:=body_center()+cam.z*.13
				for i in 12:
					var angle:=TAU*i/12+elapsed*13
					var offset:=Vector2(cos(angle)*11,sin(angle)*8)*strength
					var size:=Vector2(6,10+5*(1-cos(angle)))*strength
					ember(center+(aim.x*offset.x+aim.y*offset.y)/Arena.TILE,aim,size,.9+.43*sin(angle),strength*(.8+.16*cos(angle)),i,.36)
	if used>0: shown_frames+=1

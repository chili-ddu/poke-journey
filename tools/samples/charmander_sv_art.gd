extends "res://tools/samples/charmander_forward_art.gd"

var glow: Sprite3D
var ignition_time := 0.0
var fang_anchor := Vector3.ZERO

func sheet_path(id: String) -> String:
	return "res://docs/charmander_sv_forward/sheets/%s/sheet" % id

func setup(v: View3D, w: World, id: String) -> void:
	super.setup(v,w,id)
	glow=layer(Fx.sheet("g4_glow"))

func body_center() -> Vector3:
	var body: Sprite3D=view._sprites[world.player.get_instance_id()].sprite
	return view.sprite_pixel_position(body,visible_bounds(body).get_center())

func shine(point: Vector3, color: Color, diameter: float) -> void:
	glow.basis=view.cam.global_basis
	glow.position=point+view.cam.global_basis.z*.14
	glow.pixel_size=diameter/glow.texture.get_width()
	glow.modulate=color
	glow.show()

func draw_breath(anchor: Vector3, aim: Basis, span: float, dragon: bool) -> void:
	draw_sheet(fmod(age,1.0),anchor,aim,Vector2(span/(137 if dragon else 149),.66 if dragon else .71),1,origin)

func draw_cut(t: float, aim: Basis) -> void:
	var reach:=.68 if move=="scratch" else .93
	draw_sheet(t,mouth()+aim.x*reach,aim,Vector2.ONE*(.62 if move=="scratch" else .66),1,origin)

func render(dt: float) -> void:
	glow.hide()
	if age<0:
		if world.pending_casts.is_empty(): return
		flow=world.player.facing
		var heat:=smoothstep(0,.20,ignition_time)
		if move=="dragon_breath":
			shine(mouth(),Color(1,.65,.90,.92),.19+.43*heat)
		elif move=="flare_blitz" or move=="inferno":
			shine(body_center(),Color(1,.58,.20,.76),.31+.63*heat)
		ignition_time+=dt
		return
	if move in ["dragon_breath","flamethrower"]:
		super.render(dt)
		return
	sprite.hide()
	var aim:=aimed_basis()
	var ground:=floor_point(land,.04)
	match move:
		"scratch","slash":
			var t:=age-maxf(0,timing-.095)
			if t>=0 and t<(.32 if move=="scratch" else .38):
				draw_cut(t,aim)
		"fire_fang":
			# Position the closure sparks on the existing directional jaw, before it disappears.
			var t:=age-timing
			for fx in world.fxs:
				if fx.kind=="fang_directional":
					if t<=.035:
						fang_anchor=view._air(fx.position,10.0)
						var entry: Dictionary=view._sprites.get(fx.get_instance_id(),{})
						if entry.has("jaw0"): fang_anchor=entry.jaw0.global_position
					shown_frames+=1
			if t>=0 and t<.4:
				draw_sheet(t,fang_anchor,aim,Vector2.ONE*.68,.9,origin)
		"smoke_screen":
			var u:=clampf(age/maxf(.001,timing),0,1)
			var end:=ground+Vector3.UP*.07
			pellet.visible=u<1
			shadow.visible=age<timing+1.2
			shadow.basis=Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)*Basis.from_scale(Vector3(1,.55,1))
			shadow.position=floor_point(world.player.position.lerp(land,u),.03)
			shadow.pixel_size=(.35+.70*u)/shadow.texture.get_width()
			shadow.modulate.a=.31*(1-smoothstep(timing+.4,timing+1.2,age))
			if u<1:
				pellet.basis=view.cam.global_basis
				pellet.pixel_size=(.19+.15*u)/pellet.texture.get_width()
				pellet.position=muzzle_start.lerp(end,u)+Vector3.UP*.36*4*u*(1-u)
			elif age-timing<1.3:
				draw_sheet(age-timing,ground,view.cam.global_basis,Vector2(.88,.69),1,origin)
		"fire_spin":
			if age<3:
				var u:=smoothstep(0,.20,age)
				var lift:=fmod(age,1.0)
				var center:=muzzle_start.lerp(ground,u)
				draw_sheet(lift,center,view.cam.global_basis,Vector2(.70,.61)*lerpf(.19,1,u),1-smoothstep(2.53,3,age),origin)
		"inferno":
			if age<1:
				draw_sheet(age,ground,view.cam.global_basis,Vector2(.76,.66),1,origin)
		"flare_blitz":
			if age<.46:
				draw_sheet(age,body_center()+view.cam.global_basis.z*.11,aim,Vector2.ONE*.77,1,origin)
	if sprite.visible: shown_frames+=1
	age+=dt

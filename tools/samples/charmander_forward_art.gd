extends RefCounted

# All sheet coordinates are local to their exported transparent pixelfx frames.
const SHEETS := {
	"scratch":"melee/claw-swipe","slash":"melee/sword-slash","smoke_screen":"explosions/smoke-bomb",
	"dragon_breath":"fire/fire-breath","flamethrower":"fire/flamethrower","fire_spin":"fire/fire-tornado",
	"inferno":"fire/flame-pillar","flare_blitz":"fire/fireball"
}
var view: View3D
var world: World
var sprite: Sprite3D
var pellet: Sprite3D
var shadow: Sprite3D
var atlas: Texture2D
var cells: Array
var origin: Vector2
var fps: float
var move: String
var flow := Vector2.RIGHT
var land := Vector2.ZERO
var muzzle_start := Vector3.ZERO
var frame_bounds := {}
var timing := 0.0
var age := -1.0
var shown_frames := 0

func setup(v: View3D, w: World, id: String) -> void:
	view=v
	world=w
	move=id
	var path := sheet_path(move)
	if not path.is_empty():
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
		cells=info.frames
		fps=info.meta.pixelfx.fps
		origin=Vector2(info.meta.pixelfx.pivot[0],info.meta.pixelfx.pivot[1])
		atlas=ImageTexture.create_from_image(Image.load_from_file(path+".png"))
		sprite=layer(atlas)
	if id=="smoke_screen":
		pellet=layer(Fx.sheet("g4_smoke_blob"))
		pellet.modulate=Color(.32,.28,.35)
		shadow=layer(Fx.sheet("g4_glow"))
		shadow.modulate=Color(.13,.11,.15,.55)
	w.connect("release",start)

func sheet_path(id: String) -> String:
	if not SHEETS.has(id): return ""
	return "res://docs/charmander_forward_casts/sheets/%s/%s" % [SHEETS[id],String(SHEETS[id]).get_file()]

func layer(tex: Texture2D) -> Sprite3D:
	var s := view._new_sprite(BaseMaterial3D.BILLBOARD_DISABLED)
	s.texture=tex
	s.region_enabled=false
	s.shaded=false
	s.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	s.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.hide()
	return s

func start(_move: String, dir: Vector2, landing: Vector2, close: float) -> void:
	flow=dir
	land=landing
	timing=close
	age=0
	muzzle_start=mouth()

func mouth() -> Vector3:
	var mon := world.player
	var body: Sprite3D=view._sprites[mon.get_instance_id()].sprite
	var used:=visible_bounds(body)
	var pixel:=Vector2(used.get_center().x,used.position.y+used.size.y*.34)
	var forward := Vector3(flow.x,0,flow.y)*mon.radius*.75/Arena.TILE
	return view.sprite_pixel_position(body,pixel)+forward

func visible_bounds(body: Sprite3D) -> Rect2:
	var key: Array=[body.texture.get_instance_id(),body.region_rect]
	if not frame_bounds.has(key):
		var image:=body.texture.get_image()
		if image.is_compressed(): image.decompress()
		frame_bounds[key]=Rect2(image.get_region(Rect2i(body.region_rect)).get_used_rect())
	return frame_bounds[key]

func floor_point(pos: Vector2, height: float) -> Vector3:
	return View3D.to3d(pos+Vector2(0,world.player.feet_offset()),height)

func aimed_basis() -> Basis:
	var vector:=Vector3(flow.x,0,flow.y)
	var angle:=atan2(vector.dot(view.cam.global_basis.y),vector.dot(view.cam.global_basis.x))
	var basis:=view.cam.global_basis*Basis(Vector3.BACK,angle)
	if vector.dot(view.cam.global_basis.x)<-.001: basis.y = -basis.y
	return basis

func draw_sheet(seconds: float, anchor: Vector3, basis: Basis, pixels: Vector2, opacity: float, pivot: Vector2) -> void:
	var cell: Dictionary=cells[clampi(floori(seconds*fps),0,cells.size()-1)].frame
	var rect:=Rect2(cell.x,cell.y,cell.w,cell.h)
	sprite.region_enabled=true
	sprite.region_rect=rect
	sprite.pixel_size=1.0/Arena.TILE
	sprite.basis=basis*Basis.from_scale(Vector3(pixels.x,pixels.y,1))
	sprite.position=anchor+(basis.x*(rect.size.x*.5-pivot.x)*pixels.x+basis.y*(pivot.y-rect.size.y*.5)*pixels.y)/Arena.TILE
	sprite.modulate=Color(1,1,1,clampf(opacity,0,1))
	sprite.visible=opacity>.02

func render(dt: float) -> void:
	if age<0: return
	if sprite: sprite.hide()
	var aim:=aimed_basis()
	var ground:=floor_point(land,.035)
	match move:
		"scratch","slash":
			var t:=age-maxf(0,timing-.085)
			var speed:=2.1 if move=="scratch" else 1.55
			if t>=0 and t*speed<.66:
				var anchor:=mouth()+aim.x*(.20 if move=="scratch" else .27)
				draw_sheet(t*speed,anchor,aim,Vector2.ONE*(.48 if move=="scratch" else .64),1-smoothstep(.37,.66,t*speed),origin+Vector2(16 if move=="scratch" else 3,-22))
		"fire_fang":
			# Native paired jaws and the collision-limited step share the closing clock.
			for fx in world.fxs:
				if fx.kind=="fang_directional": shown_frames+=1
		"smoke_screen":
			var u:=clampf(age/maxf(.001,timing),0,1)
			var end:=ground+Vector3.UP*.07
			pellet.visible=u<1
			shadow.visible=age<timing+1.3
			if u<1:
				pellet.basis=view.cam.global_basis*Basis(Vector3.BACK,-2.5*u)
				pellet.pixel_size=.28/float(pellet.texture.get_width())
				pellet.position=muzzle_start.lerp(end,u)+Vector3.UP*.67*4*u*(1-u)
				shadow.position=floor_point(world.player.position.lerp(land,u),.04)
				shadow.basis=Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)*Basis.from_scale(Vector3(1,.75,1))
				shadow.pixel_size=(.40+.12*u)/shadow.texture.get_width()
			else:
				var t:=age-timing
				shadow.position=floor_point(land,.04)
				shadow.pixel_size=(.52+.46*smoothstep(0,.32,t))/shadow.texture.get_width()
				shadow.modulate.a=.35*(1-smoothstep(.52,1.3,t))
				if t<1.72:
					draw_sheet(1.03+t*2.25,ground,view.cam.global_basis,Vector2(.36,.27),.26*(1-smoothstep(.78,1.45,t)),origin)
		"dragon_breath","flamethrower":
			var near_x:=INF
			var far_x:=0.0
			for p: Projectile in world.projectiles:
				if p.dead or p.hit.get("move")!=move: continue
				var dist:=maxf(0,(p.position-p.launch_position).dot(flow))
				near_x=minf(near_x,dist)
				far_x=maxf(far_x,dist)
				p.hide()
				if view._sprites.has(p.get_instance_id()):
					for node in view._sprites[p.get_instance_id()].values():
						if node is VisualInstance3D: node.hide()
			if near_x!=INF:
				var dragon:=move=="dragon_breath"
				# The front follows the leading projectile; after release the rear detaches.
				var first:=maxf(0,near_x-11.0)
				var planar:=Vector3(flow.x,0,flow.y)
				var projected:=Vector2(planar.dot(view.cam.global_basis.x),planar.dot(view.cam.global_basis.y)).length()
				var span:=maxf(4.0,far_x+5.0-first)*projected
				var anchor:=mouth()+Vector3(flow.x,0,flow.y)*first/Arena.TILE
				draw_breath(anchor,aim,span,dragon)
		"fire_spin":
			if age<3.0:
				var scale:=smoothstep(0,.23,age)
				draw_sheet(fmod(age,2),ground,view.cam.global_basis,Vector2(.85,.50)*lerpf(.18,1,scale),1-smoothstep(2.56,3,age),origin)
		"inferno":
			if age<1.0:
				draw_sheet(.56+age*3.5,ground,view.cam.global_basis,Vector2(.81,.44),1-smoothstep(.72,1,age),origin)
		"flare_blitz":
			if age<.41:
				var actor: Sprite3D=view._sprites[world.player.get_instance_id()].sprite
				var body:=view.sprite_pixel_position(actor,visible_bounds(actor).get_center())+aim.x*.27+view.cam.global_basis.z*.10
				var amount:=smoothstep(0,.065,age)*(1-smoothstep(.29,.41,age))
				draw_sheet(fmod(age*2.1,1.2),body,aim,Vector2(.67,.88)*lerpf(.38,1,amount),.88*amount,origin)
	if sprite and sprite.visible: shown_frames+=1
	age+=dt

func draw_breath(anchor: Vector3, aim: Basis, span: float, dragon: bool) -> void:
	draw_sheet(fmod(age,1.5),anchor,aim,Vector2(span/(138.0 if dragon else 149.0),.38 if dragon else .43),.96,origin)

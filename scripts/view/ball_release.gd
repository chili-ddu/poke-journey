class_name BallRelease
extends RefCounted

const ATLAS := preload("res://assets/fx/pixelfx/ball_release.png")
const BALL_RECT := Rect2(3,5,10,10)
const PIXEL := Arena.MAP_SCALE * 0.75 * 0.60
const REST := 0.15
const OPEN := 0.16
const GROWN := 0.235
const LIFE := 0.70
const CREAM := Color("fff5d8")
static var masks := {}

static func growth(age: float) -> float:
	return smoothstep(0.045, GROWN, age)

static func frame(age: float) -> Rect2:
	var index := clampi(floori(age*30.0),0,21)
	return Rect2((index%5)*64, floori(index/5.0)*64,64,64)

# Only the alpha shape changes between poses. Fade the cached mask on the GPU.
static func mask(texture: Texture2D, rect: Rect2i) -> Texture2D:
	var key := [texture.get_instance_id(),rect]
	if not masks.has(key):
		if masks.size() >= 48: masks.erase(masks.keys()[0])
		var alpha := MonSprite._visual_image(texture).get_region(rect)
		var white := Image.create_empty(rect.size.x,rect.size.y,false,Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		var result := Image.create_empty(rect.size.x,rect.size.y,false,Image.FORMAT_RGBA8)
		result.blit_rect_mask(white,alpha,Rect2i(Vector2i.ZERO,rect.size),Vector2i.ZERO)
		masks[key] = ImageTexture.create_from_image(result)
	return masks[key]

static func strength(age: float) -> float:
	return 1.0-smoothstep(0.11,0.31,age)

static func support_of(mon: Mon, table := false) -> Vector2:
	if table or Arena.native_at(Arena.tile_of(mon.position)): return mon.position
	return mon.position + Vector2.DOWN*mon.feet_offset()

static func center_3d(view: View3D, support: Vector2, table: bool) -> Vector3:
	var height := view._starter_table_height+0.015 if table else 0.0
	return View3D.to3d(support,height)+view.cam.global_basis.y*(5.0*PIXEL/Arena.TILE)

static func draw_shadow(view: View3D, shadow: MeshInstance3D, at: Vector3, opacity: float) -> void:
	var sole := at-view.cam.global_basis.y*(5.0*PIXEL/Arena.TILE)
	shadow.position = View3D.to3d(Vector2(sole.x,sole.z)*Arena.TILE,0.012)
	var height := clampf((sole.y-shadow.position.y)/1.6,0,1)
	var size := lerpf(0.43,0.30,height)
	shadow.scale = Vector3(size,1.0,size)
	(shadow.material_override as StandardMaterial3D).albedo_color = Color(0,0,0,lerpf(0.54,0.11,height)*opacity)
	shadow.visible = opacity > 0.0

static func shell_offset(top: bool, age: float) -> float:
	return 2.5+4.2*sin(clampf(age/OPEN,0,1)*PI*0.5) if top else -2.5

static func draw_flat(f: Fx) -> void:
	var origin := Vector2.UP*5.0*PIXEL
	if f.age < OPEN:
		for i in 2:
			var at := origin + Vector2.UP*shell_offset(i==0,f.age)*PIXEL
			f.draw_set_transform(at, -0.28*f.age/OPEN if i==0 else 0.0)
			f.draw_texture_rect_region(StarterBalls.ItemPalette.ground_ball(),Rect2(Vector2(-5,-2.5)*PIXEL,Vector2(10,5)*PIXEL),Rect2(3,5+i*5,10,5),Color(1,1,1,1.0-smoothstep(0.09,OPEN,f.age)))
	f.draw_set_transform(Vector2.ZERO)
	if is_instance_valid(f.owner_mon):
		var m := f.owner_mon as Mon
		origin = origin.lerp(m.position-f.position+Vector2.UP*m.lift,smoothstep(0.045,OPEN,f.age))
	var size := Vector2.ONE * 64.0*0.052*Arena.TILE
	f.draw_texture_rect_region(ATLAS,Rect2(origin-size/2.0,size),frame(f.age))

static func draw_3d(view: View3D, f: Fx, ent: Dictionary) -> void:
	var origin := center_3d(view,f.position,f.starter_table)
	var axes := view.cam.global_basis.orthonormalized()
	if not ent.has("light"):
		var light := view._new_unlit_sprite(BaseMaterial3D.BILLBOARD_DISABLED,SpriteBase3D.ALPHA_CUT_DISABLED)
		light.texture = ATLAS
		light.region_enabled = true
		light.pixel_size = 0.052
		light.render_priority = 2
		ent.light = light
		for i in 2:
			var half := view._new_unlit_sprite(BaseMaterial3D.BILLBOARD_DISABLED,SpriteBase3D.ALPHA_CUT_DISABLED)
			half.texture = StarterBalls.ItemPalette.ground_ball()
			half.region_enabled = true
			half.region_rect = Rect2(3,5+i*5,10,5)
			half.pixel_size = PIXEL/Arena.TILE
			half.render_priority = 1
			ent[i] = half
		if not f.starter_table: ent.shadow = view._new_blob()
	for i in 2:
		var half: Sprite3D = ent[i]
		half.visible = f.age < OPEN
		half.modulate.a = 1.0-smoothstep(0.09,OPEN,f.age)
		half.position = origin+axes.y*half.pixel_size*shell_offset(i==0,f.age)
		half.basis = axes*Basis(Vector3.FORWARD,0.28*clampf(f.age/OPEN,0,1) if i==0 else 0.0)
	if ent.has("shadow"): draw_shadow(view,ent.shadow,origin,1.0-smoothstep(0.09,OPEN,f.age))
	var light: Sprite3D = ent.light
	light.region_rect = frame(f.age)
	light.basis = axes
	light.position = origin+axes.z*0.10
	if not is_instance_valid(f.owner_mon): return
	var body: Sprite3D = view._sprites.get(f.owner_mon.get_instance_id(),{}).get("sprite")
	if body == null or not body.visible: return
	var bounds := MonSprite.release_bounds(body.texture,Rect2i(body.region_rect))
	var center := view.sprite_pixel_position(body,bounds.get_center())
	light.position = origin.lerp(center,smoothstep(0.045,OPEN,f.age))+axes.z*0.10

static func align_body(view: View3D, f: Fx, body: Sprite3D) -> void:
	var settle := 1.0-smoothstep(0.055,0.24,f.age)
	if settle <= 0.0: return
	var bounds := MonSprite.release_bounds(body.texture,Rect2i(body.region_rect))
	var foot := view.sprite_pixel_position(body,Vector2(bounds.get_center().x,bounds.end.y))
	var lip := center_3d(view,f.position,f.starter_table)-view.cam.global_basis.y*5.0*PIXEL/Arena.TILE*smoothstep(0.045,OPEN,f.age)
	body.position += (lip-foot)*settle

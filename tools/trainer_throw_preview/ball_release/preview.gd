extends RefCounted

const ItemArt = preload("res://scripts/view/item_palette.gd")
const OPEN_TIME := 0.16
const LIGHT_TIME := 0.70
const BALL_PIXEL := Arena.MAP_SCALE*0.75*0.60/Arena.TILE
var grounded := false
var foot_aligned := false
var contact: MeshInstance3D
var light: Sprite3D
var shell: Array[Sprite3D] = []
var images := {}

func ball_center(view: View3D, at: Vector2, mon: Mon) -> Vector3:
	if foot_aligned:
		var feet := at
		if not Arena.native_at(Arena.tile_of(at)): feet.y += mon.feet_offset()
		# The ball is a camera-facing sprite. Put its lowest pixel on the
		# same ground point as the Pokemon's contact shadow at this lens angle.
		return View3D.to3d(feet) + view.cam.global_basis.y * (5.0*BALL_PIXEL)
	var height := 5.0*BALL_PIXEL*view.cam.global_basis.y.y if grounded else 0.35
	return View3D.to3d(at,height)

func draw_shadow(view: View3D, ball_at: Vector3, opacity := 1.0) -> void:
	if contact == null: contact = view._new_blob()
	var support := ball_at - view.cam.global_basis.y*(5.0*BALL_PIXEL) if foot_aligned else ball_at
	var floor_at := View3D.to3d(Vector2(support.x,support.z)*Arena.TILE,0.012)
	var height := clampf(ball_at.y-floor_at.y,0.0,1.6)/1.6
	var size := lerpf(0.43,0.30,height)
	contact.position = floor_at
	contact.scale = Vector3(size,1.0,size)
	(contact.material_override as StandardMaterial3D).albedo_color = Color(0,0,0,lerpf(0.54,0.11,height)*opacity)
	contact.visible = opacity > 0.0

func draw(game: Node, view: View3D, age: float) -> void:
	if age < 0.0: return
	var mon: Enemy = game.sendout.mon
	# Replace just the three original ball emitters in this review.
	for fx: Fx in game.world.fxs:
		if fx.text.begins_with("g4_ballopen_"):
			var effect: Dictionary = view._sprites.get(fx.get_instance_id(), {})
			if effect.has("sprite"): effect.sprite.hide()
	if light == null: _setup(view)
	var origin := ball_center(view,mon.position,mon)
	if grounded: draw_shadow(view,origin,1.0-smoothstep(0.09,OPEN_TIME,age))
	var axes := view.cam.global_basis.orthonormalized()
	var progress := clampf(age / OPEN_TIME, 0.0, 1.0)
	for i in shell.size():
		var half := shell[i]
		var side := 1.0 if i == 0 else -1.0
		half.visible = age < OPEN_TIME
		half.modulate.a = 1.0 - smoothstep(0.09, OPEN_TIME, age)
		var hinge := progress
		if grounded and i == 1: hinge = 0.0  # Keep the lower shell on its point of contact.
		half.position = origin + axes.y * side * half.pixel_size * (2.5 + 4.2*sin(hinge*PI*0.5))
		half.basis = axes * Basis(Vector3.FORWARD, side * 0.28 * hinge)
	light.visible = age < LIGHT_TIME
	if light.visible:
		var idx := mini(21, floori(age * 30.0))
		light.region_rect = Rect2((idx%5)*64, floori(idx/5.0)*64,64,64)
		light.basis = axes
		light.position = origin + Vector3.UP * (0.21*smoothstep(0.0,0.24,age)) + axes.z * 0.08
	# Use the actual visible frame so the light resolves into this species' own silhouette.
	var entry: Dictionary = view._sprites.get(mon.get_instance_id(), {})
	if age >= LIGHT_TIME or not entry.has("sprite"): return
	var body: Sprite3D = entry.sprite
	if not body.visible: return
	var bounds := MonSprite.release_bounds(body.texture,Rect2i(body.region_rect))
	var center := view.sprite_pixel_position(body,bounds.get_center())
	var settle := 1.0-smoothstep(0.055,0.24,age)
	if foot_aligned:
		var sole := Vector2(bounds.get_center().x,bounds.end.y)
		var foot := view.sprite_pixel_position(body,sole)
		var lip := origin - axes.y * 5.0*BALL_PIXEL * smoothstep(0.045,0.16,age)
		body.position += (lip-foot)*settle
	else:
		body.position += (origin-center)*settle
	center = view.sprite_pixel_position(body,bounds.get_center())
	light.position = origin.lerp(center,smoothstep(0.045,0.16,age)) + axes.z*0.10
	if age >= 0.31: return
	var ink := roundi(8.0 * (1.0 - smoothstep(0.11,0.31,age)))
	var key := [body.texture.get_instance_id(),body.region_rect,ink]
	if not images.has(key):
		var img := body.texture.get_image().get_region(Rect2i(body.region_rect))
		for y in img.get_height():
			for x in img.get_width():
				var pixel := img.get_pixel(x,y)
				if pixel.a > 0:
					var bright := pixel.lerp(Color("fff5d8"), ink/8.0)
					bright.a = pixel.a
					img.set_pixel(x,y,bright)
		images[key] = ImageTexture.create_from_image(img)
	body.texture = images[key]
	body.region_rect = Rect2(Vector2.ZERO,body.texture.get_size())
	body.modulate = Color.WHITE

func _setup(view: View3D) -> void:
	light = view._new_unlit_sprite(BaseMaterial3D.BILLBOARD_DISABLED, SpriteBase3D.ALPHA_CUT_DISABLED)
	var filename := "ground-release" if grounded else "release"
	var atlas := Image.load_from_file("res://tools/trainer_throw_preview/ball_release/%s.png" % filename)
	# The pixelfx transparent export stores light premultiplied; Sprite3D
	# blends straight alpha. Restore the bright RGB of low-opacity glows.
	for y in atlas.get_height():
		for x in atlas.get_width():
			var c := atlas.get_pixel(x,y)
			if c.a > 0.0 and c.a < 1.0:
				atlas.set_pixel(x,y,Color(minf(1,c.r/c.a),minf(1,c.g/c.a),minf(1,c.b/c.a),c.a))
	light.texture = ImageTexture.create_from_image(atlas)
	light.region_enabled = true
	light.pixel_size = 0.052
	light.render_priority = 2
	for i in 2:
		var half := view._new_unlit_sprite(BaseMaterial3D.BILLBOARD_DISABLED, SpriteBase3D.ALPHA_CUT_DISABLED)
		half.texture = ItemArt.ground_ball()
		half.region_enabled = true
		half.region_rect = Rect2(3,5*i+5,10,5)
		half.pixel_size = BALL_PIXEL
		half.render_priority = 1
		shell.append(half)

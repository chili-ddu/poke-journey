# Review-only: align to the actual rendered eye surface, then sharpen the glint.
extends "res://tools/samples/self_cut_eye_side.gd"

var depth_correction:=0.0
var screen_error_before:=0.0
var aligned_fx:=0
var eye_images: Dictionary={}
var live_eye_pixel:=Vector2.ZERO

func _rendered_eye(body: Sprite3D,reference: Vector2,species: String) -> Vector2:
	var key:=body.texture.get_instance_id()
	if not eye_images.has(key):
		var image:=body.texture.get_image()
		if image.is_compressed():image.decompress()
		eye_images[key]=image
	var image: Image=eye_images[key]
	var sum:=Vector2.ZERO
	var weight:=0.0
	for y in range(maxi(0,int(reference.y)-4),mini(int(body.region_rect.size.y),int(reference.y)+5)):
		for x in range(maxi(0,int(reference.x)-4),mini(int(body.region_rect.size.x),int(reference.x)+5)):
			var pixel:=Vector2(x,y)
			if pixel.distance_to(reference)>4.0:continue
			var color:=image.get_pixel(int(body.region_rect.position.x)+x,int(body.region_rect.position.y)+y)
			var iris: bool=(color.b>color.r+0.1 and color.b>0.25 and color.r<0.55) if species=="charmander" else (color.r>0.45 and color.g<0.28 and color.b<0.28)
			if color.a>0.5 and iris:sum+=pixel;weight+=1.0
	return sum/weight if weight>0.0 else reference

func _align(fx: Fx,p: Player,view: View3D) -> void:
	var body: Sprite3D=view._sprites[p.get_instance_id()].sprite
	live_eye_pixel=_rendered_eye(body,fx.get_meta("eye_source_pixel"),p.species_id)
	var eye_world:=view.sprite_pixel_position(body,live_eye_pixel)
	var relative:=eye_world-body.position
	var camera_basis:=view.cam.global_basis
	fx.offset=Vector2(relative.dot(camera_basis.x)*Arena.TILE,p.feet_offset()-relative.dot(camera_basis.y)*Arena.TILE)
	fx.position=p.position+fx.offset
	fx.body_depth=relative.dot(camera_basis.z)+0.05
	var fixed: Dictionary=view._fx_sprite_state(fx,fx.sprite_texture())
	assert(view.cam.unproject_position(eye_world).distance_to(view.cam.unproject_position(fixed.position))<1.0,"The light stays on the rendered eye")
	assert((Vector3(fixed.position)-eye_world).dot(camera_basis.z)>0.02,"The eye light is in front of the face")

func _flash_eyes() -> void:
	super._flash_eyes()
	if not Fx._sheets.has("field_eye_glint_sample"):
		var image:=Image.load_from_file("res://docs/direct_field_hms/self_cut_eye_visible_sample/pixelfx/eye-glint-peak.png")
		Fx._sheets["field_eye_glint_sample"]=ImageTexture.create_from_image(image)
	var p: Player=game.world.player
	var view: View3D=game.view3d
	var anim: Dictionary=p._sprites["Idle"]
	var row:=MonSprite.row_for(anim,p.facing)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(POINTS))
	var points: Array=data[p.species_id].rows[row]
	if points.is_empty():return
	var eye_pixel:=Vector2.ZERO
	for point: Array in points:eye_pixel+=Vector2(float(point[0]),float(point[1]))/float(points.size())
	var body: Sprite3D=view._sprites[p.get_instance_id()].sprite
	var eye_world:=view.sprite_pixel_position(body,eye_pixel)
	var camera_basis:=view.cam.global_basis
	var spark_index:=0
	for fx: Fx in game.world.fxs:
		if fx.follow!=p or fx.age>0.001 or fx.text not in ["g4_spark","g4_streak"]:continue
		if fx.text=="g4_streak":
			fx.dead=true;continue
		var old_state: Dictionary=view._fx_sprite_state(fx,fx.sprite_texture())
		depth_correction=maxf(depth_correction,(eye_world-Vector3(old_state.position)).dot(camera_basis.z))
		screen_error_before=maxf(screen_error_before,view.cam.unproject_position(eye_world).distance_to(view.cam.unproject_position(old_state.position)))
		# The upright character's head is nearer the camera than its ground origin.
		# Preserve the projected eye coordinate while placing the light before that surface.
		fx.set_meta("eye_surface_aligned",true)
		var source_pixel:=eye_pixel
		if fx.text=="g4_spark":
			var point: Array=points[mini(spark_index,points.size()-1)]
			source_pixel=Vector2(float(point[0]),float(point[1]));spark_index+=1
			fx.text="field_eye_glint_sample";fx.size=18.0;fx.lifetime=0.28;fx.grow=0.35;fx.fade_in=0.035;fx.fade_out=0.5
			fx.color=Color.WHITE;fx.material=null
		else:
			fx.size=1.35;fx.stretch=10.0;fx.lifetime=0.22;fx.grow=0.5;fx.fade_out=0.6
		fx.set_meta("eye_source_pixel",source_pixel)
		_align(fx,p,view)
		aligned_fx+=1
	print("Eye visibility / ",p.species_id," / old depth behind face: ",depth_correction," / screen error: ",screen_error_before," px / aligned effects: ",aligned_fx)

func step(dt: float) -> void:
	super.step(dt)
	for fx: Fx in game.world.fxs:
		if not fx.dead and fx.get_meta("eye_surface_aligned",false):_align(fx,game.world.player,game.view3d)

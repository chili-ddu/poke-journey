extends RefCounted
## The same impact time drives the physical cuts, their residual size and both fragment layers.
const Art = preload("res://scripts/view/contact_move_art.gd")
const Shimmer = preload("res://assets/shaders/clash_chip_shimmer.gdshader")
const FlatShimmer = preload("res://assets/shaders/clash_chip_flat.gdshader")
const CHIP_CELL := Vector2(72,44)
const CUT_LEAD := .095
const FPS := 30.0
const CUTS := {
	"scratch": {"cell": Vector2(68,56), "cols": 4, "frames": 11, "near": Vector2(-23.5,-13.5), "scale": .62, "duration": .32},
	"slash": {"cell": Vector2(94,66), "cols": 3, "frames": 12, "near": Vector2(-43,-19.5), "scale": .66, "duration": .38},
}
static var _cut_pixels: Dictionary = {}

static func _chip_sheet(element: String) -> String:
	return "clash_"+element if element in ["fire","water"] else "clash_normal"

static func _chip_tint(element: String) -> Color:
	return Color.WHITE if element in ["fire","water","normal"] else TypeChart.type_color(element)

static func _cut_time(f) -> float:
	return f.age - float(f.clash_hit.get("clash_visual_t",f.cut_delay)) + CUT_LEAD

static func residual_scale(f) -> float:
	if not f.clash_hit.has("clash_visual_t"): return 1.0
	var elapsed: float=f.age-f.clash_hit.clash_visual_t
	return lerpf(1.0,f.clash_hit.clash_fraction,smoothstep(0,2.0/FPS,elapsed))

static func residual_center_flat(f, center: Vector2, ratio: float) -> Vector2:
	var pair: Dictionary=f.clash_hit.get("clash_pair",{})
	if ratio>=1 or not pair.has("at"): return center
	var contact: Vector2=pair.at-f.position
	return contact+(center-contact)*ratio

static func residual_center_3d(view, f, center: Vector3, ratio: float) -> Vector3:
	var pair: Dictionary=f.clash_hit.get("clash_pair",{})
	if ratio>=1 or not pair.has("at"): return center
	var contact: Vector3=pair.get("anchor3",view._air(pair.at,6.0))
	return contact+(center-contact)*ratio

static func _cell(frame: int, columns: int, size: Vector2) -> Rect2:
	return Rect2(Vector2(frame%columns,frame/columns)*size,size)

static func draw_3d(view, f, entry: Dictionary) -> void:
	if f.kind=="clash_chip":
		_chip_3d(view,f,entry)
	elif CUTS.has(f.text) and is_instance_valid(f.follow):
		_cut_3d(view,f,entry)
	elif entry.has(0):
		entry[0].hide()

static func _chip_3d(view, f, entry: Dictionary) -> void:
	var sprite:=Art.layer(view,entry,0,_chip_sheet(f.text))
	var camera: Basis=view.cam.global_basis
	var direction:=Vector3(f.dir.x,0,f.dir.y)
	sprite.basis=camera*Basis(Vector3.BACK,atan2(direction.dot(camera.y),direction.dot(camera.x)))
	var base: Vector3=view.to3d(f.position+Vector2.DOWN*6,6.0/Arena.TILE*view.k)
	sprite.position=Vector3(f.clash_pair.get("anchor3",base))+camera.z*(.08 if f.clash_pair.get("melee",false) else .6)
	sprite.pixel_size=.82/Arena.TILE
	var material:=sprite.material_override as ShaderMaterial
	if material==null:
		material=_chip_material(f,Shimmer,sprite.texture)
		sprite.material_override=material
	sprite.region_enabled=true
	sprite.region_rect=_advance_chip(f.age,material)

static func _chip_material(f, shader: Shader, texture: Texture2D) -> ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("fragments",texture)
	material.set_shader_parameter("chip_tint",_chip_tint(f.text))
	material.set_shader_parameter("colored_chip",f.text!="normal")
	material.set_shader_parameter("offset_phase",.23 if f.dir.x<0 else 0.0)
	var shine: Color={"fire":Color("#ffaf54"),"water":Color("#69c9ff")}.get(f.text,_chip_tint(f.text))
	material.set_shader_parameter("shine_tint",shine)
	return material

static func _advance_chip(age: float, material: ShaderMaterial) -> Rect2:
	var frame:=clampi(floori(age*FPS),0,12)
	var region:=_cell(frame,3,CHIP_CELL)
	material.set_shader_parameter("frame_px",Vector4(region.position.x,region.position.y,region.size.x,region.size.y))
	material.set_shader_parameter("phase",frame/12.0)
	return region

static func _cut_3d(view, f, entry: Dictionary) -> void:
	var shape: Dictionary=CUTS[f.text]
	var seconds:=_cut_time(f)
	var sprite:=Art.layer(view,entry,0,"clash_"+f.text)
	var body: Sprite3D=view._sprites.get(f.follow.get_instance_id(),{}).get("sprite")
	sprite.visible=seconds>=0 and seconds<shape.duration and body!=null and body.texture!=null
	if not sprite.visible: return
	var camera: Basis=view.cam.global_basis
	var forward:=Vector3(f.dir.x,0,f.dir.y)
	var bounds:=MonSprite.release_bounds(body.texture,Rect2i(body.region_rect))
	if body.flip_h: bounds.position.x=body.region_rect.size.x-bounds.end.x
	var center: Vector3=view.sprite_pixel_position(body,bounds.get_center())
	var start: Vector3=center+forward*f.follow.radius*.83/Arena.TILE+Vector3.UP*.27+camera.y*6.0/Arena.TILE
	var side:=forward.dot(camera.x)
	var wrist:=.40*(1-absf(side))*(1.0 if side>=0 else -1.0)
	var along:=camera.x*(side+wrist)+camera.y*minf(forward.dot(camera.y),.23)
	var frame:=clampi(floori(seconds*FPS),0,shape.frames-1)
	Art.sheet(sprite,frame,shape.cols,shape.cell,shape.cell*.5+shape.near,start,Basis(along,camera.y,camera.z),Vector2.ONE*shape.scale,1)
	var pair: Dictionary=f.clash_hit.get("clash_pair",{})
	if pair.is_empty(): return
	_register_cut(view,pair,f.follow.get_instance_id(),sprite)
	var ratio:=residual_scale(f)
	sprite.visible=ratio>0
	if sprite.visible and ratio<1:
		sprite.position=residual_center_3d(view,f,sprite.position,ratio)
		sprite.basis.x*=ratio
		sprite.basis.y*=ratio

static func _local_ink(sprite: Sprite3D) -> PackedVector3Array:
	var region:=Rect2i(sprite.region_rect)
	var key: Array=[sprite.texture.get_instance_id(),region]
	if not _cut_pixels.has(key):
		var image:=sprite.texture.get_image()
		if image.is_compressed(): image.decompress()
		var offsets:=PackedVector3Array()
		for y in region.size.y:
			for x in region.size.x:
				if image.get_pixel(region.position.x+x,region.position.y+y).a>=.4:
					offsets.push_back(Vector3(x+.5-region.size.x*.5,region.size.y*.5-y-.5,0)*sprite.pixel_size)
		_cut_pixels[key]=offsets
	return _cut_pixels[key]

# Resolve at most once per impact. Keep the few projected pixels, never references
# to attacks or Nodes, so a one-sided cut cannot keep combatants alive.
static func _register_cut(view, pair: Dictionary, actor_id: int, sprite: Sprite3D) -> void:
	if pair.has("anchor3") or pair.get("first_actor",0)==actor_id: return
	var ink: Dictionary={}
	for offset in _local_ink(sprite):
		var at:=sprite.to_global(offset)
		ink[Vector2i(view.cam.unproject_position(at).round())]=at
	if not pair.has("first_ink"):
		pair.first_ink=ink
		pair.first_actor=actor_id
		return
	var first: Dictionary=pair.first_ink
	var shared: Array[Vector2i]=[]
	var center:=Vector2.ZERO
	for pixel: Vector2i in ink:
		if first.has(pixel):
			shared.append(pixel)
			center+=Vector2(pixel)
	pair.erase("first_ink")
	pair.erase("first_actor")
	pair.anchor3=view._air(pair.at,6.0)
	if shared.is_empty(): return
	center/=shared.size()
	var nearest:=shared[0]
	for pixel in shared:
		if center.distance_squared_to(pixel)<center.distance_squared_to(nearest): nearest=pixel
	pair.anchor3=first[nearest]

static func draw_flat(f) -> void:
	if f.kind=="clash_chip":
		var texture: Texture2D=f.sheet(_chip_sheet(f.text))
		if f.material==null: f.material=_chip_material(f,FlatShimmer,texture)
		var region:=_advance_chip(f.age,f.material)
		f.draw_set_transform(Vector2.ZERO,f.dir.angle(),Vector2.ONE*.82)
		f.draw_texture_rect_region(texture,Rect2(-CHIP_CELL*.5,CHIP_CELL),region)
		return
	if not is_instance_valid(f.follow) or not CUTS.has(f.text): return
	var shape: Dictionary=CUTS[f.text]
	var seconds:=_cut_time(f)
	var ratio:=residual_scale(f)
	if seconds<0 or seconds>=shape.duration or ratio<=0: return
	var side: float=f.dir.x
	var wrist:=.40*(1-absf(side))*(1.0 if side>=0 else -1.0)
	var axis:=Vector2(side+wrist,maxf(-.23,f.dir.y))
	var start: Vector2=f.dir*f.follow.radius*.83+Vector2.UP*10
	start=residual_center_flat(f,start,ratio)
	var scale: float=shape.scale*ratio
	var transform:=Transform2D(axis*scale,Vector2.DOWN*scale,start)
	f.draw_set_transform_matrix(transform)
	var region:=_cell(clampi(floori(seconds*FPS),0,shape.frames-1),shape.cols,shape.cell)
	f.draw_texture_rect_region(f.sheet("clash_"+f.text),Rect2(-shape.cell*.5-shape.near,shape.cell),region)

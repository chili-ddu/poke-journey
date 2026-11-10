extends RefCounted

# Native Walk rows: S, SE, E, NE, N, NW, W, SW. Feet rest on the shell,
# while the near neck/shell rim is drawn over the rider in both renderers.
const SEATS=[Vector2(23,22),Vector2(21,23),Vector2(18,27),Vector2(22,29),Vector2(23,29),Vector2(25,29),Vector2(29,27),Vector2(26,23)]
static var _front_cache: Dictionary={}
var rider: Mon
var carrier: Mon
var layers: Array[Node2D]=[]

class Layer:
	extends Node2D
	var ride: RefCounted
	var front:=false
	func _draw() -> void:
		if is_instance_valid(ride.carrier):ride.draw_layer(self,front)

func setup(passenger: Mon,lapras: Mon) -> void:
	rider=passenger;carrier=lapras
	rider.set_meta("lapras_ride",self);carrier.set_meta("lapras_carrier",true)
	for front in [false,true]:
		var layer:=Layer.new();layer.ride=self;layer.front=front
		layer.show_behind_parent=not front
		rider.add_child(layer);layers.append(layer)

func detach() -> void:
	if is_instance_valid(rider):rider.remove_meta("lapras_ride");rider.queue_redraw()
	if is_instance_valid(carrier):carrier.remove_meta("lapras_carrier");carrier.queue_redraw()
	for layer in layers:layer.queue_free()
	layers.clear()

func step() -> void:
	for layer in layers:layer.queue_redraw()
	rider.queue_redraw()

func pose() -> Dictionary:
	var anim: Dictionary=carrier._sprites.Walk
	var row:=MonSprite.dir_row(carrier.facing)
	var visual:=MonSprite.visual_frame(anim,row,carrier.anim_t,true)
	# Green PMD markers follow the torso, rather than the nodding head.
	var torso:=MonSprite.flight_anchor(anim,row,carrier.anim_t,visual)
	var origin: Vector2=anim.flight_centers[row][0]
	return {"visual":visual,"row":row,"seat":SEATS[row]+torso-origin,"center":MonSprite.anchor_of(carrier._sprites,anim)}

func offset_2d() -> Vector2:
	var at:=pose()
	var seat: Vector2=carrier.position-rider.position+Vector2(0,carrier.radius*Mon.GROUND_RATIO)+(at.seat-at.center)*carrier.sprite_scale
	return seat-Vector2(0,rider.feet_offset()-rider.lift)

static func in_front(pixel: Vector2,seat: Vector2,row: int) -> bool:
	var p:=pixel-seat
	match row:
		# Keep the shell behind the passenger. Only the near head/neck crosses
		# in front; diagonal neck contours widen toward the chest.
		0:return p.y< -5.0 or absf(p.x)<=3.5+maxf(0.0,p.y)*0.35
		1:return p.y< -6.0 or p.x>=maxf(-1.0,4.0-(p.y+6.0)*0.5)
		7:return p.y< -6.0 or p.x<=minf(1.0,-4.0+(p.y+6.0)*0.5)
		2:return p.x>7.0 or p.y>1.0
		6:return p.x< -7.0 or p.y>1.0
		_:return p.y>=-1.0

static func foreground(tex: Texture2D,src: Rect2,at: Dictionary) -> Texture2D:
	var key: String="%d:%s:%s:%d"%[tex.get_instance_id(),str(src),str(at.seat),at.row]
	if not _front_cache.has(key):
		var image:=tex.get_image()
		if image.is_compressed():image.decompress()
		image=image.get_region(Rect2i(src))
		for y in image.get_height():
			for x in image.get_width():
				if not in_front(Vector2(x,y),at.seat,at.row):image.set_pixel(x,y,Color.TRANSPARENT)
		if _front_cache.size()>=256:_front_cache.clear()
		_front_cache[key]=ImageTexture.create_from_image(image)
	return _front_cache[key]

func draw_layer(canvas: Node2D,front: bool) -> void:
	var at:=pose();var visual: Dictionary=at.visual
	if not front:
		var feet:=carrier.position-rider.position+Vector2(0,carrier.feet_offset())
		canvas.draw_set_transform(feet,0.0,Vector2(1.0,0.4))
		canvas.draw_circle(Vector2.ZERO,carrier.radius,Color(0.55,0.85,0.95,0.28))
	var offset:=carrier.position-rider.position+Vector2(0,carrier.radius*Mon.GROUND_RATIO)
	canvas.draw_set_transform(offset,0.0,Vector2.ONE*carrier.sprite_scale)
	var dst:=Rect2(-at.center,visual.src.size)
	if front:canvas.draw_texture_rect(foreground(visual.tex,visual.src,at),dst,false)
	else:canvas.draw_texture_rect_region(visual.tex,dst,visual.src)
	canvas.draw_set_transform(Vector2.ZERO)

func sync_carrier_3d(view,seen: Dictionary) -> void:
	var ent: Dictionary=view._entry(carrier,seen)
	if not ent.has("sprite"):
		ent.sprite=view._new_sprite(BaseMaterial3D.BILLBOARD_ENABLED)
		ent.blob=view._new_blob()
	# A shore arrival already has an ordinary walking sprite entry.
	if not ent.has("front"):
		ent.front=view._new_sprite(BaseMaterial3D.BILLBOARD_ENABLED)
		ent.front.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var s: Sprite3D=ent.sprite
	s.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	var at:=pose();var visual: Dictionary=at.visual
	var shaded:=Look.selout_frame(visual.tex,visual.src,view.sky_kind(DungeonDB.current))
	s.texture=shaded.tex;s.region_rect=shaded.src;s.pixel_size=carrier.sprite_scale/Arena.TILE
	s.offset=Vector2(visual.src.size.x*0.5-at.center.x,at.center.y+float(carrier._sprites.feet_dy)-1.0-visual.src.size.y*0.5)
	s.position=view.to3d(carrier.position+Vector2(0,carrier.feet_offset()),0.04)
	s.scale=Vector3.ONE;s.visible=true;s.modulate=Color.WHITE
	view._lift_to_camera(ent,s)
	var front: Sprite3D=ent.front
	front.texture=foreground(s.texture,s.region_rect,at)
	front.region_rect=Rect2(Vector2.ZERO,visual.src.size)
	front.pixel_size=s.pixel_size;front.offset=s.offset;front.scale=s.scale
	front.position=s.position+view.cam.global_basis.z*0.024;front.visible=true
	var blob: MeshInstance3D=ent.blob
	blob.position=view.to3d(carrier.position+Vector2(0,carrier.feet_offset()),0.02)
	blob.scale=Vector3(carrier.radius*1.9/Arena.TILE,1.0,carrier.radius*1.2/Arena.TILE)
	blob.visible=true
	(blob.material_override as StandardMaterial3D).albedo_color=Color(0.55,0.85,0.95,0.3)

func place_rider_3d(view,ent: Dictionary,s: Sprite3D) -> void:
	var carrier_entry: Dictionary=view._sprites[carrier.get_instance_id()]
	var body: Sprite3D=carrier_entry.sprite
	var at:=pose()
	s.position=view.sprite_pixel_position(body,at.seat)+view.cam.global_basis.z*0.012
	s.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	var scale: Vector2=rider.stat_overlay.xform.get_scale()
	s.scale=Vector3(body.scale.x,body.scale.y*scale.y/maxf(0.001,scale.x),body.scale.z)
	(ent.blob as MeshInstance3D).visible=false
	if ent.has("twin"):(ent.twin as Sprite3D).visible=false

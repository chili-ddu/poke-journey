extends Control
## Intro exhibition and start prompt. Loading uses the small Poké Ball cover.
const Battle = preload("res://scripts/ui/intro_battle_world.gd")
const LoadingCover = preload("res://scripts/ui/loading_cover.gd")
const MAP := "res://assets/maps/arena_viridian_forest"
const VIEW := Vector2i(384,216)
signal activated
var phase := "loading"
var message := "모험을 준비하고 있습니다…"
var progress := 0.0
var total := 0.0
var world: World
var view: View3D
var host: SubViewport
var picture: TextureRect
var bridge: JavaScriptObject
var callback: JavaScriptObject
var clock := 0.0
var accumulator := 0.0
var ending := 0.0
var round_index := 0
var focus := Vector2.ZERO
var distance := 10.7
var stopped := false
var presentation_visible := true

class IntroView:
	extends View3D
	func render_target_size() -> Vector2i:return Vector2i(384,216)
	# The intro has no player-follow or arena off-axis camera choreography.
	func _follow_camera(_dt: float=1.0/60.0) -> void:pass
	func frame_battle(at: Vector2,camera_distance: float) -> void:
		cam.set_perspective(FOV,0.5,120.0)
		var basis := arena_camera_basis(ELEV_DEG)
		cam.position=to3d(at,0.55)+basis.z*camera_distance
		cam.basis=basis

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	if OS.has_feature("web"):
		bridge=JavaScriptBridge.get_interface("untamedIntro")
		if bridge!=null:
			callback=JavaScriptBridge.create_callback(func(_args):activated.emit())
			bridge.show(str(get_instance_id()),callback)
	picture=TextureRect.new()
	picture.show_behind_parent=true
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	picture.hide() # Draw the texture in the same fitted 16:9 area as the shared UI.
	_sync_bridge()

func start_battle() -> void:
	if world!=null or stopped:return
	Arena.configure({"map":MAP})
	host=SubViewport.new()
	host.size=VIEW
	host.world_2d=World2D.new()
	host.set_meta("mobile_display_scale",1)
	host.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(host)
	picture.texture=host.get_texture()
	_start_round()
	if DisplayServer.get_name()!="headless":
		view=IntroView.new()
		host.add_child(view)
		view.build(world,MAP)
		view.set_process(false)
		world.visibility_layer|=Look.GROUND_LAYER
		world.move_override=Callable()
		world.aim_override=Callable()
		_frame_camera(1.0)
	if bridge!=null:bridge.live(str(get_instance_id()))

func _start_round() -> void:
	if world!=null:world.free()
	round_index+=1
	world=Battle.new()
	host.add_child(world)
	world.setup(613+round_index,"charmander",12,["ember","scratch"],Battle.SparringInput.new())
	var center := Arena.tile_center(Vector2i(9,15))
	world.player.position=center+Vector2(40,4)
	world.player.facing=Vector2.LEFT
	world.add_starter("bulbasaur",1,["razor_leaf","vine_whip","tackle"],center+Vector2(-28,-12))
	world.add_starter("squirtle",2,["water_gun","tackle"],center+Vector2(-28,28))
	world.progression_enabled=false
	ending=0.0
	focus=center
	distance=10.7
	if view!=null:
		view.world=world
		world.visibility_layer|=Look.GROUND_LAYER

func _process(dt: float) -> void:
	clock+=dt
	if not stopped and world!=null:
		# Fixed simulation steps; slow downloads never make the battle speed up.
		accumulator=minf(accumulator+dt,0.1)
		while accumulator>=1.0/60.0:
			world.step(1.0/60.0)
			accumulator-=1.0/60.0
			var alive := (0 if world.player.dead else 1)+world.alive_enemies().size()
			if alive<=1:ending+=1.0/60.0
			if ending>=1.5:_start_round()
		if view!=null:
			view._process(dt)
			_frame_camera(dt)
	_sync_bridge()
	queue_redraw()

func _frame_camera(dt: float) -> void:
	var actors: Array=world.alive_enemies()
	if not world.player.dead:actors.append(world.player)
	if actors.is_empty():return
	var first: Mon=actors[0]
	var box := Rect2(first.cam_anchor()+Vector2(0,first.feet_offset()),Vector2.ZERO)
	var points: Array[Vector3]=[]
	for actor: Mon in actors:
		box=box.expand(actor.cam_anchor()+Vector2(0,actor.feet_offset()))
		points.append_array(_actor_corners(actor))
	focus=focus.lerp(box.get_center(),1.0-exp(-5.0*dt))
	var wanted := 10.7
	for attempt in 40:
		view.frame_battle(focus,wanted)
		var inside := true
		for point: Vector3 in points:
			if not Rect2(24,68,336,102).has_point(view.cam.unproject_position(point)):inside=false
		if inside:break
		wanted+=0.5
	distance=maxf(wanted,lerpf(distance,wanted,1.0-exp(-2.5*dt)))
	view.frame_battle(focus,distance)

func _actor_corners(actor: Mon) -> Array[Vector3]:
	var entry: Dictionary=view._sprites.get(actor.get_instance_id(),{})
	var sprite: Sprite3D=entry.get("sprite")
	if sprite!=null and sprite.visible and sprite.texture!=null:
		# Fit the actual opaque pose, including feet offsets and attack lunges.
		# Collision centres are above the rendered feet and caused excess zoom.
		var used := MonSprite.release_bounds(sprite.texture,Rect2i(sprite.region_rect))
		var result: Array[Vector3]=[]
		for pixel: Vector2 in [used.position,Vector2(used.end.x,used.position.y),used.end,Vector2(used.position.x,used.end.y)]:
			result.append(view.sprite_pixel_position(sprite,pixel))
		return result
	var feet := actor.cam_anchor()+Vector2(0,actor.feet_offset())
	return [View3D.to3d(feet),View3D.to3d(feet,1.0)]

func set_phase(value: String,text: String="",current: float=0.0,maximum: float=0.0) -> void:
	phase=value
	message=text
	progress=current
	total=maximum
	_sync_bridge()
	queue_redraw()

func _sync_bridge() -> void:
	if bridge!=null and presentation_visible:
		bridge.update(str(get_instance_id()),phase,message,progress,total,modulate.a)

func dismiss() -> void:
	presentation_visible=false
	if bridge!=null:bridge.hide(str(get_instance_id()))

func stop_battle() -> void:
	if stopped:return
	stopped=true
	# Capture before Game configures the global Arena for its own map.
	if host!=null:
		if DisplayServer.get_name()!="headless":
			var image := host.get_texture().get_image()
			if image!=null and not image.is_empty():picture.texture=ImageTexture.create_from_image(image)
		else:picture.texture=null
		host.free()
		host=null
	world=null
	view=null

func _exit_tree() -> void:
	dismiss()

func _draw() -> void:
	if phase=="loading":
		if bridge==null:LoadingCover.paint(self,size,clock,message)
		else:draw_rect(Rect2(Vector2.ZERO,size),Color("080b10"))
		return
	draw_rect(Rect2(Vector2.ZERO,size),Color("15241f"))
	var scale := minf(size.x/384.0,size.y/216.0)
	var origin := (size-Vector2(VIEW)*scale)*0.5
	if picture!=null and picture.texture!=null:draw_texture_rect(picture.texture,Rect2(origin,Vector2(VIEW)*scale),false)
	if bridge!=null:return # One Web overlay owns both boot and runtime typography.
	draw_set_transform(origin,0.0,Vector2.ONE*scale)
	draw_rect(Rect2(0,0,384,62),Color(0.025,0.055,0.047,0.9))
	draw_rect(Rect2(0,174,384,42),Color(0.025,0.055,0.047,0.92))
	PixelUi.text(self,Vector2(192,9),"POKÉMON",true,Color("e8cf8b"),Color.BLACK,HORIZONTAL_ALIGNMENT_CENTER)
	PixelUi.text(self,Vector2(192,25),"UNTAMED",false,Color("f6f0d6"),Color.BLACK,HORIZONTAL_ALIGNMENT_CENTER,2)
	if phase=="ready":
		PixelUi.text(self,Vector2(192,184),"PRESS START",false,Color("f6f0d6"),Color.BLACK,HORIZONTAL_ALIGNMENT_CENTER)
	elif phase=="error":
		PixelUi.text(self,Vector2(192,179),message,true,Color("f4bcb0"),Color.BLACK,HORIZONTAL_ALIGNMENT_CENTER)
		PixelUi.text(self,Vector2(192,196),"다시 시도하려면 눌러 주세요",true,Color.WHITE,Color.BLACK,HORIZONTAL_ALIGNMENT_CENTER)
	else:
		PixelUi.text(self,Vector2(192,180),message,true,Color("f6f0d6"),Color.BLACK,HORIZONTAL_ALIGNMENT_CENTER)
		draw_rect(Rect2(132,201,120,2),Color("526253"))
		var width := 120.0*clampf(progress/total,0,1) if total>0 else 24.0
		var offset := 0.0 if total>0 else fposmod(clock*30.0,96.0)
		draw_rect(Rect2(132+offset,201,width,2),Color("e8cf8b"))

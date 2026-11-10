extends SceneTree

## Standalone offscreen atlas. Never opens a larger native window or a save.
const Collection=preload("res://scripts/johto/hgss_map_collection.gd")
const Art=preload("res://scripts/view/hgss_environment.gd")
const OUT="res://docs/world_overview/"
var viewport: SubViewport
var root3d: Node3D
var camera: Camera3D
var labels: Control
var used: Array[Rect2]=[]
var c:=Collection.new("res://assets/maps/johto_border_hgss/")

func _init() -> void:run.call_deferred()

func add_label(at: Vector2,text: String,town: bool) -> void:
	var label:=Label.new()
	label.text=text
	label.add_theme_font_override("font",load("res://assets/fonts/Galmuri11.ttf"))
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",Color("fff1c9") if town else Color("d1eeff"))
	label.add_theme_color_override("font_outline_color",Color("122a32"))
	label.add_theme_constant_override("outline_size",1)
	var panel:=PanelContainer.new()
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.05,0.13,0.16,0.90)
	style.border_color=Color("b6ac84") if town else Color("5e8190")
	style.set_border_width_all(1)
	style.content_margin_left=8;style.content_margin_right=8
	style.content_margin_top=4;style.content_margin_bottom=4
	panel.add_theme_stylebox_override("panel",style)
	labels.add_child(panel);panel.add_child(label)
	var factor:=2.0 if town else 1.5
	panel.scale=Vector2.ONE*factor
	panel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var size:=panel.get_minimum_size()*factor
	for offset in [Vector2(0,-16),Vector2(0,32),Vector2(0,-64),Vector2(0,64),Vector2(-80,0),Vector2(80,0)]:
		var position: Vector2=at-size*0.5+offset
		position.x=clampf(position.x,8,viewport.size.x-size.x-8)
		position.y=clampf(position.y,50,viewport.size.y-size.y-40)
		var rect:=Rect2(position,size).grow(3)
		var blocked:=false
		for other in used:
			if other.intersects(rect):blocked=true;break
		if not blocked:
			panel.position=position;used.append(rect)
			return
	panel.position=at-size*0.5

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var data:=c.scene_data(c.scene_for(60))
	viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.size=Vector2i(2400,1280)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	root3d=Node3D.new();viewport.add_child(root3d)
	var environment:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("172f3a")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color.WHITE
	settings.ambient_light_energy=1.0
	environment.environment=settings;root3d.add_child(environment)
	var bounds:=Rect2(Vector2(data.chunks[0].x,data.chunks[0].z)*32,Vector2(32,32))
	var instances:=0
	for chunk in data.chunks:
		var at:=Vector2(chunk.x,chunk.z)*32
		bounds=bounds.merge(Rect2(at,Vector2(32,32)))
		var parent:=Node3D.new()
		parent.position=Vector3(at.x+16,float(chunk.altitude),at.y+16)
		root3d.add_child(parent)
		var terrain:=Art.model(c.manifest.assets[chunk.asset]).instantiate() as Node3D
		terrain.scale=Vector3.ONE/16.0;parent.add_child(terrain)
		for prop in chunk.props:
			var object:=Art.model(c.manifest.assets[prop.asset]).instantiate() as Node3D
			object.position=Vector3(prop.translation[0],prop.translation[1],prop.translation[2])/16.0
			object.scale=Vector3(prop.scale[0],prop.scale[1],prop.scale[2])/16.0
			parent.add_child(object);instances+=1
		if root3d.get_child_count()%12==0:await process_frame
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.size=maxf(bounds.size.y,bounds.size.x/float(viewport.size.x)*viewport.size.y)*1.12
	camera.far=2200.0
	root3d.add_child(camera)
	var center:=Vector3(bounds.get_center().x,0,bounds.get_center().y)
	camera.position=center+Vector3(0,1000,0)
	camera.look_at(center,Vector3(0,0,-1));camera.current=true
	var layer:=CanvasLayer.new();viewport.add_child(layer)
	labels=Control.new();layer.add_child(labels)
	add_label(Vector2(1200,25),"성도·관동 경계 지도 · HGSS / 26~28번도로 연결",true)
	# Each label comes from the actual source header's area cells, not a hand drawn graph.
	var landmarks: Array=[]
	for h in data.headers:
		var meta: Dictionary=c.manifest.headers[str(int(h))]
		if meta.mapType!="MAP_TYPE_CITY_TOWN":continue
		landmarks.append({"header":int(h),"town":true})
	for h in data.headers:
		var meta: Dictionary=c.manifest.headers[str(int(h))]
		if meta.mapType!="MAP_TYPE_CITY_TOWN":
			landmarks.append({"header":int(h),"town":false})
	for landmark in landmarks:
		var total:=Vector2.ZERO;var count:=0
		for area in data.areas:
			if int(area.header)!=landmark.header:continue
			total+=Vector2(float(area.x)+float(area.width)/2.0,float(area.z)+float(area.height)/2.0);count+=1
		if count==0:continue
		var at:=total/float(count)
		add_label(camera.unproject_position(Vector3(at.x,8.0,at.y)),c.title(landmark.header),landmark.town)
	add_label(Vector2(1200,1240),"26~48번도로 · 도시·마을 · 은빛산 / 게이트에서 관동 22·23번도로 연결",false)
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	assert(image.get_size()==Vector2i(2400,1280))
	assert(root.size==Vector2i(384,216))
	image.save_png(OUT+"johto_overview.png")
	FileAccess.open(OUT+"source.json",FileAccess.WRITE).store_string(JSON.stringify({"source":"assets/maps/johto_border_hgss/scenes/matrix_0000.json","art_source":"existing","chunks":data.chunks.size(),"props":instances,"headers":data.headers,"offscreen":[2400,1280],"native_window":[384,216],"saves_accessed":false}))
	print("Whole Johto map rendered offscreen at 2400x1280; native window remained 384x216; no saves")
	quit()

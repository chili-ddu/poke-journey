extends SceneTree
const Continent=preload("res://scripts/data/continent_world.gd")
const Game=preload("res://scripts/game.gd")
const Art=preload("res://scripts/view/hgss_environment.gd")
const OUT="res://docs/continent_world/"
var viewport: SubViewport
var labels: Control
var used: Array[Rect2]=[]
var atlas_markers: Array=[]
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
	SaveData.path="user://continent_overview_only.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON","kanto_world");OS.set_environment("LANG_CODE","ko")
	Game.skip_opening=true;Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[]
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false)
	var view=game.view3d
	view.set_process(false)
	var annotated:=OS.get_environment("ROUTE_EVENTS_ATLAS")=="1"
	viewport=view.vp;viewport.size=Vector2i(3840,1555) if annotated else Vector2i(2608,1056)
	view.ov_quad.visible=false
	var stream=view.native_renderer
	for node in stream.chunks.values():node.queue_free()
	stream.chunks.clear()
	await process_frame
	var source:=Continent.scene()
	var shift:=Continent.offset()
	for chunk in source.chunks:
		var at:=Vector2(chunk.x*32+shift.x,chunk.z*32+shift.y)
		var parent:=Node3D.new();parent.position=Vector3(at.x+16,float(chunk.altitude),at.y+16)
		view.root3d.add_child(parent)
		var terrain:=Art.model(Continent.collection().manifest.assets[chunk.asset]).instantiate() as Node3D
		terrain.scale=Vector3.ONE/16.0;parent.add_child(terrain)
		for prop in chunk.props:
			var object:=Art.model(Continent.collection().manifest.assets[prop.asset]).instantiate() as Node3D
			object.position=Vector3(prop.translation[0],prop.translation[1],prop.translation[2])/16.0
			object.scale=Vector3(prop.scale[0],prop.scale[1],prop.scale[2])/16.0
			parent.add_child(object)
	var backdrop=view.continent_backdrop
	for node in backdrop.chunks.values():node.queue_free()
	backdrop.chunks.clear()
	await process_frame
	var fill_count:=0
	for y in range(-3,13):
		for x in range(-28,0):
			var cell:=Vector2i(x,y)
			if source.chunk_index.has(cell-shift/32):continue
			backdrop.build_chunk(cell);fill_count+=1
	var camera: Camera3D=view.cam
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.size=528.0
	camera.far=2400
	var center:=Vector3(-244,0,152)
	camera.position=center+Vector3(0,1500,0)
	camera.look_at(center,Vector3(0,0,-1));camera.current=true
	var layer:=CanvasLayer.new();viewport.add_child(layer)
	labels=Control.new();layer.add_child(labels)
	add_label(Vector2(viewport.size.x/2.0,32),"관동·성도 도로번호와 사건번호" if annotated else "관동·성도 통합 플레이 필드 · FRLG 지리 + HGSS 표현",true)
	var landmarks: Array=[]
	for h in source.headers:
		var meta: Dictionary=Continent.collection().manifest.headers[str(int(h))]
		if meta.mapType!="MAP_TYPE_CITY_TOWN":continue
		var sum:=Vector2.ZERO;var count:=0
		for area in source.areas:
			if int(area.header)!=int(h):continue
			sum+=Vector2(area.x+area.width/2,area.z+area.height/2);count+=1
		if count==0:continue
		var at:=sum/count+Vector2(shift)
		add_label(camera.unproject_position(Vector3(at.x,0,at.y)),Continent.collection().title(int(h)),true)
		landmarks.append({"id":"johto_%03d"%int(h),"tile":[at.x,at.y]})
	for id in ["pallet_town","viridian_city","pewter_city","cerulean_city","lavender_town","celadon_city","vermilion_city","fuchsia_city","cinnabar_island","indigo_plateau_exterior"]:
		var rect:=Arena.area_rect(id)
		var at:=Vector2(rect.position)+Vector2(rect.size)*0.5
		add_label(camera.unproject_position(Vector3(at.x,0,at.y)),DungeonDB.area_name(id),true)
		landmarks.append({"id":id,"tile":[at.x,at.y]})
	for id in ["johto_030","johto_031","johto_032"]:
		if annotated:continue
		var rect:=Arena.area_rect(id)
		var at:=Vector2(rect.position)+Vector2(rect.size)*0.5
		add_label(camera.unproject_position(Vector3(at.x,0,at.y)),DungeonDB.area_name(id),false)
	if annotated:
		var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"route_events/catalog.json"))
		add_label(camera.unproject_position(Vector3(288,0,140)),"노랑시티*",true)
		for road in catalog.roads:
			add_atlas_marker(camera,road.anchor,str(int(road.number)),false)
		for event in catalog.events:
			add_atlas_marker(camera,event.anchor,String(event.id)+( "*" if event.get("proxy",false) else ""),true)
		add_label(Vector2(viewport.size.x/2.0,viewport.size.y-28),"파랑 1~48 = 도로번호 / 주황 E번호 = 별도 사건 목록 / * 노랑·실프 별도 지도 안내 위치 / 사건번호는 진행 순서가 아닙니다",false)
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUT+("route_events/route_event_atlas.png" if annotated else "playable_continent.png"))
	assert(root.size==Vector2i(384,216))
	FileAccess.open(OUT+("route_events/render.json" if annotated else "overview.json"),FileAccess.WRITE).store_string(JSON.stringify({"viewport":[viewport.size.x,viewport.size.y],"native_window":[384,216],"native_chunks":source.chunks.size(),"scenery_chunks":fill_count,"johto_offset":[shift.x,shift.y],"landmarks":landmarks,"markers":atlas_markers,"art_source":"existing","source":"actual Game View3D geometry, all exterior chunks loaded offscreen"},"  "))
	game.free();await process_frame;SaveData.clear()
	print("Actual unified continent offscreen render saved")
	quit()

func add_atlas_marker(camera: Camera3D,anchor: Array,text: String,event: bool) -> void:
	var at:=camera.unproject_position(Vector3(anchor[0],0,anchor[1]))
	var panel:=PanelContainer.new()
	var style:=StyleBoxFlat.new()
	var ink:=Color("ffbc66") if event else Color("9bdfff")
	style.bg_color=Color("683e15") if event else Color("123f67")
	style.border_color=ink;style.set_border_width_all(1)
	style.set_corner_radius_all(5 if event else 2)
	style.content_margin_left=5;style.content_margin_right=5
	style.content_margin_top=2;style.content_margin_bottom=2
	panel.add_theme_stylebox_override("panel",style)
	var label:=Label.new();label.text=text
	label.add_theme_font_override("font",load("res://assets/fonts/Galmuri11.ttf"))
	label.add_theme_font_size_override("font_size",16);label.add_theme_color_override("font_color",ink)
	labels.add_child(panel);panel.add_child(label)
	var scale_factor:=1.5
	panel.scale=Vector2.ONE*scale_factor
	panel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var size:=panel.get_minimum_size()*scale_factor
	var best:=at-size*0.5;var best_score:=INF;var overlap_count:=0
	for radius in [0,32,64,96,128,160,192,224]:
		for dir in [Vector2.ZERO,Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var pos: Vector2=at+dir*radius-size*0.5
			pos.x=clampf(pos.x,4,viewport.size.x-size.x-4);pos.y=clampf(pos.y,76,viewport.size.y-size.y-60)
			var rect:=Rect2(pos,size).grow(3)
			var overlaps:=0
			for other in used:
				if other.intersects(rect):overlaps+=1
			var score: float=overlaps*1000000000.0+pos.distance_squared_to(at-size*0.5)
			if score<best_score:best_score=score;best=pos;overlap_count=overlaps
	panel.position=best;used.append(Rect2(best,size).grow(3))
	if (best+size*0.5).distance_to(at)>8:
		var line:=Line2D.new();line.width=1.5;line.default_color=ink
		line.add_point(at);line.add_point(best+size*0.5);labels.add_child(line);labels.move_child(line,0)
	var dot:=ColorRect.new();dot.color=ink;dot.size=Vector2(4,4);dot.position=at-Vector2(2,2);labels.add_child(dot)
	atlas_markers.append({"label":text,"anchor":anchor,"position":[best.x,best.y],"overlaps":overlap_count})

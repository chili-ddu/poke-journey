class_name FlyMapScreen
extends Control

signal chosen(id: String)
signal closed
const SCREEN := Vector2(384,216)
const MAP := Rect2(4,27,240,160)
const LIST := Rect2(249,67,130,90)
const CONFIRM := Rect2(249,169,130,18)
const CANCEL := Rect2(330,4,48,17)
const ROW_H := 18.0
const ROWS := 5
var entries: Array=[]
var _events: Array=[]
var cursor := 0
var scroll := 0
var current := ""
var notice := ""
var browse_only := false
var _clock := 0.0
var _texture: Texture2D

func _ready() -> void:
	visible=false;mouse_filter=Control.MOUSE_FILTER_STOP
	_texture=load("res://assets/ui/kanto_town_map.png")

func open(area: String, events: Array=[], browse: bool=false) -> void:
	_events=events.duplicate()
	browse_only=browse
	entries=FlyDestinations.all_locations() if browse_only else FlyDestinations.available(events)
	current=area;cursor=0;notice=""
	for i in entries.size():
		if entries[i].id==area:cursor=i;break
	scroll=clampi(cursor-2,0,maxi(0,entries.size()-ROWS))
	visible=true;queue_redraw()

func close() -> void:visible=false

func origin() -> Vector2:return ((size-SCREEN)/2.0).floor()

func selected() -> Dictionary:
	return entries[cursor] if not entries.is_empty() else {}

func _select(index: int) -> void:
	cursor=clampi(index,0,maxi(0,entries.size()-1));notice=""
	if cursor<scroll:scroll=cursor
	elif cursor>=scroll+ROWS:scroll=cursor-ROWS+1
	Sfx.play("select");queue_redraw()

func choose() -> void:
	if browse_only:cancel();return
	if entries.is_empty():return
	Sfx.play("decide");chosen.emit(String(selected().id))

func cancel() -> void:
	Sfx.play("select");closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed):return
	var handled:=true
	match event.physical_keycode:
		KEY_UP,KEY_LEFT,KEY_W,KEY_A:_select(cursor-1)
		KEY_DOWN,KEY_RIGHT,KEY_S,KEY_D:_select(cursor+1)
		KEY_ENTER,KEY_KP_ENTER,KEY_SPACE:
			if not event.echo:choose()
		KEY_ESCAPE,KEY_B:
			if not event.echo:cancel()
		KEY_M:
			if browse_only and not event.echo:cancel()
		KEY_F11,KEY_L,KEY_MINUS,KEY_EQUAL:handled=false
	if handled:get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton and event.pressed):return
	if event.button_index==MOUSE_BUTTON_WHEEL_UP:_select(cursor-1);accept_event();return
	if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:_select(cursor+1);accept_event();return
	if event.button_index!=MOUSE_BUTTON_LEFT:return
	var at: Vector2=event.position-origin()
	if CANCEL.has_point(at):cancel()
	elif CONFIRM.has_point(at):choose()
	elif LIST.has_point(at):
		var index:=scroll+int((at.y-LIST.position.y)/ROW_H)
		if index<entries.size():
			if index==cursor:choose()
			else:_select(index)
	elif MAP.has_point(at):
		var map_at:=at-MAP.position
		var hit: Dictionary={};var distance:=INF
		for entry in FlyDestinations.all_locations():
			var r: Array=entry.region
			var region:=Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))
			var d:=region.get_center().distance_to(map_at)
			if region.grow(2).has_point(map_at) and d<distance:hit=entry;distance=d
		if not hit.is_empty():
			if browse_only:_select(entries.find(hit))
			elif not hit.enabled:notice=Lang.t("fly_unbuilt",[FlyDestinations.label(hit)]);queue_redraw()
			elif not RoadAccess.can_fly(String(hit.id),_events):notice=Lang.t("fly_road_closed",[FlyDestinations.label(hit)]);queue_redraw()
			elif not entries.has(hit):notice=Lang.t("fly_unvisited",[FlyDestinations.label(hit)]);queue_redraw()
			else:
				var index: int=entries.find(hit)
				if index==cursor:choose()
				else:_select(index)
	accept_event()

func _process(dt: float) -> void:
	if visible:_clock+=dt;queue_redraw()

func _text(at: Vector2,value: String,color: Color=PixelUi.INK,align: HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT) -> void:
	PixelUi.text(self,origin()+at,value,false,color,Color.TRANSPARENT,align)

func _draw() -> void:
	if not visible:return
	var o:=origin()
	draw_rect(Rect2(Vector2.ZERO,size),Color("263b4d"))
	draw_rect(Rect2(o,SCREEN),Color("e8edd4"))
	draw_rect(Rect2(o,Vector2(SCREEN.x,24)),PixelUi.PLAT_OLIVE)
	_text(Vector2(10,5),Lang.t("town_map_title" if browse_only else "fly_map_title"),Color.WHITE)
	draw_rect(Rect2(o+CANCEL.position,CANCEL.size),Color("f3e8ce"))
	_text(CANCEL.get_center()-Vector2(0,6),Lang.t("fly_cancel"),PixelUi.INK,HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(Rect2(o+MAP.position,MAP.size),Color("d9e8c4"))
	if _texture!=null:draw_texture(_texture,o+MAP.position)
	for entry in FlyDestinations.all_locations():
		var a: Array=entry.region
		var r:=Rect2(o+MAP.position+Vector2(float(a[0]),float(a[1])),Vector2(float(a[2]),float(a[3])))
		if (not entry.enabled or not entries.has(entry)) and entry.kind!="route":draw_circle(r.get_center(),3.0,Color("8b9892"))
		if entry.id==current:draw_circle(r.get_center(),3.0,Color("42bfff"))
		if not selected().is_empty() and entry.id==selected().id:
			draw_rect(r,Color(1,0.9,0.25,0.18+sin(_clock*6.0)*0.06))
			draw_rect(r.grow(2),PixelUi.CURSOR_RED,false,2.0)
	_text(Vector2(253,28),FlyDestinations.label(selected()))
	_text(Vector2(253,47),Lang.t("town_map_places" if browse_only else "fly_pick_place"),PixelUi.INK_DIM)
	for row in ROWS:
		var index:=scroll+row
		if index>=entries.size():break
		var at:=LIST.position+Vector2(0,row*ROW_H)
		if index==cursor:
			draw_rect(Rect2(o+at,Vector2(LIST.size.x,ROW_H)),Color.WHITE)
			draw_rect(Rect2(o+at,Vector2(LIST.size.x,ROW_H)),PixelUi.CURSOR_RED,false,1.0)
		_text(at+Vector2(7,2),FlyDestinations.label(entries[index]))
	if scroll>0:_text(Vector2(372,52),"▲",PixelUi.INK_DIM,HORIZONTAL_ALIGNMENT_RIGHT)
	if scroll+ROWS<entries.size():_text(Vector2(372,152),"▼",PixelUi.INK_DIM,HORIZONTAL_ALIGNMENT_RIGHT)
	draw_rect(Rect2(o+CONFIRM.position,CONFIRM.size),PixelUi.PLAT_OLIVE)
	_text(CONFIRM.get_center()-Vector2(0,6),Lang.t("town_map_close" if browse_only else "fly_go"),Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(o+Vector2(4,190),o+Vector2(380,190),Color("a9b69a"))
	_text(Vector2(8,195),notice if notice!="" else Lang.t("town_map_hint" if browse_only else "fly_map_hint"))

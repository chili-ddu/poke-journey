class_name TouchControls
extends Control

## Mobile gamepad below the game display. The existing game HUD never moves.
const CONFIG_PATH := "res://assets/data/touch_controls.json"
const FACE_COLORS := {"A":Color("75d49c"),"B":Color("ef8c92"),"X":Color("88bfee"),"Y":Color("edd486")}
var game: Node
var mobile_override := -1
var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
var router := MobileKeyRouter.new()
var control_area := Rect2()
var control_scale := 1.0
var display_area := Rect2()
var stick_center := Vector2.ZERO
var stick_knob := Vector2.ZERO
var finger := -1
var aim_center := Vector2.ZERO
var aim_knob := Vector2.ZERO
var aim_finger := -1
var contacts := {}
var blocked_fingers := {}
var deck := {}
var _context := ""
var _nav_code := KEY_NONE
var _nav_timer := 0.0
var _styles := {}
var _layout_area := Rect2()

static func mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(cancel_all)
	get_window().focus_exited.connect(cancel_all)
	refresh()
	if available() and human()!=null and Input.is_action_pressed("move_click"):human().hold = true

func human() -> Controllers.Human:
	router.target = game
	return router.human()

func available() -> bool:
	var mobile := mobile_platform() if mobile_override<0 else mobile_override==1
	if not mobile or not control_area.has_area() or not is_instance_valid(game):return false
	return (human()!=null and not bool(game.get("bot"))) or game is TitleScreen

func playing() -> bool:
	router.target = game
	return available() and router.gameplay() and not bool(game.get("cinematic")) and game.get("encounter")==null

func refresh() -> void:
	size = get_viewport_rect().size
	router.target = game
	if deck.is_empty() or _layout_area!=control_area:
		deck = MobilePadLayout.calculate(control_area)
		_layout_area = control_area
	stick_center = deck.stick
	aim_center = deck.aim
	var state = game.get("state") if is_instance_valid(game) else null
	var title_menu = game.menu_open if game is TitleScreen else false
	var context := "%s:%s:%s:%s:%s" % [available(),state,title_menu,playing(),router.navigation()]
	if context!=_context:
		cancel_all()
		_context = context
	visible = available()
	queue_redraw()

func _process(dt: float) -> void:
	refresh()
	if _nav_code!=KEY_NONE and finger>=0 and router.navigation():
		_nav_timer -= dt
		if _nav_timer<=0.0:
			router.navigate(_nav_code)
			_nav_timer = float(config.navigation_repeat)
	if router.navigation() and not GamepadBindings.bag_assignment(router,_summary_held()):
		for contact in contacts.values():
			if contact.get("nav",KEY_NONE)==KEY_NONE:continue
			contact.timer -= dt
			if contact.timer<=0.0:
				contact.timer = float(config.navigation_repeat)
				router.navigate(contact.nav)

func cancel_all() -> void:
	var had_contact := not contacts.is_empty() or not blocked_fingers.is_empty()
	contacts.clear();blocked_fingers.clear()
	finger = -1;stick_knob = Vector2.ZERO;_nav_code = KEY_NONE
	aim_finger = -1;aim_knob = Vector2.ZERO
	if human()!=null:
		human().clear_touch()
		if had_contact:human().hold = true
	queue_redraw()

func _exit_tree() -> void:cancel_all()

func _input(event: InputEvent) -> void:
	refresh()
	if not visible:return
	var viewport := get_viewport()
	if event is InputEventScreenTouch:
		if pointer(event.index,event.position,"cancel" if event.canceled else ("press" if event.pressed else "release")):
			if is_instance_valid(viewport):viewport.set_input_as_handled()
	elif event is InputEventScreenDrag:
		if pointer(event.index,event.position,"drag") and is_instance_valid(viewport):viewport.set_input_as_handled()

func pointer(id: int, at: Vector2, phase: String) -> bool:
	if not available():return false
	if phase=="press":return _press(id,at)
	if blocked_fingers.has(id):
		if phase in ["release","cancel"]:blocked_fingers.erase(id)
		_ownership();return true
	if not contacts.has(id):return false
	var contact: Dictionary = contacts[id]
	if phase=="drag":
		if contact.kind=="move":_move(at)
		elif contact.kind=="aim":_aim(at)
		elif not contact.rect.grow(6).has_point(at):
			router.release(contact.code,true);contact.code = KEY_NONE
			contact["nav"] = KEY_NONE
			contact["cancelled"] = true
	else:
		contacts.erase(id)
		if contact.kind=="move":
			finger = -1;stick_knob = Vector2.ZERO;_nav_code = KEY_NONE
			if human()!=null:human().touch_move = Vector2.ZERO
		elif contact.kind=="aim":
			aim_finger = -1;aim_knob = Vector2.ZERO
			if human()!=null:human().touch_aim = Vector2.ZERO
		else:router.release(contact.code,phase=="cancel")
	_ownership();queue_redraw();return true

func _press(id: int, at: Vector2) -> bool:
	if contacts.has(id) or blocked_fingers.has(id):return true
	var outside := display_area.has_area() and not display_area.has_point(at)
	if not control_area.has_point(at) and not outside:return false
	if control_area.has_point(at):
		for command in deck.hits:
			var rect: Rect2 = deck.hits[command]
			if rect.has_point(at):return _press_button(id,command,rect)
		if at.distance_to(stick_center)<=stick_radius() and finger<0:
			contacts[id] = {"kind":"move"};finger = id
			_ownership();_move(at);return true
		if at.distance_to(aim_center)<=aim_radius() and aim_finger<0:
			contacts[id] = {"kind":"aim"};aim_finger = id
			_ownership();_aim(at);return true
	blocked_fingers[id] = true
	_ownership();return true

func _press_button(id: int, command: String, rect: Rect2) -> bool:
	for contact in contacts.values():
		if contact.kind=="key" and contact.command==command:
			blocked_fingers[id] = true;_ownership();return true
	contacts[id] = {"kind":"key","command":command,"rect":rect,"code":KEY_NONE}
	_ownership()
	if command=="summary" and game.get("menu")=="bag":return true
	if command.begins_with("item_") and router.navigation() and not GamepadBindings.bag_assignment(router,_summary_held()):
		var nav: int = [KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_LEFT][int(command.trim_prefix("item_"))]
		contacts[id]["nav"] = nav;contacts[id]["timer"] = float(config.navigation_delay)
		router.navigate(nav);return true
	var code := router.press(command)
	if contacts.has(id):contacts[id].code = code
	else:router.release(code)
	queue_redraw();return true

func _summary_held() -> bool:
	for contact in contacts.values():
		if contact.kind=="key" and contact.command=="summary" and not contact.get("cancelled",false):return true
	return false

func _ownership() -> void:
	if human()==null:return
	human().touch_owned = not contacts.is_empty() or not blocked_fingers.is_empty()
	if human().touch_owned:human().has_target = false

func _move(at: Vector2) -> void:
	var delta := at-stick_center
	var radius := stick_radius()
	if radius<=0:return
	stick_knob = delta.limit_length(radius*0.58)
	var strength := clampf(delta.length()/radius,0.0,1.0)
	var value := delta.normalized()*((strength-float(config.stick_deadzone))/(1.0-float(config.stick_deadzone))) if strength>float(config.stick_deadzone) else Vector2.ZERO
	if router.navigation():
		if human()!=null:human().touch_move = Vector2.ZERO
		var code := KEY_NONE
		if value.length()>0.25:code = (KEY_RIGHT if value.x>0 else KEY_LEFT) if absf(value.x)>absf(value.y) else (KEY_DOWN if value.y>0 else KEY_UP)
		if code!=_nav_code:
			_nav_code = code;_nav_timer = float(config.navigation_delay)
			if code!=KEY_NONE:router.navigate(code)
	elif playing() and human()!=null:
		human().touch_move = value;human().touch_active = true
	queue_redraw()

func stick_radius() -> float:return float(deck.get("radius",0.0))
func aim_radius() -> float:return float(deck.get("aim_radius",0.0))

func _aim(at: Vector2) -> void:
	var delta := at-aim_center
	var radius := aim_radius()
	if radius<=0:return
	aim_knob = delta.limit_length(radius*0.58)
	if human()!=null:
		human().touch_aim = delta.normalized() if playing() and delta.length()/radius>float(config.stick_deadzone) else Vector2.ZERO
		if playing():human().touch_active = true
	queue_redraw()

func _draw() -> void:
	if not available() or float(deck.scale)<=0:return
	draw_set_transform(deck.origin,0,Vector2.ONE*float(deck.scale))
	_draw_stick(false)
	_draw_stick(true)
	draw_circle(deck.dpad,float(deck.cell)*1.6,Color("172630"))
	draw_rect(Rect2(deck.dpad-Vector2.ONE*float(deck.cell)/2,Vector2.ONE*float(deck.cell)),Color("263640"))
	for command in deck.rects:_draw_button(command,deck.rects[command])
	_text(deck.dpad-Vector2(0,8),"+",true,Color("8196a1"))
	draw_set_transform(Vector2.ZERO)

func _draw_stick(right: bool) -> void:
	var center: Vector2 = ((aim_center if right else stick_center)-deck.origin)/float(deck.scale)
	var radius := (aim_radius() if right else stick_radius())/float(deck.scale)
	var knob := aim_knob if right else stick_knob
	draw_circle(center,radius,Color("172630"))
	draw_arc(center,radius,0,TAU,40,Color("78939f"),1.5)
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		draw_line(center+direction*(radius-9),center+direction*(radius-4),Color("cadbe2"),2)
	draw_circle(center+knob/float(deck.scale),radius*0.4,Color("9eb6c2"))
	_text(center+knob/float(deck.scale)-Vector2(0,8),"R" if right else "L",true,Color("20313e"))

func _draw_button(command: String, rect: Rect2) -> void:
	var selected := false
	for contact in contacts.values():
		if contact.kind=="key" and contact.command==command:selected = true
	if command.begins_with("item_"):_draw_direction(command,rect,selected);return
	var glyph: String = deck.glyphs[command]
	var face := glyph in ["A","B","X","Y"]
	var style := _button_style(glyph,selected)
	draw_style_box(style,rect)
	if face:
		var color: Color = FACE_COLORS[glyph]
		_text(Vector2(rect.get_center().x,rect.position.y+2),glyph,false,color)
		var hint := _hint(command)
		if command=="action" and router.gameplay():hint = "행동" if Lang.is_ko() else "Act"
		_text(Vector2(rect.get_center().x,rect.position.y+20),hint,true,Color("b9c8d0"))
	else:
		_text(Vector2(rect.get_center().x,rect.position.y+2),glyph,true,Color("d9e4ea"))
		var color := Color("9bafba")
		var y := rect.position.y+(16 if rect.size.y<=32 else 18)
		_text(Vector2(rect.get_center().x,y),_hint(command),true,color)

func _button_style(glyph: String, selected: bool) -> StyleBoxFlat:
	var key := glyph+str(selected)
	if not _styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = Color("405b6b") if selected else Color("20313e")
		style.border_color = Color("a2c7d5") if selected else Color("526c7a")
		style.set_border_width_all(1);style.set_corner_radius_all(24 if glyph in ["A","B","X","Y"] else 8)
		_styles[key] = style
	return _styles[key]

func _text(at: Vector2, value: String, small: bool=true, color: Color=Color.WHITE) -> void:
	PixelUi.text(self,at,value,small,color,Color(0,0,0,0),HORIZONTAL_ALIGNMENT_CENTER)

func _hint(command: String) -> String:
	var ko := Lang.is_ko()
	if command.begins_with("skill_"):
		return ("기술 " if ko else "Skill ")+str(int(command.trim_prefix("skill_"))+1)
	if command=="action":return ("확인" if ko else "OK") if router.navigation() else (("다시" if ko else "Retry") if game.get("state") in ["gameover","victory"] else ("점프·대화" if ko else "Jump/Talk"))
	var labels := {"bag":["가방","Bag"],"summary":["상태","Info"],"town_map":["타운맵","Map"],"menu":["메뉴","Menu"],"cancel":["취소","Back"]}
	return labels[command][0 if ko else 1]

func _draw_direction(command: String, rect: Rect2, selected: bool) -> void:
	var slot := int(command.trim_prefix("item_"))
	draw_style_box(_button_style("direction",selected),rect)
	var center := rect.get_center()-Vector2(0,4)
	var angle := float(slot)*PI/2
	var arrow := PackedVector2Array()
	for point in [Vector2(0,-5),Vector2(5,3),Vector2(-5,3)]:arrow.append(center+point.rotated(angle))
	draw_colored_polygon(arrow,Color("bdcdd5"))

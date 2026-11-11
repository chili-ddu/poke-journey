class_name GamepadControls
extends Node

## Standard Godot gamepad events share commands with the mobile controller.
const CONFIG := "res://assets/data/gamepad_controls.json"
var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
var router := MobileKeyRouter.new()
var target_override: Node # Isolated test fixture; ordinary play follows current_scene.
var track_window_focus := true
var active_device := -1
var _focused := true
var _axes := {}
var _down := {}
var _held := {}
var _suppressed_buttons := {}
var _suppressed_axes := {}
var _context := ""
var _bound: Controllers.Human
var _nav := KEY_NONE
var _nav_timer := 0.0

func _ready() -> void:
	router.source = "gamepad"
	_focused = get_window().has_focus() if track_window_focus else true
	get_window().focus_exited.connect(func():
		if track_window_focus:set_focused(false))
	get_window().focus_entered.connect(func():
		if track_window_focus:set_focused(true))
	Input.joy_connection_changed.connect(connection_changed)

func _exit_tree() -> void:_clear_intents()

func _target() -> Node:
	if is_instance_valid(target_override):return target_override
	var scene := MobileGameFrame.unwrap(get_tree().current_scene)
	if scene is TitleScreen:return scene
	if is_instance_valid(scene) and scene.has_method("_fit_ui") and not bool(scene.get("bot")):return scene
	return null

func refresh_target() -> void:
	router.target = _target()
	var human := router.human()
	var next := ""
	if is_instance_valid(router.target):
		var launching: bool = router.target.launching if router.target is TitleScreen else false
		next = "%s:%s:%s:%s:%s:%s:%s"%[router.target.get_instance_id(),human.get_instance_id() if human!=null else 0,router.target.get("state"),router.navigation(),_playing(),launching,_transition_active()]
	if next==_context:return
	_clear_intents()
	_bound = human;_context = next
	_suppress_current()

func _playing() -> bool:
	return router.gameplay() and not _transition_active() and not bool(router.target.get("cinematic")) and router.target.get("encounter")==null

func _transition_active() -> bool:
	var cover := get_tree().root.get_node_or_null("TitleGameTransition")
	return is_instance_valid(cover) and bool(cover.get("active"))

func _clear_intents() -> void:
	if _bound!=null:_bound.clear_gamepad()
	_held.clear();_nav = KEY_NONE;_nav_timer = 0.0

func _suppress_current() -> void:
	_suppressed_buttons = _down.duplicate()
	_suppressed_axes.clear()
	for axis in _axes:
		if not _neutral(axis,float(_axes[axis])):_suppressed_axes[axis] = true

func set_focused(value: bool) -> void:
	_focused = value
	_clear_intents()
	if value and active_device in Input.get_connected_joypads():_snapshot_device()
	_suppress_current()

func _snapshot_device() -> void:
	_down.clear();_axes.clear()
	for button in GamepadBindings.BUTTONS:
		if Input.is_joy_button_pressed(active_device,button):_down["b:%d"%button] = GamepadBindings.BUTTONS[button]
	for axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
		_axes[axis] = Input.get_joy_axis(active_device,axis)
	for axis in GamepadBindings.TRIGGERS:
		if float(_axes[axis])>=float(config.trigger_press):_down["a:%d"%axis] = GamepadBindings.TRIGGERS[axis]

func connection_changed(device: int, connected: bool) -> void:
	if connected or device!=active_device:return
	_clear_intents();_axes.clear();_down.clear()
	_suppressed_axes.clear();_suppressed_buttons.clear();active_device = -1

func _input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if handle_event(event) and is_instance_valid(viewport):viewport.set_input_as_handled()

## Event seam also exercises native root input without changing hardware state.
func handle_event(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):return false
	refresh_target()
	var accepted := is_instance_valid(router.target) or _transition_active()
	if event is InputEventJoypadButton and not GamepadBindings.BUTTONS.has(event.button_index):return false
	if event is InputEventJoypadMotion:
		if event.axis<JOY_AXIS_LEFT_X or event.axis>JOY_AXIS_TRIGGER_RIGHT:return false
		# R-stick motion is unbound and cannot claim a device or change input mode.
		if event.axis in [JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:return accepted
	if active_device!=event.device:
		if active_device>=0 and _has_input():return accepted
		_clear_intents();_axes.clear();_down.clear();_suppress_current();active_device = event.device
	if _bound!=null and _focused:
		_bound.pad_active = true
		if not _bound.touch_owned:_bound.touch_active = false
	if event is InputEventJoypadButton:
		_button("b:%d"%event.button_index,GamepadBindings.BUTTONS[event.button_index],event.pressed)
	else:_axis(event.axis,event.axis_value)
	refresh_target()
	_update_axes(0.0)
	return accepted

func _has_input() -> bool:
	if not _down.is_empty():return true
	for axis in _axes:
		if not _neutral(axis,float(_axes[axis])):return true
	return false

func _button(token: String, command: String, pressed: bool) -> void:
	if not pressed:
		_down.erase(token);_suppressed_buttons.erase(token)
		if _held.has(token):router.release(int(_held[token]));_held.erase(token)
		return
	if _down.has(token):return
	_down[token] = command
	if not _focused or not is_instance_valid(router.target) or _transition_active():_suppressed_buttons[token] = true
	if _suppressed_buttons.has(token):return
	if command=="summary" and router.target.get("menu")=="bag":return
	if command.begins_with("item_") and router.navigation() and not GamepadBindings.bag_assignment(router,_summary_held()):return
	if command.begins_with("skill_") and not _playing():return
	var code := router.press(command)
	if code!=KEY_NONE:_held[token] = code

func _axis(axis: int, value: float) -> void:
	_axes[axis] = clampf(value,-1.0,1.0)
	if _neutral(axis,value):_suppressed_axes.erase(axis)
	elif not _focused:_suppressed_axes[axis] = true
	if GamepadBindings.TRIGGERS.has(axis):
		var token := "a:%d"%axis
		if value<=float(config.trigger_release):_button(token,GamepadBindings.TRIGGERS[axis],false)
		elif value>=float(config.trigger_press):_button(token,GamepadBindings.TRIGGERS[axis],true)

func _neutral(axis: int, value: float) -> bool:
	return value<=float(config.trigger_release) if GamepadBindings.TRIGGERS.has(axis) else absf(value)<=float(config.stick_deadzone)

func _stick(x_axis: int, y_axis: int) -> Vector2:
	if _suppressed_axes.has(x_axis) or _suppressed_axes.has(y_axis):return Vector2.ZERO
	var value := Vector2(float(_axes.get(x_axis,0.0)),float(_axes.get(y_axis,0.0)))
	var deadzone := float(config.stick_deadzone)
	if value.length()<=deadzone:return Vector2.ZERO
	return value.normalized()*clampf((value.length()-deadzone)/(1.0-deadzone),0.0,1.0)

func _direction(left: Vector2) -> int:
	var code := KEY_NONE
	for token in _down:
		var command: String = _down[token]
		if not _suppressed_buttons.has(token) and command.begins_with("item_") and not GamepadBindings.bag_assignment(router,_summary_held()):code = GamepadBindings.DIRECTIONS[int(command.trim_prefix("item_"))]
	if code!=KEY_NONE or left.length()<0.25:return code
	return (KEY_RIGHT if left.x>0 else KEY_LEFT) if absf(left.x)>absf(left.y) else (KEY_DOWN if left.y>0 else KEY_UP)

func _summary_held() -> bool:
	for token in _down:
		if _down[token]=="summary" and not _suppressed_buttons.has(token):return true
	return false

func _update_axes(dt: float) -> void:
	if not _focused or not is_instance_valid(router.target) or _transition_active():return
	var left := _stick(JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y)
	if _bound!=null:
		_bound.pad_move = left if _playing() else Vector2.ZERO
		_bound.pad_aim = Vector2.ZERO
		if left!=Vector2.ZERO:_bound.pad_active = true
	var code := _direction(left) if router.navigation() else KEY_NONE
	if code!=_nav:
		_nav = code;_nav_timer = float(config.navigation_delay)
		if code!=KEY_NONE:router.navigate(code)
	elif code!=KEY_NONE:
		_nav_timer -= dt
		if _nav_timer<=0.0:
			_nav_timer = float(config.navigation_repeat);router.navigate(code)

func _process(dt: float) -> void:
	refresh_target()
	_update_axes(dt)

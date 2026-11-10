class_name MobileKeyRouter
extends RefCounted

## Shared mobile/physical routing. UI events stay inside the game viewport.
const KEYS := {"bag":KEY_B,"summary":KEY_C,"water":KEY_F,"town_map":KEY_M,"menu":KEY_ESCAPE,
	"dodge":KEY_SHIFT,"view_minus":KEY_MINUS,"view_plus":KEY_EQUAL,"language":KEY_L,
	"look":KEY_F8,"map":KEY_F9,"fullscreen":KEY_F11}
var target: Node
var source := "touch"
var event_sink := Callable() # Test seam: capture routing without writing preferences.

func human() -> Controllers.Human:
	if not is_instance_valid(target):return null
	var world = target.get("world")
	return world.player.controller as Controllers.Human if is_instance_valid(world) else null

func gameplay() -> bool:
	return human()!=null and target.get("state") in ["fight","town"]

func navigation() -> bool:
	if not is_instance_valid(target):return false
	if target is TitleScreen:return true
	var panel = target.get("panel")
	return target.get("state")=="menu" or (is_instance_valid(panel) and panel.visible)

func code_for(command: String) -> int:
	if command.begins_with("skill_"):return Controllers.SKILL_KEYS[int(command.trim_prefix("skill_"))]
	if command.begins_with("item_"):return Controllers.HOTBAR_KEYS[int(command.trim_prefix("item_"))]
	if command=="action":
		if target.get("state") in ["gameover","victory"]:return KEY_R
		return KEY_ENTER if navigation() else KEY_SPACE
	if command=="cancel":
		if gameplay() and not navigation():
			return KEY_F if not target.get("world").field_water.fishing.is_empty() else KEY_NONE
		if target.get("menu")=="bag":return KEY_B
		if target.get("menu")=="summary":
			var screen = target.get("summary_screen")
			if is_instance_valid(screen) and screen.modal<0 and screen.move_cursor<0:return KEY_C
		return KEY_ESCAPE
	return KEYS.get(command,KEY_NONE)

## Returns the held key, or KEY_NONE for an immediately dispatched UI key.
func press(command: String) -> int:
	if not is_instance_valid(target):return KEY_NONE
	var code := code_for(command)
	if code==KEY_NONE:return KEY_NONE
	if gameplay() and (command.begins_with("skill_") or command.begins_with("item_") or command=="dodge"):
		_press_virtual(code)
		return code
	var handled := _push(code,true)
	_push(code,false)
	if code==KEY_SPACE and gameplay() and not handled:
		_press_virtual(code)
		return code
	return KEY_NONE

func release(code: int, cancelled: bool = false) -> void:
	if code==KEY_NONE or human()==null:return
	if source=="gamepad":human().release_gamepad_key(code,cancelled)
	else:human().release_touch_key(code,cancelled)

func _press_virtual(code: int) -> void:
	if source=="gamepad":human().press_gamepad_key(code)
	else:human().press_touch_key(code)

func navigate(code: int) -> void:
	_push(code,true)
	_push(code,false)

func _push(code: int, pressed: bool) -> bool:
	var event := InputEventKey.new()
	event.physical_keycode = code;event.keycode = code;event.pressed = pressed
	if event_sink.is_valid():event_sink.call(event);return false
	if not is_instance_valid(target) or not target.is_inside_tree():return true
	var viewport := target.get_viewport()
	if pressed and code in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_ENTER]:_ensure_focus(viewport)
	viewport.push_input(event,true)
	if not is_instance_valid(viewport) or not viewport.is_inside_tree():return true
	return viewport.is_input_handled()

func _ensure_focus(viewport: Viewport) -> void:
	var panel = target.get("panel")
	if not is_instance_valid(panel) or not panel.visible or panel._buttons.is_empty():return
	for card in panel._buttons:
		if not card.disabled:
			card.focus_mode = Control.FOCUS_ALL
			card.add_theme_stylebox_override("focus",card.get_theme_stylebox("hover"))
	var focus := viewport.gui_get_focus_owner()
	if panel._buttons.has(focus):return
	for i in range(panel._buttons.size()-1,-1,-1):
		var button: Button = panel._buttons[i]
		if not button.disabled:button.grab_focus();return

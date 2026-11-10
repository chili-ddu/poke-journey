class_name GamepadBindings
extends RefCounted

## Shared physical/mobile bindings. Unavailable actions have no pad assignment.
const FACES := {"action":"A","cancel":"B","skill_0":"X","skill_1":"Y"}
const SHOULDERS := ["bag","summary","skill_2","skill_3"] # LT, RT, LB, RB.
const BUTTONS := {
	JOY_BUTTON_A:"action",JOY_BUTTON_B:"cancel",JOY_BUTTON_X:"skill_0",JOY_BUTTON_Y:"skill_1",
	JOY_BUTTON_LEFT_SHOULDER:"skill_2",JOY_BUTTON_RIGHT_SHOULDER:"skill_3",
	JOY_BUTTON_BACK:"town_map",JOY_BUTTON_START:"menu",
	JOY_BUTTON_DPAD_UP:"item_0",JOY_BUTTON_DPAD_RIGHT:"item_1",
	JOY_BUTTON_DPAD_DOWN:"item_2",JOY_BUTTON_DPAD_LEFT:"item_3"
}
const TRIGGERS := {JOY_AXIS_TRIGGER_LEFT:"bag",JOY_AXIS_TRIGGER_RIGHT:"summary"}
const DIRECTIONS := [KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_LEFT]

static func bag_assignment(router: MobileKeyRouter, summary_held: bool) -> bool:
	return summary_held and is_instance_valid(router.target) and router.target.get("menu")=="bag"

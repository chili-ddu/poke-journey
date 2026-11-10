class_name MobileScreenLayout
extends RefCounted

static var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/touch_controls.json"))

## Fit the unchanged game image above a separate control area.
static func calculate(surface: Vector2, logical: Vector2, safe: Rect2 = Rect2()) -> Dictionary:
	var bounds := Rect2(Vector2.ZERO,surface)
	var usable := bounds.intersection(safe) if safe.has_area() else bounds
	if not usable.has_area() or logical.x<=0 or logical.y<=0:
		return {"display":Rect2(),"controls":Rect2(),"scale":0.0}
	var short_scale := minf(usable.size.x,usable.size.y)/float(config.layout_reference_width)
	var landscape := usable.size.x>usable.size.y
	var pad_height := float(config.landscape_control_height)*usable.size.x/float(config.landscape_reference_width) if landscape else float(config.minimum_control_height)*short_scale
	var minimum_pad := minf(usable.size.y*0.55,pad_height)
	var top_gap := minf(usable.size.y*0.12,float(config.landscape_top_inset if landscape else config.display_top_inset)*short_scale)
	var scale := minf(usable.size.x/logical.x,(usable.size.y-top_gap-minimum_pad)/logical.y)
	var extent := logical*scale
	var display := Rect2(usable.position+Vector2((usable.size.x-extent.x)/2.0,top_gap),extent)
	var controls := Rect2(Vector2(usable.position.x,display.end.y),Vector2(usable.size.x,usable.end.y-display.end.y))
	return {"display":display,"controls":controls,"scale":scale}

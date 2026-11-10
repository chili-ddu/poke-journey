class_name MobilePadLayout
extends RefCounted

const DIRECTIONS := [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]

## A controller deck with face diamond, shoulders, stick and directional cross.
static func calculate(area: Rect2) -> Dictionary:
	var wide := area.size.x>area.size.y*1.6
	var base := Vector2(768,128) if wide else Vector2(360,312)
	var scale := minf(area.size.x/base.x,area.size.y/base.y)
	var origin := area.get_center()-base*scale/2.0
	var rects := {"town_map":Rect2(116,0,72,36) if wide else Rect2(12,0,88,40),
		"menu":Rect2(116,40,72,36) if wide else Rect2(12,46,88,40)}
	var glyphs := {"town_map":"SELECT","menu":"START"}
	var shoulders := GamepadBindings.SHOULDERS
	for i in 4:
		var old_right := i%2==1
		if wide:
			rects[shoulders[i]] = Rect2(684,(i/2)*40,72,36) if old_right else Rect2(294+(i/2)*76,12,64,32)
		else:
			rects[shoulders[i]] = Rect2(260 if old_right else 156,(i/2)*46,88,40)
		glyphs[shoulders[i]] = ["LT","RT","LB","RB"][i]
	var faces: Dictionary = GamepadBindings.FACES
	var diamond := Vector2(576,64) if wide else Vector2(270,166)
	var step := 38.0 if wide else 48.0
	var face_size := 36.0 if wide else 44.0
	var offsets := [Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT,Vector2.UP]
	var index := 0
	for command in faces:
		rects[command] = Rect2(diamond+offsets[index]*step-Vector2.ONE*face_size/2,Vector2.ONE*face_size)
		glyphs[command] = faces[command];index += 1
	var dpad := Vector2(236,64) if wide else Vector2(92,250)
	var cell := 24.0 if wide else 30.0
	for i in 4:
		rects["item_%d"%i] = Rect2(dpad+DIRECTIONS[i]*cell-Vector2.ONE*cell/2,Vector2.ONE*cell)
	var center := Vector2(54,64) if wide else Vector2(74,148)
	var aim := Vector2(446,88) if wide else Vector2(232,274)
	var radius := 40.0 if wide else 44.0
	var hits := {}
	for key in rects:hits[key] = Rect2(origin+rects[key].position*scale,rects[key].size*scale)
	return {"origin":origin,"scale":scale,"base":base,"rects":rects,"hits":hits,"glyphs":glyphs,
		"stick":origin+center*scale,"radius":radius*scale,"aim":origin+aim*scale,
		"aim_radius":(30.0 if wide else 32.0)*scale,"dpad":dpad,"cell":cell,"wide":wide}

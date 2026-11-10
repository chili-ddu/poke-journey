extends RefCounted

# 원본 지붕에 함께 잘려 들어온 벽 띠를 제외한다. 기와 픽셀은 그대로.
static func roof(source: Image) -> Image:
	var end := source.get_height()
	for y in range(source.get_height() - 1, -1, -1):
		var c := source.get_pixel(source.get_width() / 2, y)
		if c.a > 0.0 and c.r > c.b + 30.0 / 255.0:
			end = y + 1
			break
	return source.get_region(Rect2i(0, 0, source.get_width(), end))

# 처마: 지붕의 마감색으로 위/중간/아래 세 도트 띠, 벽 무늬를 늘이지 않는다.
static func eave(source: Image) -> Image:
	var clean := roof(source)
	var color := clean.get_pixel(clean.get_width() / 2, clean.get_height() - 1)
	var out := Image.create(1, 3, false, Image.FORMAT_RGBA8)
	for y in 3:
		var gain: float = [1.0, 0.82, 0.64][y]
		out.set_pixel(0, y, Color(color.r * gain, color.g * gain, color.b * gain, color.a))
	return out

static func wall(source: Image) -> Image:
	var out := source.duplicate() as Image
	for y in mini(2, source.get_height()):
		var gain := 0.82 if y == 0 else 0.92
		for x in source.get_width():
			var c := source.get_pixel(x, y)
			out.set_pixel(x, y, Color(c.r * gain, c.g * gain, c.b * gain, c.a))
	return out

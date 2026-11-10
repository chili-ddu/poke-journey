extends RefCounted

# 캐릭터 도트의 순수 이미지 변환. 환경 변수·텍스처 캐시·장소 조명에 의존하지 않는다.
# 원본 이미지는 보존하고, 외곽선 보정 → 몸 음영 순서로 새 이미지를 만든다.
const SELOUT_DARK := 0.42
const SELOUT_LIT := 0.72
const SHADE_DARK := 0.8
const SHADE_LIT := 1.12
const BODY_SHADOW := Color(0.80, 0.84, 0.92)
const BODY_LIGHT := Color(1.10, 1.06, 1.00)

# 장면의 실제 3D 조명 위에 전체 색을 다시 곱하지 않고 몸의 명암 대비만 조절한다.
const PROFILES := {
	"day": [BODY_SHADOW, BODY_LIGHT],
	"indoor": [Color(0.90, 0.88, 0.86), Color(1.06, 1.04, 1.00)],
	"forest": [Color(0.84, 0.90, 0.94), Color(1.04, 1.06, 1.02)],
}

static func process(image: Image, stepped: bool, profile: String = "day") -> Image:
	var src: Image = image.duplicate()
	if src.is_compressed():
		if src.decompress() != OK:
			return null
	src.convert(Image.FORMAT_RGBA8)
	var out: Image = src.duplicate()
	_recolor_outline(src, out)
	shade_body(src, out, stepped, profile)
	return out

static func _recolor_outline(src: Image, out: Image) -> void:
	var w := src.get_width()
	var h := src.get_height()
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a < 0.5 or c.r > 0.12 or c.g > 0.12 or c.b > 0.12:
				continue
			# 바깥과 맞닿았나(4이웃 중 투명) — 어느 쪽이 바깥인지에 따라 빛 쪽/그늘 쪽
			var lit := false
			var outer := false
			for dv in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var nx: int = x + dv.x
				var ny: int = y + dv.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or src.get_pixel(nx, ny).a < 0.5:
					outer = true
					if dv.x > 0 or dv.y > 0:
						lit = true
			if not outer:
				continue
			# 안쪽 몸 색: 8이웃 중 검지 않은 불투명 픽셀의 평균
			var sum := Vector3.ZERO
			var n := 0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var mx := x + ox
					var my := y + oy
					if mx < 0 or my < 0 or mx >= w or my >= h:
						continue
					var m := src.get_pixel(mx, my)
					if m.a >= 0.5 and (m.r > 0.12 or m.g > 0.12 or m.b > 0.12):
						sum += Vector3(m.r, m.g, m.b)
						n += 1
			if n == 0:
				continue
			var avg := sum / float(n) * (SELOUT_LIT if lit else SELOUT_DARK)
			out.set_pixel(x, y, Color(avg.x, avg.y, avg.z, c.a))

static func shade_body(src: Image, out: Image, stepped: bool, profile: String = "day") -> void:
	var tones: Array = PROFILES.get(profile, PROFILES["day"])
	var w := src.get_width()
	var h := src.get_height()
	for y in h:
		var x := 0
		while x < w:
			if src.get_pixel(x, y).a < 0.5:
				x += 1
				continue
			var x0 := x
			while x < w and src.get_pixel(x, y).a >= 0.5:
				x += 1
			var n := x - x0
			if n < 5:
				continue
			for i in n:
				var t := float(i) / float(n - 1)
				var original := src.get_pixel(x0 + i, y)
				if stepped:
					# 외곽선은 이미 별도로 보정했으므로 다시 물들이지 않는다. 눈·입도 보존.
					if maxf(original.r, maxf(original.g, original.b)) < 0.12:
						continue
					var tone: Color = tones[0] if t < 0.25 else tones[1] if t > 0.82 else Color.WHITE
					# 원본 밝은 노랑(불꽃 핵 등)은 추가 하이라이트로 탈색하지 않는다.
					if original.r > 0.95 and original.g > 0.85:
						continue
					out.set_pixel(x0 + i, y, Color(minf(1.0, original.r * tone.r), minf(1.0, original.g * tone.g), minf(1.0, original.b * tone.b), original.a))
					continue
				var k := 1.0
				if t < 0.3:
					k = lerpf(SHADE_DARK, 1.0, t / 0.3)
				elif t > 0.8:
					k = lerpf(1.0, SHADE_LIT, (t - 0.8) / 0.2)
				if k == 1.0:
					continue
				var c := out.get_pixel(x0 + i, y)
				if c.r < 0.12 and c.g < 0.12 and c.b < 0.12:
					continue
				out.set_pixel(x0 + i, y, Color(minf(1.0, c.r * k), minf(1.0, c.g * k), minf(1.0, c.b * k), c.a))


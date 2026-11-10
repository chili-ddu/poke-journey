extends RefCounted

# 연구소 가구의 면별 도트 보정. 원본/알파/해상도 보존, 확대나 노이즈 없음.
static func surface(source: Image, top: bool) -> Image:
	var result := source.duplicate() as Image
	for y in source.get_height():
		for x in source.get_width():
			var c := source.get_pixel(x, y)
			if c.a == 0.0:
				continue
			# 밝은 무채색 판만 낮춰 후처리 하이라이트에 여유를 둔다.
			var high := maxf(c.r, maxf(c.g, c.b))
			var low := minf(c.r, minf(c.g, c.b))
			if low > 0.72 and high - low < 0.12:
				c.r *= 0.86
				c.g *= 0.86
				c.b *= 0.88
			# 넓은 윗판의 같은 색 영역 안쪽에 1픽셀 접합 음영.
			# 어두운 외곽선과 작은 장비/책 무늬에는 적용하지 않는다.
			if top and low > 0.45 and x > 0 and y > 0 and x < source.get_width() - 1 and y < source.get_height() - 1:
				var original := source.get_pixel(x, y)
				var left := source.get_pixel(x - 1, y)
				var above := source.get_pixel(x, y - 1)
				var right := source.get_pixel(x + 1, y)
				var below := source.get_pixel(x, y + 1)
				if (above != original or left != original) and right == original and below == original:
					c.r *= 0.90
					c.g *= 0.90
					c.b *= 0.92
			result.set_pixel(x, y, c)
	return result

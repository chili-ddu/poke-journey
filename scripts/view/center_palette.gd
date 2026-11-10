extends RefCounted

# 센터 타일 팔레트만 교체: 표식·출입구·검정 바깥·알파는 보존한다.
const FLOOR_COLORS := {
	Color8(246, 246, 205): Color8(218, 213, 180),
	Color8(238, 238, 172): Color8(207, 201, 151),
	Color8(230, 222, 156): Color8(198, 187, 140),
	Color8(213, 205, 156): Color8(181, 172, 135),
	Color8(197, 180, 139): Color8(165, 149, 117),
}
const Furniture = preload("res://scripts/view/furniture_palette.gd")

static func applies(map_dir: String) -> bool:
	return map_dir in ["res://assets/maps/viridian_center", "res://assets/maps/pewter_center"]

static func floor_surface(source: Image) -> Image:
	var out := source.duplicate() as Image
	for y in source.get_height():
		for x in source.get_width():
			var c := source.get_pixel(x, y)
			if FLOOR_COLORS.has(c):
				out.set_pixel(x, y, FLOOR_COLORS[c])
	return out

static func counter(source: Image, top: bool) -> Image:
	# 밝은 명패·판 모서리는 연구소와 같은 기준. 붉은 카운터 색은 유지한다.
	return Furniture.surface(source, top)

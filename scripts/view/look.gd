class_name Look

# 화면 느낌(사용자 요청 2026-11-02: HD-2D 한번 해 보기). 게임 로직은 그대로 두고 그림 위에만 얹는다.
#   flat  지금까지의 화면(GBA·DS 처럼 평평한 2D)
#   hd2d  옥토패스 트래블러 같은 HD-2D '느낌'을 2D 안에서 흉내 — 1단계 시제품:
#         · 틸트시프트: 화면 위·아래 띠가 점점 흐려져 미니어처를 내려다보는 깊이감(assets/shaders/hd2d_post.gdshader)
#         · 발광: 불꽃·번개·섬광 효과는 가산 합성 + 빛무리로 빛나 보이고, 아주 밝은 채색 픽셀만 살짝 번진다(블룸)
#         · 색보정·비네팅: 채도·대비를 조금 올리고, 그늘은 서늘하게·밝은 곳은 따뜻하게, 화면 가장자리는 어둡게
#         · 조명: 장소마다 화면을 조금 어둡게(CanvasModulate) 깔고, 파이리 꼬리불·불꽃 기술이 둘레를 밝힌다(PointLight2D)
#         진짜 HD-2D(3D 지도 + 빌보드 도트)는 2단계 — README "화면 느낌" 참고.
# 되돌리기: DEFAULT_MODE = "flat", 또는 실행할 때 환경 변수 LOOK=flat, 게임 안에서 F8 로 바로 바꾼다(비교용).
const DEFAULT_MODE := "hd2d"

# 꼬리에 불이 있는 종(꼬리불이 둘레를 밝힌다)
const TAIL_FLAME := ["charmander", "charmeleon", "charizard"]
# 투사체 스타일 → 빛 색(불꽃·번개 기술이 날아가며 둘레를 밝힌다)
const PROJECTILE_LIGHT := {
	"ember": Color(1.0, 0.55, 0.2), "ember_c": Color(1.0, 0.55, 0.2), "flame": Color(1.0, 0.5, 0.15), "flame_c": Color(1.0,0.45,0.12),
	"dragon_c": Color(0.55, 0.45, 1.0), "dragon": Color(0.7, 0.45, 1.0), "breath": Color(1.0, 0.45, 0.7), "spark": Color(1.0, 0.95, 0.4),
}

static var mode := _initial()
# HD-2D 2단계 시제품(View3D): 3D 로 세운 지도. 쓸 수 있는 지도(hd2d_cards.json)에서만. 게임 안에서 F9, 끄려면 VIEW3D=0.
static var view3d := OS.get_environment("VIEW3D") != "0"
static var ambient_now := Color.WHITE      # 지금 장소의 밝기(Game._apply_look 가 정한다) — 조명 세기를 여기에 맞춘다

# 포켓몬·효과 그림은 조명을 받지 않는다(light_mask 2) — 꼬리불이 제 몸을 비추면 도트가 하얗게 날아갔다(캡처 확인 2026-11-02).
# 조명은 바닥(지도)·사람만 밝힌다(range_item_cull_mask 1).
const UNLIT_MASK := 2

# 3D 화면(View3D)의 바닥 오버레이: 2D 세계를 한 번 더 비추는 작은 뷰포트가 이 렌더 레이어(비트 2)의 노드만 그려 바닥 판에 입힌다.
# 바닥에 깔리는 표시(할퀴기 호·연막 점선 고리·예고원·장판·풀숲 흔들림·떨어진 도구·배틀 울타리)만 이 레이어를 더 갖는다.
const GROUND_LAYER := 2
# Grass has its own terrain-aligned 3D mesh. Sending it to the floor overlay
# as well leaves a second flat rustle underneath the moving leaves.
const GROUND_FX := ["swipe", "dashring", "circle", "spawn", "line", "beam"]

static func _initial() -> String:
	var env := OS.get_environment("LOOK")
	return env if env in ["flat", "hd2d"] else DEFAULT_MODE

static func hd2d() -> bool:
	return mode == "hd2d"

static func toggle() -> void:
	mode = "flat" if mode == "hd2d" else "hd2d"

# 장소마다 깔리는 밝기·색(CanvasModulate). 숲은 나무 그늘로 어둡고 푸르게, 건물 안은 거의 그대로.
static func ambient(location: String) -> Color:
	if not hd2d():
		return Color.WHITE
	if DungeonDB.is_indoor(location):
		return Color(0.97, 0.95, 0.92)
	if String(DungeonDB.DUNGEONS.get(location, {}).get("theme", "")) == "forest" or location.begins_with("arena_viridian_forest") or location=="arena_forest_rescue":
		return Color(0.7, 0.77, 0.72)
	return Color(0.98, 0.95, 0.9)                # 낮: 거의 그대로, 살짝 따뜻하게

# 조명 세기 배율: 장소가 어두울수록 세다(낮 바깥은 은은하게, 숲 그늘에선 또렷하게).
static func light_gain() -> float:
	var lum := ambient_now.r * 0.299 + ambient_now.g * 0.587 + ambient_now.b * 0.114
	return clampf((1.0 - lum) * 3.6, 0.15, 1.0)

# 스스로 빛나는 효과 텍스처: hd2d 에선 가산 합성으로 그려 발광처럼 보이게(밝은 색일 때만 — 그을음 같은 어두운 색은 그대로).
# 화면 밝기만 보는 블룸은 낮의 밝은 모래길까지 번져서(캡처 확인 2026-11-02) 발광은 이렇게 효과 쪽에서 정한다.
const EMISSIVE := ["g4_flame", "g4_fire_puff", "g4_burst_q", "g4_glow", "g4_bolt_a", "g4_bolt_b", "g4_tw_bolt_a", "g4_tw_bolt_b",
	"g4_tw_ring", "g4_tw_arcs", "g4_spark", "g4_breath_a", "g4_breath_b", "fire_fang_flame", "fire_fang_puff", "g4_flash_star",
	"g4_beam_glow", "g4_ray", "g4_star64", "g4_polish_star", "g4_hitburst", "g4_ballopen_glow", "g4_ballopen_ray", "g4_ballopen_spark"]

static var _add_mat: CanvasItemMaterial = null

static func additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat

static func emissive(text: String, color: Color) -> bool:
	return hd2d() and EMISSIVE.has(text) and color.r * 0.299 + color.g * 0.587 + color.b * 0.114 > 0.45

# 꼬리불 자리(사용자 '빛나는 효과는 꼬리에만' 2026-11-02): 도트 프레임에서 불꽃의 밝은 노랑 픽셀이 모인 자리(프레임 안 원본 px).
# 배의 노란 점도 같은 색이라 프레임 가운데에서 가장 먼 픽셀의 연결 덩어리를 선택한다. 뒤를 보는 프레임은
# 꼬리불이 가운데에 하나뿐이라 그대로 잡힌다. 없으면 Vector2(-1, -1). 시트·영역마다 한 번만 센다.
const FLAME_COLOR := Color8(255, 247, 0)
static var _flame_cache := {}
static var _sheet_images := {}

static func flame_point(tex: Texture2D, src: Rect2) -> Vector2:
	if tex == null:
		return Vector2(-1, -1)
	var key := "%d:%d,%d,%d,%d" % [tex.get_rid().get_id(), int(src.position.x), int(src.position.y), int(src.size.x), int(src.size.y)]
	if _flame_cache.has(key):
		return _flame_cache[key]
	var id := tex.get_rid().get_id()
	if not _sheet_images.has(id):
		_sheet_images[id] = tex.get_image()
	var img: Image = _sheet_images[id]
	var pts: Array = []
	var center := src.size / 2.0
	if img != null:
		for y in int(src.size.y):
			for x in int(src.size.x):
				var c := img.get_pixel(int(src.position.x) + x, int(src.position.y) + y)
				if c.a > 0.5 and absf(c.r - FLAME_COLOR.r) < 0.02 and absf(c.g - FLAME_COLOR.g) < 0.02 and c.b < 0.1:
					var p := Vector2(x + 0.5, y + 0.5)
					pts.append(p)
	var out := _flame_cluster_center(pts, center)
	_flame_cache[key] = out
	return out

# 몸 중심에서 가장 먼 노랑 픽셀과 연결된 덩어리만 사용한다.
# 배·공격 도트의 다른 노랑까지 평균내면 빛이 빈 공간을 가로질러 튄다.
static func _flame_cluster_center(points: Array, center: Vector2) -> Vector2:
	if points.is_empty():
		return Vector2(-1, -1)
	var remaining := {}
	var seed: Vector2 = points[0]
	for point: Vector2 in points:
		remaining[point] = true
		if point.distance_squared_to(center) > seed.distance_squared_to(center):
			seed = point
	var cluster: Array[Vector2] = [seed]
	remaining.erase(seed)
	var i := 0
	var sum := Vector2.ZERO
	while i < cluster.size():
		var point := cluster[i]
		sum += point
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var next := point + Vector2(dx, dy)
				if remaining.has(next):
					remaining.erase(next)
					cluster.append(next)
		i += 1
	var mean := sum / float(cluster.size())
	# 오목한 덩어리도 중심이 투명한 틈에 놓이지 않도록 실제 픽셀 위로 고정.
	var nearest := seed
	for point in cluster:
		if point.distance_squared_to(mean) < nearest.distance_squared_to(mean):
			nearest = point
	return nearest

# 캐릭터 픽셀 변환은 SpritePalette, 환경 설정과 텍스처 재사용은 Look이 담당한다.
const SpritePalette = preload("res://scripts/view/sprite_palette.gd")
static var selout := OS.get_environment("SELOUT") != "0"
static var sprite_tone := OS.get_environment("SPRITE_TONE") != "legacy"
static var _selout_cache := {}
static var _sprite_images := {}

# Transform only the visible cell, rather than all directions/in-betweens in
# its atlas on the first step of an animation. Keep results in the same cache
# as legacy whole-sheet transforms so mode/profile changes remain distinct.
static func selout_frame(tex: Texture2D, region: Rect2, profile: String = "day") -> Dictionary:
	# Authored species palettes already include their outline and shade ramps.
	if tex == null or not selout or tex.get_meta("authored_palette", false):
		return {"tex": tex, "src": region}
	var effective_profile := profile if sprite_tone and SpritePalette.PROFILES.has(profile) else "day"
	var key := "frame:%d:%s:%s:%s" % [tex.get_instance_id(), sprite_tone, effective_profile, str(region)]
	if not _selout_cache.has(key):
		var id := tex.get_instance_id()
		if not _sprite_images.has(id):
			# Retain only a small working set of decoded source sheets. The final
			# per-frame textures are much smaller and remain reusable independently.
			if _sprite_images.size() >= 8:
				_sprite_images.erase(_sprite_images.keys()[0])
			var image := tex.get_image()
			if image == null: return {"tex": tex, "src": region}
			if image.is_compressed() and image.decompress() != OK:
				return {"tex": tex, "src": region}
			_sprite_images[id] = image
		var image: Image = _sprite_images[id]
		var cell := image.get_region(Rect2i(region))
		var shaded: Image = SpritePalette.process(cell, sprite_tone, effective_profile)
		if shaded == null: return {"tex": tex, "src": region}
		_selout_cache[key] = ImageTexture.create_from_image(shaded)
	return {"tex": _selout_cache[key], "src": Rect2(Vector2.ZERO, region.size)}

static func selout_texture(tex: Texture2D, profile: String = "day") -> Texture2D:
	if tex == null or not selout:
		return tex
	# 같은 원본이라도 새 단계형 음영과 기존 음영의 결과는 다르다.
	var effective_profile := profile if sprite_tone and SpritePalette.PROFILES.has(profile) else "day"
	var key := "%d:%s:%s" % [tex.get_instance_id(), sprite_tone, effective_profile]
	if _selout_cache.has(key):
		return _selout_cache[key]
	var src := tex.get_image()
	if src == null:
		return tex
	var out: Image = SpritePalette.process(src, sprite_tone, effective_profile)
	if out == null:
		return tex
	var result := ImageTexture.create_from_image(out)
	_selout_cache[key] = result
	return result

static var _light_tex: Texture2D = null

# 둥근 빛 텍스처(가운데 흰색 → 가장자리 투명). PointLight2D 가 같이 쓴다.
static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_light_tex = t
	return _light_tex

# 반지름 radius(px)의 점 조명.
static func make_light(color: Color, energy: float, radius: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = radius / 32.0
	l.color = color
	l.energy = energy
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.range_item_cull_mask = 1
	return l

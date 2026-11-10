class_name Projectile
extends Node2D

const EMBER_DRAW := 3.6   # 불꽃세례 그림 = 판정 반지름 × 이만큼(32px 불꽃 그림 기준)

func visual_flame_texture() -> Texture2D:
	return Fx.sheet(flame_texture)

# 날아가는 탄. 데미지는 쏜 순간의 능력치(hit)를 들고 다닌다 —
# 쏜 적이 먼저 쓰러져도 탄은 그대로 맞아야 하므로.
#
# 생김새는 기술의 fx 로 고른다(원작 전투 애니메이션을 흉내 낸 것).
#   ember   불꽃세례: 플래티넘 ember.spa 의 유일한 텍스처(불꽃, assets/fx/g4_flame.png) 하나가 곧추선 채 일렁이며 날아간다(판정용 탄).
#           원작엔 날아가는 단계가 없고 불꽃이 맞는 쪽에서 피어난다 — 맞은 뒤 연출은 World.apply_hit 의 "ember"(사용자 결정 2026-10-28).
#   flame   화염방사: 같은 불꽃을 더 크고 노랗게
#   dragon  용의분노: 같은 불꽃을 보라색으로, 속은 하늘색
#   water·hydro·pulse·bubble·leaf·flash  이상해씨·꼬북이 기술: 플래티넘 텍스처(TEX_STYLES)
#   acid    산성액: 보라 점액
#   needle  독침·미사일바늘: 가늘고 긴 바늘
#   thread  실뿜기: 하얀 실 두 가닥
#   spark   전기쇼크·번개: 노란 지그재그 번개
#   (빈 값)  기본 원

# 텍스처로 그리는 탄: [텍스처, 판정 반지름의 몇 배로 그릴지, 바깥 색, (속 색)]. 색은 플래티넘 이미터 색(tools/plat_fx.py spa_resources).
const TEX_STYLES := {
	"mud": ["world_mud_slap_2",3.2,Color8(160,112,64,240)],
	"ice": ["world_icy_wind_2",4.0,Color8(168,232,255,235)],
	"voice": ["g4_ring_q", 3.8, Color8(248, 160, 216, 230), Color8(255, 232, 248, 210)],
	"leaf": ["g4_leaf", 3.4, Color.WHITE],                                          # razor_leaf.spa 잎(이미 초록)
	"bubble": ["g4_bubble_blue", 3.0, Color(1, 1, 1, 0.95)],                        # bubble.spa 거품
	"water": ["g4_glow", 3.2, Color8(16, 208, 248, 230), Color8(200, 248, 248, 240)],   # water_gun.spa 물(하늘 → 파랑)
	"hydro": ["g4_glow", 3.4, Color8(64, 152, 248, 235), Color8(200, 248, 248, 240)],   # hydro_pump.spa
	"pulse": ["g4_ring_q", 3.4, Color8(96, 200, 248, 235), Color8(200, 232, 248, 220)], # water_pulse.spa 물결 고리
	"flash": ["g4_flash_star", 5.5, Color8(248, 208, 248, 240), Color(1, 1, 1, 0.9)],   # flash_cannon.spa 빛 구슬
	"brine": ["g4_glow", 3.6, Color8(128, 200, 248, 235), Color8(248, 248, 248, 240)],  # brine.spa 물덩이(하늘 → 흰색)
	"breath": ["g4_breath_a", 3.6, Color8(248, 88, 160, 235), Color8(248, 216, 128, 220)],  # dragon_breath.spa 숨결 뭉치(자홍, 속은 노랑)
	"rock": ["g4_rock", 2.8, Color.WHITE],                                           # rock_throw.spa 바위(이미 회색) — 돌떨구기·떨어뜨리기
}

const RELEASE_GAP := 5.0 # Visual pixels ahead of the tip at launch.
var flat_release := Vector2.ZERO
var mouth_delta := Vector3.ZERO
var mouth_ready := false
# Cosmetic variation only; never alter radius, velocity or combat RNG.
var flame_texture := "g4_flame"
var flame_size := 1.0
var flame_aspect := Vector2.ONE
var flame_tilt := 0.0
var flame_phase := 0.0
var flame_mirror := false
var emitter: WeakRef
var launch_position := Vector2.ZERO

var team := Mon.TEAM_PLAYER
var hit := {}
var vel := Vector2.ZERO
var radius := 4.0
var range_left := 200.0
var pierce := false
var hit_ids := {}
var color := Color.WHITE
var style := ""
var grow := 1.0             # 사거리 끝에서의 크기 배율(1 이면 그대로). 날아갈수록 커진다
var range_full := 200.0
var dead := false
var age := 0.0
var trail: Array = []       # 커스텀 불꽃세례(ember_c): 지나온 자리(최근 것이 뒤) — 꼬리 불티

const TRAIL_LEN := 6

func step(dt: float, record_trail: bool = true) -> void:
	age += dt
	if style == "ember_c" and record_trail:
		trail.append(position)
		if trail.size() > TRAIL_LEN:
			trail.pop_front()
	var d := (vel * dt).limit_length(maxf(0.0,range_left))
	position += d
	range_left = maxf(0.0,range_left-d.length())
	if range_left <= 0.0001:
		range_left = 0.0
		dead = true

# 지금 크기 배율. grow 가 1 이 넘으면 날아간 거리에 비례해 커진다(판정도 같이).
func scale_now() -> float:
	if grow <= 1.0 or range_full <= 0.0:
		return 1.0
	var done := 1.0 - clampf(range_left / range_full, 0.0, 1.0)
	return lerpf(1.0, grow, done)

# Visual envelope only: a tiny mouth spark blooms, then flickers independently in flight.
func flame_envelope() -> float:
	var travel := clampf(1.0-range_left/maxf(range_full,0.001),0.0,1.0)
	var opening := smoothstep(0.0,0.45,travel)
	var bloom := lerpf(0.22,1.05,opening)
	var taper := lerpf(1.0,0.88,smoothstep(0.8,1.0,travel))
	var pulse := 1.0+sin(age*(18.0+flame_phase*1.5)+flame_phase)*0.14*opening
	return bloom*taper*pulse

func hit_radius() -> float:
	return radius * scale_now()

func _process(_dt: float) -> void:
	queue_redraw()
	# HD-2D 느낌(Look): 불꽃·번개 투사체는 날아가며 둘레를 밝힌다.
	if Look.PROJECTILE_LIGHT.has(style):
		if _light == null:
			light_mask = Look.UNLIT_MASK
			_light = Look.make_light(Look.PROJECTILE_LIGHT[style], 1.0, 40.0 * maxf(1.0, scale_now()))
			_light_full_scale = _light.texture_scale
			add_child(_light)
		_light.texture_scale = _light_full_scale * float(hit.get("clash_fraction", 1.0))
		_light.visible = Look.hd2d() and not dead
		_light.energy = 1.1 * maxf(0.45, Look.light_gain())     # 날아가는 불꽃은 낮에도 조금은 보이게
		# 빛무리: 불꽃 둘레에 은은한 빛(가산 합성) — 블룸 대신 발광을 여기서
		if _halo == null:
			_halo = Sprite2D.new()
			_halo.texture = Fx.sheet("g4_glow")
			_halo.material = Look.additive()
			_halo.light_mask = Look.UNLIT_MASK
			_halo.show_behind_parent = true
			add_child(_halo)
		_halo.visible = _light.visible and _halo.texture != null
		var c: Color = Look.PROJECTILE_LIGHT[style]
		_halo.modulate = Color(c.r, c.g, c.b, 0.55 + 0.1 * sin(age * 30.0))
		var hs := radius * 6.0 * scale_now() / 32.0
		_halo.scale = Vector2(hs, hs)
		_halo.position = Vector2(0, radius * 1.0) if style in ["ember", "ember_c"] else Vector2.ZERO

var _light_full_scale := 1.0
var _light: PointLight2D = null
var _halo: Sprite2D = null

# 플래티넘 불꽃 텍스처(끝이 위). 꼬리가 진행 방향 뒤로 가게 돌려 두 겹(바깥색·속색)으로 그린다.
func _draw_flame(dir: Vector2, outer: Color, inner: Color, size_mult: float) -> void:
	var tex := Fx.sheet("g4_flame")
	var flick := 1.0 + 0.12 * sin(age * 40.0)
	var sc := radius * size_mult * scale_now() * flick / 16.0
	_draw_projectile_transform(Vector2.ZERO, dir.angle() + PI / 2.0, Vector2(sc, sc * 1.15))
	draw_texture(tex, Vector2(-16, -16), outer)
	_draw_projectile_transform(Vector2.ZERO, dir.angle() + PI / 2.0, Vector2(sc * 0.55, sc * 0.7))
	draw_texture(tex, Vector2(-16, -16), inner)
	_draw_projectile_transform(Vector2.ZERO)

# 커스텀 불꽃세례(FxStyle, 2026-11-02): 불꽃 끝이 날아가는 반대쪽으로 흩날리는 혜성 모양 + 지나온 자리에 작아지는 불티 꼬리.
# 그림 높이는 원작 모드처럼 판정 자리보다 조금 아래(파이리 입 높이).
func _draw_ember_custom(_dir: Vector2) -> void:
	var tex := visual_flame_texture()
	var low := Vector2(0, radius * 1.0)
	var sc := radius * EMBER_DRAW * scale_now()*flame_envelope()*flame_size / float(tex.get_width())
	# The flame stays upright in the same space as the HD-2D body sprites.
	_draw_projectile_transform(low,flame_tilt,Vector2(sc,sc)*flame_aspect)
	draw_texture(tex,-Vector2(tex.get_size())/2.0,Color(1.0,0.55,0.15))
	_draw_projectile_transform(Vector2.ZERO)

# Shared cosmetic layers for 2D and HD-2D; collision radius is untouched.
func dragon_layers() -> Array:
	var direction := vel.normalized()
	var side := Vector2(-direction.y, direction.x)
	var r := radius * scale_now()
	var layers: Array = []
	for i in range(4, 0, -1):
		layers.append({"offset": -direction*r*i*0.65 + side*sin(age*24.0-i)*r*0.25,
			"size": r*(2.5-i*0.3), "color": Color(0.5,0.25,1.0,0.55-i*0.08)})
	layers.append({"offset": Vector2.ZERO, "size": r*(3.4+sin(age*32.0)*0.18), "color": Color(0.6,0.35,1.0,0.9)})
	layers.append({"offset": direction*r*0.25, "size": r*1.65, "color": Color(0.65,0.95,1.0,1.0)})
	return layers

# Each existing collision projectile paints overlapping elongated flame layers.
# Visual width grows with travel; hit radius, lifetime and velocity do not.
func stream_layers() -> Array:
	var travel := clampf(1.0-range_left/maxf(range_full,0.001),0.0,1.0)
	var width := radius*lerpf(0.8,3.7,smoothstep(0.0,0.85,travel))
	var flicker := 1.0+0.1*sin(age*31.0+flame_phase)
	return [
		{"width":width*flicker,"length":radius*4.4,"color":Color(1.0,0.32,0.07,0.8)},
		{"width":width*0.65,"length":radius*3.8,"color":Color(1.0,0.68,0.12,0.9)},
		{"width":width*0.28,"length":radius*3.2,"color":Color(1.0,0.94,0.6,0.95)}]

func _draw_stream() -> void:
	var tex := Fx.sheet("g4_flame")
	if tex == null: return
	var rotation := vel.angle()+PI/2.0
	for layer in stream_layers():
		var extent := Vector2(float(layer["width"]),float(layer["length"]))
		_draw_projectile_transform(Vector2(0,6),rotation)
		draw_texture_rect(tex,Rect2(-extent*0.5,extent),false,layer["color"])
	_draw_projectile_transform(Vector2.ZERO)

func _draw_projectile_transform(offset: Vector2, angle: float=0.0, stretch:=Vector2.ONE) -> void:
	draw_set_transform(offset+flat_release*clampf(range_left/maxf(1.0,range_full),0,1),angle,stretch)

func _draw() -> void:
	_draw_projectile_transform(Vector2.ZERO)
	if style == "flame_c":
		_draw_stream()
		return
	var dir := vel.normalized()
	var side := Vector2(-dir.y, dir.x)
	if style == "dragon_c":
		var tex := Fx.sheet("g4_glow")
		if tex != null:
			for layer in dragon_layers():
				var extent := Vector2.ONE * float(layer["size"])
				draw_texture_rect(tex, Rect2(layer["offset"]-extent*0.5,extent),false,layer["color"])
		return
	if style == "ember_c":
		_draw_ember_custom(dir)
		return
	if style == "ember" and Fx.sheet("g4_flame") != null:
		# 불꽃세례: ember.spa 불꽃 그림 하나. 날아가는 방향으로 눕히지 않고 위로 곧추세워(원작 파티클처럼) 좌우로 일렁인다.
		var tex := Fx.sheet("g4_flame")
		var flick := 1.0 + 0.12 * sin(age * 40.0)
		var sway := 0.12 * sin(age * 25.0)
		# 그림 크기: 판정 반지름의 3.6배(사용자 요청 2026-10-28: 2.4배는 너무 작아 잘 안 보임 → 1.5배). 판정은 그대로.
		var sc := radius * EMBER_DRAW * scale_now() / 32.0
		# 그림은 판정 자리보다 조금 아래 — 파이리 입 높이에서 나오게(사용자 지적 2026-10-28: 눈높이에서 떠 보였다).
		_draw_projectile_transform(Vector2(0, radius * 1.0), sway, Vector2(sc, sc * flick))
		draw_texture(tex, Vector2(-16, -16), Color(1.0, 0.5, 0.15))
		_draw_projectile_transform(Vector2(0, radius * 1.2), -sway, Vector2(sc * 0.55, sc * 0.65 * flick))
		draw_texture(tex, Vector2(-16, -16), Color(1.0, 0.92, 0.55))
		_draw_projectile_transform(Vector2.ZERO)
		return
	# 이상해씨·꼬북이 기술(플래티넘 텍스처, 색은 각 파일의 이미터 색).
	if style in ["water","pulse"]:
		for layer in layered_layers():
			var texture := Fx.sheet(layer.texture)
			if texture==null:continue
			var size := Vector2.ONE*float(layer.size)
			var angle := dir.angle()+PI/2.0+float(layer.get("rot",0.0))
			_draw_projectile_transform(layer.offset,angle,Vector2(1.0,float(layer.get("stretch",1.0))))
			draw_texture_rect(texture,Rect2(-size*0.5,size),false,layer.color)
		_draw_projectile_transform(Vector2.ZERO)
		return
	if style=="needle":
		for layer in needle_layers():
			var texture := Fx.sheet(layer.texture)
			if texture==null:continue
			var size := Vector2.ONE*float(layer.size)
			_draw_projectile_transform(layer.offset,dir.angle()+PI/2.0,Vector2(1.0,float(layer.get("stretch",1.0))))
			draw_texture_rect(texture,Rect2(-size*0.5,size),false,layer.color)
		_draw_projectile_transform(Vector2.ZERO)
		return
	if style=="voice":
		for layer in voice_layers():
			var texture := Fx.sheet(layer.texture)
			if texture==null:continue
			var size := Vector2.ONE*float(layer.size)
			var angle := dir.angle()+PI/2.0 if bool(layer.get("aimed",false)) else float(layer.get("rot",0.0))
			_draw_projectile_transform(layer.offset,angle,Vector2(1.0,float(layer.get("stretch",1.0))))
			draw_texture_rect(texture,Rect2(-size*0.5,size),false,layer.color)
		_draw_projectile_transform(Vector2.ZERO)
		return

	if style in TEX_STYLES:
		var spec: Array = TEX_STYLES[style]
		var tex := Fx.sheet(spec[0])
		if tex != null:
			var px: float = radius * float(spec[1]) * scale_now()
			var sc := px / float(tex.get_width())
			var rot := 0.0
			match style:
				"leaf": rot = age * 18.0                              # 잎날가르기: 돌며 날아간다
				"flash": rot = age * 6.0
				"pulse": sc *= 1.0 + 0.15 * sin(age * 30.0)             # 물결이 떨린다
				"bubble": sc *= 1.0 + 0.08 * sin(age * 20.0)
				"water", "hydro": rot = dir.angle() + PI / 2.0
				"rock": rot = age * 10.0                               # 바위가 구르며 날아간다
				"breath": sc *= 1.0 + 0.12 * sin(age * 36.0)
			var stretch := 1.6 if style in ["water", "hydro"] else 1.0
			_draw_projectile_transform(Vector2.ZERO, rot, Vector2(sc, sc * stretch))
			draw_texture(tex, -Vector2(tex.get_width(), tex.get_height()) / 2.0, spec[2])
			if spec.size() > 3:
				_draw_projectile_transform(Vector2.ZERO, rot, Vector2(sc * 0.5, sc * 0.5 * stretch))
				draw_texture(tex, -Vector2(tex.get_width(), tex.get_height()) / 2.0, spec[3])
			_draw_projectile_transform(Vector2.ZERO)
			return
	if style in ["flame", "dragon"] and Fx.sheet("g4_flame") != null:
		match style:
			"flame":
				_draw_flame(dir, Color(1.0, 0.62, 0.15), Color(1.0, 0.95, 0.6), 1.5)
			"dragon":
				_draw_flame(dir, Color(0.62, 0.38, 1.0), Color(0.55, 0.9, 1.0), 1.4)
		return
	match style:
		"ember", "flame":
			var big := style == "flame"
			var r := radius * (1.3 if big else 1.0) * scale_now()
			var flick := 1.0 + 0.2 * sin(age * 40.0)
			# 뒤로 흩어지는 불티
			for i in 3:
				var k := float(i + 1)
				var p := -dir * r * (1.6 * k) + side * sin(age * 30.0 + k) * 2.0
				draw_circle(p, maxf(1.0, r * 0.5 - k * 0.6), Color(1.0, 0.55, 0.15, 0.6 - k * 0.15))
			draw_circle(Vector2.ZERO, r * flick, Color("f85830"))
			draw_circle(-dir * r * 0.2, r * 0.6 * flick, Color("f8a040"))
			draw_circle(-dir * r * 0.3, r * 0.3, Color("f8e060"))
		"dragon":
			var flick := 1.0 + 0.25 * sin(age * 35.0)
			draw_circle(-dir * radius * 1.2, radius * 0.8, Color(0.55, 0.35, 0.95, 0.5))
			draw_circle(Vector2.ZERO, radius * flick, Color("a060f8"))
			draw_circle(Vector2.ZERO, radius * 0.5 * flick, Color("80e8f8"))
		"water":
			_draw_projectile_transform(Vector2.ZERO, dir.angle(), Vector2(1.6, 0.8))
			draw_circle(Vector2.ZERO, radius, Color("3878e8"))
			draw_circle(Vector2(-radius * 0.2, -radius * 0.3), radius * 0.4, Color("b8e0ff"))
			_draw_projectile_transform(Vector2.ZERO)
		"acid":
			var tex := Fx.sheet("g4_glow")
			if tex!=null:
				for layer in acid_layers():
					var size := Vector2.ONE*float(layer.size)
					draw_texture_rect(tex,Rect2(Vector2(layer.offset)-size*0.5,size),false,layer.color)
		"thread":
			for s in [-1.0, 1.0]:
				var a: Vector2 = -dir * 7.0 + side * s * 1.5
				var b: Vector2 = dir * 5.0 + side * s * (1.5 + sin(age * 25.0) * 1.5)
				draw_line(a, b, Color(0.97, 0.97, 0.97), 1.0)
		"spark":
			# 플래티넘 thunder_shock.spa 번개 두 장(세로 지그재그)을 번갈아, 진행 방향으로.
			var fraction := float(hit.get("clash_fraction", 1.0))
			var bolt := Fx.sheet("g4_bolt_a" if int(age * 20.0) % 2 == 0 else "g4_bolt_b")
			if bolt != null:
				_draw_projectile_transform(Vector2.ZERO, dir.angle() + PI / 2.0, Vector2(0.8, 0.8) * fraction)
				var next := Fx.sheet("g4_bolt_b" if int(age * 20.0) % 2 == 0 else "g4_bolt_a")
				var region := Rect2(Vector2.ZERO, bolt.get_size())
				var visual := SmoothSprite.between(bolt, region, region, fposmod(age*20.0, 1.0), next)
				draw_texture_rect_region(visual.tex, Rect2(Vector2(-16, -16), bolt.get_size()), visual.src, Color(1.0, 0.95, 0.4))
				draw_texture_rect_region(visual.tex, Rect2(Vector2(-16, -16), bolt.get_size()), visual.src, Color(1.0, 1.0, 0.8, 0.6))
				_draw_projectile_transform(Vector2.ZERO)
				return
			_draw_projectile_transform(Vector2.ZERO, 0.0, Vector2.ONE * fraction)
			var pts := PackedVector2Array()
			for i in 5:
				var t := float(i) / 4.0
				var zig := (1.0 if i % 2 == 0 else -1.0) * 3.0 * (1.0 if i > 0 and i < 4 else 0.0)
				pts.append(-dir * 8.0 + dir * 16.0 * t + side * zig + side * sin(age * 50.0 + i) * 0.5)
			draw_polyline(pts, Color("f8e030"), 2.0)
			draw_polyline(pts, Color.WHITE, 1.0)
		_:
			draw_line(-dir * radius * 2.2, Vector2.ZERO, Color(color, 0.45), radius * 1.2)
			draw_circle(Vector2.ZERO, radius, color.darkened(0.35))
			draw_circle(Vector2.ZERO, radius * 0.65, color.lightened(0.35))

# The extra droplets are cosmetic; all layers share one unchanged projectile hitbox.
func acid_layers() -> Array:
	var forward := vel.normalized()
	var side := forward.orthogonal()
	var layers: Array=[]
	for i in range(3,-1,-1):
		var wobble := sin(age*20.0+float(i)*1.7)
		layers.append({"offset":-forward*float(i)*radius*0.85+side*wobble*float(i)*0.65,"size":radius*(2.7 if i==0 else 1.2-float(i)*0.18)*(1.0+wobble*0.08),"color":Color(0.72,0.74,0.10,0.94 if i==0 else 0.72)})
	return layers

# A single damaging voice front with three soft visual bands, never extra hits.
func voice_layers() -> Array:
	var forward := vel.normalized()
	var side := forward.orthogonal()
	var layers: Array=[]
	for i in range(1,-1,-1):
		var shimmer := 1.0+sin(age*13.0+float(i))*0.05
		layers.append({"texture":"g4_ring_q","aimed":true,"offset":-forward*radius*float(i)*0.85,"size":radius*(3.4+float(i)*0.4)*shimmer,"stretch":0.55,"color":Color(1.0,0.58+float(i)*0.12,0.84,0.78-float(i)*0.16)})
	for i in 3:
		var drift := sin(age*10.0+float(i)*1.7)*radius*0.12
		layers.append({"texture":"kanto_sing_%d"%(1+i),"aimed":false,"offset":-forward*radius*(0.30+float(i)*0.35)+side*((float(i)-1.0)*radius*1.7+drift),"size":(8.5+float(i%2))*float(hit.get("clash_fraction",1.0)),"rot":sin(age*8.0+float(i))*0.12,"color":Color(1.0,0.78,0.91,0.94)})
	return layers

# One needle and a faint tapered wake; both are artwork on one collision body.
func needle_layers() -> Array:
	var forward := vel.normalized()
	return [
		{"texture":"g4_glow","offset":-forward*radius*1.9,"size":radius*0.95,"stretch":2.2,"color":Color(0.66,0.36,0.88,0.25)},
		{"texture":"poison_needle","offset":Vector2.ZERO,"size":radius*4.8,"stretch":1.0,"color":Color(0.96,0.83,1.0,0.98)}
	]

func layered_layers() -> Array:
	match style:
		"water":return water_layers()
		"pulse":return pulse_layers()
		"needle":return needle_layers()
		"voice":return voice_layers()
		"acid":return acid_layers()
	return []

# Five existing volley bodies overlap into a short coherent jet. Cosmetic only.
func water_layers() -> Array:
	var forward := vel.normalized()
	var launch := lerpf(0.65,1.0,smoothstep(0.0,0.06,age))
	return [
		{"texture":"g4_glow","offset":-forward*radius*1.3,"size":radius*1.25*launch,"stretch":3.2,"color":Color(0.15,0.67,0.96,0.70)},
		{"texture":"g4_glow","offset":Vector2.ZERO,"size":radius*2.2*launch,"stretch":1.6,"color":Color(0.25,0.83,1.0,0.90)},
		{"texture":"g4_glow","offset":forward*radius*0.2,"size":radius*0.75*launch,"stretch":2.2,"color":Color(0.83,0.98,1.0,0.90)}
	]

# SV still-image shape reference: a forward column of water rings.
# Four rings, their spacing and reveal time are real-time adaptations, not SV timings.
func pulse_layers() -> Array:
	var forward := vel.normalized()
	var traveled := maxf(0.0,range_full-range_left)
	var layers: Array=[]
	for i in range(3,-1,-1):
		var gap := radius*1.3*float(i)
		var visible_age := maxf(0.0,traveled-gap)/maxf(1.0,vel.length())
		var reveal := smoothstep(0.0,0.045,visible_age)
		var ripple := 1.0+sin(age*18.0-float(i)*1.1)*0.035
		layers.append({"texture":"g4_ring_q","offset":-forward*minf(traveled,gap),"size":radius*(2.4+float(i)*0.7)*ripple,"stretch":0.48,"rot":sin(age*11.0+float(i))*0.025,
			"color":Color(0.42+float(i)*0.06,0.90+float(i)*0.02,1.0,(0.94-float(i)*0.10)*reveal)})
	return layers

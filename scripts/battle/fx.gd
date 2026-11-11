class_name Fx
extends Node2D
const PickupTrail = preload("res://scripts/view/pickup_trail.gd")

# 판정 없는 그림 효과. 수명이 끝나면 World 가 치운다.
#   sprite     플래티넘 파티클 텍스처(assets/fx/g4_*.png, 흰 마스크) 한 장을 color 로 물들여 그린다. dir·speed 로 날아가고
#              grow 배까지 커지며(작아지려면 <1) spin 으로 돌고 stretch 로 세로 늘림. 불꽃·연기·고리·불티·발톱 자국 전부 이걸로.
#   anim       세로로 쌓인 frames 장짜리 스프라이트(발톱 g4_claw_strike, 겁나는얼굴 g4_scary_face)를 수명 동안 차례로.
#   impact     타격 섬광(플래티넘 hit 별 g4_spark)
#   beam       실뿜기. font_size/1000 초 동안 dir 쪽으로 size 만큼 늘어난 뒤 뒤에서부터 걷힌다(플래티넘 string_shot.png 실 가닥)
#   text       떠오르는 숫자·문구
#   spawn      적이 나타날 자리 예고
#   line       돌진 예고선(지금은 안 씀)
#   circle     광역기 예고원
#   spark      이로치 반짝임 한 알(플래티넘 common_anims/shiny.s 의 파티클 그대로, World.shiny_fx 가 뿌린다).
#              pivot 둘레 ang 방향 rad0 에서 시작해 바깥으로 vel0(px/프레임) 로 나가며 프레임마다 drag 배로 느려지고 swirl 만큼 돈다.
#              크기·색·투명도는 원작 SPL 곡선(scale3 시작·중간·끝 / color → color_mid → color_end / alpha3 + alpha_in·alpha_out).
#   burst      진화·쓰러짐 섬광
#   rustle     풀숲이 흔들림(야생 포켓몬 출현). 원작 필드 효과 스프라이트(assets/fx/tall_grass.png)의 벌어지는 세 프레임을
#              지도 풀숲 위에 되풀이해 그린다(원작에서 풀숲에 들어설 때 나오는 그 동작)
#   rain       비바라기: 화면 크기만큼 빗줄기(rain_dance.spa 빗방울)가 비스듬히 내리고 화면이 조금 어두워진다(원작 Func_FadeBg). 플레이어를 따라간다.
#   tallgrass  풀숲을 지날 때의 풀 흔들림 — 원작 FRLG 필드 효과 FLDEFF_TALL_GRASS 그대로(field_effect_helpers.c).
#              포켓몬이 풀숲 칸에 들어서면 그 칸에 생겨 프레임 1→2→3→4 를 1/6초씩(원작 10프레임) 보이고, 그 뒤 프레임 0
#              (아래쪽 풀잎)으로 몸 아랫부분을 덮은 채 남는다. 포켓몬이 그 칸을 벗어나고 동작이 끝나면 사라진다.
#              노드 자리는 칸 바닥선 바로 위라 그 칸에 선 포켓몬보다 앞, 아래 칸의 포켓몬보다 뒤로 y 정렬된다.
#   fang       불꽃엄니: 플래티넘 fire_fang.spa 의 윗니·아랫니 텍스처가 맞은 몸 위아래에서 닫혀 물었다가 사라진다
#   swipe      커스텀 할퀴기(FxStyle): 반지름 size, 가운데 각 rot, 반각 arc_half 의 호를 도트처럼 또렷한 선(안티에일리어싱 없음)으로
#              처음 40% 동안 한쪽에서 다른 쪽으로 그어 나가고 나머지 동안 옅어진다. 바깥 2px 흰 선 + 안쪽 1px 옅은 선.
#   dashring   커스텀 연막(FxStyle): 떨어질 자리의 범위 고리. 점선 원(반지름 size × grow → size 로 조여 듦) + 아주 옅은 안쪽 칠.
#   light      HD-2D 느낌(Look) 전용: 그림 없이 점 조명 하나가 color 로 번쩍였다가 수명 동안 꺼진다(size = 반지름). flat 이면 아무것도 없음.
#   fangfire   불꽃엄니의 불: 같은 파일의 불덩이(puff) 가 부풀며 꺼진다. text="flame" 이면 불길(16×32)이 위로 솟는다

const SCARE_SNAP_START := 0.68
const SCARE_DURATION := 0.8
var scare_snap := false # Custom final-frame eye/mouth surprise.
var aimed_wave := false  # Orient a wave front along its actual projected travel.
var sound_fracture := false # Paired light/dark segments of a broken sound front.
var smoke_group := 0
var smoke_origin := Vector2.ZERO
var smoke_radius := 0.0
var smoke_alpha_gain := 1.0
var smoke_veil := false # Custom smoke gently dims bodies inside the visible cloud.
var landing_dust := false
var starter_table := false # Opening particles inherit the HD-2D starter tabletop height.
var water_surface := false
var grounded_flame := false # Ember landing flare: sprite base rests on the floor.
var kind := "text"
var lifetime := 0.6
var age := 0.0
var color := Color.WHITE
var text := ""
var dir := Vector2.RIGHT
var size := 30.0
var arc_deg := 90.0
var font_size := 8
var dead := false
var delay := 0.0                 # 이 시간이 지나야 그리기 시작(연타·두 번째 휘두름 등)
var speed := 0.0                 # sprite: dir 쪽으로 이 속도로 움직인다(px/s)
var grow := 1.0                  # sprite: 수명 끝의 크기 배율
var spin := 0.0                  # sprite: 회전 속도(rad/s)
var rot := 0.0                   # sprite·anim: 기본 회전(rad)
var fang_row := 0
var fang_close_time := 0.12
const WrapFx = preload("res://scripts/battle/wrap_fx.gd")
var bind_source: WeakRef
var caster_aura := false  # Source-bound aura ends safely when its caster is gone.
var body_impact := false  # Contact particle anchored to the rendered body, with normal depth testing.
var body_depth := 0.025 # Positive is before the body; negative is behind its cutout.
var ember_coat := false # Brief cosmetic flame envelope, independent of burn status.
var ember_phase := 0.0
const EmberArt = preload("res://scripts/view/ember_art.gd")
var claw_downstroke := false
const ClashArt = preload("res://scripts/view/clash_art.gd")
var clash_pair: Dictionary = {}
var clash_hit: Dictionary = {}
var cut_delay := 0.0
const CLAW_DRAW_TIME := 0.065
var stretch := 1.0               # sprite: 세로 배율(줄 모양 늘리기)
var fade_in := 0.0               # sprite: 이 비율(0~1)까지 서서히 나타남
var fade_out := 1.0              # sprite: 수명의 마지막 이 비율 동안만 옅어짐(1 이면 처음부터 서서히)
var frames := 1                  # anim: 프레임 수(세로)
var arc_half := 0.5              # swipe: 호의 반각(rad)
var arc_h := 0.0                 # sprite: 포물선 높이(px). 수명 동안 위로 솟았다 내려온다(씨앗 던지기)
var orbit_r := 0.0               # sprite+follow: 따라가는 몸 둘레를 이 반지름으로 돈다(세로는 절반으로 눌러 원근)
var orbit_speed := 0.0           # rad/s
var orbit_phase := 0.0
var seeking := false
var seek_target: Node2D:
	set(value):
		seek_target=value
		seeking=seeking or value!=null
var seek_from := Vector2.ZERO
var seek_offset := Vector2.ZERO
var seek_bend := 0.0
var follow: Node2D = null        # 있으면 매 틱 이 노드의 자리 + offset 으로 옮긴다(물린 몸이 밀려나도 송곳니가 따라감)
var pickup_item: LootItem = null
var pickup_height := -1.0
var pickup_trail: PickupTrail
var offset := Vector2.ZERO
# spark(원작 파티클 프레임 = 1/30초)
const SPL_FPS := 30.0
var pivot := Vector2.ZERO
var ang := 0.0
var rad0 := 0.0
var vel0 := 0.0
var drag := 1.0
var swirl := 0.0                 # rad/프레임
var scale3 := Vector3.ONE
var alpha3 := Vector3.ONE
var alpha_in := 0.0
var alpha_out := 1.0
var color_mid := Color.WHITE
var color_end := Color.WHITE
const GRASS_FX := "res://assets/fx/tall_grass.png"
# tallgrass
const GRASS_FRAME_T := 10.0 / 60.0   # 원작 ANIMCMD_FRAME(n, 10)
const FRAME1_TOP := 6                # 프레임 1 은 이 줄부터 그린다(아래 설명)
var tile := Vector2i.ZERO
var owner_mon: Node2D = null         # 이 풀을 밟은 포켓몬(follow 와 달리 따라 움직이지 않는다)
var settled := false                 # 처음부터 프레임 0(원작 SeekSpriteAnim(4): 이미 풀숲에 서 있던 경우)
static var _grass_tex: Texture2D = null

static func grass_cutout_texture() -> Texture2D:
	if _grass_tex != null: return _grass_tex
	if not ResourceLoader.exists(GRASS_FX): return null
	var image := (load(GRASS_FX) as Texture2D).get_image()
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x,y)
			var rgb := Vector3i(c.r8,c.g8,c.b8)
			if rgb in [Vector3i(115,205,164),Vector3i(65,180,139),Vector3i(164,230,197),Vector3i(24,164,106)]:
				image.set_pixel(x,y,Color.TRANSPARENT)
	_grass_tex = ImageTexture.create_from_image(image)
	return _grass_tex

# 플래티넘 연출 텍스처(tools/plat_fx.py, assets/fx): .spa 파티클의 흰 마스크(g4_*)와 2D 스프라이트(발톱·겁나는얼굴), 불꽃엄니 송곳니.
const SHEETS := {
	"metronome_star": "res://assets/fx/pixelfx/metronome_star.png",
	"pixelfx_pickup": "res://assets/fx/pixelfx/pickup.png",
	"pixelfx_scratch": "res://assets/fx/pixelfx/scratch.png",
	"pixelfx_ember": "res://assets/fx/pixelfx/ember.png",
	"pixelfx_smoke": "res://assets/fx/pixelfx/smoke.png",
	"field_cut_crescent": "res://assets/fx/field_cut_crescent.svg",
	"poison_needle": "res://assets/fx/poison_needle.svg",
	"fang_upper": "res://assets/fx/fang_upper.png", "fang_lower": "res://assets/fx/fang_lower.png",
	"ff_puff": "res://assets/fx/fire_fang_puff.png", "ff_flame": "res://assets/fx/fire_fang_flame.png",
	"g4_claw3": "res://assets/fx/g4_claw3.png", "g4_smoke": "res://assets/fx/g4_smoke.png",
	"g4_smoke_blob": "res://assets/fx/g4_smoke_blob.png", "g4_smoke_ring": "res://assets/fx/g4_smoke_ring.png",
	"g4_spark": "res://assets/fx/g4_spark.png", "g4_streak": "res://assets/fx/g4_streak.png",
	"g4_fire_puff": "res://assets/fx/g4_fire_puff.png", "g4_flame": "res://assets/fx/g4_flame.png",
	"g4_glow": "res://assets/fx/g4_glow.png", "g4_ring": "res://assets/fx/g4_ring.png",
	"g4_claw_strike": "res://assets/fx/g4_claw_strike.png", "g4_scary_face": "res://assets/fx/g4_scary_face.png",
	# 상록숲 적 기술(tackle·string_shot·harden·poison_sting·fury_attack·thunder_shock)
	"g4_star64": "res://assets/fx/g4_star64.png", "g4_bubble": "res://assets/fx/g4_bubble.png", "g4_needle": "res://assets/fx/g4_needle.png",
	"g4_bolt_a": "res://assets/fx/g4_bolt_a.png", "g4_bolt_b": "res://assets/fx/g4_bolt_b.png", "g4_horn": "res://assets/fx/g4_horn.png",
	"g4_hitburst": "res://assets/fx/g4_hitburst.png", "g4_thread": "res://assets/fx/g4_thread.png",
	"g4_shiny": "res://assets/fx/g4_shiny.png"}
static var _sheets := {}

static func sheet(name: String) -> Texture2D:
	if name == "ember_flame": return EmberArt.texture(0.0)
	if not _sheets.has(name):
		var path: String = SHEETS.get(name, "res://assets/fx/%s.png" % name)   # 표에 없으면 assets/fx/<이름>.png(tools/plat_fx.py 가 뽑은 것)
		_sheets[name] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _sheets[name]

var _light: PointLight2D = null

func sprite_texture() -> Texture2D:
	return EmberArt.texture(maxf(0.0,age-delay),ember_phase) if text=="ember_flame" else sheet(text)

# Bounded visual coverage, independent of accuracy debuff and combat duration.
func fang_close_progress() -> float:
	return clampf((age-fang_close_time*0.6)/maxf(0.001,fang_close_time*0.4),0.0,1.0)

# Shared by flat and 3D sprite renderers. This affects artwork only.
func sprite_scale_at(t: float) -> float:
	if ember_coat:
		return lerpf(0.65,1.0,smoothstep(0.0,0.18,t))*lerpf(1.0,grow,smoothstep(0.50,1.0,t))
	return lerpf(1.0,grow,t)

# Reveal a downward stroke with a stationary upper endpoint. These geometry
# helpers are shared by flat and HD-2D renderers and do not affect hit timing.
func claw_progress() -> float:
	var progress := clampf((age - delay) / CLAW_DRAW_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - progress, 2.0)

func sprite_stretch_at() -> float:
	return stretch * claw_progress() if claw_downstroke else stretch

func sprite_draw_offset(texture_aspect: float, scale_factor: float) -> Vector2:
	if not claw_downstroke: return Vector2.ZERO
	var full_height := size * texture_aspect * scale_factor * stretch
	return Vector2(0, (claw_progress() - 1.0) * full_height * 0.5).rotated(rot)

func anim_frame_at(t: float) -> int:
	if scare_snap:
		if t < 0.4: return 0
		if t < 0.55: return 1
		if t < SCARE_SNAP_START: return 2
		return 3
	return clampi(int(t*frames),0,frames-1)

func anim_visual(t: float) -> Dictionary:
	var tex := sheet(text)
	if tex == null: return {"tex": null, "src": Rect2()}
	var frame := anim_frame_at(t)
	var progress := fposmod(clampf(t, 0.0, 1.0) * frames, 1.0)
	var next := mini(frame + 1, frames - 1)
	if scare_snap:
		# Keep the authored instant of the final surprise/impact.
		if frame == 0: progress = clampf(t / 0.4, 0.0, 1.0)
		elif frame == 1: progress = clampf((t - 0.4) / 0.15, 0.0, 1.0)
		else: next = frame
	return SmoothSprite.vertical(tex, Vector2(tex.get_width(), tex.get_height() / maxi(1, frames)), frame, next, progress)

func grass_visual() -> Dictionary:
	var tex := grass_cutout_texture()
	if kind == "tallgrass":
		var sequence := [1, 2, 3, 4, 0]
		var step := 4 if settled else mini(int(age / GRASS_FRAME_T), 4)
		return SmoothSprite.vertical(tex, Vector2(16, 16), sequence[step], sequence[mini(step + 1, 4)], fposmod(age / GRASS_FRAME_T, 1.0), GRASS_FX)
	var step := int(age * 10.0) % 3
	return SmoothSprite.vertical(tex, Vector2(16, 16), 2 + step, 2 + ((step + 1) % 3), fposmod(age * 10.0, 1.0), GRASS_FX)

func anim_scale_at(t: float) -> float:
	if not scare_snap: return 1.0
	# Anticipation stays small; only the last open-eyed frame lunges forward.
	return lerpf(0.85,1.55,smoothstep(SCARE_SNAP_START,0.76,t))

func anim_alpha_at(t: float) -> float:
	if scare_snap:
		return color.a*clampf(t/0.06,0.0,1.0)*clampf((1.0-t)/0.13,0.0,1.0)
	return color.a*smoke_alpha_gain*(1.0 if t<0.75 else (1.0-t)*4.0)

func smoke_cover(at: Vector2) -> float:
	if not smoke_veil or dead or age <= delay or age >= lifetime: return 0.0
	var t := clampf((age-delay)/maxf(0.001,lifetime-delay),0.0,1.0)
	var alpha := color.a*minf(t/maxf(fade_in,0.001),1.0)*minf((1.0-t)/maxf(fade_out,0.001),1.0)
	var radius := size*lerpf(1.0,grow,t)*0.7
	return alpha*(1.0-smoothstep(radius*0.25,radius,at.distance_to(position)))

func binding_live() -> bool:
	if get_meta("story_silk",false):
		return is_instance_valid(follow) and follow.get_meta("silk_bound",false)
	return is_instance_valid(follow) and follow is Mon and not follow.dead and follow.bind_t>0.0 and bind_source!=null and is_instance_valid(bind_source.get_ref()) and not bind_source.get_ref().dead and follow.bind_by==bind_source.get_ref()

func binding_ribbon() -> Array:
	if not binding_live():return []
	if get_meta("story_silk",false):
		var bands:=WrapFx.ribbon(maxf(age,0.31),follow.radius,3.0,0.7)
		for band in bands:
			band.color=Color(0.93,0.96,0.91,band.color.a)
			band.width=maxf(1.0,float(band.width)*0.55)
		return bands
	return WrapFx.ribbon(age,follow.radius,follow.bind_t,follow.bind_acc)

func step(dt: float) -> void:
	if kind=="pickup_trail":
		if pickup_trail==null: pickup_trail=PickupTrail.new()
		pickup_trail.advance(dt,pickup_item if is_instance_valid(pickup_item) else null)
	if is_instance_valid(pickup_item):
		position=pickup_item.draw_at
		pickup_height=pickup_item.height
	if caster_aura and (not is_instance_valid(follow) or (follow is Mon and follow.dead)):
		dead=true
		return
	if kind=="wrap" and not binding_live():
		dead=true
		return
	if kind == "light":
		if _light == null:
			_light = Look.make_light(color, color.a * 1.6, size)
			add_child(_light)
		_light.visible = Look.hd2d() and age >= delay
		_light.energy = color.a * 1.6 * maxf(0.45, Look.light_gain()) * (1.0 - clampf((age - delay) / maxf(0.001, lifetime - delay), 0.0, 1.0))
	age += dt
	if follow != null and is_instance_valid(follow):
		position = follow.position + offset
		if orbit_r > 0.0:
			var a := orbit_phase + orbit_speed * age
			position += Vector2(cos(a) * orbit_r, sin(a) * orbit_r * 0.5)
		if kind == "sprite" and speed != 0.0:
			position += dir * speed * maxf(0.0, age - delay)   # 따라가면서 솟기(불꽃세례 불꽃이 맞은 몸에서 피어오름)
	if kind == "tallgrass":
		# 원작 UpdateTallGrassFieldEffect: 밟은 쪽이 칸을 벗어났고(지금 칸·직전 칸 둘 다 아님) 동작이 끝났으면 멈춤.
		# 여기선 걸음이 칸 단위가 아니라서 '발 원이 그 칸에 걸쳐 있음'을 지금 칸·직전 칸으로 본다.
		var on := false
		if owner_mon != null and is_instance_valid(owner_mon) and not owner_mon.dead:
			var r := Rect2(Vector2(tile) * Arena.TILE, Vector2(Arena.TILE, Arena.TILE)).grow(owner_mon.radius * 0.5)
			on = r.has_point(owner_mon.position + Vector2(0, owner_mon.feet_offset()))
		if not on and (settled or age >= GRASS_FRAME_T * 5.0):
			dead = true
		return
	if kind == "spark":
		# 원작은 전투라 포켓몬이 서 있다. 여기선 움직이므로 중심(pivot)이 몸을 따라간다(follow + offset).
		if follow != null and is_instance_valid(follow):
			pivot = follow.position + offset
		position = spark_pos(maxf(0.0, age - delay) * SPL_FPS)
	if kind == "text":
		position.y -= 22.0 * dt
	elif kind == "sprite" and speed != 0.0 and age >= delay:
		var next := position + dir * speed * dt
		if sound_fracture and Arena.blocks(next, 0.0):
			dead = true
			return
		if grounded_flame and Arena.blocks(next, 0.0):
			speed = 0.0
		else:
			position = next
	if smoke_veil and age >= delay:
		# Cross-flow breaks the radial puff pattern without moving gameplay bounds.
		position += dir.orthogonal()*sin((age-delay)*9.0+rot*13.0)*speed*0.38*dt
	if seeking:
		if not is_instance_valid(seek_target) or bool(seek_target.get("dead")):
			dead=true
			return
		var t := clampf((age-delay)/maxf(0.001,lifetime-delay),0.0,1.0)
		var destination := seek_target.position+seek_offset
		var side := (destination-seek_from).normalized().orthogonal()
		position=seek_from.lerp(destination,smoothstep(0.0,1.0,t))+side*sin(PI*t)*seek_bend

	if age >= lifetime and kind!="wrap":
		dead = true

# spark 의 n 프레임 뒤 자리. 속도가 프레임마다 drag 배 → 간 거리는 등비급수.
func spark_pos(n: float) -> Vector2:
	var dist := rad0 + (vel0 * (1.0 - pow(drag, n)) / (1.0 - drag) if drag < 1.0 else vel0 * n)
	var a := ang + swirl * n
	return pivot + Vector2(cos(a), sin(a)) * dist

# SPL 곡선: 시작 → (in 까지) 중간 → (out 부터) 끝. in·out 은 수명 비율.
static func _curve3(v: Vector3, t: float, t_in: float, t_out: float) -> float:
	if t < t_in:
		return lerpf(v.x, v.y, t / maxf(0.001, t_in))
	if t > t_out:
		return lerpf(v.y, v.z, (t - t_out) / maxf(0.001, 1.0 - t_out))
	return v.y

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if age < delay:
		return
	var t := clampf(age / lifetime, 0.0, 1.0)
	if delay > 0.0:
		t = clampf((age - delay) / maxf(0.001, lifetime - delay), 0.0, 1.0)
	match kind:
		"ball_release":
			if not Look.view3d: BallRelease.draw_flat(self)
		"forward_cut", "clash_chip":
			if not Look.view3d and not dead: ClashArt.draw_flat(self)
		"flare_coat":
			if not Look.view3d:
				var frame:=clampi(floori(age*30),0,14)
				draw_set_transform(Vector2.ZERO,dir.angle(),Vector2.ONE*.77)
				draw_texture_rect_region(sheet("cast_flare_blitz"),Rect2(-73,-43,116,86),Rect2((frame%4)*116,(frame/4)*86,116,86))
		"pickup_trail":
			if pickup_trail!=null: pickup_trail.draw_flat(self)
		"wrap":
			for band in binding_ribbon():
				if not band.front:continue
				var a: Vector3=band.a
				var b: Vector3=band.b
				var start := Vector2(a.x,-a.y)
				var end := Vector2(b.x,-b.y)
				var delta := end-start
				var width: float=band.width
				draw_set_transform((start+end)*0.5,delta.angle())
				draw_texture_rect_region(sheet("kanto_wrap_soft"),Rect2(-Vector2(delta.length()+width*0.5,width)*0.5,Vector2(delta.length()+width*0.5,width)),Rect2(12.8,0,6.4,32),band.color)
				draw_set_transform(Vector2.ZERO)
		"beam":
			# 앞으로 쭉 뻗은 뒤, 뒤(쏜 쪽)에서부터 앞으로 걷힌다(사용자 결정) — 흐려지지 않는다.
			var grow_t := maxf(0.05, font_size / 1000.0)
			var reach := size * clampf(age / grow_t, 0.0, 1.0)
			var retract_t := 0.3
			var k0 := clampf((age - (lifetime - retract_t)) / retract_t, 0.0, 1.0)   # 걷힌 비율
			var from := size * k0
			if from >= reach:
				return
			var side := Vector2(-dir.y, dir.x)
			var thread := sheet("g4_thread")
			if thread != null:
				# 플래티넘 moves/string_shot.png: 휘어진 실 가닥 세 줄을 뻗은 길이만큼 늘려 그린다(걷힌 앞부분은 잘라냄).
				var full := size
				for k in 3:
					var row: int = [0, 3, 6][k]
					var off := side * float(k - 1) * 2.5
					var sx0 := from / full * 64.0
					var sx1 := reach / full * 64.0
					if sx1 - sx0 < 1.0:
						continue
					draw_set_transform(off, dir.angle(), Vector2(full / 64.0, 1.0))
					draw_texture_rect_region(thread, Rect2(sx0, -4, sx1 - sx0, 8), Rect2(sx0, row * 8, sx1 - sx0, 8))
					draw_set_transform(Vector2.ZERO)
				return
			# 하얀 실 두 가닥이 살짝 꼬이며 뻗는다(그림이 없을 때).
			var pts_a := PackedVector2Array()
			var pts_b := PackedVector2Array()
			var n := maxi(2, int((reach - from) / 6.0))
			for i in n + 1:
				var d := from + (reach - from) * float(i) / float(n)
				var wig := sin(d / size * 14.0 + age * 20.0) * 1.5
				pts_a.append(dir * d + side * wig)
				pts_b.append(dir * d - side * wig)
			draw_polyline(pts_a, Color(0.95, 0.95, 0.95), 1.5)
			draw_polyline(pts_b, Color(0.85, 0.85, 0.9), 1.0)
		"fang_directional":
			var ratio := ClashArt.residual_scale(self)
			if ratio <= 0.0 or dead: return
			var anchor := ClashArt.residual_center_flat(self,Vector2.ZERO,ratio)
			draw_set_transform(anchor,0.0,Vector2.ONE*ratio)
			var atlas := sheet("fang_eight_hd2d")
			if atlas == null: return
			var cell := Vector2(atlas.get_width()/2.0, atlas.get_height()/8.0)
			var close := fang_close_progress()
			var gap := size * lerpf(0.22, 0.01, close*close)
			var sc := size / cell.x
			for jaw in 2:
				var shift := Vector2(0, gap * (-1.0 if jaw == 0 else 1.0))
				var rect := Rect2(shift - cell*sc*0.5, cell*sc)
				draw_texture_rect_region(atlas, rect, Rect2(Vector2(jaw*cell.x,fang_row*cell.y),cell), Color(1,1,1,minf(1.0,(1.0-t)*4.0)))
		"fang":
			# 윗니는 위에서, 아랫니는 아래에서 size 만큼 떨어진 채 나타나 0.12초 만에 닫히고(이가 맞물림), 잠깐 물고 있다가 옅어진다.
			var up := sheet("fang_upper")
			var low := sheet("fang_lower")
			if up == null or low == null:
				draw_arc(Vector2.ZERO, size * 0.6, 0.0, TAU, 12, Color(1, 1, 1, 1.0 - t), 2.0)
				return
			var close := clampf(age / 0.12, 0.0, 1.0)
			var gap := lerpf(size * 1.1, size * 0.08, close * close)
			var alpha := 1.0 if t < 0.65 else (1.0 - t) / 0.35
			var sc := size / 40.0            # 이빨 그림(64px) 이 물린 몸 지름의 1.6배쯤
			var mod := Color(1, 1, 1, alpha)
			draw_set_transform(Vector2(0, -gap), 0.0, Vector2(sc, sc))
			draw_texture(up, Vector2(-32, -32), mod)
			draw_set_transform(Vector2(0, gap), 0.0, Vector2(sc, sc))
			draw_texture(low, Vector2(-32, -32), mod)
			draw_set_transform(Vector2.ZERO)
		"fangfire":
			# 불덩이: 작게 나타나 부풀며 옅어진다. 불길(text=flame) 은 위로 솟으며 가늘어진다.
			var tex := sheet("ff_flame" if text == "flame" else "ff_puff")
			if tex == null:
				draw_circle(Vector2.ZERO, size * 0.4 * (1.0 - t), Color(1.0, 0.5, 0.1, 1.0 - t))
				return
			# 텍스처 자체가 반투명이라 두 번 겹쳐 그려 불빛을 진하게 한다.
			var mod := Color(1.0, 0.7, 0.3, 1.0 - t * t)
			if text == "flame":
				var sc := size / 32.0
				draw_set_transform(Vector2(0, -size * 0.8 * t), 0.0, Vector2(sc * (1.0 - t * 0.5), sc))
				draw_texture(tex, Vector2(-8, -24), mod)
				draw_texture(tex, Vector2(-8, -24), Color(1.0, 0.9, 0.5, mod.a * 0.8))
			else:
				var sc := size / 32.0 * (0.5 + 0.9 * t)
				draw_set_transform(dir * size * 0.5 * t, 0.0, Vector2(sc, sc))
				draw_texture(tex, Vector2(-16, -16), mod)
				draw_texture(tex, Vector2(-16, -16), Color(1.0, 0.85, 0.4, mod.a * 0.8))
			draw_set_transform(Vector2.ZERO)
		"impact":
			# 플래티넘 hit 별(g4_spark)이 커졌다 사라진다. 그림이 없으면 네 갈래 별.
			var s := size * (0.6 + 0.9 * t)
			var a := 1.0 - t
			var spark := sheet("g4_spark")
			if spark != null:
				draw_set_transform(Vector2.ZERO, t * 0.6, Vector2.ONE * (s / 8.0))
				draw_texture(spark, Vector2(-8, -8), Color(color, a))
				draw_set_transform(Vector2.ZERO)
				return
			for i in 4:
				var ang := i * PI / 2.0
				var v := Vector2.from_angle(ang) * s
				var w := Vector2.from_angle(ang + PI / 2.0) * s * 0.18
				draw_colored_polygon(PackedVector2Array([Vector2.ZERO + w, v, Vector2.ZERO - w]), Color(color, a))
			draw_circle(Vector2.ZERO, s * 0.25, Color(1, 1, 1, a))
		"sprite":
			var tex := sprite_texture()
			if tex == null:
				draw_circle(Vector2.ZERO, size * 0.4 * (1.0 - t), Color(color, 1.0 - t))
				return
			var k := sprite_scale_at(t)
			var sc := size / float(tex.get_width()) * k
			var a := color.a * smoke_alpha_gain * ((1.0 - t * t) if fade_out >= 1.0 else clampf((1.0 - t) / fade_out, 0.0, 1.0))
			if fade_in > 0.0:
				a *= clampf(t / fade_in, 0.0, 1.0)
			var lift := Vector2(0, -arc_h * 4.0 * t * (1.0 - t)) if arc_h > 0.0 else Vector2.ZERO
			draw_set_transform(lift + sprite_draw_offset(float(tex.get_height()) / tex.get_width(), k), rot + spin * age, Vector2(sc, sc * sprite_stretch_at() * (0.45 if water_surface else 1.0)))
			draw_texture(tex, -Vector2(tex.get_width(), tex.get_height()) / 2.0, Color(color.r, color.g, color.b, a))
			draw_set_transform(Vector2.ZERO)
		"spark":
			var tex := sheet("g4_shiny")
			if tex == null:
				return
			# 크기 곡선은 in·out 이 모두 1/2(가운데가 최대), 색은 0.2 → 0.5 → 0.8(SPLColorAnim in·peak·out).
			var k := _curve3(scale3, t, 0.5, 0.5)
			var a := _curve3(alpha3, t, alpha_in, alpha_out)
			var c := color
			if t < 0.2:
				c = color
			elif t < 0.5:
				c = color.lerp(color_mid, (t - 0.2) / 0.3)
			elif t < 0.8:
				c = color_mid.lerp(color_end, (t - 0.5) / 0.3)
			else:
				c = color_end
			var sc := size / float(tex.get_width()) * k
			draw_set_transform(Vector2.ZERO, rot + spin * (age - delay), Vector2(sc, sc))
			draw_texture(tex, -Vector2(tex.get_width(), tex.get_height()) / 2.0, Color(c.r, c.g, c.b, a))
			draw_set_transform(Vector2.ZERO)
		"anim":
			var tex := sheet(text)
			if tex == null:
				return
			var fw := tex.get_width()
			var fh := tex.get_height() / maxi(1, frames)
			var visual := anim_visual(t)
			var sc := size / float(fw) * anim_scale_at(t)
			var a := anim_alpha_at(t)
			draw_set_transform(Vector2(0,-pickup_height) if pickup_height>=0.0 else Vector2.ZERO, rot, Vector2(sc, sc))
			draw_texture_rect_region(visual.tex, Rect2(-fw / 2.0, -fh / 2.0, fw, fh), visual.src, Color(color.r, color.g, color.b, a))
			draw_set_transform(Vector2.ZERO)
		"text":
			# font_size 는 옛 단위(9 미만 = 작은 글자). 픽셀 글꼴은 두 가지 크기뿐이다.
			var c := Color(color, 1.0 - t * t)
			PixelUi.field_text(self, Vector2(0, -12), text, font_size < 9, c,
				Color(PixelUi.FIELD_OUTLINE, c.a), HORIZONTAL_ALIGNMENT_CENTER)
		"spawn":
			var pulse := 0.6 + 0.4 * sin(age * 18.0)
			draw_arc(Vector2.ZERO, size * (1.0 - t * 0.5), 0.0, TAU, 20, Color(color, pulse), 1.5)
			draw_circle(Vector2.ZERO, 2.0, Color(color, pulse))
		"line":
			var blink := 0.35 + 0.35 * sin(age * 30.0)
			# 짧은 선(졸개 돌진 예고)은 가늘게, 긴 선(보스)은 굵게.
			var base_w := clampf(size * 0.1, 4.0, 10.0)
			draw_line(Vector2.ZERO, dir * size, Color(1.0, 0.25, 0.2, blink), base_w + base_w * 0.8 * t)
		"swipe":
			var reveal := clampf(t / 0.4, 0.0, 1.0)
			var a_sw := 1.0 if t < 0.4 else clampf((1.0 - t) / 0.6, 0.0, 1.0)
			var a0 := rot - arc_half
			var a1 := a0 + 2.0 * arc_half * reveal
			var segs := maxi(4, int(24.0 * arc_half))
			draw_arc(Vector2.ZERO, size, a0, a1, segs, Color(color.r, color.g, color.b, color.a * a_sw), 2.0, false)
			draw_arc(Vector2.ZERO, size - 3.0, a0, a1, segs, Color(color.r, color.g, color.b, color.a * a_sw * 0.5), 1.0, false)
		"dashring":
			var r_now := size * lerpf(grow, 1.0, t)
			var a_dr := color.a * (clampf(t / fade_in, 0.0, 1.0) if fade_in > 0.0 else 1.0)
			draw_circle(Vector2.ZERO, r_now, Color(color.r, color.g, color.b, a_dr * 0.15))
			var dashes := 20
			for i in dashes:
				var b0 := TAU * float(i) / float(dashes) + age * 0.6
				draw_arc(Vector2.ZERO, r_now, b0, b0 + TAU / float(dashes) * 0.55, 3, Color(color.r, color.g, color.b, a_dr), 1.0, false)
		"circle":
			draw_circle(Vector2.ZERO, size * t, Color(1.0, 0.25, 0.2, 0.18))
			draw_arc(Vector2.ZERO, size, 0.0, TAU, 32, Color(1.0, 0.3, 0.25, 0.7), 1.5)
		"burst":
			draw_circle(Vector2.ZERO, size * (0.4 + t), Color(color, 0.8 * (1.0 - t)))
		"rain":
			var drop := sheet("g4_raindrop")
			var fade := clampf(age / 0.4, 0.0, 1.0) * clampf((lifetime - age) / 0.4, 0.0, 1.0)
			var half := Vector2(320, 190)
			draw_rect(Rect2(-half, half * 2.0), Color(0.1, 0.15, 0.35, 0.18 * fade))
			if drop == null:
				return
			for i in 70:
				var x := fposmod(float(i) * 97.3 + float(i * i) * 13.1, half.x * 2.0) - half.x
				var y := fposmod(float(i) * 53.7 + age * 420.0, half.y * 2.0) - half.y
				draw_set_transform(Vector2(x - (y + half.y) * 0.25, y), -0.25, Vector2(0.22, 0.32))
				draw_texture(drop, -Vector2(drop.get_width(), drop.get_height()) / 2.0, Color(0.8, 0.9, 1.0, 0.75 * fade))
			draw_set_transform(Vector2.ZERO)
		"tallgrass":
			if _grass_tex == null and ResourceLoader.exists(GRASS_FX):
				_grass_tex = grass_cutout_texture()
			if _grass_tex == null:
				return
			var frame: int = 0 if settled else [1, 2, 3, 4, 0][mini(int(age / GRASS_FRAME_T), 4)]
			# offset.y = 밟은 포켓몬의 발 높이: 노드는 정렬용으로 그만큼 위에 있고, 그림은 칸 자리에 그린다.
			# 원작은 풀 한 칸(16)이 주인공 키(32)의 절반이라 프레임 1(풀 전체, 바탕까지 칠해짐)이 아랫도리만 가린다. 여기선 칸(24)이
			# 파이리 키와 비슷해 통째로 가려지므로, 프레임 1 만 아래 10줄(칸의 5/8)을 그려 같은 비율을 맞춘다. 나머지 프레임은 원본 그대로.
			var top := FRAME1_TOP if frame == 1 else 0
			var k := Arena.TILE / 16.0
			var visual := grass_visual()
			var crop: Rect2 = visual.src
			crop.position.y += top
			crop.size.y -= top
			draw_texture_rect_region(visual.tex, Rect2(Vector2(-Arena.TILE / 2.0, 1.0 - Arena.TILE + offset.y + top * k), Vector2(Arena.TILE, (16 - top) * k)), crop)
		"rustle":
			if _grass_tex == null and ResourceLoader.exists(GRASS_FX):
				_grass_tex = grass_cutout_texture()
			if _grass_tex == null:
				draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 12, Color(0.6, 1.0, 0.5, 0.8), 1.5)
				return
			# 원작 프레임 2→3→4(풀이 벌어지며 잎이 튐)를 0.3초 주기로 되풀이. 지도 한 칸(24px) 크기로.
			var frame := 2 + int(fmod(age * 10.0, 3.0))
			var half := Arena.TILE / 2.0
			var visual := grass_visual()
			draw_texture_rect_region(visual.tex, Rect2(Vector2(-half, -half), Vector2(Arena.TILE, Arena.TILE)), visual.src)

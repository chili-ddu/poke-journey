class_name EvolutionScreen
extends Control

# 진화 화면 — 플래티넘 진화 장면(pret/pokeplatinum src/evolution.c) 그대로(사용자 요청 2026-10-30: 필드 번쩍임 대신 원작 화면).
# 원작 상태 순서와 프레임 수를 60fps 한 프레임씩(_frame) 옮겼다. Game._step_evolve 가 dt 를 넘겨 돌린다(스모크 도구도 같은 길).
#   필드가 검게 → 화면이 검정에서 밝아짐(팔레트 16→0, wait 1) → "어…? ○○의 상태가…!" → SEQ_SHINKA, 20프레임 →
#   두 모습이 하얗게(0→16, 5프레임마다) + 빛 알갱이(이미터 0), 40프레임 동안 위아래 검은 띠가 2px 씩 40px 까지(창 0) →
#   교대: 옛 모습은 줄고 새 모습은 커지기를 번갈아(배율 256 에서 한 프레임 8씩, 한 바퀴마다 두 배, 64 까지 — 점점 빨라짐) +
#   빛줄기·노란 빛·네 갈래 별(이미터 1·2·7·8·9·11). 이미터가 다 끝나면(약 200프레임) 색 구슬이 터지고(3~6·10) 배경이 하얗게(wait 2),
#   새 모습만 남는다 → 띠가 걷히고 8프레임 뒤 반짝임(12) + 배경·모습에 색이 돌아옴 → "축하합니다! …진화했다!" + SEQ_FANFA5
#   (팡파르가 끝날 때까지) → 40프레임 → 검게 → 필드가 밝아짐.
# 취소(원작: 교대 중 B): 하얗게(wait 0) → 옛 모습으로, 띠·빛을 거두고 SEQ_SHINKA 를 멈춤 → "어라…? ○○의 변화가 멈췄다!" → 검게.
# 울음소리·효과음(SE_DP_W025 등)은 이 게임에 아직 없어서 그 자리는 기다리기만 한다(CRY_HOLD).
# 배경은 알 부화 배경(tools/plat_evolution.py 가 구운 evo_bg.png), 모습은 상태창과 같은 플래티넘 정면 그림 80×80.
# 파티클은 원작 SPA(shinka_demo_particle.narc)의 이미터 값을 2D 로 옮긴 근사 — 아래 EMITTERS.

signal evolved                    # 원작 SET_POKEMON_VALUES: 이때 종족을 바꾼다(Game)
signal finished(did_evolve: bool)

const SCREEN := Vector2(256, 192)
const MON_CENTER := Vector2(128, 80)
const MON_SIZE := 80.0
const ONE := 256                  # MON_AFFINE_SCALE(1)
const BAND_TOP := 40              # 띠가 들어오는 끝(창 0 의 위 40 · 아래 120)
const MSG_FRAME := Rect2(0, 144, 248, 48)   # 글상자: 창 (2,19) 27×4 타일 + 둘레(좌우 2타일·위아래 1타일)
const MSG_TEXT := Vector2(16, 152)
const MSG_W := 216.0
const FIELD_FADE := 16            # 필드 ↔ 검정(원작 화면 전환 페이드 길이에 맞춤)
const WHAT_HOLD := 60             # "…의 상태가…!" 를 읽는 동안(원작: 글 + 옛 모습 울음소리)
const CRY_HOLD := 40              # 울음소리 자리
const STOP_HOLD := 60             # "…변화가 멈췄다!" 를 읽는 동안(원작: 글 뒤 20프레임)
const AFTER_CONGRATS := 40
const PX := 4096.0 / 172.0        # 파티클 1단위 = 23.8px(원작 이미터 위치 콜백이 8px 을 8 × 172 로 적는다)
const EMIT_AT := Vector2(128, 88) # 이미터 자리(화면 가운데에서 8px 위)
const WHITE := Color.WHITE
const BLACK := Color.BLACK

# 이미터(tools/plat_evolution.py --spa). 단위는 px · 프레임. size = 기본 배율 × PX(알갱이 한 변), scale = [시작, 가운데, 끝] 배율.
# 원작 3D 카메라의 정확한 환산은 옮기지 못해 크기는 캡처를 보며 맞춘 값이다(× 2 × PX 로는 빛이 실루엣을 다 덮음).
# shape: point(한 점) / shell(구 껍질 — 화면엔 원 안) / ring(원 둘레) / disc(원 안). dir: 속도 방향으로 늘인 그림(원작 directional billboard).
# col = [시작, 정점(기본색), 끝] (색 애니메이션이 없으면 셋 다 기본색).
const EMITTERS := [
	{"tex": "evo_glow", "shape": "shell", "r": 44.3, "count": 3, "every": 4, "delay": 0, "life": 41, "plife": 23, "vel": 0.0,
		"size": 14.2, "scale": [0.089, 0.476, 0.0], "col": [Color8(248, 248, 248), Color8(200, 152, 200), Color8(200, 152, 200)], "alpha": 1.0},
	{"tex": "evo_ray", "shape": "ring", "r": 5.3, "count": 1, "every": 2, "delay": 10, "life": 9, "plife": 126, "vel": 0.44, "dir": true,
		"size": 17.0, "scale": [0.506, 3.45, 4.253], "col": [Color8(248, 248, 200), Color8(248, 248, 200), Color8(248, 248, 224)], "alpha": 25.0 / 31.0},
	{"tex": "evo_ray", "shape": "disc", "r": 8.9, "count": 2, "every": 3, "delay": 30, "life": 15, "plife": 99, "vel": 0.44, "dir": true,
		"size": 19.9, "scale": [0.506, 3.241, 3.658], "col": [Color8(248, 248, 216), Color8(248, 248, 224), Color8(248, 248, 232)], "alpha": 24.0 / 31.0},
	{"tex": "evo_glow", "shape": "ring", "r": 12.4, "count": 1, "every": 1, "delay": 0, "life": 6, "plife": 19, "vel": 12.4, "dir": true,
		"size": 19.9, "scale": [1.0, 2.052, 3.152], "col": [Color8(248, 248, 152), Color8(248, 56, 104), Color8(248, 248, 248)], "alpha": 25.0 / 31.0},
	{"tex": "evo_glow", "shape": "ring", "r": 12.4, "count": 1, "every": 1, "delay": 0, "life": 6, "plife": 19, "vel": 12.4, "dir": true,
		"size": 19.9, "scale": [1.0, 2.052, 3.152], "col": [Color8(248, 248, 152), Color8(56, 248, 8), Color8(248, 248, 248)], "alpha": 25.0 / 31.0},
	{"tex": "evo_glow", "shape": "ring", "r": 12.4, "count": 1, "every": 1, "delay": 0, "life": 6, "plife": 19, "vel": 12.4, "dir": true,
		"size": 19.9, "scale": [1.0, 2.052, 3.152], "col": [Color8(248, 248, 152), Color8(8, 152, 248), Color8(248, 248, 248)], "alpha": 25.0 / 31.0},
	{"tex": "evo_glow", "shape": "ring", "r": 12.4, "count": 1, "every": 1, "delay": 0, "life": 6, "plife": 19, "vel": 12.4, "dir": true,
		"size": 19.9, "scale": [1.0, 2.052, 3.152], "col": [Color8(248, 248, 152), Color8(200, 8, 248), Color8(248, 248, 248)], "alpha": 25.0 / 31.0},
	{"tex": "evo_glow", "shape": "point", "r": 0.0, "count": 1, "every": 1, "delay": 0, "life": 1, "plife": 19, "vel": 0.0,
		"size": 34.0, "scale": [0.416, 1.606, 2.706], "col": [Color8(248, 248, 216), Color8(248, 200, 176), Color8(248, 248, 48)], "alpha": 23.0 / 31.0},
	{"tex": "evo_glow", "shape": "point", "r": 0.0, "count": 1, "every": 1, "delay": 12, "life": 1, "plife": 173, "vel": 0.0,
		"size": 34.0, "scale": [1.963, 2.706, 1.963], "col": [Color8(248, 248, 56), Color8(248, 248, 152), Color8(248, 248, 224)], "alpha": 25.0 / 31.0},
	{"tex": "evo_glow", "shape": "point", "r": 0.0, "count": 1, "every": 1, "delay": 158, "life": 1, "plife": 41, "vel": 0.0,
		"size": 31.1, "scale": [2.082, 3.45, 0.0], "col": [Color8(248, 248, 224), Color8(248, 248, 248), Color8(248, 248, 248)], "alpha": 25.0 / 31.0},
	{"tex": "evo_ring_a", "anim": ["evo_ring_a", "evo_ring_a", "evo_ring_b", "evo_ring_b", "evo_ring_b"], "shape": "point", "r": 0.0,
		"count": 1, "every": 1, "delay": 0, "life": 1, "plife": 41, "vel": 0.0,
		"size": 31.1, "scale": [0.416, 2.706, 3.45], "col": [Color8(248, 248, 56), Color8(248, 248, 192), Color8(248, 248, 216)], "alpha": 25.0 / 31.0},
	{"tex": "evo_star", "shape": "point", "r": 0.0, "count": 1, "every": 1, "delay": 18, "life": 141, "plife": 32, "vel": 2.66,
		"size": 17.0, "scale": [1.0, 0.684, 0.387], "col": [Color8(248, 248, 248), Color8(248, 248, 248), Color8(248, 248, 248)], "alpha": 1.0},
	{"tex": "evo_glow", "shape": "shell", "r": 138.0, "at": Vector2(0, -37), "count": 12, "every": 3, "delay": 0, "life": 13, "plife": 59, "vel": 0.0,
		"size": 19.9, "scale": [2.379, 1.13, 0.0], "col": [Color8(248, 248, 248), Color8(248, 248, 248), Color8(248, 248, 248)], "alpha": 1.0},
]
const START_FX := [0]                          # START_FADE
const ALTERNATE_FX := [1, 2, 7, 8, 9, 11]      # CLAMP_IN 끝
const BURST_FX := [3, 4, 5, 6, 10]             # 교대 끝
const SPARKLE_FX := [12]                       # CLAMP_OUT

var mon: Player
var from_id := ""
var to_id := ""
var from_name := ""
var phase := ""                    # 비면 닫힘
var did_evolve := false
var text := ""
var delay := 0
var field_t := 0                   # 필드 ↔ 검정 프레임
var top := 0                       # 창 0 위·아래(원작 windowTop / windowBottom)
var bottom := 160
var scale_old := ONE
var scale_new := 0
var show_new := true
var shrink := 0                    # 원작 shrinkAndGrowState(0 = 멈춤, 짝수 = 옛 모습이 줄어듦, 홀수 = 커짐)
var shrink_delta := 8
# 팔레트 페이드(PaletteData_StartFade): 배경·바탕(그리고 msg 면 글상자까지)을 color 쪽으로 level/16.
var pal := {}
var pal_level := 16
var pal_color := BLACK
var msg_level := 16
var msg_color := BLACK
# 두 모습의 페이드(PokemonSprite_StartFade): 한 단계씩, delay+1 프레임마다.
var mfade := {}
var mon_level := 16
var mon_color := BLACK
var emitters: Array = []           # {i, age, done}
var particles: Array = []          # {e, pos, vel, age}
var _acc := 0.0
var _cancel := false
var _rng := RandomNumberGenerator.new()
var _band: Control
var _mons: Control
var _fx: Control
var _top_layer: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_band = Control.new()
	_band.clip_contents = true
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	_mons = Control.new()
	_mons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec4 fade_color : source_color = vec4(1.0);\nuniform float amount = 0.0;\n" \
		+ "void fragment() { vec4 c = texture(TEXTURE, UV); COLOR = vec4(mix(c.rgb, fade_color.rgb, amount), c.a); }\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_mons.material = mat
	_mons.draw.connect(_draw_mons)
	# 빛(파티클)은 모습 뒤에: 원작 3D 층의 앞뒤를 그대로 옮기지 못해, 교대하는 흰 실루엣이 빛에 묻히지 않게 뒤에 둔다.
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	_band.add_child(_fx)
	_band.add_child(_mons)
	_top_layer = Control.new()
	_top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_layer.draw.connect(_draw_top)
	add_child(_top_layer)

# 진화를 시작한다. 필드가 검게 바뀌는 데서부터.
func open(p: Player, target: String) -> void:
	mon = p
	from_id = p.species_id
	to_id = target
	from_name = p.display_name()
	_rng.seed = 4                  # 캡처·시험이 늘 같은 그림이 되게
	phase = "field_out"
	did_evolve = false
	text = ""
	field_t = 0
	top = 0
	bottom = 160
	scale_old = ONE
	scale_new = 0
	show_new = true
	shrink = 0
	pal = {}
	pal_level = 16
	pal_color = BLACK
	msg_level = 16
	msg_color = BLACK
	mfade = {}
	mon_level = 16
	mon_color = BLACK
	emitters.clear()
	particles.clear()
	_acc = 0.0
	_cancel = false
	visible = true
	Bgm.stop()
	_sync()

func close() -> void:
	visible = false
	phase = ""

func is_open() -> bool:
	return phase != ""

# 원작은 교대(ANIMATION_ALTERNATE_POKEMON) 중 B 를 누른 프레임에만 받는다.
func request_cancel() -> void:
	if phase == "alternate":
		_cancel = true

func can_cancel() -> bool:
	return phase == "alternate"

func origin() -> Vector2:
	return ((size - SCREEN) / 2.0).floor()

func step(dt: float) -> void:
	if phase == "":
		return
	_acc += dt * 60.0
	while _acc >= 1.0 and phase != "":
		_acc -= 1.0
		_frame()
	_sync()

# ── 원작 Evolution_Main 한 프레임 ──

func _frame() -> void:
	_shrink_and_grow()
	if _cancel:
		_cancel = false
		if phase == "alternate":
			_pal_start(0, 16, 0, WHITE, false)
			phase = "cancel"
	match phase:
		"field_out":
			field_t += 1
			if field_t >= FIELD_FADE:
				_pal_start(16, 0, 1, BLACK, true)       # Evolution_Begin
				_mon_fade(16, 0, 0, BLACK)
				delay = 2
				phase = "start_delay"
		"start_delay":
			delay -= 1
			if delay == 0:
				phase = "print_what"
		"print_what":
			if pal.is_empty():
				text = Lang.t("evolving", [from_name])
				delay = WHAT_HOLD
				phase = "wait_what"
		"wait_what":
			delay -= 1
			if delay == 0:
				Bgm.play(Bgm.EVOLVING)
				delay = 20
				phase = "start_fade"
		"start_fade":
			delay -= 1
			if delay == 0:
				_emit(START_FX)
				_mon_fade(0, 16, 4, WHITE)
				delay = 40
				phase = "clamp_in"
		"clamp_in":
			if top < BAND_TOP:
				top += 2
				bottom -= 2
			delay -= 1
			if delay == 0:
				_emit(ALTERNATE_FX)
				shrink = 0x10
				shrink_delta = 8
				phase = "alternate"
		"alternate":
			if not _fx_active():
				_emit(BURST_FX)
				_pal_start(0, 16, 2, WHITE, false)
				scale_old = 0
				scale_new = ONE
				shrink = 0
				delay = 8
				phase = "clamp_out"
		"clamp_out":
			if top > 0:
				top -= 2
				bottom += 2
			if pal.is_empty():
				delay -= 1
				if delay == 0:
					_emit(SPARKLE_FX)
					_pal_start(16, 0, 4, WHITE, false)
					_mon_fade(16, 0, 3, WHITE)
					phase = "new_mon"
		"new_mon":
			if pal.is_empty() and not _fx_active():
				delay = CRY_HOLD
				phase = "new_cry"
		"new_cry":
			delay -= 1
			if delay == 0:
				did_evolve = true
				evolved.emit()
				text = Lang.t("evolved", [from_name, Lang.species_name(to_id)])
				Bgm.fanfare(Bgm.EVOLVED)
				delay = maxi(1, int(round(Bgm.length(Bgm.EVOLVED) * 60.0)))   # {WAIT 2}: 팡파르가 끝날 때까지
				phase = "congrats"
		"congrats":
			delay -= 1
			if delay == 0:
				delay = AFTER_CONGRATS
				phase = "congrats_hold"
		"congrats_hold":
			delay -= 1
			if delay == 0:
				_fade_out()
		"cancel":
			if pal.is_empty():
				scale_old = ONE
				scale_new = 0
				show_new = false
				_pal_start(16, 0, 0, WHITE, false)
				_mon_fade(16, 0, 0, WHITE)
				top = 0
				bottom = 160
				shrink = 0
				Bgm.stop(false)
				emitters.clear()
				particles.clear()
				phase = "cancel_mon"
		"cancel_mon":
			if pal.is_empty():
				delay = CRY_HOLD
				phase = "cancel_cry"
		"cancel_cry":
			delay -= 1
			if delay == 0:
				text = Lang.t("evolve_stopped", [from_name])
				delay = STOP_HOLD
				phase = "cancel_text"
		"cancel_text":
			delay -= 1
			if delay == 0:
				_fade_out()
		"end":
			if pal.is_empty():
				text = ""
				field_t = FIELD_FADE
				phase = "field_in"
		"field_in":
			field_t -= 1
			if field_t <= 0:
				phase = ""
				visible = false
				finished.emit(did_evolve)
				return
	_pal_tick()
	_mon_tick()
	_fx_tick()

func _fade_out() -> void:
	_pal_start(0, 16, 1, BLACK, true)
	_mon_fade(0, 16, 0, BLACK)
	phase = "end"

# 원작: 짝수면 옛 모습이 줄고 새 모습이 커지다 옛 모습이 0 이 되면 뒤집고, 홀수면 반대로 — 새 모습이 0 이 되면 한 바퀴, 배율 변화 두 배(64 까지).
func _shrink_and_grow() -> void:
	if shrink == 0:
		return
	if shrink & 1 == 0:
		scale_old -= shrink_delta
		scale_new += shrink_delta
		if scale_old == 0:
			shrink ^= 1
	else:
		scale_old += shrink_delta
		scale_new -= shrink_delta
		if scale_new == 0:
			shrink ^= 1
			if shrink_delta < 64:
				shrink_delta *= 2

# 팔레트 페이드: 2단계씩, wait+1 프레임마다(palette.c SetTimedFadeParams·UpdateFadeBlendStep). 끝 단계를 칠한 다음 프레임에 끝난다.
func _pal_start(from: int, to: int, wait: int, color: Color, with_msg: bool) -> void:
	pal = {"cur": from, "end": to, "wait": wait, "ws": wait, "color": color, "msg": with_msg}

func _pal_tick() -> void:
	if pal.is_empty():
		return
	if int(pal["ws"]) < int(pal["wait"]):
		pal["ws"] = int(pal["ws"]) + 1
		return
	pal["ws"] = 0
	pal_level = int(pal["cur"])
	pal_color = pal["color"]
	if pal["msg"]:
		msg_level = pal_level
		msg_color = pal_color
	if int(pal["cur"]) == int(pal["end"]):
		pal = {}
	else:
		pal["cur"] = int(move_toward(float(pal["cur"]), float(pal["end"]), 2.0))

func _mon_fade(from: int, to: int, d: int, color: Color) -> void:
	mfade = {"cur": from, "to": to, "delay": d, "count": 0, "color": color}

func _mon_tick() -> void:
	if mfade.is_empty():
		return
	if int(mfade["count"]) > 0:
		mfade["count"] = int(mfade["count"]) - 1
		return
	mfade["count"] = mfade["delay"]
	mon_level = int(mfade["cur"])
	mon_color = mfade["color"]
	if int(mfade["cur"]) == int(mfade["to"]):
		mfade = {}
	else:
		mfade["cur"] = int(mfade["cur"]) + (1 if int(mfade["to"]) > int(mfade["cur"]) else -1)

# ── 파티클 ──

func _emit(ids: Array) -> void:
	for i in ids:
		emitters.append({"i": i, "age": 0})

# 원작 sub_0207C8E0: 살아 있는 이미터가 하나라도 있나(이미터는 제 수명이 끝나고 알갱이가 다 사라질 때까지 산다).
func _fx_active() -> bool:
	return not emitters.is_empty()

func _fx_tick() -> void:
	for e in emitters:
		var d: Dictionary = EMITTERS[e["i"]]
		var a := int(e["age"]) - int(d["delay"])
		if a >= 0 and a < int(d["life"]) and a % int(d["every"]) == 0:
			for k in int(d["count"]):
				_spawn(int(e["i"]), d)
		e["age"] = int(e["age"]) + 1
	var alive: Array = []
	for p in particles:
		p["age"] = int(p["age"]) + 1
		p["pos"] = p["pos"] + p["vel"]
		if int(p["age"]) < int(EMITTERS[p["e"]]["plife"]):
			alive.append(p)
	particles = alive
	var live := {}
	for p in particles:
		live[p["e"]] = true
	var still: Array = []
	for e in emitters:
		var d: Dictionary = EMITTERS[e["i"]]
		if int(e["age"]) < int(d["delay"]) + int(d["life"]) or live.has(e["i"]):
			still.append(e)
	emitters = still

func _spawn(i: int, d: Dictionary) -> void:
	var c: Vector2 = EMIT_AT + d.get("at", Vector2.ZERO)
	var ang := _rng.randf() * TAU
	var dirv := Vector2.from_angle(ang)
	var off := Vector2.ZERO
	match String(d["shape"]):
		"ring":
			off = dirv * float(d["r"])
		"disc":
			off = dirv * float(d["r"]) * sqrt(_rng.randf())
		"shell":
			off = dirv * float(d["r"]) * sqrt(1.0 - pow(_rng.randf(), 2.0))   # 구 껍질을 위에서 본 모양
	var v := dirv * float(d["vel"])
	if String(d["shape"]) == "point" and float(d["vel"]) > 0.0:
		v *= _rng.randf_range(0.4, 1.0)            # 한 점에서 사방으로(깊이 방향 성분은 화면에서 짧아 보임)
	particles.append({"e": i, "pos": c + off, "vel": v, "age": 0})

static var _fx_cache := {}

static func _fx_tex(name: String) -> Texture2D:
	if not _fx_cache.has(name):
		var path := "res://assets/fx/%s.png" % name
		_fx_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _fx_cache[name]

static func _curve(v: Array, t: float):
	if t < 0.5:
		return lerp(v[0], v[1], t * 2.0)
	return lerp(v[1], v[2], (t - 0.5) * 2.0)

# ── 그리기 ──

func _sync() -> void:
	var o := origin()
	_band.position = o + Vector2(0, top)
	_band.size = Vector2(SCREEN.x, maxf(0.0, bottom - top))
	_mons.position = Vector2(0, -top)
	_mons.size = SCREEN
	_fx.position = Vector2(0, -top)
	_fx.size = SCREEN
	_top_layer.position = o
	_top_layer.size = SCREEN
	var showing := phase != "field_out" and phase != "field_in" and phase != ""
	_band.visible = showing
	_top_layer.visible = showing
	var mat := _mons.material as ShaderMaterial
	mat.set_shader_parameter("fade_color", mon_color)
	mat.set_shader_parameter("amount", mon_level / 16.0)
	queue_redraw()
	_mons.queue_redraw()
	_fx.queue_redraw()
	_top_layer.queue_redraw()

func _draw() -> void:
	if phase == "field_out" or phase == "field_in":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, float(field_t) / FIELD_FADE))
		return
	draw_rect(Rect2(Vector2.ZERO, size), BLACK)
	var o := origin()
	# 창 0 안쪽만 배경(BG3), 바깥은 바탕색(팔레트 0번 색 0 = 검정). 둘 다 팔레트 페이드를 받는다.
	var bg := PixelUi.ui_tex("plat/evo_bg")
	if bg != null and bottom > top:
		var r := Rect2(0, top, SCREEN.x, bottom - top)
		draw_texture_rect_region(bg, Rect2(o + r.position, r.size), r)
	if pal_level > 0:
		var c := pal_color
		c.a = pal_level / 16.0
		draw_rect(Rect2(o, SCREEN), c)

func _draw_mons() -> void:
	_draw_front(from_id, scale_old)
	if show_new:
		_draw_front(to_id, scale_new)

func _draw_front(species: String, s: int) -> void:
	if s <= 0:
		return
	var tex := PixelUi.ui_tex("plat/front/" + species + ("_shiny" if mon != null and mon.shiny else ""))
	if tex == null:
		return
	var k := s / float(ONE)
	_mons.draw_set_transform(MON_CENTER, 0.0, Vector2(k, k))
	_mons.draw_texture(tex, -Vector2(MON_SIZE, MON_SIZE) / 2.0)
	_mons.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_fx() -> void:
	for p in particles:
		var d: Dictionary = EMITTERS[p["e"]]
		var t := float(p["age"]) / float(d["plife"])
		var name := String(d["tex"])
		if d.has("anim"):
			var frames: Array = d["anim"]
			name = frames[mini(frames.size() - 1, int(t * frames.size()))]
		var tex := _fx_tex(name)
		if tex == null:
			continue
		var source_size := Vector2(tex.get_size())
		var visual := {"tex": tex, "src": Rect2(Vector2.ZERO, source_size)}
		if d.has("anim"):
			var sequence: Array = d["anim"]
			var index := mini(sequence.size()-1, int(t*sequence.size()))
			var next_tex := _fx_tex(sequence[mini(index+1, sequence.size()-1)])
			visual = SmoothSprite.between(tex, visual.src, Rect2(Vector2.ZERO, source_size), fposmod(t*sequence.size(), 1.0), next_tex)
		var sz := float(d["size"]) * float(_curve(d["scale"], t))
		if sz <= 0.0:
			continue
		var c: Color = _curve(d["col"], t)
		c.a = float(d["alpha"]) * clampf(t / 0.15, 0.0, 1.0) * clampf((1.0 - t) / 0.3, 0.0, 1.0)
		var pos: Vector2 = p["pos"]
		if d.get("dir", false) and (p["vel"] as Vector2).length() > 0.0:
			# 속도 방향으로 늘인 그림: 그림의 위(좁은 쪽)가 가운데를 향하게.
			var v: Vector2 = p["vel"]
			var tw := tex.get_width() * sz / tex.get_height()
			_fx.draw_set_transform(pos, v.angle() - PI / 2.0, Vector2.ONE)
			_fx.draw_texture_rect_region(visual.tex, Rect2(-tw / 2.0, -sz / 2.0, tw, sz), visual.src, c)
			_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_fx.draw_texture_rect_region(visual.tex, Rect2(pos - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), visual.src, c)

func _draw_top() -> void:
	# 글상자(BG1, 팔레트 10·11): 흰 페이드는 받지 않고 검정 페이드만 받는다.
	if not PixelUi.nine(_top_layer, "plat/msgbox", MSG_FRAME, 10):
		_top_layer.draw_rect(MSG_FRAME, PixelUi.PAPER)
	if text != "":
		PixelUi.paragraph(_top_layer, MSG_TEXT, text, MSG_W, 2, PixelUi.INK, PixelUi.INK_SHADOW)
	if msg_level > 0:
		var c := msg_color
		c.a = msg_level / 16.0
		_top_layer.draw_rect(MSG_FRAME, c)

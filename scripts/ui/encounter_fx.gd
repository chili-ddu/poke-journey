class_name EncounterFx
extends Control

# 트레이너 배틀 인카운트 연출(사용자 결정 2026-10-29: 원작처럼 컷신 뒤 경기장으로). 플래티넘 src/overlay005/encounter_effect_core.c 를
# 프레임 단위(60fps)로 옮겼다. 원작은 화면 창(window)·HBlank 로 화면을 자르는데, 여기선 연출 시작 순간의 화면을 찍어(snap) 잘라 그린다.
#   low  (EncounterEffect_Trainer_Grass_LowerLevel — 상대 첫 포켓몬이 내 포켓몬보다 레벨이 낮을 때)
#        화면이 검게 두 번 깜빡임(3프레임 어두워짐·3프레임 밝아짐 ×2) → 큰 몬스터볼이 한 바퀴 돌며 0.01 → 1배로 커짐(10프레임, 가속)
#        → 화면이 96px 띠로 갈라져 위는 왼쪽·아래는 오른쪽으로 밀려나고 몬스터볼도 위·아래 반쪽으로 갈라져 같이 나감(6프레임), 카메라는 다가감
#   high (_HigherLevel — 레벨이 같거나 높을 때)
#        하얗게 두 번 깜빡임 → 작은 몬스터볼 둘이 위(왼쪽으로)·아래(오른쪽으로) 줄에서 두 바퀴씩 반대로 돌며 화면을 가로지름(8프레임)
#        → 화면 위 반쪽은 오른쪽 아래 모서리부터, 아래 반쪽은 왼쪽 위 모서리부터 검게 먹힘(8프레임)
#   leader (EncounterEffect_GymLeader — 관장, 사용자 결정 2026-10-29: 플래티넘 구조에 파이어레드 웅 그림)
#        하얗게 한 번 깜빡임(6프레임) → 관장 띠가 톱니 가장자리(8줄마다 16px 지그재그)로 오른쪽에서 쓸려 들어옴(6프레임), 띠는 프레임마다 30px 흐름
#        → 10프레임 쉼 → VS 가 3프레임 간격으로 넷(테두리 VS 셋은 2배 → 1배로 6프레임, 마지막은 꽉 찬 VS) → 검은 실루엣 얼굴이 오른쪽(272)에서
#        214 로 미끄러져 옴(4프레임) → 10프레임 쉼 → 화면이 하얘졌다(3프레임) 돌아오며(3프레임) 얼굴에 색이 돌아오고 바탕은 어두워지고 이름이 뜸
#        → 26프레임 유지 → 하얗게 사라짐(15프레임)
# 끝나면 화면이 검다(leader 는 하얗다)(done). 좌표는 DS 화면(256×192) 기준을 뷰포트 크기로 늘린다. 그림은 tools/plat_encounter.py.

const FRAME := 1.0 / 60.0
const DS := Vector2(256, 192)
const FLASH_FRAMES := 12

# 관장 컷인 단계(프레임). 원작 상태 1~14 의 길이 그대로.
const L_FLASH := 6
const L_SWEEP := 6
const L_WAIT1 := 10
const L_VS := 16
const L_SLIDE := 4
const L_WAIT2 := 10
const L_WHITE := 3
const L_HOLD := 26
const L_FADE := 15
const BAND_Y := 42.0                # 띠(BG3)의 화면 y(원작 화면표 42~101)
const BAND_SCROLL := 30.0           # 프레임마다 띠가 흐르는 px
const MUG_Y := 66.0
const MUG_X0 := 272.0
const MUG_X1 := 214.0
const VS_POS := Vector2(72, 74)

var kind := "low"
var snap: Texture2D = null
var done := false
var leader_name := ""
var _f := 0.0                       # 지난 프레임 수
var _ball: Texture2D = null
var _ball_small: Texture2D = null
var _band: Texture2D = null
var _vs: Texture2D = null
var _vs_outline: Texture2D = null
var _mug: Texture2D = null

func setup(effect_kind: String, snapshot: Texture2D, opts: Dictionary = {}) -> void:
	kind = effect_kind
	snap = snapshot
	_ball = PixelUi.ui_tex("plat/enc_ball")
	_ball_small = PixelUi.ui_tex("plat/enc_ball_small")
	if kind == "leader":
		_band = PixelUi.ui_tex(String(opts.get("banner", "plat/enc_leader_banner_rock")))
		_vs = PixelUi.ui_tex("plat/enc_vs")
		_vs_outline = PixelUi.ui_tex("plat/enc_vs_outline")
		_mug = PixelUi.ui_tex(String(opts.get("mugshot", "")))
		leader_name = String(opts.get("name", ""))
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func total_frames() -> int:
	if kind == "leader":
		return L_FLASH + L_SWEEP + L_WAIT1 + L_VS + L_SLIDE + L_WAIT2 + L_WHITE * 2 + L_HOLD + L_FADE
	return FLASH_FRAMES + 16

func step(dt: float) -> void:
	if done:
		return
	_f += dt / FRAME
	if _f >= total_frames():
		done = true
	queue_redraw()

# 원작 QuadraticInterpolationTask: 처음 속도 rate(한 프레임 증가량)에서 가속해 n 프레임에 끝값. 0~1 비율로.
static func _quad(k: float, n: float, rate: float, span: float) -> float:
	var u := clampf(k / n, 0.0, 1.0)
	var r := clampf(rate * n / maxf(span, 0.001), 0.0, 1.0)
	return r * u + (1.0 - r) * u * u

func _draw() -> void:
	if kind == "leader":
		_draw_leader()
		return
	var vs := size
	var sc := Vector2(vs.x / DS.x, vs.y / DS.y)
	draw_rect(Rect2(Vector2.ZERO, vs), Color.BLACK)
	if _f < FLASH_FRAMES:
		_draw_snap(Rect2(Vector2.ZERO, vs), Vector2.ZERO, 1.0)
		# 깜빡임: 6프레임 주기로 0 → 1 → 0(3프레임씩). low 는 검게, high 는 하얗게.
		var k := fmod(_f, 6.0)
		var a := (k / 3.0) if k < 3.0 else (2.0 - k / 3.0)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, a) if kind == "low" else Color(1, 1, 1, a))
		return
	var f := _f - FLASH_FRAMES
	if kind == "low":
		if f < 10.0:
			_draw_snap(Rect2(Vector2.ZERO, vs), Vector2.ZERO, 1.0)
			var s := 0.01 + 0.99 * _quad(f, 10.0, 0.0, 1.0)
			_draw_ball(_ball, vs / 2.0, s * sc.y, TAU * f / 10.0, 0)
		else:
			var g := f - 10.0
			var x := 255.0 * _quad(g, 6.0, 10.0, 255.0) * sc.x
			var zoom := 1.0 + 0.12 * _quad(g, 6.0, 0.0, 1.0)
			var half := vs.y / 2.0
			_draw_snap(Rect2(Vector2(-x, 0), Vector2(vs.x, half)), Vector2.ZERO, zoom, true)
			_draw_snap(Rect2(Vector2(x, half), Vector2(vs.x, half)), Vector2(0, half), zoom, false)
			_draw_ball(_ball, vs / 2.0 - Vector2(x, 0), sc.y, 0.0, 1)
			_draw_ball(_ball, vs / 2.0 + Vector2(x, 0), sc.y, 0.0, 2)
	else:
		if f < 8.0:
			_draw_snap(Rect2(Vector2.ZERO, vs), Vector2.ZERO, 1.0)
			var v := lerpf(-192.0, 192.0, f / 8.0)
			var rot := TAU * 2.0 * f / 8.0
			_draw_ball(_ball_small, Vector2((128.0 - v) * sc.x, 64.0 * sc.y), sc.y, rot, 0)
			_draw_ball(_ball_small, Vector2((128.0 + v) * sc.x, 128.0 * sc.y), sc.y, -rot, 0)
		else:
			var g := f - 8.0
			var cx := 255.0 * _quad(g, 8.0, 1.0, 255.0)
			var cy := 96.0 * _quad(g, 8.0, 1.0, 96.0)
			var zoom := 1.0 + 0.12 * _quad(g, 8.0, 0.0, 1.0)
			# 위: x 0~255−cx, y 0~96−cy / 아래: x cx~255, y 96+cy~192 만 보인다(원작 창 0·1).
			var top := Rect2(Vector2.ZERO, Vector2((255.0 - cx) * sc.x, (96.0 - cy) * sc.y))
			var bot := Rect2(Vector2(cx * sc.x, (96.0 + cy) * sc.y), Vector2((255.0 - cx) * sc.x, (96.0 - cy) * sc.y))
			for r in [top, bot]:
				if r.size.x > 0.5 and r.size.y > 0.5:
					_draw_snap_clip(r, zoom)

# 찍어 둔 화면을 dst 에 그린다(src 는 같은 크기의 화면 영역, 가운데 기준 zoom 배). top_half/bottom 은 띠 하나만.
func _draw_snap(dst: Rect2, src_origin: Vector2, zoom: float, _top: bool = true) -> void:
	if snap == null:
		return
	var ts := Vector2(snap.get_size())
	var k := ts / size
	var src := Rect2(src_origin, dst.size)
	# 확대: 화면 가운데 기준으로 원본 영역을 줄인다.
	var c := size / 2.0
	var sp := c + (src.position - c) / zoom
	var ss := src.size / zoom
	draw_texture_rect_region(snap, dst, Rect2(sp * k, ss * k))

func _draw_snap_clip(r: Rect2, zoom: float) -> void:
	_draw_snap(r, r.position, zoom)

# 몬스터볼: part 0 = 전체, 1 = 위 반쪽, 2 = 아래 반쪽(원작 셀 0·1·2). size 는 원래 크기 × s.
func _draw_ball(tex: Texture2D, center: Vector2, s: float, rot: float, part: int) -> void:
	if tex == null:
		draw_circle(center, 32.0 * s, Color("e04040"))
		return
	var ts := Vector2(tex.get_size())
	var src := Rect2(Vector2.ZERO, ts)
	var off := -ts / 2.0
	if part == 1:
		src = Rect2(Vector2.ZERO, Vector2(ts.x, ts.y / 2.0))
	elif part == 2:
		src = Rect2(Vector2(0, ts.y / 2.0), Vector2(ts.x, ts.y / 2.0))
		off.y = 0.0
	draw_set_transform(center, rot, Vector2(s, s))
	draw_texture_rect_region(tex, Rect2(off, src.size), src)
	draw_set_transform(Vector2.ZERO)

# ── 관장 컷인(EncounterEffect_GymLeader) ──

func _draw_leader() -> void:
	var vs := size
	var sc := Vector2(vs.x / DS.x, vs.y / DS.y)
	var u := sc.y                                   # 스프라이트는 세로 배율로(찌그러지지 않게)
	var f := _f
	draw_rect(Rect2(Vector2.ZERO, vs), Color.BLACK)
	var t_sweep := float(L_FLASH)
	var t_vs := t_sweep + L_SWEEP + L_WAIT1
	var t_slide := t_vs + L_VS
	var t_white := t_slide + L_SLIDE + L_WAIT2
	var t_reveal := t_white + L_WHITE                # 하얘진 순간: 색이 돌아오고 바탕이 어두워지고 이름이 뜬다
	var t_fade := t_reveal + L_WHITE + L_HOLD
	var revealed := f >= t_reveal
	# 바탕(찍어 둔 필드). 드러난 뒤엔 원작 밝기 −14/16 로 어둡게.
	_draw_snap(Rect2(Vector2.ZERO, vs), Vector2.ZERO, 1.0)
	if revealed:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 14.0 / 16.0))
	# 띠: 오른쪽에서 톱니 가장자리로 쓸려 들어오고(원작 창 0 의 줄마다 시작 x = 남은 값 − 지그재그), 프레임마다 30px 흐른다.
	if f >= t_sweep and _band != null:
		var k := clampf((f - t_sweep) / float(L_SWEEP), 0.0, 1.0)
		var edge := 255.0 * (1.0 - k)
		var scroll := fmod((f - t_sweep) * BAND_SCROLL, 256.0)
		var bh := float(_band.get_height())
		for line in int(bh):
			var y := int(BAND_Y) + line
			var m := y % 8
			var zig := m * 16.0 / 8.0 if (y / 8) % 2 == 0 else 16.0 - m * 16.0 / 8.0
			var x0 := maxf(0.0, edge - zig) if k < 1.0 else 0.0
			_draw_band_line(line, x0, scroll, sc)
	# VS: 3프레임마다 하나씩, 테두리 VS 셋은 2배 → 1배(6프레임), 넷째는 꽉 찬 VS.
	if f >= t_vs and _vs != null:
		var g := f - t_vs
		for i in 4:
			var start := 3.0 * i
			if g < start:
				continue
			var s := 1.0 if i == 3 else lerpf(2.0, 1.0, clampf((g - start) / 6.0, 0.0, 1.0))
			var tex := _vs if i == 3 else _vs_outline
			_draw_center(tex, Vector2(VS_POS.x * sc.x, VS_POS.y * sc.y), s * u, Color.WHITE)
	# 얼굴: 검은 실루엣(원작 팔레트 14/16 검정)으로 미끄러져 와서, 하얘진 순간 원래 색.
	if f >= t_slide and _mug != null:
		var x := lerpf(MUG_X0, MUG_X1, clampf((f - t_slide) / float(L_SLIDE), 0.0, 1.0))
		var tint := Color.WHITE if revealed else Color(2.0 / 16.0, 2.0 / 16.0, 2.0 / 16.0)
		_draw_center(_mug, Vector2(x * sc.x, MUG_Y * sc.y), u, tint)
	# 이름(원작 창: 위에서 80px, 얼굴 왼쪽 아래 — 글자는 흰색에 짙은 그림자).
	if revealed and leader_name != "":
		# 원작 글자 크기 비율대로 띠와 같은 세로 배율로 키운다.
		draw_set_transform(Vector2((MUG_X1 - 92.0) * sc.x, 80.0 * sc.y), 0.0, Vector2(u, u))
		PixelUi.text(self, Vector2.ZERO, leader_name, false, Color.WHITE, Color8(74, 82, 82))
		draw_set_transform(Vector2.ZERO)
	# 하얘짐(마스터 밝기 0 → 16 → 0, 3프레임씩)과 첫 깜빡임, 끝의 하얀 페이드.
	var white := 0.0
	if f < L_FLASH:
		var h := f
		white = (h / 3.0) if h < 3.0 else (2.0 - h / 3.0)
	elif f >= t_white and f < t_reveal + L_WHITE:
		var h := f - t_white
		white = (h / 3.0) if h < 3.0 else (2.0 - h / 3.0)
	elif f >= t_fade:
		white = clampf((f - t_fade) / float(L_FADE), 0.0, 1.0)
	if white > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, clampf(white, 0.0, 1.0)))

# 띠 한 줄: 원본 256px 폭 띠를 화면 폭까지 되풀이해서(세로 배율로) 흐름만큼 밀어 그린다. x0(DS px)보다 왼쪽은 안 보인다(창).
func _draw_band_line(line: int, x0: float, scroll: float, sc: Vector2) -> void:
	var u := sc.y
	var bw := float(_band.get_width()) * u
	var y := (BAND_Y + line) * sc.y
	var clip := x0 * sc.x
	var x := -fmod(scroll * u, bw)
	while x < size.x:
		var a := maxf(x, clip)
		var b := minf(x + bw, size.x)
		if b > a:
			var src_x := (a - x) / u
			draw_texture_rect_region(_band, Rect2(a, y, b - a, u + 0.5), Rect2(src_x, line, (b - a) / u, 1))
		x += bw

func _draw_center(tex: Texture2D, center: Vector2, s: float, tint: Color) -> void:
	var ts := Vector2(tex.get_size()) * s
	draw_texture_rect(tex, Rect2((center - ts / 2.0).round(), ts), false, tint)

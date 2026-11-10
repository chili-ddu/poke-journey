class_name Hud
extends Control

# 전투 화면 위 정보. 노드를 쌓지 않고 _draw 로 한 번에 그린다 — 값이 매 프레임 바뀌는 것뿐이라. 읽기만 하고 상태는 바꾸지 않는다.
#
# 배치는 플래티넘(4세대) 전투 화면(docs/plan-gen4.md 3단계; 사용자가 보낸 한국어판 스크린샷 기준). 원본 그림은 assets/ui/plat/(tools/plat_ui.py).
#   왼쪽 위      상대 체력 상자 — healthbox_enemy.png(128×64 스프라이트, 상자 x 3..117 / y 12..44). 이름·Lv·HP 막대(흰 글자)
#   오른쪽 아래  내 체력 상자 — healthbox_player.png(상자 x 17..127 / y 11..52), 글상자 바로 위. 이름·Lv·HP 막대·HP 숫자("/" 는 그림)·EXP 바
#   왼쪽 아래    기술 버튼 세로 1열 — 시야를 가리지 않게 왼쪽 가장자리에 넷을 쌓는다(사용자 결정 2026-10-27). 버튼은 DS 아래 화면 '싸운다'
#                메뉴처럼 타입색 틀 안에 밝은 판: 위에 기술 이름(가운데), 아래에 타입 아이콘과 PP n/max. 원작 128×80 을 100×40 으로 줄였다.
#                1~4 로 고른 버튼엔 빨간 모서리 커서(cursor.png).
#   오른쪽 아래  대사 글상자 — 기본 대화창 틀(msgbox.png: 흰 테·갈색 띠, 9분할 여백 10)을 224×44 로 오른쪽 아래에(화면 폭으로 늘리지 않음 —
#                사용자: 상자 비율 작게). 내 체력 상자가 그 위. 어두운 글자. 대사가 있을 때만.
#   레벨업 창    시스템 창(sys_window.png, 흰 바탕 청회색 테)이 원작처럼 오른쪽, 글상자 위에 아랫변이 6px 살짝 겹치게(사용자 스크린샷).
#                내 체력 상자를 잠시 덮는다. 어두운 글자.
# 좌표는 DS px(PixelUi.UI_SCALE 1). UI 레이어는 Game.UI_RATIO(2/3)로 축소되어 그려지므로 HUD 가 보는 화면(size)은 뷰포트의 1.5배다.
# 화면 크기(ViewScale)는 바뀌므로 자리는 _layout() 이 매 프레임 계산한다.
# 체력 상자 글자 자리는 원작 스프라이트를 실측한 값(이름 줄 위 18, 숫자 줄 위 37 등).

# 상자 비율은 작게(사용자 결정 2026-10-27): 픽셀은 1:1 로 두고 여백·폭만 줄인다(비정수 축소는 번진다).
const BTN_W := 88.0                              # 판(틀 안쪽 −4) 80: 이름 12글자(72) / 타입 아이콘 32 + "35/35" 30
const BTN_H := 36.0                              # 판 28 = 이름 줄 + 타입·PP 줄(12px 간격). 한국어는 글자가 높아 줄 간격 14 → 38(_btn_h)
const BTN_GAP := 2.0
const STAT_W := 120.0                            # 레벨업 창: 작은 글꼴 6줄 × 12
const STAT_H := 84.0
const MSG_W := 224.0                             # 글상자: 두 줄(16×2)에 여백 6
const MSG_H := 44.0
const HB_W := 128.0                              # 체력 상자 스프라이트 크기
const HB_H := 64.0
const STAT_KEYS := ["hp", "atk", "def", "spa", "spd", "spe"]     # 이름은 Lang.stat_label
const EMPTY_TINT := Color(0.62, 0.62, 0.64)
const GREY := Color("8c8c98")

var game = null
var W := 512.0
var H := 288.0
var CX := 256.0
var BUTTONS: Array = []                          # 버튼 네모 4개(위에서 아래로)
var PANEL := Rect2()                             # 버튼 세로 1열 전체
var MSG := Rect2()
var PLAYER_BOX := Rect2()                        # 스프라이트 왼쪽 위 기준
var ENEMY_BOX := Rect2()
var STAT_BOX := Rect2()
var HOTBAR: Array = []                           # 도구 편성 칸 4개(1~4): 기술 판 바로 위 한 줄(사용자 결정 2026-11-02)
const HOT_W := 40.0 # 열매 네 자리 수량까지 표시
const HOT_H := 26.0
var _icons := {}                                 # 도구 id → 아이콘
var _exposure_clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 크기는 Game._fit_ui 가 준다(UI 레이어가 m/k 배라 뷰포트 ÷ 배율).

const RecoveryFill=preload("res://scripts/ui/recovery_fill.gd")
var _hp_fill_display := RecoveryFill.new()
var _pp_fill_display: Array=[]

func _update_recovery_fill(dt: float) -> void:
	if game==null or game.world==null or not is_instance_valid(game.world.player):return
	var p: Player=game.world.player
	_hp_fill_display.step(p.hp,p.max_hp,str(p.get_instance_id()),dt)
	while _pp_fill_display.size()<Player.SLOT_COUNT:
		var fill=RecoveryFill.new()
		fill.duration=0.18
		_pp_fill_display.append(fill)
	for i in Player.SLOT_COUNT:
		var id: String=p.slots[i]
		_pp_fill_display[i].step(p.pp[i],MoveDB.pp_of(id) if id!="" else 0,"%d:%s"%[p.get_instance_id(),id],dt)

var _berry_clock := 0.0

static func berry_bounce_offset(time: float) -> float:
	var phase := fposmod(time,1.15)/0.36
	return roundf(16.0*phase*(1.0-phase)) if phase<1.0 else 0.0

func _process(_dt: float) -> void:
	_exposure_clock+=_dt
	_berry_clock+=_dt
	_update_recovery_fill(_dt)
	queue_redraw()

func _layout() -> void:
	var vs := size if size.x > 0.0 else get_viewport_rect().size
	W = vs.x
	H = vs.y
	CX = floorf(W / 2.0)
	# 기술 네 칸은 2×2(Q W / E R — 키보드 배치처럼), 그 위에 도구 편성 1~4 한 줄.
	var bh := _btn_h()
	var ph := bh * 2.0 + BTN_GAP
	PANEL = Rect2(2, H - ph - 2, BTN_W * 2.0 + BTN_GAP, ph)
	BUTTONS.clear()
	for i in Player.SLOT_COUNT:
		BUTTONS.append(Rect2(PANEL.position + Vector2((i % 2) * (BTN_W + BTN_GAP), (i / 2) * (bh + BTN_GAP)), Vector2(BTN_W, bh)))
	HOTBAR.clear()
	for n in Player.HOTBAR:
		HOTBAR.append(Rect2(Vector2(PANEL.position.x + n * (HOT_W + BTN_GAP), PANEL.position.y - HOT_H - BTN_GAP), Vector2(HOT_W, HOT_H)))
	# 글상자·체력 상자는 오른쪽 끝에 빈틈없이 붙인다(사용자 결정 2026-10-28). 체력 상자 그림은 오른쪽 끝까지 차 있다.
	MSG = Rect2(W - MSG_W, H - MSG_H - 2, MSG_W, MSG_H)
	PLAYER_BOX = Rect2(W - HB_W, MSG.position.y - 55, HB_W, HB_H)     # 상자 아랫줄(52)이 글상자 3px 위
	ENEMY_BOX = Rect2(4, -2, HB_W, HB_H)                                   # 상자 윗줄(12)이 화면 10px
	STAT_BOX = Rect2(W - STAT_W - 4, MSG.position.y + 6 - STAT_H, STAT_W, STAT_H)   # 글상자 위에 6px 겹침

# 버튼 안 두 줄의 간격: 영문 12(대문자 9px), 한글 14(갈무리 11px + 받침).
func _row_gap() -> float:
	return 14.0 if Lang.is_ko() else 12.0

func _btn_h() -> float:
	return BTN_H + (_row_gap() - 12.0)

func _draw() -> void:
	if game == null or game.world == null:
		return
	_layout()
	_update_recovery_fill(0.0)
	_draw_quest_markers()
	if game.monologue:
		_draw_monologue()
		return
	if game.cinematic:
		if game.dialog_text != "":
			_draw_message()           # 시작 연출에서 볼에 다가간 동안은 글이 있을 때만 글상자
		return
	# 넘기는 대화(NPC·트레이너·해설): 플래티넘 필드 대화창처럼 화면 아래 전체 폭 창 하나만(사용자 결정 2026-10-29).
	if game.state == "talk":
		_draw_message()
		return
	if game.state=="bird_event":
		return
	var w: World = game.world
	var p: Player = w.player
	if game.mode == "dungeon" or game.is_event_battle():
		_draw_progress()          # 던전만: 남은 적 진행 막대(장소 이름은 원작처럼 들어설 때 알림판으로만 — 사용자 결정 2026-10-30)
	_draw_player_box(p)
	_draw_exposure(p)
	# 트레이너 배틀: 상대 포켓몬 체력 상자(왼쪽 위)와 남은 포켓몬(몬스터볼).
	if not game.battle.is_empty():
		var bm = game.battle["mon"]
		if bm != null and is_instance_valid(bm) and not bm.dead:
			_draw_enemy_box(bm)
		_draw_party_balls()
	elif game.is_event_battle():
		var boss: Enemy=game.event_battle().boss()
		if boss!=null:_draw_enemy_box(boss)
	if game.mode == "indoor" and game.battle.is_empty():
		pass                          # 건물 안: 기술 없음(체육관 배틀 중엔 쓴다)
	else:
		_draw_buttons(p)
		_draw_hotbar(p)
	# 안내(왼쪽 아래, 기술 버튼 위 — 건물 안은 버튼이 없어 맨 아래): 말 걸기(사람 앞에서) / 가방·상태·메뉴(던전 밖).
	var hints: Array = []
	var nearby: Npc=game.npc_in_reach()
	if nearby!=null:
		var hint:="hint_talk"
		if nearby.talk=="friend_cut":hint="hint_cut" if game.events.has("friend_scyther_cut") else "hint_inspect"
		hints.append(Lang.t(hint))
	if game.mode=="overworld" and game.battle.is_empty() and game.world.field_water.can_use(game.world):
		hints.append(Lang.t("hint_water"))
	if game.hub:
		hints.append(Lang.t("hint_bag"))
		hints.append(Lang.t("hint_summary"))
		hints.append(Lang.t("hint_menu"))
	var hy := (H - 18.0) if game.mode == "indoor" and game.battle.is_empty() else (PANEL.position.y - HOT_H - BTN_GAP - 16.0)
	for i in hints.size():
		PixelUi.field_text(self, Vector2(6, hy - i * 14.0), hints[i], false, Color.WHITE, PixelUi.FIELD_OUTLINE)
	_draw_message()               # 글이 없어도 글상자는 늘 그 자리(사용자 결정 2026-10-28)
	if not game.stat_box.is_empty():
		_draw_stat_box()
	if game.banner_t > 0.0:
		_draw_banner()
	if game.state in ["gameover", "victory"]:
		_draw_end()

# ── 체력 상자 ──

# 내 포켓몬: 이름(22,18)·Lv(오른끝 122) / HP 홈 x 72..120, 34~37행 / 숫자: 현재 오른끝 87, "/" 는 그림(88..93), 최대 94, 줄 위 37 / EXP 24..119, 49~50행
func _draw_player_box(p: Player) -> void:
	var o := PLAYER_BOX.position
	if not PixelUi.blit_rect(self, "plat/healthbox_player", PLAYER_BOX):
		draw_rect(Rect2(o + Vector2(17, 11), Vector2(111, 42)), PixelUi.PLAT_OLIVE)
	_hb_text(o + Vector2(22, 18), p.display_name())
	# Lv·숫자는 원작처럼 시스템 글꼴이 아니라 전용 이미지 글자(src/battle/healthbox.c 의 VRAM 자리를 상자 좌표로 옮김):
	#   Lv 글자(성별 없음) (88,16) 16×16 / 레벨 숫자 (104,20) 왼쪽 정렬 / 현재 HP (64,40) 3칸 오른쪽 정렬 / 최대 HP (96,40) 왼쪽 정렬.
	PixelUi.blit_rect(self, "plat/hb_lv", Rect2(o + Vector2(88, 16), Vector2(16, 16)))
	_hb_num(o + Vector2(104, 20), game.displayed_level() if game != null else p.level, 3, false)
	_hp_fill(o + Vector2(72, 34), 48.0, _hp_fill_display.ratio())
	_hb_num(o + Vector2(64, 40), p.hp, 3, true)
	_hb_num(o + Vector2(96, 40), p.max_hp, 3, false)
	var ew := floorf(96.0 * (game.displayed_exp_progress() if game != null else p.exp_progress()))
	if ew > 0.0:
		draw_rect(Rect2(o + Vector2(24, 49), Vector2(ew, 1)), PixelUi.PLAT_EXP)
		draw_rect(Rect2(o + Vector2(24, 50), Vector2(ew, 1)), PixelUi.PLAT_EXP_DARK)

# 상대: 이름(8,18)·Lv(오른끝 112) / HP 홈 x 56..104, 34~37행. 숫자는 없다.
# 상대 체력 상자(플래티넘 healthbox_enemy). 보스를 없앤 뒤로 부르는 곳은 없지만 그림 자리는 남겨 둔다.
func _draw_enemy_box(b: Enemy) -> void:
	var o := ENEMY_BOX.position
	if not PixelUi.blit_rect(self, "plat/healthbox_enemy", ENEMY_BOX):
		draw_rect(Rect2(o + Vector2(3, 12), Vector2(114, 32)), PixelUi.PLAT_OLIVE)
	_hb_text(o + Vector2(8, 18), b.display_name())
	_hb_text(o + Vector2(112, 18), "Lv%d" % b.level, HORIZONTAL_ALIGNMENT_RIGHT)
	_hp_fill(o + Vector2(56, 34), 48.0, b.hp_ratio())

# 체력 상자 숫자(plat/hb_digits: font_special_chars 의 0~9, 8px 칸). digits 칸 안에서 오른쪽 정렬(빈 칸 채움) 또는 왼쪽 정렬.
func _hb_num(at: Vector2, value: int, digits: int, right: bool) -> void:
	var tex := PixelUi.ui_tex("plat/hb_digits")
	var s := str(clampi(value, 0, int(pow(10, digits)) - 1))
	var x := at.x + (8.0 * (digits - s.length()) if right else 0.0)
	for ch in s:
		var d := int(ch)
		if tex != null:
			draw_texture_rect_region(tex, Rect2(x, at.y, 8, 8), Rect2(d * 8, 0, 8, 8))
		else:
			_hb_text(Vector2(x, at.y - 3), ch)
		x += 8.0

# 체력 상자 글자: 시스템 글꼴, 흰 글자 + 어두운 그림자.
func _hb_text(at: Vector2, s: String, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	PixelUi.text(self, at, s, true, PixelUi.PLAT_TEXT, PixelUi.PLAT_SHADOW, align)

# 흰 창 위 글자: 어두운 글자 + 연회색 그림자.
func _ink(at: Vector2, s: String, small: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	PixelUi.text(self, at, s, small, PixelUi.INK, PixelUi.INK_SHADOW, align)

# HP 막대 채움(홈 4줄): 플래티넘 parts 색. 아랫줄은 조금 어둡게.
func _hp_fill(at: Vector2, width: float, ratio: float) -> void:
	var w := floorf(width * clampf(ratio, 0.0, 1.0))
	if ratio > 0.0 and w < 1.0:
		w = 1.0
	if w <= 0.0:
		return
	var c: Color = PixelUi.PLAT_HP[0] if ratio > 0.5 else (PixelUi.PLAT_HP[1] if ratio > 0.2 else PixelUi.PLAT_HP[2])
	draw_rect(Rect2(at, Vector2(w, 3)), c)
	draw_rect(Rect2(at + Vector2(0, 3), Vector2(w, 1)), c.darkened(0.35))

# 가운데 위: 던전 이름과 진행도. 체력 상자 색의 작은 판.
func _draw_progress() -> void:
	var label: String = game.location_name()
	var tw := maxf(PixelUi.text_width(label, true), 60.0)
	var r := Rect2(CX - floorf(tw / 2.0) - 8, 4, tw + 16, 20)
	draw_rect(r, PixelUi.PLAT_LIGHT)
	draw_rect(r.grow(-1), PixelUi.PLAT_OLIVE)
	_hb_text(Vector2(CX, r.position.y + 1), label, HORIZONTAL_ALIGNMENT_CENTER)
	if game.mode != "dungeon" and not game.is_event_battle():
		return
	var gr := Rect2(r.position.x + 4, r.end.y - 4, r.size.x - 8, 2)
	draw_rect(gr, PixelUi.PLAT_OLIVE_DARK)
	draw_rect(Rect2(gr.position, Vector2(floorf(gr.size.x * game.progress()), gr.size.y)), PixelUi.PLAT_EXP)
	if game.state == "fight":
		var remaining:=Lang.t("left", [game.enemies_left()])
		if game.is_event_battle() and game.event_battle().has_method("progress_text"):remaining=game.event_battle().progress_text()
		PixelUi.field_text(self, Vector2(CX, r.end.y + 2), remaining, true, Color.WHITE, PixelUi.FIELD_OUTLINE, HORIZONTAL_ALIGNMENT_CENTER)

# ── 아래: 대사 글상자 + 기술 버튼 ──

# 글상자 자리: 넘기는 대화 중엔 화면 아래 전체 폭(양옆 2px), 그 밖엔 오른쪽 아래 작은 상자(MSG).
# 넘기는 대화 중엔 높이도 두 배(사용자 결정 2026-10-29), 글자도 정수 2배 — 두 줄에 안 들어가는 쪽(좁은 화면)만 1배로.
func msg_rect() -> Rect2:
	if game != null and game.state == "talk":
		return Rect2(2, H - MSG_H * 2.0 - 2, W - 4, MSG_H * 2.0)
	return MSG

func _draw_message() -> void:
	var r := msg_rect()
	var message: String = game.displayed_message()
	var talk: bool = game.state == "talk"
	if not PixelUi.nine(self, "plat/msgbox", r, 10):
		draw_rect(r, PixelUi.PAPER)
	if message != "":
		var k := 1
		if talk and PixelUi.line_count(message, r.size.x - 36, 2) <= 2:
			k = 2
		var pad := Vector2(18, 10) if talk else Vector2(15, 6)
		if talk and k == 1:
			pad.y = floorf((r.size.y - 32.0) / 2.0)        # 1배 글자는 큰 창 가운데에
		PixelUi.paragraph(self, r.position + pad, message, r.size.x - pad.x * 2.0, 2, PixelUi.INK, PixelUi.INK_SHADOW, k)

	# 넘기는 대사: 오른쪽 아래 빨간 ▼ 가 깜빡인다(원작 글상자의 다음 표시). 큰 창에선 2배.
	if talk and game.can_advance() and int(Time.get_ticks_msec() / 400) % 2 == 0:
		var m := 2.0 if r.size.y > MSG_H else 1.0
		var a := r.end - Vector2(16, 12) * m
		draw_colored_polygon(PackedVector2Array([a, a + Vector2(7, 0) * m, a + Vector2(3.5, 5) * m]), Color("e04040"))

# 검은 화면 독백(시작 이야기 — 내 포켓몬의 속마음): 화면 가운데에 흰 글씨, 줄마다 가운데 맞춤, 아래에 깜빡이는 ▼.
# 글자는 정수 2배(사용자 결정 2026-10-29) — 한 줄이라도 화면 폭(양옆 8px)을 넘는 쪽(좁은 화면)만 1배.
func _draw_monologue() -> void:
	draw_rect(Rect2(0, 0, W, H), Color.BLACK)
	var lines := String(game.dialog_text).split("\n")
	var k := 2
	for l in lines:
		if PixelUi.text_width(l, false, 2) > W - 16.0:
			k = 1
	var lh := 16.0 * k
	var y0 := floorf(H / 2.0 - lines.size() * lh / 2.0) - 6.0 * k
	for i in lines.size():
		PixelUi.text(self, Vector2(CX, y0 + i * lh), lines[i], false, Color.WHITE, Color(0.25, 0.25, 0.3), HORIZONTAL_ALIGNMENT_CENTER, k)
	if game.state == "talk" and int(Time.get_ticks_msec() / 400) % 2 == 0:
		var a := Vector2(CX - 3.5 * k, y0 + lines.size() * lh + 10.0 * k)
		draw_colored_polygon(PackedVector2Array([a, a + Vector2(7, 0) * k, a + Vector2(3.5, 5) * k]), Color("e04040"))

# 트레이너의 남은 포켓몬: 상대 체력 상자 아래에 볼(빨강 = 아직, 회색 = 쓰러짐). 원작 배틀의 파티 표시처럼.
func _draw_party_balls() -> void:
	var t: Dictionary = game.battle_trainer()
	var n: int = t["party"].size()
	var gone := int(game.battle["idx"]) - 1
	var bm = game.battle["mon"]
	if bm == null or not is_instance_valid(bm) or bm.dead:
		gone += 1
	var o := ENEMY_BOX.position + Vector2(12, 50)
	for i in n:
		var c := o + Vector2(i * 10, 0)
		var alive := i >= gone
		draw_circle(c, 4.0, Color("303030"))
		draw_circle(c, 3.0, Color("e84848") if alive else Color("8c8c98"))
		draw_rect(Rect2(c + Vector2(-3, 0), Vector2(6, 1)), Color("303030"))
		draw_circle(c, 1.2, Color.WHITE if alive else Color("c0c0c8"))

# 기술 버튼: 타입색 틀 + 밝은 판. 위 줄 기술 이름(가운데, 대사 글꼴), 아래 줄 왼쪽 타입 아이콘·오른쪽 "PP n/max"(시스템 글꼴).
# PP가 0이어도 수치를 표시하고 아래에 회복 게이지를 둔다. 마지막 입력 칸의 커서는 유지한다.
func _draw_buttons(p: Player) -> void:
	for i in Player.SLOT_COUNT:
		var r: Rect2 = BUTTONS[i]
		var id: String = p.slots[i]
		if id == "":
			if not PixelUi.nine(self, "plat/fight_frame", r, 8, EMPTY_TINT):
				draw_rect(r, GREY)
			continue
		var m := MoveDB.get_move(id)
		var selected := i==p.pp_focus_slot
		var reloading: bool = int(p.pp[i]) <= 0      # PP 가 바닥: 다음 1 이 찰 때까지 게이지
		var type_col: Color = TypeChart.type_color(m["type"])
		var tint := type_col.lerp(Color.WHITE, 0.2)
		if reloading:
			tint = tint.lerp(GREY, 0.5)
		if not PixelUi.nine(self, "plat/fight_frame", r, 8, tint):
			draw_rect(r, tint)
		var plate := r.grow(-4)
		if not PixelUi.nine(self, "plat/pp_plate", plate, 4):
			draw_rect(plate, PixelUi.PAPER)
		var ink := PixelUi.INK_DIM if reloading else PixelUi.INK
		PixelUi.text(self, Vector2(floorf(plate.position.x + plate.size.x / 2.0), plate.position.y - 1), MoveDB.move_name(id), false, ink, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
		var row_y := plate.position.y + _row_gap()
		_draw_type(Rect2(plate.position.x + 3, row_y, 32, 16), m["type"])
		var pp_s := "%d/%d" % [p.pp[i], MoveDB.pp_of(id)]
		if PixelUi.text_width("PP " + pp_s, true) <= plate.size.x - 38 - 6:pp_s="PP "+pp_s
		PixelUi.text(self,Vector2(plate.end.x-3,row_y),pp_s,true,ink,Color(0,0,0,0),HORIZONTAL_ALIGNMENT_RIGHT)
		var fill_ratio: float = p.regen_ratio(i) if reloading else _pp_fill_display[i].ratio()
		PixelUi.gauge(self,Rect2(plate.position.x+39,plate.end.y-3,plate.size.x-42,2),fill_ratio,type_col)
		if selected:_draw_corners(r)
		# 어느 키인지: 왼쪽 위에 Q / W / E / R.
		PixelUi.text(self, plate.position + Vector2(2, -2), Player.SLOT_KEYS[i], true, PixelUi.INK_DIM, Color(0, 0, 0, 0))

# 도구 편성 칸(1~4): 기술 버튼과 같은 틀(회색빛 초록)에 도구 아이콘·개수, 왼쪽 위에 숫자 키. 빈 칸·다 쓴 칸은 회색.
# 열매는 공통 사용 대기 게이지를 표시하고, 현재 필요한 열매 아이콘만 수직으로 튀어 오른다.
func _draw_hotbar(p: Player) -> void:
	for n in Player.HOTBAR:
		var r: Rect2 = HOTBAR[n]
		var id: String = p.hotbar[n] if n < p.hotbar.size() else ""
		var count := int(p.bag.get(id, 0)) if id != "" else 0
		var empty := count <= 0
		var tint := Color("78b878") if not empty else GREY
		if not PixelUi.nine(self, "plat/fight_frame", r, 8, tint):
			draw_rect(r, tint)
		var plate := r.grow(-3)
		if not PixelUi.nine(self, "plat/pp_plate", plate, 4):
			draw_rect(plate, PixelUi.PAPER)
		var ink := PixelUi.INK_DIM if empty else PixelUi.INK
		PixelUi.text(self, plate.position + Vector2(1, -3), str(n + 1), true, ink, Color(0, 0, 0, 0))
		if id == "":
			continue
		if not _icons.has(id):
			_icons[id] = ItemDB.icon(id)
		var icon: Texture2D = _icons[id]
		if icon != null:
			var lift := berry_bounce_offset(_berry_clock) if game.world.berry_needs_attention(id) else 0.0
			draw_texture_rect(icon, Rect2(Vector2(floorf(plate.end.x - 17), plate.position.y - 2-lift), Vector2(16, 16)), false, Color(1, 1, 1, 0.45 if empty else 1.0))
		PixelUi.text(self, Vector2(plate.end.x - 1, plate.end.y - 12), str(count), true, ink, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_RIGHT)
		if ItemDB.pocket_of(id)=="berries" and p.berry_cd > 0.0:
			PixelUi.gauge(self, Rect2(plate.position.x + 1, plate.end.y - 2, plate.size.x - 2, 2), 1.0 - p.berry_cd / Player.BERRY_COOLDOWN, Color("78b878"))

# 타입 표시 32×16. 영어는 원작 아이콘(types/*.png), 한국어는 아이콘 그림이 없어 타입색 딱지에 한글 이름(한국어판처럼).
func _draw_type(r: Rect2, type_id: String) -> void:
	if not Lang.is_ko() and PixelUi.blit_rect(self, "plat/types/%s" % type_id, r):
		return
	var col: Color = TypeChart.type_color(type_id)
	draw_rect(r, col.darkened(0.45))
	draw_rect(r.grow(-1), col)
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), col.lightened(0.35))
	PixelUi.text(self, Vector2(floorf(r.position.x + r.size.x / 2.0), r.position.y), Lang.type_name(type_id), true, Color.WHITE, col.darkened(0.5), HORIZONTAL_ALIGNMENT_CENTER)

# 고른 버튼의 네 모서리에 빨간 꺾쇠(interface/cursor.png 를 네 모서리로 모은 34×34 를 9분할, 가운데는 투명).
func _draw_corners(r: Rect2) -> void:
	if not PixelUi.nine(self, "plat/cursor", r, 16):
		draw_rect(r, Color("ff2020"), false, 2.0)

# ── 알림·창 ──

# 왼쪽 위(상대 상자 아래)에 쌓이는 짧은 알림. 체력 상자 색 판에 흰 글자.
# (왼쪽 위 알림(토스트)은 그리지 않는다 — 사용자 결정 2026-10-30. Game.toasts 는 도구가 확인용으로만 본다.)
func _draw_stat_box() -> void:
	var sb: Dictionary = game.stat_box
	var totals: bool = game.stat_t <= game.STAT_PHASE
	var r := STAT_BOX
	if not PixelUi.nine(self, "plat/sys_window", r, 8):
		draw_rect(r, PixelUi.PAPER)
	var y := r.position.y + 6
	for key in STAT_KEYS:
		_ink(Vector2(r.position.x + 10, y), Lang.stat_label(key), true)
		var v: String = str(sb["after"][key]) if totals else "+ %d" % sb["delta"][key]
		_ink(Vector2(r.end.x - 10, y), v, true, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 12

# 장소 이름 알림판(플래티넘 MapNamePopUp): 장소 종류 그림(136×40 — 그림 위 다섯 칸 줄) 왼쪽 위, 위에서 내려왔다 올라간다.
# 글자는 원작 FONT_SYSTEM 자리(y 16, 왼쪽은 글자 폭을 칸으로 올림한 상자 가운데 — MapNamePopUp_DrawWindowFrame), 검정 + 회색 그림자.
const POPUP := Vector2(136, 40)
const POPUP_INK := Color(0, 0, 0)
const POPUP_SHADOW := Color8(148, 148, 164)

func banner_drop() -> float:
	var e: float = game.BANNER_TIME - game.banner_t
	var hide := POPUP.y - 2.0                       # 원작 yOffset 38 = 다 올라간 자리
	if e < game.BANNER_SLIDE:
		return hide * (1.0 - e / game.BANNER_SLIDE)
	if game.banner_t < game.BANNER_SLIDE:
		return hide * (1.0 - game.banner_t / game.BANNER_SLIDE)
	return 0.0

func _draw_banner() -> void:
	var tex := PixelUi.ui_tex("plat/popup_" + String(game.banner_kind))
	var y := -roundf(banner_drop())
	if tex != null:
		draw_texture_rect_region(tex, Rect2(0, y, POPUP.x, POPUP.y), Rect2(Vector2.ZERO, POPUP))
	else:
		draw_rect(Rect2(0, y, POPUP.x, POPUP.y), PixelUi.PAPER)
	var w := PixelUi.text_width(game.banner_text)
	var left := (int(w + 8) / 8 * 8) - int(w)
	var spare := 0 if 4 + left / 2 >= 8 else ((8 - (4 + left / 2)) * 2 + 7) / 8
	var x := 4.0 + floorf(((int(w + 8) / 8 + spare) * 8 + 8 - w) / 2.0)
	PixelUi.text(self, Vector2(x, y + 16 - 4), game.banner_text, false, POPUP_INK, POPUP_SHADOW)

func _draw_end() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5))
	var p: Player = game.world.player
	var title: String
	var sub: String
	if game.state == "victory":
		title = Lang.t("cleared", [DungeonDB.display_name()])
		sub = Lang.t("beat_all", [p.display_name(), p.level, game.total_enemies])
	else:
		title = Lang.t("fainted", [p.display_name()])
		sub = Lang.t("defeated", [game.defeated, game.total_enemies, p.level])
	var prompt := Lang.t("back_overworld") if not game.bot else Lang.t("retry")
	var w := maxf(PixelUi.text_width(title), PixelUi.text_width(sub, true)) + 32.0
	var r := Rect2(CX - floorf(w / 2.0), floorf(H * 0.3), w, 72)
	if not PixelUi.nine(self, "plat/sys_window", r, 8):
		draw_rect(r, PixelUi.PAPER)
	_ink(Vector2(CX, r.position.y + 8), title, false, HORIZONTAL_ALIGNMENT_CENTER)
	_ink(Vector2(CX, r.position.y + 28), sub, true, HORIZONTAL_ALIGNMENT_CENTER)
	_ink(Vector2(CX, r.position.y + 48), prompt, false, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_exposure(p: Player) -> void:
	if game.mode!="overworld" or not game.battle.is_empty() or not game.road_pursuit.gauge_visible(p.level):return
	var meter:=Rect2(W-108,23,100,5)
	var label: String="노출" if Lang.is_ko() else "EXPOSURE"
	var count: int=game.road_pursuit.deployed.size()
	var total: int=game.road_pursuit.Data.POOLS.get(game.road_pursuit.visit_area,[]).size()
	PixelUi.field_text(self,Vector2(W-108,7),"%s %d/%d" % [label,count,total],false,Color.WHITE,PixelUi.FIELD_OUTLINE)
	var phase: String=game.road_pursuit.gauge_phase()
	var tint:=Color("efbd5c")
	var strength:=1.0
	if phase=="search":
		strength=0.45+0.55*(0.5+0.5*cos(TAU*_exposure_clock/0.65))
	elif phase=="hiding":
		tint=Color("8bd5b0")
		strength=0.45+0.55*(0.5+0.5*cos(TAU*_exposure_clock/1.6))
	elif phase=="retreat":
		tint=Color("a2ada5")
		strength=0.45
	tint.a=strength
	draw_rect(meter,Color("343b38"))
	draw_rect(Rect2(meter.position,Vector2(meter.size.x*game.road_pursuit.attention/100.0,meter.size.y)),tint)
	if phase!="idle":draw_rect(meter.grow(1.0),Color(tint,strength*0.6),false,1.0)

# Project markers through the same camera as the characters, so they remain
# visible in HD-2D and flat-map views without adding world collision.
func _draw_quest_markers() -> void:
	if game.quests==null or game.state not in ["fight","town"] or not game.battle.is_empty():return
	for actor in game.quests.actors:
		if not is_instance_valid(actor):continue
		var screen:=quest_marker_position(actor)
		if not Rect2(8,8,W-16,H-16).has_point(screen):continue
		var done: bool=actor.get_meta("quest_done",false)
		var quest_id: String=actor.get_meta("quest_id","")
		var started: bool=game.quests.stage_done(quest_id,0)
		var color:=Color("80db9e") if done else (Color("faf3db") if started else Color("ffda57"))
		draw_circle(screen+Vector2(0,-5),7,Color("303440"))
		if done:
			draw_line(screen+Vector2(-3,-5),screen+Vector2(-1,-3),color,2)
			draw_line(screen+Vector2(-1,-3),screen+Vector2(3,-8),color,2)
		elif started:
			for offset in [-4,0,4]:draw_rect(Rect2(screen+Vector2(offset-1,-6),Vector2(2,2)),color)
		else:
			draw_rect(Rect2(screen+Vector2(-1,-10),Vector2(2,6)),color)
			draw_rect(Rect2(screen+Vector2(-1,-2),Vector2(2,2)),color)

func quest_marker_position(actor: Npc) -> Vector2:
	if game.view3d!=null and game.view3d.visible and game.view3d.cam!=null:
		var view: View3D=game.view3d
		var at:=View3D.to3d(actor.position,1.55)
		if actor.visible and view._sprites.has(actor.get_instance_id()):
			var body: Sprite3D=view._sprites[actor.get_instance_id()].get("sprite")
			if body!=null:
				var vertical:=view.cam.global_basis.y if body.billboard==BaseMaterial3D.BILLBOARD_ENABLED else Vector3.UP
				at=body.position+vertical*(actor.frame_size.y-actor._head+6.0)*body.pixel_size*body.scale.y
		if view.cam.is_position_behind(at):return Vector2.INF
		return (view.cam.unproject_position(at)*view.rect.size/Vector2(view.vp.size)+view.rect.position)/game.ui_scale
	return (game.world.get_global_transform_with_canvas()*(actor.position+Vector2(0,-36)))/game.ui_scale

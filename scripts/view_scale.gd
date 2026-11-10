class_name ViewScale
extends RefCounted

# 시야 크기 옵션(사용자 결정: UI 가 시야를 가려서 기본은 원래의 1.5배 넓게, 줄일 수도 있게).
# 뷰포트(원본 px) 크기를 바꾸면 도트·글꼴·상자의 픽셀 크기는 그대로이고 보이는 들판만 넓어진다 —
# 상자와 글자가 화면에서 차지하는 비율이 줄어드는 셈. 창은 그 정수 배 중 화면에 들어가는 가장 큰 것.
#   0: 384×216 ×1.0  (16×9칸, GBA 폭 15칸에 가장 가까움)   창 1536×864(4배)
#   1: 448×252 ×1.17 (18.7×10.5칸, 기본 — 사용자 결정 2026-10-28: 4배 창이라 UI 3/4 가 또렷)  창 1792×1008(4배)
#   2: 512×288 ×1.33 (21.3×12칸)                          창 1536×864(3배, UI 는 2/3)
#   3: 576×324 ×1.5  (24×13.5칸)                          창 1728×972(3배)
# `-` / `=` 키로 돌리고 user://settings.cfg 에 남긴다. 캡처 도구는 저장 없이 384×216 을 강제한다(tools/capture.gd).

const SIZES := [Vector2i(384, 216), Vector2i(448, 252), Vector2i(512, 288), Vector2i(576, 324)]
const NAMES := ["x1.0", "x1.17", "x1.33", "x1.5"]
const DEFAULT := 1
const DEFAULT_TAG := "448"            # 기본값을 바꾸면 이 표를 바꿔 저장된 옛 선택을 기본으로 되돌린다
const SETTINGS := "user://settings.cfg"

static var index := DEFAULT
static var window_ready := false     # 창 크기·자리는 실행마다 처음 한 번만 잡는다(문·R 로 장면을 다시 읽어도 창을 안 옮김)

static func mobile_mode(tree: SceneTree) -> bool:
	return TouchControls.mobile_platform() or bool(tree.root.get_meta("mobile_presentation",false))

static func load_saved() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK and String(cf.get_value("view", "default_tag", "")) == DEFAULT_TAG:
		index = clampi(int(cf.get_value("view", "size", DEFAULT)), 0, SIZES.size() - 1)

static func save() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	cf.set_value("view", "size", index)
	cf.set_value("view", "default_tag", DEFAULT_TAG)
	cf.save(SETTINGS)

static func size() -> Vector2i:
	return SIZES[index]

# 뷰포트를 바꾸고 창을 맞춘다. 전체화면이면 창 크기는 건드리지 않는다(정수 배율 늘리기가 알아서 맞춘다).
# center: 화면 가운데로(처음 켤 때·전체화면에서 돌아올 때). 아니면 창의 가운데 점을 그대로 두고 크기만 바꾼다 —
# 사용자가 옮겨 둔 자리를 지킨다(사용자 지적 2026-10-28: 건물에 들어가면 창이 가운데로 가 버림).
static func apply(tree: SceneTree, new_index: int, persist: bool = true, center: bool = false) -> void:
	index = clampi(new_index, 0, SIZES.size() - 1)
	if mobile_mode(tree):
		var scene := tree.current_scene
		if scene != null and scene.has_method("set_game_size"):scene.set_game_size(size())
		if persist:save()
		return
	var win := tree.root
	win.content_scale_size = size()
	if win.mode == Window.MODE_WINDOWED:
		var mid := win.position + win.size / 2
		win.size = size() * best_scale(size())
		if center:
			win.move_to_center()
		else:
			win.position = mid - win.size / 2
	if persist:
		save()

# 창은 실행마다 처음 한 번만 맞춘다(시작 화면·게임 공통) — 문·R 로 장면을 다시 읽을 때마다 하면 옮겨 둔 창이 가운데로 돌아간다.
static func init_window(tree: SceneTree) -> void:
	if mobile_mode(tree):
		if not window_ready:load_saved()
		window_ready = true
		return
	if DisplayServer.get_name() == "headless" or window_ready:
		return
	window_ready = true
	load_saved()
	apply(tree, index, false, true)

# 시작 화면(PC 박스와 저장 목록 384×216)을 창에 맞추고(소수 배율), 가로로 남는 자리는
# 시작 화면이 박스 줄무늬로 채운다(뷰포트가 창 비율대로 넓어짐). 게임으로 넘어가면 use_game 이 원래(정수 배, 시야 크기)로 되돌린다.
# 헤드리스(도구)는 건드리지 않는다.
const TITLE_VIEW := Vector2i(384, 216)
static var title_view := false

static func use_title(tree: SceneTree) -> void:
	if mobile_mode(tree):
		title_view = true
		return
	if DisplayServer.get_name() == "headless":
		return
	title_view = true
	var win := tree.root
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	win.content_scale_size = TITLE_VIEW

static func use_game(tree: SceneTree) -> void:
	if mobile_mode(tree):
		title_view = false
		return
	if not title_view:
		return
	title_view = false
	var win := tree.root
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	win.content_scale_size = size()

static func cycle(tree: SceneTree, step: int) -> void:
	apply(tree, posmod(index + step, SIZES.size()))

# 연결된 모든 화면 중 가장 작은 화면(작업 영역)에 들어가는 가장 큰 정수 배율. 최소 1.
# macOS 레티나는 usable_rect 가 물리 픽셀이고 창 크기는 논리 픽셀이라 screen_get_scale 로 나눈다.
# 사용자 결정 2026-10-28: 처음 켤 때 4K 화면에서 7배(3136×1764)로 열리고 R 뒤엔 3배로 줄던 것을, 어느 화면에서 열리든
# 가장 작은 화면 기준(이 환경에선 3배 1344×756)으로 고정한다. 창 크기 조절은 그대로 된다(정수 배 늘리기가 안에서 맞춘다).
static func best_scale(view: Vector2i) -> int:
	var k := 99
	for screen in DisplayServer.get_screen_count():
		var usable := DisplayServer.screen_get_usable_rect(screen).size / maxf(1.0, DisplayServer.screen_get_scale(screen))
		# 제목 표시줄 몫으로 세로 40px 남긴다.
		k = mini(k, mini(int(usable.x / view.x), int((usable.y - 40) / view.y)))
	return maxi(1, k)

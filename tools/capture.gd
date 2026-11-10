class_name CaptureWindow
extends RefCounted

# 캡처 도구(스크린샷·기술 도감·즉석 probe)용 창 설정.
# 사용자 요청: 검증 창은 항상 선택한 뷰포트의 최소 1배 크기.
# 포커스를 요구하지 않고 화면 가장자리에 둔다. 게임 초기화가 창을 다시 키우지 않게 한다.
# 시작 프레임도 작은 창을 쓰려면 tools/run_visual_test.py로 실행한다.

const VIEW := Vector2i(384, 216)
const SCALE := 1
const VISIBLE := Vector2i(48, 48)
const WINDOW := VIEW

# CAP_VIEW=512x288 처럼 주면 그 뷰포트로(기본 플레이 화면 확인용). 없으면 384×216.
static func view_size() -> Vector2i:
	var env := OS.get_environment("CAP_VIEW")
	if env.contains("x"):
		return Vector2i(int(env.get_slice("x", 0)), int(env.get_slice("x", 1)))
	return VIEW

static func park(tree: SceneTree) -> void:
	# Native game scenes normally choose their largest fitting window once.
	# A review owns its window dimensions for the entire process, across reloads.
	ViewScale.window_ready=true
	await tree.process_frame # SceneTree._init callers have no Engine main loop yet.
	# Visual captures do not need playback. Keep audio state/timing, but avoid
	# stalled native audio callbacks in unattended sessions. CAP_AUDIO=1 opts in.
	if OS.get_environment("CAP_AUDIO") != "1":
		Bgm._node()._silent = true
		Sfx._node()
		Sfx._silent = true
	# 첫 프레임에 엔진이 프로젝트 설정(384×216)을 창에 다시 적용하므로 한 프레임 기다린 뒤 바꿔야 남는다.
	await tree.process_frame
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	tree.root.content_scale_size = view_size()
	DisplayServer.window_set_size(view_size())
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(usable.position + usable.size - VISIBLE)
	await tree.create_timer(0.2).timeout

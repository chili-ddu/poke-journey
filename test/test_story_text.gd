extends GutTest

# 시작 이야기·오박사 대사(사용자 승인 2026-10-29)가 한 쪽에 들어가는지: 글상자 대사는 두 줄(Hud.MSG_W − 30 폭)을 넘지 않고,
# 대화 중 큰 창에선 글자 2배로 두 줄 안, 검은 화면 독백은 줄마다 가장 좁은 시야(384px)에 들어간다. 한국어·영어 모두.

const BOX_KEYS := ["gym_liam", "gym_luis", "gym_diana", "intro_lab", "oak_escape", "oak_wait", "oak_huff", "oak_eyes", "oak_go", "oak_hello", "oak_grow"]
const MONO_KEYS := ["intro_self_bulbasaur", "intro_self_charmander", "intro_self_squirtle", "intro_world", "intro_resolve"]

func _lines(s: String, width: float) -> int:
	var para := TextParagraph.new()
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.width = width
	para.add_string(s, UiFont.get_font(), UiFont.BASE_SIZE)
	return para.get_line_count()

func test_story_pages_fit() -> void:
	var keep := Lang.code
	for code in ["ko", "en"]:
		Lang.code = code
		for k in BOX_KEYS:
			for page in Lang.t(k, ["CHARMANDER"] if k == "oak_hello" else []).split("|"):
				assert_lte(_lines(page, Hud.MSG_W - 30.0), 2, "%s %s: %s" % [code, k, page])
				# 대화 중 큰 창(기본 시야 448 → HUD 폭 448 ÷ 3/4)에서 글자 2배로 두 줄 안(넘치면 1배로 그린다).
				assert_lte(PixelUi.line_count(page, 448.0 / 0.75 - 4.0 - 36.0, 2), 2, "2배 %s %s: %s" % [code, k, page])
		for k in MONO_KEYS:
			for line in Lang.t(k).split("\n"):
				assert_lte(PixelUi.text_width(line), 384.0 - 16.0, "%s %s: %s" % [code, k, line])
				# 글자 2배로도 들어가는지(가장 작은 시야 384 의 HUD 폭 512 기준 — 넘치면 HUD 가 1배로 그린다).
				assert_lte(PixelUi.text_width(line, false, 2), 512.0 - 16.0, "2배 %s %s: %s" % [code, k, line])
	Lang.code = keep

func test_oak_hello_josa() -> void:
	var keep := Lang.code
	Lang.code = "ko"
	assert_string_starts_with(Lang.t("oak_hello", ["파이리"]), "오, 파이리로구나!")
	assert_string_starts_with(Lang.t("oak_hello", ["리자몽"]), "오, 리자몽이로구나!")
	Lang.code = keep

func test_dialogue_pages_keep_speaker_across_splits_and_clear_for_narration() -> void:
	var game = load("res://scripts/game.gd").new()
	var oak := Npc.new()
	var nurse := Npc.new()
	var pages: Array = game._pages(["first|second"], oak)
	assert_eq(pages.size(), 2)
	for page in pages:
		game._show_talk_page(page)
		assert_eq(game.talk_focus.get_ref(), oak)
	assert_eq(game.dialog_text, "second")
	game._show_talk_page(game._pages(["healed"], nurse)[0])
	assert_eq(game.talk_focus.get_ref(), nurse)
	game._show_talk_page("received item")
	assert_null(game.talk_focus)
	assert_eq(game.dialog_text, "received item")
	game._show_talk_page(pages[0])
	oak.free()
	assert_null(game.talk_focus.get_ref(), "Removed event NPC is not retained")
	nurse.free()
	game.free()

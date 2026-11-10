extends GutTest

# 게임 글이 그 언어 글꼴에 다 있는지(사용자 지적 2026-10-29: 영어 독백의 긴 줄표 "—" 가 플래티넘 글꼴에 없어 깨짐).
# Lang 문구 전부와 트레이너 대사를 한국어(갈무리11)·영어(플래티넘 글꼴)로 본다. %s·%d·쪽 나눔 "|"·줄바꿈·조사 {이/가} 는 빼고.

func _missing(text: String) -> String:
	var f := UiFont.get_font()
	var miss := ""
	for i in text.length():
		var ch := text.unicode_at(i)
		if ch in [10, 124, 32]:
			continue
		if not f.has_char(ch) and not miss.contains(char(ch)):
			miss += char(ch)
	return miss

func _clean(s: String) -> String:
	s = s.replace("%s", "").replace("%d", "")
	return Lang.josa(s) if Lang.is_ko() else s

func test_all_text_has_glyphs() -> void:
	var keep := Lang.code
	for code in Lang.CODES:
		Lang.code = code
		for k in Lang.S:
			var entry: Dictionary = Lang.S[k]
			var s := _clean(String(entry.get(code, entry["en"])))
			assert_eq(_missing(s), "", "%s %s 글꼴에 없는 글자" % [code, k])
		for id in TrainerDB.TRAINERS:
			for key in ["intro", "defeat", "after"]:
				if not TrainerDB.get_trainer(id).has(key):
					continue
				for page in TrainerDB.pages(id, key):
					assert_eq(_missing(_clean(String(page))), "", "%s %s.%s 글꼴에 없는 글자" % [code, id, key])
	Lang.code = keep

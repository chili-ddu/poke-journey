extends GutTest

# 배경 음악 배치(사용자 결정 2026-10-29: 장소는 파이어레드, 시스템·배틀·팡파르는 플래티넘). 곡 파일이 다 있는지, 갈 수 있는 장소마다
# 곡이 정해졌는지, 팡파르가 배경 곡을 멈췄다가 이어 주는지 본다.

func _wav(song: String) -> bool:
	return ResourceLoader.exists(Bgm.DIR + song + ".wav")

func test_every_place_has_song() -> void:
	for id in DungeonDB.DUNGEONS:
		var d: Dictionary = DungeonDB.DUNGEONS[id]
		if not (d.get("indoor", false) or d.get("overworld", false)):
			continue                       # 던전·경기장은 장소 곡이 없다(경기장은 배틀 곡이 이어짐)
		var areas: Dictionary = d.get("areas", {})
		if areas.is_empty():
			assert_ne(Bgm.place(id), "", id)
		for a in areas:
			assert_ne(Bgm.place(a), "", "%s/%s" % [id, a])
	for id in Bgm.PLACE:
		assert_true(_wav(Bgm.PLACE[id]), Bgm.PLACE[id])

func test_system_songs_exist() -> void:
	for s in [Bgm.TITLE, Bgm.HEAL, Bgm.LEVEL_UP, Bgm.EVOLVING, Bgm.EVOLVED, Bgm.BADGE, Bgm.ITEM, Bgm.TM]:
		assert_true(_wav(s), s)
	for id in TrainerDB.TRAINERS:
		assert_true(_wav(TrainerDB.battle_music(id)), id)
		assert_true(_wav(TrainerDB.victory_music(id)), id)
		var eye := TrainerDB.eye_music(id)
		if eye != "":
			assert_true(_wav(eye), id)
	assert_eq(TrainerDB.eye_music("leader_brock"), "")       # 플래티넘 관장은 눈 마주침 곡이 없다
	assert_eq(TrainerDB.battle_music("leader_brock"), "seq_ba_gym")
	assert_eq(TrainerDB.battle_music("bug_catcher_sammy"), "seq_ba_train")

func test_fanfare_pauses_and_resumes() -> void:
	# 헤드리스라 실제로 틀지는 않는다(Bgm._silent) — 고른 곡과 멈춤 상태만 본다.
	Bgm.play("mus_route1")
	await wait_frames(2)
	var b := Bgm._node()
	assert_true(b.is_inside_tree())
	assert_eq(b.main.stream.resource_path, Bgm.DIR + "mus_route1.wav")
	assert_false(b.held)
	b.jingle.stream = load(Bgm.DIR + Bgm.LEVEL_UP + ".wav")   # 팡파르가 울리는 중인 것처럼
	b.held = true
	Bgm.play("mus_pewter")                 # 팡파르 도중에 바뀐 곡은 멈춘 채로 기다린다
	assert_eq(Bgm.now(), "mus_pewter")
	assert_true(b.held, "팡파르 동안 멈춤")
	b._on_jingle_done()
	assert_false(b.held, "팡파르가 끝나면 이어서")
	Bgm.fanfare(Bgm.LEVEL_UP)
	assert_true(b.held)
	await wait_frames(2)
	assert_false(b.held, "헤드리스는 팡파르를 바로 끝낸다")
	Bgm.stop(false)
	assert_null(b.main.stream)

func test_battle_gain_restores_when_returning_to_field() -> void:
	var b := Bgm.new()
	add_child_autofree(b)
	for song in ["seq_ba_train", "seq_ba_rival", "seq_ba_gym"]:
		b._play(song, false)
		assert_eq(b.main.volume_db, -9.0)
	b.held = true
	b._play("mus_route1", false)
	assert_eq(b.main.volume_db, -6.0, "Field gain resets even during a fanfare")
	assert_eq(b.jingle.volume_db, -6.0, "Fanfare keeps its independent level")
	b._on_jingle_done()
	assert_eq(b.main.volume_db, -6.0)

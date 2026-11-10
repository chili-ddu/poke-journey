extends GutTest

# 장소 이름 알림판(플래티넘 MapNamePopUp, 사용자 요청 2026-10-30): 장소 종류마다 원작 그림이 있고, 마을·시티·도로·숲·건물 안이 맞게 고른다.

func test_popup_images_exist() -> void:
	for k in ["town", "city", "route", "forest", "cave", "indoors", "lake", "park", "water"]:
		assert_true(ResourceLoader.exists("res://assets/ui/plat/popup_%s.png" % k), k)

func test_popup_kinds() -> void:
	var keep := DungeonDB.current
	DungeonDB.current = "kanto_south"
	assert_eq(DungeonDB.popup_kind("pallet_town"), "town")
	assert_eq(DungeonDB.popup_kind("viridian_city"), "city")
	assert_eq(DungeonDB.popup_kind("pewter_city"), "city")
	assert_eq(DungeonDB.popup_kind("route1"), "route")
	DungeonDB.current = "viridian_forest"
	assert_eq(DungeonDB.popup_kind("viridian_forest"), "forest")
	DungeonDB.current = "viridian_center"
	assert_eq(DungeonDB.popup_kind(), "indoors")
	DungeonDB.current = keep

func test_trainer_berry_rewards_replace_tm_rewards() -> void:
	for id in ["bug_catcher_sammy","leader_brock","rival_green_squirtle"]:
		for st in ["charmander","squirtle","bulbasaur"]:
			assert_eq(TrainerDB.tm_for(id,st),"")
		assert_false(TrainerDB.berry_rewards(id).is_empty())
	assert_eq(MoveDB.pp_of("facade"),20)

func test_rival_counters_starter() -> void:
	assert_eq(TrainerDB.get_trainer(TrainerDB.rival_for("charmander"))["party"][0][0], "squirtle")
	assert_eq(TrainerDB.get_trainer(TrainerDB.rival_for("squirtle"))["party"][0][0], "bulbasaur")
	assert_eq(TrainerDB.get_trainer(TrainerDB.rival_for("bulbasaur"))["party"][0][0], "charmander")
	assert_eq(TrainerDB.battle_music("rival_green_squirtle"), "seq_ba_rival")
	assert_eq(TrainerDB.eye_music("rival_green_squirtle"), "seq_the_riv")

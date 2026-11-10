extends GutTest
class Idle:
	extends RefCounted
	func move_dir(_w): return Vector2.ZERO
	func aim_point(w): return w.player.position
	func want_dodge(_w): return false
	func want_skill(_i,_w): return false
	func want_jump(_w): return false
	func want_item(_w): return false
func fixture():
	DungeonDB.set_current("kanto_south")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7,"charmander",15,["scratch","ember"],Idle.new())
	w.player.position = Arena.tile_center(Arena.area_rect("route1").get_center())
	var game = load("res://scripts/game.gd").new()
	game.world=w
	game.mode="overworld"
	game.state="fight"
	game.bot=true
	game.panel=ChoicePanel.new()
	add_child_autofree(game.panel)
	return game
func test_threshold_uses_highest_nonzero_encounter_level():
	var game=fixture()
	var cfg={"encounters":[["rattata",3,99],["pidgey",5,1],["pidgey",90,0]]}
	game.world.player.set_level(14)
	assert_false(game.wild_fear_suppressed(cfg))
	game.world.player.set_level(15)
	assert_true(game.wild_fear_suppressed(cfg))
	assert_false(game.wild_fear_suppressed({"encounters":[]}))
	assert_false(game.wild_fear_suppressed({}))
	game.battle={"trainer":"protected"}
	assert_false(game.wild_fear_suppressed(cfg),"Trainer battles are unaffected")
	game.free()
func test_fear_cancels_pending_spawns_lure_and_does_not_award_experience():
	var game=fixture()
	game.world.pending_spawns.append({"species":"pidgey","level":3,"pos":game.world.player.position,"t":5.0})
	var exp_before: int=game.world.player.exp_total
	game._step_wild(1.0)
	assert_true(game.world.pending_spawns.is_empty())
	assert_true(game._fear_active)
	assert_eq(game.world.player.exp_total,exp_before)
	assert_eq(game.defeated,0)
	game._on_lured()
	assert_true(game.world.pending_spawns.is_empty())
	assert_eq(game.lure_t,0.0)
	game.free()
func test_notice_only_once_per_area_and_condition_can_clear():
	var game=fixture()
	var cfg= DungeonDB.area_cfg("route1")
	game._update_wild_fear(cfg)
	var notice: String=game.dialog_text
	assert_true(notice.is_empty()==false)
	game._advance_timed_message()
	while not game.dialog_text.is_empty():game._advance_timed_message()
	game._update_wild_fear(cfg)
	assert_true(game.dialog_text.is_empty(),"No repeated notification every frame")
	game.world.player.position=Arena.tile_center(Arena.area_rect("viridian_city").get_center())
	game._update_wild_fear({})
	game.world.player.position=Arena.tile_center(Arena.area_rect("route1").get_center())
	game._update_wild_fear(cfg)
	assert_eq(game.dialog_text,notice)
	game.world.player.set_level(14)
	assert_false(game._update_wild_fear(cfg))
	assert_false(game._fear_active)
	game.free()
func test_last_small_page_remains_visible_without_blocking_progress():
	var game=fixture()
	game._queue_status_message("First notice")
	game._advance_timed_message()
	assert_true(game.dialog_text.is_empty())
	assert_eq(game.displayed_message(),"First notice")
	game._queue_status_message("New event")
	assert_eq(game.displayed_message(),"New event")
	game._advance_timed_message()
	assert_eq(game.displayed_message(),"New event")
	game.pending_battle_end="victory"
	game._finish_pending_battle_end()
	assert_eq(game.state,"victory","Visible history does not block battle completion")
	game.free()

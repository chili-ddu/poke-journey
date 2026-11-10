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
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7,"charmander",12,["scratch","ember"],Idle.new())
	w.player.hold = "everstone"
	var game = load("res://scripts/game.gd").new()
	game.world = w
	game.bot = true
	game.state = "fight"
	game.panel = ChoicePanel.new()
	add_child_autofree(game.panel)
	return game
func award(game, amount: int) -> void:
	var foe := Enemy.new()
	foe.setup_enemy("caterpie",5,game.world.rng)
	add_child_autofree(foe)
	game._on_enemy_defeated(foe,amount)
func test_new_notice_replaces_old_without_interrupting_speech():
	var game = fixture()
	game._queue_status_message("old")
	game._queue_status_message("new")
	assert_eq(game.dialog_text,"new")
	assert_true(game.status_messages.is_empty())
	var speaker := Npc.new()
	game._say_pages(game._pages(["speech"],speaker))
	game._queue_status_message("latest")
	assert_eq(game.dialog_text,"speech")
	game._talk_next()
	game._show_next_status_message()
	assert_eq(game.dialog_text,"latest")
	speaker.free()
	game.free()
func test_partial_experience_animates_without_text_or_level_event():
	var game = fixture()
	award(game,1)
	game._advance_timed_message()
	assert_false(game.dialog_text.contains("경험치"))
	assert_true(game.exp_display_pending())
	game.advance(0.4)
	assert_gt(game.displayed_exp_progress(),0.0)
	assert_lt(game.displayed_exp_progress(),game.world.player.exp_progress())
	game.advance(0.5)
	assert_false(game.exp_display_pending())
	assert_true(game.stat_queue.is_empty())
	game.free()
func test_full_bar_precedes_level_event_and_next_opponent_waits():
	var game = fixture()
	var p = game.world.player
	award(game,SpeciesDB.exp_for_level(13,SpeciesDB.growth_of(p.species_id))-p.exp_total)
	game._advance_timed_message()
	game.advance(0.4)
	assert_true(game.stat_box.is_empty())
	assert_eq(game.displayed_level(),12)
	game.advance(0.4)
	assert_almost_eq(game.displayed_exp_progress(),1.0,0.001)
	assert_true(game.stat_box.is_empty())
	game.battle = {"faint_t":0.0,"next_t":1.0,"done_t":0.0}
	game._step_battle(0.2)
	assert_eq(game.battle.next_t,1.0)
	game.battle = {}
	game.advance(0.13)
	assert_eq(int(game.stat_box.level),13)
	assert_eq(game.displayed_level(),13)
	game.free()
func test_multi_level_award_finishes_learning_and_gauge_before_victory():
	var game = fixture()
	var p = game.world.player
	award(game,SpeciesDB.exp_for_level(20,SpeciesDB.growth_of(p.species_id))-p.exp_total)
	game._win()
	var levels: Array = []
	for frame in 9000:
		game.advance(1.0/60)
		if not game.stat_box.is_empty() and not levels.has(game.stat_box.level): levels.append(game.stat_box.level)
		if game.state=="victory": break
	assert_eq(levels,[13,14,15,16,17,18,19,20])
	assert_eq(game.state,"victory")
	assert_false(game.exp_display_pending())
	for level in range(13,21):
		for move in SpeciesDB.moves_at_level(p.species_id,level): assert_true(p.known_moves().has(move))
	game.free()

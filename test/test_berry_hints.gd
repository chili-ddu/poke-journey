extends GutTest
class Idle:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.RIGHT*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false
func fixture() -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7,"charmander",12,["scratch","ember","growl"],Idle.new())
	w.player.bag={"oran_berry":2,"sitrus_berry":2,"leppa_berry":2,"pecha_berry":1,"cheri_berry":1,"chesto_berry":1,"rawst_berry":1,"persim_berry":1,"lum_berry":1}
	return w
func test_low_health_and_only_matching_status_cures_are_suggested():
	var w := fixture()
	assert_false(w.berry_needs_attention("oran_berry"))
	w.player.hp=1
	assert_true(w.berry_needs_attention("oran_berry"))
	assert_true(w.berry_needs_attention("sitrus_berry"))
	assert_false(w.berry_needs_attention("leppa_berry"))
	w.player.hp=w.player.max_hp
	for pair in [["poison_t","pecha_berry"],["para_t","cheri_berry"],["sleep_t","chesto_berry"],["burn_t","rawst_berry"],["confuse_t","persim_berry"]]:
		w.player.set(pair[0],10.0)
		assert_true(w.berry_needs_attention(pair[1]))
		assert_true(w.berry_needs_attention("lum_berry"))
		for other in ["pecha_berry","cheri_berry","chesto_berry","rawst_berry","persim_berry"]:
			if other!=pair[1]:assert_false(w.berry_needs_attention(other))
		w.player.set(pair[0],0.0)
func test_low_pp_hint_tracks_only_the_visible_selected_skill():
	var w := fixture()
	w.player.pp[0]=0
	w.player.select_skill(1)
	assert_false(w.berry_needs_attention("leppa_berry"),"Another empty move is not the recovery target")
	w.player.pp[1]=1
	assert_true(w.berry_needs_attention("leppa_berry"))
	w.player.pp[1]=int(ceil(MoveDB.pp_of(w.player.slots[1])*0.5))
	assert_false(w.berry_needs_attention("leppa_berry"))
func test_zero_pp_press_selects_before_cooldown_validation_and_survives_other_autofire():
	var w := fixture()
	Controllers.ensure_input_map()
	w.player.controller=Controllers.Human.new()
	w.player.pp[1]=0
	w.player.use_t[1]=3.0
	w.player.skill_lock_t=3.0
	var game=load("res://scripts/game.gd").new()
	game.world=w;game.state="fight"
	var key := InputEventKey.new()
	key.pressed=true;key.physical_keycode=KEY_W
	game._unhandled_input(key)
	w._step_player(1.0/60.0)
	assert_eq(w.player.pp_focus_slot,1)
	assert_eq(w.berry_pp_slot(),1)
	assert_false(w.player.can_use(1))
	w.player.spend(0)
	assert_eq(w.player.pp_focus_slot,1,"An older held skill firing does not move the recovery target")
	assert_eq(w.use_item("leppa_berry"),"")
	assert_eq(w.player.pp[1],10)
	game.free()
func test_full_selected_move_does_not_consume_or_redirect_pp_berry():
	var w := fixture()
	w.player.pp[0]=0
	w.player.select_skill(1)
	assert_eq(w.berry_pp_slot(),-1)
	assert_eq(w.use_item("leppa_berry"),"item_no_effect")
	assert_eq(w.player.pp[0],0)
	assert_eq(w.player.bag.leppa_berry,2)
	assert_false(w.player.select_skill(3),"Empty slot cannot replace a valid selection")
	assert_eq(w.player.pp_focus_slot,1)
func test_empty_cooling_down_and_fainted_berries_do_not_bounce():
	var w := fixture()
	w.player.hp=1
	w.player.bag.oran_berry=0
	assert_false(w.berry_needs_attention("oran_berry"))
	w.player.bag.oran_berry=1
	w.player.berry_cd=1.0
	assert_false(w.berry_needs_attention("oran_berry"))
	w.player.berry_cd=0.0;w.player.dead=true
	assert_false(w.berry_needs_attention("oran_berry"))
func test_bounce_rises_and_returns_to_the_same_baseline_with_a_rest():
	assert_eq(Hud.berry_bounce_offset(0.0),0.0)
	assert_eq(Hud.berry_bounce_offset(0.18),4.0)
	assert_eq(Hud.berry_bounce_offset(0.36),0.0)
	assert_eq(Hud.berry_bounce_offset(0.8),0.0)
	assert_eq(Hud.berry_bounce_offset(1.33),4.0)
	for i in 116:assert_between(Hud.berry_bounce_offset(i/100.0),0.0,4.0)
func test_recovery_focus_survives_save():
	var w := fixture()
	var previous := SaveData.path
	SaveData.path="user://test_berry_pp_focus.cfg"
	w.player.select_skill(2)
	SaveData.store(w.player,[])
	assert_eq(SaveData.load_saved().pp_focus_slot,2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	SaveData.path=previous

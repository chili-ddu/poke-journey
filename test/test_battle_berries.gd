extends GutTest
const BERRIES := ["oran_berry","sitrus_berry","leppa_berry","cheri_berry","chesto_berry","pecha_berry","rawst_berry","persim_berry","lum_berry"]
class Idle:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position+Vector2.UP*80
	func want_skill(_i,_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_item(_w) -> bool: return false
class BerryKey:
	extends Idle
	func want_hotbar(n,_w) -> bool: return n==0
func _world() -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7,"charmander",12,["scratch","ember","growl"],Idle.new())
	return w
func test_berries_have_original_icons_names_and_shop_access() -> void:
	for id in BERRIES:
		assert_true(ItemDB.has_item(id))
		assert_true(ItemDB.icon(id)!=null)
		assert_eq(ItemDB.pocket_of(id),"berries")
		assert_true(ItemDB.shop_items().has(id))
		assert_false(ItemDB.effect(id).is_empty())
func test_sitrus_heals_quarter_and_clamps_to_maximum() -> void:
	var w := _world()
	w.player.bag={"sitrus_berry":2}
	w.player.hp=1
	var amount := maxi(1,int(floor(w.player.max_hp*0.25)))
	assert_eq(w.use_item("sitrus_berry"),"")
	assert_eq(w.player.hp,1+amount)
	assert_eq(w.player.bag.sitrus_berry,1)
	w.player.berry_cd=0.0
	w.player.hp=w.player.max_hp-1
	assert_eq(w.use_item("sitrus_berry"),"")
	assert_eq(w.player.hp,w.player.max_hp)
func test_no_effect_cooldown_and_fainted_player_do_not_spend_berries() -> void:
	var w := _world()
	w.player.bag={"sitrus_berry":2,"pecha_berry":1,"leppa_berry":1}
	assert_eq(w.use_item("sitrus_berry"),"item_no_effect")
	assert_eq(w.use_item("pecha_berry"),"item_no_effect")
	assert_eq(w.use_item("leppa_berry"),"item_no_effect")
	w.player.hp=1
	w.player.berry_cd=1.0
	assert_eq(w.use_item("sitrus_berry"),"item_wait")
	w.player.berry_cd=0.0
	w.player.dead=true
	assert_eq(w.use_item("sitrus_berry"),"item_no_effect")
	assert_eq(w.player.bag,{"sitrus_berry":2,"pecha_berry":1,"leppa_berry":1})
func test_specific_cures_leave_unrelated_status_intact() -> void:
	var w := _world()
	for pair in [["cheri_berry","para_t"],["chesto_berry","sleep_t"],["pecha_berry","poison_t"],["rawst_berry","burn_t"],["persim_berry","confuse_t"]]:
		w.full_restore(false)
		w.player.bag={pair[0]:1}
		w.player.berry_cd=0.0
		w.player.slow_t=4.0
		w.player.set(pair[1],10.0)
		assert_eq(w.use_item(pair[0]),"")
		assert_eq(float(w.player.get(pair[1])),0.0)
		assert_eq(w.player.slow_t,4.0,"A healing berry does not reset speed modifiers")
		assert_false(w.player.bag.has(pair[0]))
func test_lum_cures_major_status_and_confusion_once() -> void:
	var w := _world()
	w.player.bag={"lum_berry":2}
	w.player.burn_t=10.0
	w.player.poison_t=10.0
	w.player.para_t=10.0
	w.player.sleep_t=10.0
	w.player.confuse_t=10.0
	assert_eq(w.use_item("lum_berry"),"")
	for field in ["burn_t","poison_t","para_t","sleep_t","confuse_t"]: assert_eq(float(w.player.get(field)),0.0)
	assert_eq(w.player.bag.lum_berry,1)
func test_leppa_explicit_target_and_last_pressed_target_restore_only_one_move() -> void:
	var w := _world()
	w.player.bag={"leppa_berry":3}
	w.player.pp[0]=12
	w.player.pp[1]=0
	w.player.pp[2]=1
	w.player.select_skill(1)
	assert_eq(w.berry_pp_slot(),1,"Last pressed skill stays the target at zero PP")
	assert_eq(w.use_item("leppa_berry",0),"")
	assert_eq(w.player.pp[0],22)
	assert_eq(w.player.pp[1],0)
	w.player.berry_cd=0.0
	assert_eq(w.use_item("leppa_berry"),"")
	assert_eq(w.player.pp[1],10)
	assert_eq(w.player.pp[2],1)
	assert_eq(w.player.bag.leppa_berry,1)
func test_leppa_invalid_target_does_not_consume_and_full_restore_resets_regen() -> void:
	var w := _world()
	w.player.bag={"leppa_berry":2}
	w.player.pp[0]=MoveDB.pp_of(w.player.slots[0])-1
	w.player.regen_t[0]=0.4
	assert_eq(w.use_item("leppa_berry",9),"item_no_effect")
	assert_eq(w.use_item("leppa_berry",1),"item_no_effect","An explicitly full move must not fall back to a different slot")
	assert_eq(w.player.bag.leppa_berry,2)
	assert_eq(w.use_item("leppa_berry",0),"")
	assert_eq(w.player.pp[0],MoveDB.pp_of(w.player.slots[0]))
	assert_eq(w.player.regen_t[0],0.0)
func test_sleep_cure_hotkey_works_while_normal_actions_are_blocked() -> void:
	var w := _world()
	w.player.controller=BerryKey.new()
	w.player.hotbar[0]="chesto_berry"
	w.player.bag={"chesto_berry":1}
	w.player.sleep_t=10.0
	w.hotbar_used.connect(func(id): w.use_item(id))
	assert_false(w.player.can_act())
	w._step_player(1.0/60.0)
	assert_eq(w.player.sleep_t,0.0)
	assert_false(w.player.bag.has("chesto_berry"))

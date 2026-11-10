extends GutTest
class Idle:
	extends RefCounted
	func move_dir(_w): return Vector2.ZERO
	func aim_point(w): return w.player.position+Vector2.RIGHT*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false
func world() -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(9,"charmander",8,["scratch","ember"],Idle.new())
	w.player.position=Arena.center()
	w.player.bag.clear()
	return w
func test_same_kind_coalesces_visuals_counts_and_one_inventory_notification():
	var w := world()
	var notices: Array=[]
	var saves: Array=[]
	w.status_message.connect(func(text):notices.append(text))
	w.inventory_changed.connect(func():saves.append(true))
	var first := w.spawn_loot("oran_berry",w.player.position+Vector2(20,0))
	var second := w.spawn_loot("oran_berry",w.player.position+Vector2(24,2))
	var third := w.spawn_loot("oran_berry",w.player.position+Vector2(18,-2))
	w._step_drops(0.4)
	assert_eq(w.player.bag.oran_berry,3)
	assert_eq(saves.size(),1,"One save notification per collection frame")
	assert_true(notices.is_empty(),"Wait briefly to collect the batch")
	assert_eq(first.count,3)
	assert_eq(second.merge_target,first)
	assert_eq(third.merge_target,first)
	w.step_loot_visual(0.11)
	assert_eq(w.drops.size(),1,"Duplicate icons converge and fade")
	assert_true(notices.is_empty())
	w.step_loot_visual(0.08)
	assert_eq(notices,[Lang.t("got_items",[ItemDB.name_of("oran_berry"),3])])
	w.step_loot_visual(0.5)
	assert_true(w.drops.is_empty())
	assert_eq(w.player.bag.oran_berry,3)
	assert_eq(saves.size(),1)
func test_mixed_types_share_two_line_message_with_exact_counts():
	var w := world()
	var notices: Array=[]
	w.status_message.connect(func(text):notices.append(text))
	w.spawn_loot("oran_berry",w.player.position+Vector2(20,0))
	w.spawn_loot("pecha_berry",w.player.position+Vector2(22,0))
	w.spawn_loot("pecha_berry",w.player.position+Vector2(24,0))
	w._step_drops(0.4)
	w.step_loot_visual(0.19)
	assert_eq(notices.size(),1)
	assert_eq(notices[0],Lang.t("got_items",[ItemDB.name_of("oran_berry"),1])+"\n"+Lang.t("got_items",[ItemDB.name_of("pecha_berry"),2]))
	assert_eq(w._loot_flights.size(),2,"Different original icons stay recognizable")

func test_pickup_sparkles_follow_flight_and_expire_without_duplicate_inventory():
	var w := world()
	var first := w.spawn_loot("oran_berry",w.player.position+Vector2(20,0))
	w.spawn_loot("oran_berry",w.player.position+Vector2(22,0))
	w._step_drops(0.4)
	var sparks := w.fxs.filter(func(f): return f.kind=="pickup_trail")
	assert_eq(sparks.size(),1,"Merged loot shares one sparkle effect")
	w.player.position+=Vector2(8,3)
	for i in 6: w.step_visual(1.0/60.0)
	var trail: RefCounted=sparks[0].pickup_trail
	var first_at: Vector2=trail.history[0].at
	var first_height: float=trail.history[0].height
	for i in 6: w.step_visual(1.0/60.0)
	assert_eq(trail.history[0].at,first_at,"Old light stays on the path instead of following the item")
	assert_eq(trail.history[0].height,first_height)
	assert_gt(first.draw_at.distance_to(first_at),1.0)
	assert_lte(trail.history.size(),9)
	assert_lte(trail.motes.size(),4)
	assert_true(w.fxs.filter(func(f): return f.text=="pixelfx_pickup").is_empty(),"Replaces the old surrounding particles")
	for i in 12: w.step_visual(1.0/60.0)
	for i in 20: w.step_visual(1.0/60.0)
	assert_true(w.drops.is_empty())
	assert_true(w.fxs.filter(func(f): return f.kind=="pickup_trail").is_empty())
	assert_eq(w.player.bag.oran_berry,2,"Cosmetic effects never transfer inventory again")
func test_trail_expires_after_the_item_node_is_actually_freed() -> void:
	var w := world()
	var item := w.spawn_loot("oran_berry",w.player.position+Vector2(20,0))
	w._step_drops(0.4)
	for i in 30: w.step_visual(1.0/60.0)
	await get_tree().process_frame
	assert_false(is_instance_valid(item),"The icon is gone while its last light samples remain")
	for i in 20: w.step_visual(1.0/60.0)
	assert_true(w.fxs.filter(func(f): return f.kind=="pickup_trail").is_empty())
	assert_eq(w.player.bag.oran_berry,1)

func test_full_bag_items_are_not_counted_as_received():
	var w := world()
	w.player.bag.oran_berry=ItemDB.cap("oran_berry")-1
	var notices: Array=[]
	w.status_message.connect(func(text):notices.append(text))
	for i in 3:w.spawn_loot("oran_berry",w.player.position+Vector2(20+i,0))
	w._step_drops(0.4)
	w.step_loot_visual(0.19)
	assert_eq(w.player.bag.oran_berry,ItemDB.cap("oran_berry"))
	assert_eq(notices,[Lang.t("got_items",[ItemDB.name_of("oran_berry"),1])])
	var ground := 0
	for item in w.drops:
		if item.flight<0:ground+=1
	assert_eq(ground,2)
func test_notice_deadline_is_not_extended_by_more_pickups():
	var w := world()
	var notices: Array=[]
	w.status_message.connect(func(text):notices.append(text))
	w._queue_loot_notice("pecha_berry",1)
	w.step_loot_visual(0.1)
	w._queue_loot_notice("pecha_berry",2)
	w.step_loot_visual(0.09)
	assert_eq(notices,[Lang.t("got_items",[ItemDB.name_of("pecha_berry"),3])])
	w._queue_loot_notice("pecha_berry",1)
	w.step_loot_visual(0.19)
	assert_eq(notices.size(),2,"Later pickup starts a new bounded batch")
func test_reserve_and_ground_collection_share_a_single_batch_and_save():
	var w := world()
	w.player.reward_reserve={"oran_berry":2}
	var notices: Array=[]
	var saves: Array=[]
	w.status_message.connect(func(text):notices.append(text))
	w.inventory_changed.connect(func():saves.append(true))
	w.spawn_loot("oran_berry",w.player.position+Vector2(22,-6))
	w._step_drops(0.4)
	assert_eq(w.player.bag.oran_berry,3)
	assert_true(w.player.reward_reserve.is_empty())
	assert_eq(saves.size(),1)
	w.step_loot_visual(0.19)
	assert_eq(notices,[Lang.t("got_items",[ItemDB.name_of("oran_berry"),3])])
func test_many_types_are_split_into_fixed_two_line_pages_in_both_languages():
	var old := Lang.code
	var items := {"oran_berry":2,"leppa_berry":1,"sitrus_berry":1,"pecha_berry":3,"cheri_berry":1}
	for language in ["ko","en"]:
		Lang.code=language
		var pages := World.loot_summary_pages(items)
		assert_eq(pages.size(),3)
		for page in pages:assert_lte(page.split("\n").size(),2)
		var joined := "\n".join(pages)
		for id in items:assert_true(joined.contains(Lang.t("got_items",[ItemDB.name_of(id),items[id]])))
	Lang.code=old
func test_distant_sources_do_not_teleport_into_a_single_icon():
	var w := world()
	var a := w.pickup_visual("pecha_berry",1,w.player.position+Vector2.LEFT*30)
	var b := w.pickup_visual("pecha_berry",1,w.player.position+Vector2.RIGHT*30)
	assert_null(a.merge_target)
	assert_null(b.merge_target)
	assert_eq(a.count,1)
	assert_eq(b.count,1)

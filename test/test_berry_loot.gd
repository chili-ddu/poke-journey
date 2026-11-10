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
func test_trainer_rewards_are_berries_instead_of_skills():
	for id in TrainerDB.TRAINERS:
		var trainer := TrainerDB.get_trainer(id)
		assert_false(trainer.has("tm"),id)
		assert_false(trainer.has("tm_drop"),id)
		var reward := TrainerDB.berry_rewards(id)
		if trainer.has("berry_reward") and trainer.berry_reward.is_empty():
			assert_true(reward.is_empty(),id+" explicitly opts out of item rewards")
		else:
			assert_false(reward.is_empty(),id)
		for berry in reward:
			assert_eq(ItemDB.pocket_of(berry),"berries",id+berry)
			assert_gt(int(reward[berry]),0)
	assert_true(TrainerDB.berry_rewards("bug_catcher_sammy").has("pecha_berry"))
func test_forest_has_only_original_pool_members_and_no_exit_event():
	assert_true(DungeonDB.DUNGEONS.viridian_forest.trainers.is_empty())
	var data=preload("res://scripts/data/road_trainer_db.gd")
	assert_eq(data.POOLS.viridian_forest.size(),5)
	var names: Array=[]
	for id in data.POOLS.viridian_forest:
		var trainer := TrainerDB.get_trainer(id)
		names.append(trainer.name)
		assert_eq(trainer.party,data.TRAINERS[id].party,id)
	assert_has(names,"RICK");assert_has(names,"DOUG");assert_has(names,"ANTHONY");assert_has(names,"CHARLIE");assert_has(names,"SAMMY")
	assert_eq(TrainerDB.get_trainer("bug_catcher_sammy").party,[["weedle",9]])
func test_cure_berries_follow_actual_move_effects_and_level():
	for pair in [["weedle",5,"pecha_berry"],["pikachu",3,"cheri_berry"],["jigglypuff",3,"chesto_berry"],["zubat",7,"persim_berry"],["charmander",8,"rawst_berry"]]:
		assert_has(BerryLoot.status_berries(SpeciesDB.enemy_moves(pair[0],pair[1])),pair[2],pair[0])
	assert_true(BerryLoot.status_berries(SpeciesDB.enemy_moves("caterpie",5)).is_empty(),"Rank reductions are not curable status ailments")
	assert_true(BerryLoot.status_berries(SpeciesDB.enemy_moves("charmander",1)).is_empty(),"No cure drop for an unlearned attack")
	assert_eq(BerryLoot.status_berries(["poison_sting","poison_powder"]),["pecha_berry"],"No duplicate weighting for the same ailment")
func test_seeded_wild_rolls_are_probabilistic_and_only_drop_matching_cures():
	var rng := RandomNumberGenerator.new()
	rng.seed=17
	var common := 0
	var cures := 0
	var empty := 0
	for i in 5000:
		var loot := BerryLoot.roll("weedle",5,rng)
		if loot.is_empty():empty+=1
		for id in loot:
			if id=="pecha_berry":cures+=1
			else:
				assert_true(id in ["oran_berry","leppa_berry","sitrus_berry"])
				common+=1
	assert_almost_eq(float(common)/5000.0,BerryLoot.COMMON_CHANCE,0.025)
	assert_between(cures,850,1150)
	assert_gt(empty,0)
func test_drop_commits_once_then_flies_into_moving_player():
	var w := world()
	var drop := w.spawn_loot("pecha_berry",w.player.position+Vector2.RIGHT*24)
	var hp: int=w.player.hp
	w._step_drops(0.4)
	assert_eq(w.player.bag.get("pecha_berry",0),1)
	assert_eq(drop.flight,0.0)
	assert_eq(w.player.hp,hp,"Pickup adds to bag without consuming the berry")
	var start := drop.draw_at
	w.player.position+=Vector2.DOWN*8
	w.step_loot_visual(0.23)
	assert_lt(drop.draw_at.distance_to(w.player.position),start.distance_to(w.player.position))
	assert_gt(drop.height,10.0,"Curved flight rises before reaching the player")
	w._step_drops(0.3)
	assert_true(w.drops.is_empty())
	assert_eq(w.player.bag.pecha_berry,1)
func test_full_bag_ground_loot_remains_and_trainer_overflow_is_reserved():
	var w := world()
	w.player.bag.oran_berry=ItemDB.cap("oran_berry")
	var drop := w.spawn_loot("oran_berry",w.player.position+Vector2.RIGHT*20)
	w._step_drops(0.4)
	assert_lt(drop.flight,0.0)
	var learned := w.player.known_moves().duplicate()
	assert_eq(w.award_berries({"oran_berry":2},w.player.position),{"oran_berry":2})
	assert_eq(w.player.reward_reserve.oran_berry,2)
	assert_eq(w.player.known_moves(),learned)
	w.player.take_item("oran_berry")
	w._step_drops(0.01)
	assert_eq(w.player.bag.oran_berry,ItemDB.cap("oran_berry"))
	assert_eq(w.player.reward_reserve.oran_berry,1)
	assert_lt(drop.flight,0.0,"Reservation does not duplicate ground loot")
func test_trainer_owned_pokemon_do_not_drop_wild_rewards():
	var w := world()
	var enemy := Enemy.new()
	enemy.setup_trainer_mon("weedle",9,[],w.rng)
	enemy.position=w.player.position+Vector2.RIGHT*50
	w.add_child(enemy);w.enemies.append(enemy)
	w.damage(enemy,9999)
	assert_true(w.drops.is_empty())
func test_trainer_reserve_survives_save_without_erasing_learned_skills():
	var previous := SaveData.path
	SaveData.path="user://test_berry_reserve.cfg"
	var w := world()
	w.player.add_learned("dig")
	w.player.reward_reserve={"oran_berry":2,"leppa_berry":1}
	SaveData.store(w.player,[],"kanto_south",Vector2(100,100))
	var saved := SaveData.load_saved()
	assert_eq(saved.reward_reserve,w.player.reward_reserve)
	assert_has(saved.learned,"dig","Existing skills survive the reward change")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	SaveData.path=previous

func test_regular_rewards_scale_with_actual_party_effort_without_flooding_pp_berries():
	var simple := TrainerDB.berry_rewards("bug_catcher_sammy")
	assert_eq(simple.oran_berry,1)
	assert_false(simple.has("leppa_berry"))
	assert_eq(simple.pecha_berry,1,"Keep a guaranteed matching status cure")
	var pair := TrainerDB.berry_rewards("forest_bug_catcher_rick")
	assert_eq(pair.oran_berry,2)
	assert_false(pair.has("leppa_berry"))
	var group := TrainerDB.berry_rewards("forest_bug_catcher_doug")
	assert_eq(group.oran_berry,2)
	assert_eq(group.leppa_berry,1)
	var brock := TrainerDB.berry_rewards("leader_brock")
	assert_eq(brock.sitrus_berry,2,"Keep milestone healing")
	assert_eq(brock.leppa_berry,1)
	assert_eq(brock.lum_berry,1)

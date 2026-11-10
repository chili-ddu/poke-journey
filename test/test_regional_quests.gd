extends GutTest
const Regional = preload("res://scripts/story/regional_quests.gd")

func quest(id: String, starter: String="charmander") -> Dictionary:
	for value in Regional.quests(starter):
		if value.id==id:return value
	return {}

func test_all_regional_starts_wait_for_saffron_and_have_one_time_rewards() -> void:
	assert_eq(Regional.quests().size(),8)
	var ids: Array=[]
	for value in Regional.quests():
		assert_false(ids.has(value.id));ids.append(value.id)
		assert_has(value.requires,"visited_area_saffron_city")
		assert_gt(value.stages.size(),0)
		assert_gt(value.reward.size(),0)
		assert_gt(value.xp_levels,0.0)
		for id in value.reward:assert_true(ItemDB.has_item(id),id)

func test_forest_is_accepted_at_gate_then_fights_both_adult_groups_and_negotiates() -> void:
	var value:=quest("forest_truce")
	assert_eq(value.stages[0].map,"forest_gate_south")
	assert_eq(value.stages[0].sprite,"bug_catcher")
	assert_false(value.stages[0].has("battle"))
	assert_eq(value.stages[0].flag,"forest_truce_accepted")
	var adults: Array=[]
	for opponent in value.stages[1].battle:adults.append(opponent.species)
	assert_has(adults,"butterfree");assert_has(adults,"beedrill")
	assert_false(adults.has("caterpie"));assert_false(adults.has("weedle"))
	assert_true(" ".join(value.stages[1].outro).contains("합의"))
	assert_eq(value.stages.size(),2,"No mandatory return to the boy after the agreement")

func test_museum_visits_registered_floors_and_keeps_cinnabar_cause_uncertain() -> void:
	var value:=quest("museum_fossils")
	assert_eq(value.stages[0].map,"pewter_museum_1f")
	assert_eq(value.stages[1].map,"pewter_museum_2f")
	assert_eq(value.stages[2].map,"pewter_museum_1f")
	assert_true(" ".join(value.stages[2].intro).contains("짐작"))
	assert_eq(value.stages[2].flag,"rumor_cinnabar_research")

func test_daycare_egg_requires_two_berry_gifts_and_full_story_for_every_starter() -> void:
	for starter in SaveData.STARTERS:
		var value:=quest("daycare_courtship",starter)
		assert_eq(value.stages[0].species,starter)
		assert_true(value.stages[0].opposite_sex)
		assert_false(value.stages[0].has("flag"),"Merely visiting never marks the egg")
		assert_eq(value.stages[1].cost,{"oran_berry":2})
		assert_eq(value.stages[2].cost,{"leppa_berry":1})
		assert_eq(value.stages[3].flag,Regional.DAYCARE_EGG)
		assert_eq(value.stages[3].action,"daycare_egg")
		assert_eq(value.completion_flag,Regional.DAYCARE_EGG)
		assert_has(value.unless,"campaign_cycle_2","The child must not court its parent's partner")

func test_eevee_battles_seven_evolutions_and_consults_after_independent_bill_rescue() -> void:
	var value:=quest("eevee_evolution")
	assert_eq(value.stages[0].battle.size(),7)
	assert_eq(value.stages[0].action,"eevee_follow_start")
	assert_has(value.stages[1].requires,"quest_bill_rescue_complete")
	assert_eq(value.stages[1].action,"eevee_follow_end")
	assert_eq(value.completed_companions[0].species,"eevee")
	assert_false(quest("bill_rescue").requires.has("quest_eevee_evolution_complete"))

func test_ditto_is_a_current_growth_mirror_then_promises_before_people_return() -> void:
	var value:=quest("ditto_rumor")
	assert_eq(value.stages[0].map,"lavender_town_pokemon_center_1f")
	assert_eq(value.stages[1].area,"route15")
	assert_eq(value.stages[1].appearance,"player")
	assert_true(value.stages[1].battle[0].mirror)
	assert_eq(value.stages[1].flag,"ditto_promised_no_scares")
	assert_eq(value.stages[2].sprite,"man")
	assert_eq(value.stages[2].companions[0].species,"ditto")

func test_snorlax_wake_cost_is_attainable_and_actor_stands_west_of_barrier() -> void:
	var value:=quest("snorlax_wake")
	assert_eq(value.completion_flag,"route11_snorlax_awakened")
	assert_eq(value.stages[1].cost,{"oran_berry":3})
	assert_lt(value.stages[1].tile.x,10)
	assert_false(value.stages[1].has("battle"))
	assert_eq(value.stages[1].action,"snorlax_wake")

func test_all_story_sprites_and_battle_assets_exist_without_event_stat_multipliers() -> void:
	for value in Regional.quests():
		for stage in value.stages:
			if stage.has("sprite"):assert_true(ResourceLoader.exists("res://assets/npcs/%s.png"%stage.sprite))
			if stage.has("species"):
				assert_true(SpeciesDB.has_species(stage.species))
				assert_true(MonSprite.load_set(int(SpeciesDB.get_species(stage.species).dex)).has("Walk"))
			for foe in stage.get("battle",[]):
				assert_true(SpeciesDB.has_species(foe.species))
				assert_false(foe.has("hp_scale"));assert_false(foe.has("damage_scale"))
				for move in foe.get("moves",[]):assert_true(MoveDB.is_shaped(move),move)
				if not foe.get("mirror",false):assert_lte(foe.min,foe.max)

func test_authored_actor_and_companion_tiles_are_walkable_and_do_not_cover_doors() -> void:
	var keep:=DungeonDB.current
	for value in Regional.quests():
		for stage in value.stages:
			var place:=String(stage.get("map","kanto_world"))
			DungeonDB.set_current(place);Arena.configure(DungeonDB.theme())
			var offset:=Vector2i.ZERO
			if stage.has("area"):offset=Arena.area_rect(String(stage.area)).position
			var targets: Array=[stage]
			targets.append_array(stage.get("companions",[]))
			for target in targets:
				var tile: Vector2i=target.tile+offset
				assert_false(Arena.solid_at(tile.x,tile.y),"%s actor/companion %s"%[value.id,tile])
				assert_true(Arena.warp_at(Arena.tile_center(tile)).is_empty(),"%s cannot occupy an exit"%value.id)
	DungeonDB.set_current(keep);Arena.configure(DungeonDB.theme())


func test_second_cycle_forest_reunion_preserves_the_parent_agreement() -> void:
	var original:=quest("forest_truce")
	var reunion:=quest("forest_descendants")
	assert_has(original.unless,"campaign_parent_forest_truce")
	assert_has(reunion.requires,"campaign_cycle_2")
	assert_has(reunion.requires,"campaign_parent_forest_truce")
	assert_eq(reunion.stages[0].sprite,"bug_catcher")
	assert_eq(reunion.stages[1].battle.size(),2)
	assert_true(" ".join(reunion.stages[1].intro).contains("친선"))
	assert_gte(reunion.ng_plus_xp_levels,1.0)

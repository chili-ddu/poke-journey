extends GutTest
const Bird=preload("res://scripts/story/bird_event.gd")

func test_all_registered_species_have_one_valid_pokedex_height_tier() -> void:
	var counts: Dictionary={}
	for id in SpeciesDB.all_ids():
		var species:=SpeciesDB.get_species(id)
		assert_gt(int(species.height_dm),0,id)
		assert_between(int(species.size_tier),1,8,id)
		assert_eq(int(species.size_tier),PokemonSize.tier_for_height(int(species.height_dm)),id)
		assert_gt(float(species.display_span),0.0,id)
		assert_lte(float(species.radius),11.5,id+" fits a one-tile door")
		counts[int(species.size_tier)]=int(counts.get(int(species.size_tier),0))+1
	assert_eq(SpeciesDB.all_ids().size(),493)
	assert_eq(counts.size(),8,"All eight tiers contain species")

func test_tier_boundaries_are_contiguous_and_large_lengths_are_compressed() -> void:
	for pair in [[1,1],[3,1],[4,2],[6,2],[7,3],[10,3],[11,4],[14,4],[15,5],[20,5],[21,6],[30,6],[31,7],[50,7],[51,8],[145,8]]:
		assert_eq(PokemonSize.tier_for_height(pair[0]),pair[1])
	var tiers:=PokemonSize.tiers()
	assert_eq(tiers.size(),8)
	for i in range(1,8):
		assert_gt(float(tiers[i].display_span),float(tiers[i-1].display_span))
		assert_gt(float(tiers[i].radius),float(tiers[i-1].radius))
	assert_eq(float(PokemonSize.profile("onix").display_span),88.0)
	assert_eq(float(PokemonSize.profile("wailord").display_span),88.0)

func test_visible_walking_silhouettes_match_tiers_without_pose_resizing() -> void:
	for species in ["caterpie","charmander","bulbasaur","charmeleon","charizard","lapras","dragonair","onix"]:
		var mon:=Mon.new();mon.setup(species,20,Mon.TEAM_PLAYER)
		assert_almost_eq(float(mon._sprites.reference_span)*mon.sprite_scale,mon.display_span,0.001,species)
		var scale:=mon.sprite_scale
		for facing in [Vector2.UP,Vector2.LEFT,Vector2.DOWN,Vector2.RIGHT]:
			mon.facing=facing;mon.play_attack("Attack")
			assert_eq(mon.sprite_scale,scale,"Changing direction or action cannot change body size")
		mon.free()
	var charmander:=Mon.new();charmander.setup("charmander",5,Mon.TEAM_PLAYER)
	assert_eq(charmander.sprite_scale,1.0,"The existing Charmander visual calibration stays intact")
	charmander.free()

func test_shiny_and_normal_keep_the_same_size_and_ground_support() -> void:
	for species in ["charmander","blastoise","venusaur","lapras","onix"]:
		var normal:=Mon.new();normal.setup(species,20,Mon.TEAM_ENEMY)
		var shiny:=Mon.new();shiny.shiny=true;shiny.setup(species,20,Mon.TEAM_ENEMY)
		assert_eq(shiny.sprite_scale,normal.sprite_scale,species)
		assert_eq(shiny.size_tier,normal.size_tier)
		assert_eq(shiny.radius,normal.radius)
		normal.free();shiny.free()

func test_evolution_recomputes_size_and_preserves_growth_and_hp_ratio() -> void:
	var player:=Player.new();player.setup_player("charmander",36,["scratch"],{})
	player.hp=maxi(1,int(player.max_hp*0.6))
	var exp_before:=player.exp_total;var pp_before:=player.pp.duplicate();var bag_before:=player.bag.duplicate(true)
	player.evolve_to("charmeleon")
	assert_eq(player.size_tier,4);assert_eq(player.display_span,34.0)
	var ratio:=player.hp_ratio()
	player.evolve_to("charizard")
	assert_eq(player.size_tier,5);assert_eq(player.display_span,40.0)
	assert_almost_eq(player.hp_ratio(),ratio,0.02)
	assert_eq(player.exp_total,exp_before);assert_eq(player.pp,pp_before);assert_eq(player.bag,bag_before)
	assert_almost_eq(player.sprite_scale*float(player._sprites.reference_span),40.0,0.001)
	player.free()

func test_carrier_selection_uses_shared_size_tier_and_not_collision_radius() -> void:
	for id in ["caterpie","charmander","bulbasaur","charmeleon","charizard","blastoise","onix"]:
		var mon:=Mon.new();mon.setup(id,20,Mon.TEAM_PLAYER)
		var expected: String="pidgeot" if mon.size_tier>=4 else "pidgeotto"
		assert_eq(Bird.carrier(mon),expected,id)
		mon.radius=1.0
		assert_eq(Bird.carrier(mon),expected,"Ground-footprint changes cannot choose a weaker carrier")
		mon.free()

func test_every_tier_passes_a_one_tile_corridor() -> void:
	var before:=Arena.theme
	var place:=DungeonDB.current
	DungeonDB.set_current("oaks_lab");Arena.configure(DungeonDB.theme())
	# Verify the core circle resolver in an isolated synthetic one-tile passage.
	Arena.map={"width":5,"height":5,"start":Vector2(60,60)}
	Arena._solid.resize(25);Arena._solid.fill(1);Arena._ledge.resize(25);Arena._ledge.fill(0);Arena._water.clear()
	for y in 5:Arena._solid[y*5+2]=0
	for tier in PokemonSize.tiers():
		for y in [36.0,48.0,60.0,72.0,84.0]:
			var point:=Vector2(60,y)
			assert_almost_eq(Arena.resolve(point,float(tier.radius)).distance_to(point),0.0,0.001)
	DungeonDB.set_current(place);Arena.configure(before)

func test_species_without_art_still_receive_the_common_size_profile() -> void:
	var mon:=Mon.new();mon.setup("wailord",40,Mon.TEAM_PLAYER)
	assert_eq(mon.size_tier,8);assert_eq(mon.display_span,88.0)
	assert_eq(mon.radius,11.5);assert_gt(mon.sprite_scale,1.0)
	mon.free()

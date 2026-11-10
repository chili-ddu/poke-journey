extends GutTest
const Rules = preload("res://scripts/johto/visual_style_rules.gd")
const Collection = preload("res://scripts/johto/hgss_map_collection.gd")

func test_actual_forest_and_cave_use_distinct_profiles_despite_shared_cave_map_type() -> void:
	var maps := Collection.new()
	assert_eq(Rules.profile(maps.manifest.headers["117"]),"forest")
	assert_eq(Rules.profile(maps.manifest.headers["99"]),"cave")
	assert_eq(Rules.profile(maps.manifest.headers["76"]),"outdoor")
	var pallet := Collection.new("res://assets/maps/hgss_pallet_sample/")
	assert_eq(Rules.profile(pallet.manifest.headers["505"]),"indoor")

func test_all_profiles_preserve_the_common_camera_and_only_change_post_parameters() -> void:
	var data := Rules.data()
	assert_eq(float(data.camera.elevation),40.0)
	assert_eq(int(data.world_pixels_per_tile),Arena.TILE)
	assert_eq(data.viewport,[384.0,216.0])
	var material := ShaderMaterial.new()
	material.shader=load("res://assets/shaders/hd2d_post.gdshader")
	for kind in data.profiles:
		Rules.apply(material,kind)
		assert_eq(float(material.get_shader_parameter("bloom_strength")),float(data.profiles[kind].bloom_strength))
		assert_eq(float(material.get_shader_parameter("blur_px")),float(data.profiles[kind].blur_px))
		assert_eq(typeof(material.get_shader_parameter("light_tint")),TYPE_VECTOR3)

func test_game_profiles_distinguish_caves_from_indoor_random_encounters() -> void:
	for place in ["mt_moon_1f","arena_mt_moon","rock_tunnel_b1f","digletts_cave_b1f","seafoam_islands_b4f"]:
		assert_eq(Rules.game_profile(place),"cave",place)
	assert_eq(Rules.game_profile("viridian_forest"),"forest")
	assert_eq(Rules.game_profile("oaks_lab"),"indoor")
	assert_eq(Rules.game_profile("kanto_world"),"outdoor")
	assert_ne(Rules.game_profile("power_plant"),"cave","Encounter terrain is not a visual cave classification")
	assert_ne(Rules.game_profile("pokemon_mansion_1f"),"cave")

func test_real_game_post_processing_uses_shared_profile_and_preserves_battle_focus() -> void:
	const Game = preload("res://scripts/game.gd")
	var original_place := DungeonDB.current
	var game := Game.new()
	game.look_rect = ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/hd2d_post.gdshader")
	game.look_rect.material = material
	for place in ["viridian_forest","mt_moon_1f","oaks_lab","kanto_world"]:
		DungeonDB.set_current(place)
		game._apply_look()
		var expected: Dictionary = Rules.data().profiles[Rules.game_profile(place)]
		assert_almost_eq(float(material.get_shader_parameter("saturation")),float(expected.saturation),0.0001,place)
		assert_almost_eq(float(material.get_shader_parameter("bloom_strength")),float(expected.bloom_strength),0.0001,place)
	Rules.apply_game(material,"arena_mt_moon",true)
	assert_almost_eq(float(material.get_shader_parameter("band_top")),0.14,0.0001)
	assert_almost_eq(float(material.get_shader_parameter("blur_px")),2.0,0.0001)
	assert_almost_eq(float(material.get_shader_parameter("bloom_strength")),0.06,0.0001)
	game.look_rect.free()
	game.free()
	DungeonDB.set_current(original_place)

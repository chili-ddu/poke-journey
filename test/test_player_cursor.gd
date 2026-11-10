extends GutTest

func test_window_exit_and_focus_loss_restore_default_until_mouse_reenters() -> void:
	var player:=Player.new();player.setup_player("charmander",16,[]);add_child_autofree(player)
	var cursor:=PlayerCursor.new();add_child_autofree(cursor);cursor.setup(player)
	var window:=cursor.get_window()
	assert_true(window.mouse_entered.is_connected(cursor._on_mouse_entered))
	assert_true(window.mouse_exited.is_connected(cursor._on_mouse_exited))
	window.mouse_entered.emit()
	assert_true(cursor.using_custom_cursor())
	window.mouse_exited.emit()
	assert_false(cursor.using_custom_cursor())
	player.evolve_to("charmeleon");cursor._process(0.0)
	assert_eq(cursor.current_species,"charmeleon")
	assert_false(cursor.using_custom_cursor(),"Evolving while the pointer is outside cannot reapply a custom cursor")
	window.mouse_entered.emit()
	assert_true(cursor.using_custom_cursor())
	assert_eq(cursor.current_texture.resource_path,PlayerCursor.entry_for("charmeleon").texture)
	window.focus_exited.emit()
	assert_false(cursor.using_custom_cursor(),"Switching to another app also restores the pointer")
	cursor._process(0.0)
	assert_false(cursor.using_custom_cursor(),"Regular refresh must preserve the outside state")
	window.mouse_entered.emit()
	assert_true(cursor.using_custom_cursor())

func test_each_starter_line_updates_cursor_after_actual_evolution() -> void:
	for line in [["charmander","charmeleon","charizard"],["squirtle","wartortle","blastoise"],["bulbasaur","ivysaur","venusaur"]]:
		var player:=Player.new()
		player.setup_player(line[0],36,[])
		add_child_autofree(player)
		var cursor:=PlayerCursor.new();add_child_autofree(cursor);cursor.setup(player)
		for species in line:
			if player.species_id!=species:player.evolve_to(species)
			cursor._process(0.0)
			assert_eq(cursor.current_species,species)
			assert_not_null(cursor.current_texture)
			assert_eq(cursor.current_texture.get_size(),Vector2(40,40))
			var image:=cursor.current_texture.get_image()
			assert_eq(image.get_pixelv(Vector2i(cursor.hotspot)),Color(PlayerCursor.entry_for(species).color),"The pointer hits the top colored toe, not transparent padding")
			var texture:=cursor.current_texture
			cursor._process(0.0)
			assert_same(cursor.current_texture,texture,"Unchanged species reuse the native cursor")

func test_unknown_species_restores_default_instead_of_borrowing_another_footprint() -> void:
	var player:=Player.new();player.setup_player("charmander",5,[]);add_child_autofree(player)
	var cursor:=PlayerCursor.new();add_child_autofree(cursor);cursor.setup(player)
	assert_not_null(cursor.current_texture)
	player.species_id="pikachu";cursor.refresh()
	assert_null(cursor.current_texture)
	assert_eq(cursor.hotspot,Vector2.ZERO)
	player.species_id="squirtle";cursor.refresh()
	assert_eq(cursor.current_species,"squirtle")
	assert_not_null(cursor.current_texture)

func test_game_installs_cursor_for_human_and_follows_evolution_signal() -> void:
	var script=load("res://scripts/game.gd")
	var old_path:=SaveData.path;SaveData.path="user://save_player_cursor_test.cfg";SaveData.clear()
	var old_starter: String=script.starter;script.starter="charmander"
	var old_bot:=OS.get_environment("BOT");var old_map:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0");OS.set_environment("DUNGEON","pewter_gym")
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",old_bot);OS.set_environment("DUNGEON",old_map)
	assert_not_null(game.player_cursor)
	assert_eq(game.player_cursor.current_species,"charmander")
	game.evolve_to="charmeleon";game._on_evolved();game.player_cursor._process(0.0)
	assert_eq(game.player_cursor.current_species,"charmeleon")
	assert_eq(game.player_cursor.current_texture.resource_path,PlayerCursor.entry_for("charmeleon").texture)
	SaveData.clear();SaveData.path=old_path;script.starter=old_starter
	script.destination={};script.arena_trip={};script.carry={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

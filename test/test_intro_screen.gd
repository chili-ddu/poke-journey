extends GutTest
const Intro = preload("res://scripts/ui/intro_screen.gd")
const Surface = preload("res://scripts/ui/intro_surface.gd")
signal download_finished
var intro: Control
var result := OK
var had_sfx := false

class SelectionIntro:
	extends Intro
	var entries := 0
	func _enter_selection() -> void:entries+=1

func before_each() -> void:
	result=OK
	had_sfx=is_instance_valid(Sfx._inst)
	intro=SelectionIntro.new()
	intro.prepare_override=func():
		await download_finished
		return result
	add_child_autofree(intro)

func after_each() -> void:
	if intro.phase=="loading":download_finished.emit()
	intro.surface.stop_battle()
	await get_tree().process_frame
	if not had_sfx and is_instance_valid(Sfx._inst):
		Sfx._inst.free()
		Sfx._inst=null
	await get_tree().process_frame

func finish_download() -> void:
	await get_tree().process_frame
	download_finished.emit()

func key(code: int,pressed: bool=true,echo: bool=false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode=code;event.pressed=pressed;event.echo=echo
	return event

func test_press_start_stays_hidden_and_input_is_not_queued() -> void:
	intro._input(key(KEY_SPACE))
	assert_eq(intro.surface.phase,"loading")
	assert_false(intro.launching)
	await finish_download()
	assert_eq(intro.surface.phase,"ready")
	intro._input(key(KEY_SPACE,true,true))
	intro._input(key(KEY_SPACE,false))
	assert_false(intro.launching,"Held keys and releases never start")
	intro._input(key(KEY_ENTER))
	intro._input(key(KEY_SPACE))
	await get_tree().process_frame
	assert_eq(intro.entries,1,"Fresh input starts exactly once")

func test_failed_download_retries_without_entering_selection() -> void:
	result=ERR_CANT_OPEN
	await finish_download()
	assert_eq(intro.surface.phase,"error")
	intro.activate()
	assert_eq(intro.phase,"loading")
	assert_false(intro.launching)
	result=OK
	download_finished.emit()
	assert_eq(intro.phase,"ready")
	assert_eq(intro.entries,0)

func test_mouse_touch_and_pad_have_the_same_start_gate() -> void:
	var mouse := InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true
	var touch := InputEventScreenTouch.new()
	touch.pressed=true
	var pad := InputEventJoypadButton.new()
	pad.button_index=JOY_BUTTON_START;pad.pressed=true
	for event in [mouse,touch,pad]:intro._input(event)
	assert_false(intro.launching)
	await finish_download()
	intro._input(pad)
	assert_true(intro.launching)
	await get_tree().process_frame
	assert_eq(intro.entries,1)

func test_intro_uses_common_stats_and_actual_three_way_combat() -> void:
	intro.surface.set_process(false)
	var world: World=intro.surface.world
	assert_false(world.god)
	assert_false(world.progression_enabled)
	for mon: Mon in [world.player]+world.enemies:
		assert_eq(mon.max_hp,int(SpeciesDB.stats_at(mon.species_id,12,mon.ivs).hp))
		assert_eq(world.opponents(mon.team).size(),2)
	for frame in 840:world.step(1.0/60.0)
	for species in ["charmander","bulbasaur","squirtle"]:
		var used := false
		for cast: String in world.casts:if cast.begins_with(species+":"):used=true
		assert_true(used,species+" really casts")
	intro.surface.stop_battle()
	assert_null(intro.surface.host)
	assert_null(intro.surface.world)

func test_npcs_keep_fighting_when_the_player_starter_has_fainted() -> void:
	intro.surface.set_process(false)
	var world: World=intro.surface.world
	# A particular three-way winner is not fixed. Isolate the surviving NPC duel.
	world.player.dead=true
	world.player.hp=0
	for frame in 840:world.step(1.0/60.0)
	assert_true(world.damage_pairs.has("1>2") or world.damage_pairs.has("2>1"),"NPCs actually damage each other without a living player target")

func test_transition_uses_only_the_lightweight_ball_cover() -> void:
	var transition := preload("res://scripts/ui/title_game_transition.gd").new()
	var theme: Dictionary=Arena.theme.duplicate(true)
	add_child_autofree(transition)
	assert_eq(transition.overlay.get_script(),preload("res://scripts/ui/loading_cover.gd"))
	assert_false(transition.overlay.has_method("start_battle"))
	assert_eq(transition.overlay.get_child_count(),0,"Loading does not create another battle or start button")
	assert_eq(Arena.theme,theme,"A loading cover cannot replace the active map")

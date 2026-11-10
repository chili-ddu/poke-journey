extends "res://tools/kanto_expansion_review.gd"
const HINT_OUT := "res://docs/berry_hint_review/"
func press_skill(key: int) -> void:
	var event := InputEventKey.new()
	event.pressed=true
	event.physical_keycode=key
	game._unhandled_input(event)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HINT_OUT))
	await CaptureWindow.park(self)
	SaveData.path="user://save_berry_hint_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	await open_fixture("viridian_forest")
	var w: World=game.world
	w.player.position=Arena.tile_center(Vector2i(5,16))
	w.player.controller=Controllers.Human.new()
	w.player.learn("growl",1)
	w.player.learn("ember",2)
	w.player.hotbar=["oran_berry","leppa_berry","pecha_berry","lum_berry"]
	w.player.bag={"oran_berry":3,"leppa_berry":3,"pecha_berry":2,"lum_berry":1}
	w.player.hp=5
	w.player.poison_t=10.0
	w.player.pp[2]=0
	w.player.pp[0]=0
	press_skill(KEY_E)
	assert(w.player.pp_focus_slot==2 and w.berry_pp_slot()==2)
	assert(w.berry_needs_attention("oran_berry") and w.berry_needs_attention("leppa_berry") and w.berry_needs_attention("pecha_berry") and w.berry_needs_attention("lum_berry"))
	game.hud.set_process(false)
	game.hud._berry_clock=0.0
	await shot("low_hp_zero_pp_baseline")
	game.hud._berry_clock=0.18
	await shot("low_hp_zero_pp_bounce")
	var scratch_pp: int=w.player.pp[0]
	w._use_hotbar(1,false)
	assert(w.player.pp[2]==10 and w.player.pp[0]==scratch_pp,"Hotkey restores last pressed E, not empty Q")
	assert(w.player.bag.leppa_berry==2)
	assert(game.menu.is_empty(),"No PP target modal")
	assert(not w.player.controller.hold,"Hotkey recovery does not lock held combat input")
	assert(w.player.pp_focus_slot==2)
	await shot("last_pressed_pp_restored")
	w.player.berry_cd=0.0
	press_skill(KEY_W)
	assert(w.berry_pp_slot()==-1,"Full W remains selected instead of switching to empty Q")
	var before: int=w.player.bag.leppa_berry
	w._use_hotbar(1,false)
	assert(w.player.bag.leppa_berry==before)
	assert(w.player.pp[0]==0)
	await shot("full_selected_no_redirect")
	w.player.hp=w.player.max_hp
	w.player.poison_t=0.0
	assert(not w.berry_needs_attention("oran_berry") and not w.berry_needs_attention("pecha_berry") and not w.berry_needs_attention("leppa_berry"))
	await shot("recovered_no_bounce")
	# The bag follows the same current selection, without opening a target picker.
	w.player.controller.hold=false
	press_skill(KEY_Q)
	game._open_bag()
	game._on_bag_used("leppa_berry")
	assert(w.player.pp[0]==10 and game.menu.is_empty())
	assert(w.player.pp_focus_slot==0)
	game._carry_out()
	assert(load("res://scripts/game.gd").carry.pp_focus_slot==0)
	var file := FileAccess.open(HINT_OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"zero_pp_selection":true,"last_pressed_recovery":true,"no_modal":true,"full_target_not_redirected":true,"hp_pp_status_hints":true,"vertical_bounce":true,"bag_same_target":true,"no_input_lock":true,"carry_focus":true,"hd2d":game.view3d!=null},"\t"));file.close()
	print("BERRY HINT REVIEW PASSED")
	quit()
func shot(label: String) -> void:
	game._update_dialogue_focus()
	game.queue_redraw()
	game.hud.queue_redraw()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(HINT_OUT+label+".png")

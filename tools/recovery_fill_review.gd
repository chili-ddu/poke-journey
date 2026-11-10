extends "res://tools/kanto_expansion_review.gd"
const FILL_OUT := "res://docs/recovery_fill_review/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FILL_OUT))
	await CaptureWindow.park(self)
	SaveData.path="user://save_recovery_fill_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	await open_fixture("viridian_forest")
	var w: World=game.world
	var hud: Hud=game.hud
	w.player.position=Arena.tile_center(Vector2i(5,16))
	walker.target=w.player.position
	w.player.learn("ember",2)
	w.player.select_skill(2)
	w.player.hotbar=["oran_berry","leppa_berry","",""]
	w.player.bag={"oran_berry":2,"leppa_berry":2}
	w.player.hp=2
	w.player.pp[2]=0
	hud.set_process(false)
	hud._update_recovery_fill(0.0)
	await shot("before_recovery")
	assert(w.use_item("oran_berry")=="")
	var healed: int=w.player.hp
	hud._update_recovery_fill(0.0)
	assert(hud._hp_fill_display.value==2.0 and healed>2,"HP changed immediately, display starts at prior level")
	hud._update_recovery_fill(0.11)
	assert(hud._hp_fill_display.value>2.0 and hud._hp_fill_display.value<healed)
	await shot("hp_halfway")
	hud._update_recovery_fill(0.11)
	assert(hud._hp_fill_display.value==healed)
	await shot("hp_complete")
	w.player.berry_cd=0.0
	assert(w.use_item("leppa_berry")=="")
	assert(w.player.pp[2]==10)
	hud._update_recovery_fill(0.0)
	assert(hud._pp_fill_display[2].value==0.0)
	hud._update_recovery_fill(0.09)
	assert(is_equal_approx(hud._pp_fill_display[2].value,5.0))
	assert(w.player.pp_focus_slot==2)
	await shot("pp_halfway")
	hud._update_recovery_fill(0.09)
	assert(hud._pp_fill_display[2].value==10.0)
	await shot("pp_complete")
	# An interrupted visual must never conceal the real cost/damage.
	w.player.hp=w.player.max_hp
	hud._update_recovery_fill(0.05)
	w.player.hp=4
	hud._update_recovery_fill(0.0)
	assert(hud._hp_fill_display.value==4.0)
	w.player.pp[2]=0
	hud._update_recovery_fill(0.0)
	assert(hud._pp_fill_display[2].value==0.0)
	await shot("damage_and_pp_cost_immediate")
	var file := FileAccess.open(FILL_OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"hp_duration":0.22,"pp_duration":0.18,"actual_values_immediate":true,"partial_fill_visible":true,"damage_and_cost_immediate":true,"selection_preserved":true,"hd2d":game.view3d!=null},"\t"));file.close()
	print("RECOVERY FILL REVIEW PASSED")
	quit()
func shot(label: String) -> void:
	game._update_dialogue_focus()
	game.queue_redraw()
	game.hud.queue_redraw()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(FILL_OUT+label+".png")

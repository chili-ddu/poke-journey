extends "res://tools/kanto_expansion_review.gd"
const EFFECT_OUT := "res://docs/kanto_contact_fx_review/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EFFECT_OUT))
	await CaptureWindow.park(self)
	SaveData.path="user://save_kanto_contact_fx_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	for entry in [["pound","clefairy"],["pound","poliwag"],["pound","poliwhirl"],["peck","spearow"],["peck","nidoran_m"],["peck","goldeen"],["astonish","zubat"]]:
		await open_fixture("arena_viridian_forest")
		var w: World=game.world
		w.player.set_level(25)
		w.player.hp=w.player.max_hp
		game.ui_root.visible=false
		var source := Enemy.new()
		source.setup_enemy(entry[1],16,w.rng)
		var direction := Vector2.RIGHT if entry[1] in ["clefairy","poliwhirl","nidoran_m","zubat"] else Vector2.DOWN
		source.position=Arena.resolve(w.player.position-direction*32,source.radius)
		direction=(w.player.position-source.position).normalized()
		source.facing=direction
		w.add_child(source);w.enemies.append(source)
		for i in 3:await process_frame
		var before: int=w.player.hp
		var origin := source.position
		w.cast(source,entry[0],direction,w.player.position)
		source.play_attack(String(MoveDB.get_move(entry[0]).get("anim","Attack")))
		var hit_frame := -1
		var min_gap := INF
		for frame in 90:
			var dt := 1.0/60.0
			w._tick_impact_camera(dt)
			w._tick_status(dt)
			w._step_pending_melee(dt)
			w._step_pending_calls(dt)
			w._move_mons(dt)
			w.step_fx(dt)
			min_gap=minf(min_gap,source.position.distance_to(w.player.position))
			if w.player.hp<before and hit_frame<0:hit_frame=frame
			if frame==2:await shot(entry[0]+"_"+entry[1]+"_ready")
			if hit_frame>=0 and frame-hit_frame in [0,6,14]:await shot(entry[0]+"_"+entry[1]+"_hit%02d"%(frame-hit_frame))
			if frame%4==0:await process_frame
		assert(hit_frame>=0,"Actual contact "+str(entry))
		assert(source.hop_t==0.0,"Grounded")
		assert(not source.attack_lunge,"No end teleport")
		assert(min_gap>=source.radius+w.player.radius-0.1,"No body overlap")
		results.append({"move":entry[0],"caster":entry[1],"real_cast":true,"hd2d":game.view3d!=null,"hit_frame":hit_frame,"step":source.position.distance_to(origin),"min_gap":min_gap})
	var file := FileAccess.open(EFFECT_OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"));file.close()
	print("KANTO CONTACT FX REVIEW PASSED: ",results.size()," cast cases")
	quit()
func shot(label: String) -> void:
	game.queue_redraw()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(EFFECT_OUT+label+".png")

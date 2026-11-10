extends "res://tools/kanto_expansion_review.gd"
const EFFECT_OUT := "res://docs/kanto_move_fx_review/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EFFECT_OUT))
	await CaptureWindow.park(self)
	SaveData.path="user://save_kanto_move_fx_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	for entry in [["absorb","zubat"],["absorb","oddish"],["mega_drain","oddish"],["acid","oddish"],["acid","tentacool"],["supersonic","zubat"],["supersonic","tentacool"]]:
		await open_fixture("arena_viridian_forest")
		var w: World=game.world
		w.player.set_level(25)
		w.player.hp=w.player.max_hp
		game.ui_root.visible=false
		var source := Enemy.new()
		source.setup_enemy(entry[1],16,w.rng)
		var direction := Vector2.RIGHT if entry[1]!="tentacool" else Vector2.DOWN
		source.position=Arena.resolve(w.player.position-direction*60,source.radius)
		direction=(w.player.position-source.position).normalized()
		source.facing=direction
		source.hp=1
		w.add_child(source);w.enemies.append(source)
		for i in 3:await process_frame
		var before: int=w.player.hp
		w.cast(source,entry[0],direction,w.player.position)
		source.play_attack(String(MoveDB.get_move(entry[0]).get("anim","Attack")),0.4)
		var marks: Array=[5,19] if entry[0]=="acid" else [5,13]
		for frame in 57:
			var dt := 1.0/60.0
			w._tick_status(dt)
			w._step_pending_casts(dt)
			w._step_pending_calls(dt)
			w._step_projectiles(dt)
			if entry[0] in ["absorb","mega_drain"] and frame in range(3,11):source.position.x+=0.6
			w.step_fx(dt)
			if frame in marks:await shot(entry[0]+"_"+entry[1]+"_%02d"%frame)
			if frame%8==0:await process_frame
		if entry[0]=="supersonic":assert(w.player.confuse_t>0.0)
		else:assert(w.player.hp<before,"Actual hit "+str(entry))
		if entry[0] in ["absorb","mega_drain"]:assert(source.hp>1,"Actual drain healing")
		results.append({"move":entry[0],"caster":entry[1],"real_cast":true,"hd2d":game.view3d!=null})
	var file := FileAccess.open(EFFECT_OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"));file.close()
	print("KANTO MOVE FX REVIEW PASSED: ",results.size()," cast cases")
	quit()
func shot(label: String) -> void:
	game.queue_redraw()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(EFFECT_OUT+label+".png")

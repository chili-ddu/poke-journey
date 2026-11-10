extends "res://tools/kanto_expansion_review.gd"
const EFFECT_OUT := "res://docs/water_fx_review/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EFFECT_OUT))
	await CaptureWindow.park(self)
	SaveData.path="user://save_water_fx_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	for entry in [["water_gun","squirtle"],["water_gun","psyduck"],["water_gun","poliwag"],["water_gun","horsea"],["water_gun","krabby"],["water_pulse","squirtle"],["water_pulse","psyduck"],["water_pulse","tentacool"],["water_pulse","goldeen"]]:
		await open_fixture("arena_viridian_forest")
		var w: World=game.world
		w.player.set_level(25);w.player.max_hp=999;w.player.hp=999
		game.ui_root.visible=false
		var source := Enemy.new()
		source.setup_enemy(entry[1],20,w.rng)
		var direction := Vector2.RIGHT
		if entry[1] in ["psyduck","horsea","tentacool"]:direction=Vector2.DOWN
		elif entry[1]=="goldeen":direction=Vector2(1,1).normalized()
		source.position=Arena.resolve(w.player.position-direction*60,source.radius)
		direction=(w.player.position-source.position).normalized()
		source.facing=direction
		w.add_child(source);w.enemies.append(source)
		for i in 3:await process_frame
		var hp: int=w.player.hp
		w.cast(source,entry[0],direction,w.player.position)
		source.play_attack("Shoot")
		var hit_frame := -1
		var layers_drawn := false
		var peak := 0
		for frame in 57:
			var dt := 1.0/60.0
			w._tick_status(dt)
			w._step_bursts(dt)
			w._step_projectiles(dt)
			w._move_mons(dt)
			w.step_fx(dt)
			await process_frame
			peak=maxi(peak,w.projectiles.size())
			for p in w.projectiles:
				if game.view3d._sprites.has(p.get_instance_id()):
					var ent: Dictionary=game.view3d._sprites[p.get_instance_id()]
					var key: String=p.style+"_1"
					if ent.has(key):layers_drawn=ent[key].texture==Fx.sheet("g4_glow" if p.style=="water" else "g4_ring_q") and ent[key].billboard==BaseMaterial3D.BILLBOARD_DISABLED
			if hit_frame<0 and w.player.hp<hp:hit_frame=frame
			if frame==5:await shot(entry[0]+"_"+entry[1]+"_flight")
			if frame==11 and entry[0]=="water_pulse":await shot(entry[0]+"_"+entry[1]+"_column")
			if hit_frame>=0 and frame-hit_frame in [0,8]:await shot(entry[0]+"_"+entry[1]+"_hit%02d"%(frame-hit_frame))
		assert(hit_frame>=0,"Actual water hit: "+str(entry))
		assert(layers_drawn,"HD-2D native water layers")
		assert(peak==(5 if entry[0]=="water_gun" else 1),"Collision projectile count unchanged")
		results.append({"move":entry[0],"caster":entry[1],"actual_cast":true,"native_layers":layers_drawn,"peak_projectiles":peak,"hit_frame":hit_frame,"hd2d":game.view3d!=null})
	var file := FileAccess.open(EFFECT_OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"));file.close()
	print("WATER FX REVIEW PASSED: ",results.size()," actual cast cases")
	quit()
func shot(label: String) -> void:
	game.queue_redraw()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(EFFECT_OUT+label+".png")

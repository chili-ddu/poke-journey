extends "res://tools/kanto_expansion_review.gd"
const EFFECT_OUT := "res://docs/needle_fx_review/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EFFECT_OUT))
	await CaptureWindow.park(self)
	SaveData.path="user://save_needle_fx_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	for species in ["weedle","beedrill","ekans","nidoran_f","nidoran_m","tentacool"]:
		await open_fixture("arena_viridian_forest")
		var w: World=game.world
		w.player.set_level(25);w.player.hp=w.player.max_hp
		game.ui_root.visible=false
		var source := Enemy.new()
		source.setup_enemy(species,16,w.rng)
		var direction := Vector2.RIGHT
		if species in ["beedrill","tentacool"]:direction=Vector2.DOWN
		elif species=="nidoran_m":direction=Vector2(1,1).normalized()
		source.position=Arena.resolve(w.player.position-direction*60,source.radius)
		direction=(w.player.position-source.position).normalized()
		source.facing=direction
		w.add_child(source);w.enemies.append(source)
		for i in 3:await process_frame
		var hp: int=w.player.hp
		w.cast(source,"poison_sting",direction,w.player.position)
		source.play_attack("Shoot")
		assert(w.projectiles.size()==1)
		var projectile: Projectile=w.projectiles[0]
		var hit_frame := -1
		var drawn_needle := false
		for frame in 57:
			var dt := 1.0/60.0
			w._tick_status(dt)
			w._step_projectiles(dt)
			w._move_mons(dt)
			w.step_fx(dt)
			await process_frame
			if is_instance_valid(projectile) and game.view3d._sprites.has(projectile.get_instance_id()):
				var ent: Dictionary=game.view3d._sprites[projectile.get_instance_id()]
				if ent.has("needle_1"):drawn_needle=ent.needle_1.texture==Fx.sheet("poison_needle")
			if hit_frame<0 and w.player.hp<hp:hit_frame=frame
			if frame==5:await shot(species+"_flight")
			if hit_frame>=0 and frame-hit_frame in [0,6]:await shot(species+"_hit%02d"%(frame-hit_frame))
		assert(hit_frame>=0,"Actual poison-sting hit: "+species)
		assert(drawn_needle,"Thin needle rendered in HD-2D")
		results.append({"caster":species,"actual_cast":true,"custom_needle_3d":drawn_needle,"hit_frame":hit_frame,"hd2d":game.view3d!=null})
	var file := FileAccess.open(EFFECT_OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"));file.close()
	print("NEEDLE FX REVIEW PASSED: ",results.size()," actual cast cases")
	quit()
func shot(label: String) -> void:
	game.queue_redraw()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(EFFECT_OUT+label+".png")

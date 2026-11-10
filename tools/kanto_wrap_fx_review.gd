extends "res://tools/kanto_expansion_review.gd"
const EFFECT_OUT := "res://docs/kanto_wrap_fx_review/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EFFECT_OUT))
	await CaptureWindow.park(self)
	SaveData.path="user://save_kanto_wrap_fx_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	for species in ["charmander","bulbasaur","squirtle","onix"]:
		await open_fixture("arena_viridian_forest")
		var w: World=game.world
		w.player.setup_player(species,25,["scratch"])
		w.player.max_hp=9999;w.player.hp=9999
		game.ui_root.visible=false
		var caster := Enemy.new()
		caster.setup_enemy("ekans",16,w.rng)
		caster.frozen=true
		caster.position=Arena.resolve(w.player.position+Vector2.LEFT*(w.player.radius+caster.radius+3.0),caster.radius)
		caster.facing=Vector2.RIGHT
		w.add_child(caster);w.enemies.append(caster)
		for i in 3:await process_frame
		var attempts := 0
		while w.player.bind_t<=0.0 and attempts<10:
			attempts+=1
			w.cast(caster,"wrap",Vector2.RIGHT,w.player.position)
			caster.play_attack("Attack")
			for frame in 18:await tick(w)
		assert(w.player.bind_t>0.0,"Actual Wrap bind "+species)
		var contact_gap := caster.position.distance_to(w.player.position)-caster.radius-w.player.radius
		assert(contact_gap<=4.01,"Body-contact range")
		assert(w.player.knock==Vector2.ZERO,"Grab does not throw the target")
		var duration: float=w.player.bind_t
		var start := w.player.position
		var damage_ticks := 0
		var moving_seen := false
		await shot(species+"_winding")
		for frame in 600:
			if frame in range(20,44):
				w.player.position=w.resolve_mon(w.player,w.player.position+Vector2(0.8,0.3))
				moving_seen=true
			var hp: int=w.player.hp
			await tick(w)
			if w.player.hp<hp:
				damage_ticks+=1
				if damage_ticks==1:await shot(species+"_squeeze")
			if frame==30:await shot(species+"_moving")
			if frame==125 and species=="onix":caster.dead=true
			if w.player.bind_t<=0.0:break
		assert(w.player.bind_t<=0.0,"Released")
		assert(damage_ticks>0,"Actual residual damage")
		assert(moving_seen and w.player.position.distance_to(start)>5.0,"Moving target")
		for f in w.fxs:assert(f.kind!="wrap","No stale ribbon")
		await shot(species+"_released")
		results.append({"target":species,"actual_cast":true,"contact_gap":contact_gap,"bind_duration":duration,"residual_ticks":damage_ticks,"moved":w.player.position.distance_to(start),"release":"caster_faint" if species=="onix" else "expired","hd2d":game.view3d!=null})
	var file := FileAccess.open(EFFECT_OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"));file.close()
	print("KANTO WRAP FX REVIEW PASSED: ",results.size()," actual cast cases")
	quit()
func tick(w: World) -> void:
	var dt := 1.0/60.0
	w._tick_status(dt)
	w._step_pending_melee(dt)
	w._move_mons(dt)
	w.step_fx(dt)
	await process_frame
func shot(label: String) -> void:
	game.queue_redraw()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(EFFECT_OUT+label+".png")

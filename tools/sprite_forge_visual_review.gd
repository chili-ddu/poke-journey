extends "res://tools/kanto_expansion_review.gd"

const DEST := "res://docs/sprite_forge_audit/native/"

class AuditController:
	extends RefCounted
	var direction := Vector2.ZERO
	var skill := false
	var jump := false
	var target: Mon
	func move_dir(_w): return direction
	func aim_point(w): return target.position if skill and is_instance_valid(target) else w.player.position+Vector2.RIGHT*48
	func want_skill(index,_w):
		if index!=0 or not skill: return false
		skill=false
		return true
	func want_jump(_w):
		var requested := jump
		jump=false
		return requested
	func want_dodge(_w): return false
	func want_item(_w): return false

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	SaveData.path="user://save_sprite_forge_visual_review.cfg"
	for species in ["charmander","bulbasaur","squirtle","pikachu"]:
		await open_fixture("kanto_south")
		game.ui_root.visible=false
		game.world.player.setup_player(species,12,["scratch"])
		game.world.player.position=Arena.tile_center(Vector2i(23,209))
		game.world.player.repel_steps=100000
		game.world.no_skills=false
		game.view3d._cam_ready=false
		var input := AuditController.new()
		game.world.player.controller=input
		var target := Enemy.new()
		target.setup_enemy("chansey",25,game.world.rng)
		target.position=game.world.player.position+Vector2.RIGHT*60
		target.frozen=true
		# frozen stops translation, not Enemy.think; suppress its autonomous casts
		# so Hop/Hurt phases cannot be contaminated by an unscheduled attack.
		for move in target.cds: target.cds[move]=99999.0
		game.world.add_child(target);game.world.enemies.append(target)
		input.target=target
		var output: String=DEST+species+"/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		var trace := []
		for frame in 180:
			input.direction=Vector2.RIGHT if frame>=12 and frame<36 else Vector2.ZERO
			if frame==40:
				target.position=game.world.player.position+Vector2.RIGHT*28
				input.skill=true
			if frame==104: input.jump=true
			if frame==145:
				game.world.apply_hit(game.world.player,game.world.make_hit(target,"tackle"),target.position)
			game.world.step(1.0/60.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var mon: Mon=game.world.player
			trace.append({"frame":frame,"animation":mon._anim_name,
				"position":[mon.position.x,mon.position.y],"walk_phase":mon._walk_visual_time,
				"attack_left":mon.attack_anim_t,"hop_left":mon.hop_t,"hurt_left":mon.hurt_t})
			if frame%2==0: root.get_texture().get_image().save_png(output+"%03d.png"%(frame/2))
		assert(trace.any(func(t): return t.animation=="Walk"))
		assert(trace.any(func(t): return t.attack_left>0.0),"Real controller must start the attack")
		assert(trace.any(func(t): return t.hop_left>0.0))
		assert(trace.any(func(t): return t.hurt_left>0.0))
		for frame in range(104,127): assert(trace[frame].animation=="Hop","Review jump must not be interrupted by dummy AI")
		assert(trace.slice(145).any(func(t): return t.animation=="Hurt"),"Scheduled incoming hit must show Hurt")
		assert(DisplayServer.window_get_size()==Vector2i(384,216))
		FileAccess.open(output+"trace.json",FileAccess.WRITE).store_string(JSON.stringify(trace,"  "))
		print("FORGE NATIVE ",species,": idle, movement, real input Scratch/Hop, incoming Hurt")
	game.free()
	quit()

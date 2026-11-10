extends "res://tools/kanto_expansion_review.gd"

const DEST := "res://docs/pokemon_2x_rollout/native/"
const SPECIES := ["charmander", "charizard", "bulbasaur", "pikachu", "onix", "gyarados", "umbreon", "unown", "lugia", "rayquaza", "empoleon", "arceus"]

class Controller:
	extends RefCounted
	var direction := Vector2.ZERO
	var skill := false
	var jump := false
	var target: Mon
	func move_dir(_w): return direction
	func aim_point(w): return target.position if is_instance_valid(target) else w.player.position+Vector2.RIGHT*22
	func want_skill(i,_w):
		if i != 0 or not skill: return false
		skill=false
		return true
	func want_jump(_w):
		var value:=jump; jump=false
		return value
	func want_dodge(_w): return false
	func want_item(_w): return false

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_pokemon_motion_2x_visual.cfg"
	OS.set_environment("BOT","1"); OS.set_environment("GOD","1"); OS.set_environment("SEED","7")
	await open_fixture("kanto_south")
	if game.view3d == null:
		push_error("Native motion review requires the real HD-2D renderer")
		quit(1)
		return
	game.ui_root.visible=false
	var origin: Vector2=game.world.player.position
	var report:=[]
	for sid in SPECIES:
		game.world.player.shiny=false
		game.world.player.setup_player(sid,20,["scratch"])
		game.world.player.position=origin
		game.world.player.repel_steps=100000
		game.world.player.hurt_t=0.0; game.world.player.hop_t=0.0
		game.world.no_skills=false; game.view3d._cam_ready=false
		for enemy in game.world.enemies: enemy.queue_free()
		game.world.enemies.clear()
		var target:=Enemy.new();target.setup_enemy("chansey",70,game.world.rng)
		# Keep the idle/gait/jump readable. Bring the dummy into contact only
		# for the attack; a large Chansey must not cover the reviewed actor.
		target.position=origin+Vector2.RIGHT*160;target.frozen=true
		for move in target.cds: target.cds[move]=99999.0
		game.world.add_child(target);game.world.enemies.append(target)
		var input:=Controller.new();input.target=target
		game.world.player.controller=input
		var folder: String=DEST+sid+"/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		var trace:=[]
		for frame in 168:
			input.direction=Vector2.RIGHT if frame>=16 and frame<40 else Vector2.ZERO
			if frame==44:
				target.position=game.world.player.position+Vector2.RIGHT*22;input.skill=true
			if frame==90: target.position=game.world.player.position+Vector2.RIGHT*160
			if frame==98: input.jump=true
			if frame==139: game.world.apply_hit(game.world.player,game.world.make_hit(target,"tackle"),target.position)
			game.world.step(1.0/60.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var mon: Mon=game.world.player
			trace.append({"frame":frame,"animation":mon._anim_name,"attack":mon.attack_anim_t,"hop":mon.hop_t,"hurt":mon.hurt_t,"position":[mon.position.x,mon.position.y]})
			if frame%3==0: root.get_texture().get_image().save_png(folder+"%03d.png"%(frame/3))
		assert(DisplayServer.window_get_size()==Vector2i(384,216))
		assert(trace.any(func(t):return t.animation=="Walk"))
		assert(trace.any(func(t):return t.attack>0.0))
		assert(trace.any(func(t):return t.hop>0.0))
		var gait_distance:=Vector2(float(trace[39].position[0]),float(trace[39].position[1])).distance_to(Vector2(float(trace[16].position[0]),float(trace[16].position[1])))
		assert(gait_distance>2.0,"Native gait must include actual movement")
		FileAccess.open(folder+"trace.json",FileAccess.WRITE).store_string(JSON.stringify(trace,"  "))
		report.append({"species":sid,"frames":168,"captures":56,"viewport":[384,216],"actual_input_attack_jump":true,"gait_distance":gait_distance})
		print("NATIVE POKEMON 2X ",sid)
	FileAccess.open(DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.free()
	quit()

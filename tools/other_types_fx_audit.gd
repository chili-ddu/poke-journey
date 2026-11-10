extends "res://tools/ember_hit_variants_native_review.gd"

const AUDIT_DEST := "res://docs/other_types_fx_audit/native/"
const AUDIT_CASES := {
	"normal":{"move":"scratch","distance":28.0},
	"electric":{"move":"thunder_shock","distance":48.0},
	"grass":{"move":"absorb","distance":48.0},
	"ice":{"move":"icy_wind","distance":48.0},
	"fighting":{"move":"brick_break","distance":28.0},
	"poison":{"move":"acid","distance":48.0},
	"ground":{"move":"mud_slap","distance":48.0},
	"flying":{"move":"peck","distance":28.0},
	"psychic":{"move":"confusion","distance":48.0},
	"bug":{"move":"string_shot","distance":48.0},
	"rock":{"move":"rock_throw","distance":48.0},
	"ghost":{"move":"astonish","distance":28.0},
	"dragon":{"move":"dragon_breath","distance":48.0},
	"dark":{"move":"bite","distance":28.0},
	"steel":{"move":"metal_claw","distance":28.0},
	"fairy":{"move":"disarming_voice","distance":48.0}}

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("STARTER","charmander");OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_other_types_fx_audit.cfg"
	var probe := "--depth-probe" in OS.get_cmdline_user_args()
	var report := []
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):filter=arg.trim_prefix("--kind=")
	if filter!="" and FileAccess.file_exists(AUDIT_DEST+"checks.json"):
		for row in JSON.parse_string(FileAccess.get_file_as_string(AUDIT_DEST+"checks.json")):
			if row.type!=filter:report.append(row)
	for kind in AUDIT_CASES:
		if filter!="" and filter!=kind:continue
		seed(7)
		var spec: Dictionary=AUDIT_CASES[kind]
		var move := MoveDB.get_move(spec.move)
		assert(move.type==kind and MoveDB.is_shaped(spec.move))
		var game=load("res://scenes/main.tscn").instantiate()
		root.add_child(game);current_scene=game
		game.set_process(false);game.view3d.set_process(false)
		game.stream.clear();game.banner_t=0;game.ui_root.visible=false
		var world: World=game.world
		world.player.position=Arena.tile_center(Vector2i(23,209))
		world.player.add_learned(spec.move);world.player.equip(0,spec.move)
		world.no_skills=false;world.player.repel_steps=100000
		var target := Enemy.new()
		# Normal Chansey is immune to Ghost. Use a natural Water target for that case.
		var target_species := "psyduck" if kind=="ghost" else "chansey"
		target.setup_enemy(target_species,25,world.rng)
		target.position=world.player.position+Vector2.RIGHT*float(spec.distance)
		target.frozen=true
		for m in target.cds:target.cds[m]=99999.0
		world.add_child(target);world.enemies.append(target)
		var input := ReviewInput.new()
		input.target=target;world.player.controller=input
		game.view3d._cam_ready=false
		for i in 12:
			world.step_visual(1.0/60);game.view3d._process(1.0/60);await process_frame
		var output: String=AUDIT_DEST+kind+"/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		if probe:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output+"probe/"))
		var event := -1
		var seen_attack := false
		var hp := target.hp
		var centers := []
		var trace := []
		var new_hit_fx := []
		for frame in 54:
			var previous_fx := {}
			for fx in world.fxs:previous_fx[fx.get_instance_id()]=true
			if frame==4:input.requested=true
			world.step(1.0/30);game.view3d._process(1.0/30)
			seen_attack=seen_attack or world.player.attack_anim_t>0
			var activated: bool=target.spe_stage<0 if kind=="bug" else target.hp<hp
			if activated and event<0:
				event=frame
				for fx in world.fxs:
					if previous_fx.has(fx.get_instance_id()):continue
					new_hit_fx.append({"kind":fx.kind,"texture":fx.text,"direction":[fx.dir.x,fx.dir.y],"body_impact":fx.body_impact,"follows_target":fx.follow==target})
			var body: Sprite3D=game.view3d._sprites[target.get_instance_id()].sprite
			var center: Vector2=game.view3d.cam.unproject_position(game.view3d.sprite_pixel_position(body,visible_body_center(body)))
			centers.append([center.x,center.y])
			trace.append([target.hp,target.spe_stage,target.poison_t,target.para_t,target.sleep_t])
			await process_frame;await RenderingServer.frame_post_draw
			assert(DisplayServer.window_get_size()==Vector2i(384,216))
			root.get_texture().get_image().save_png(output+"%03d.png"%frame)
			if probe:
				var originals := []
				for fx in world.fxs:
					if fx.kind in ["text","light"] or fx.position.distance_to(target.position)>38:continue
					if not game.view3d._sprites.has(fx.get_instance_id()):continue
					for node in game.view3d._sprites[fx.get_instance_id()].values():
						if node is Sprite3D and node.visible:
							originals.append([node,node.transform])
							# Diagnostic only: move along the camera ray and preserve
							# projection/size. Keep normal depth testing enabled.
							game.view3d._lift_effect_to_camera(node,3.0)
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output+"probe/%03d.png"%frame)
				for item in originals:(item[0] as Sprite3D).transform=item[1]
		assert(seen_attack and event>=0,"No real hit/debuff: "+kind)
		report.append({"type":kind,"move":spec.move,"category":move.cat,"shape":move.shape,"fx":move.get("fx",""),"hit_fx":move.get("hit_fx",""),
			"event_frame":event,"damage":hp-target.hp,"max_hp":target.max_hp,"target_species":target_species,"distance":spec.distance,
			"depth_probe":probe,"source_attack":seen_attack,"centers":centers,"trace":trace,"new_hit_fx":new_hit_fx,"window":[384,216],"production_changes":false})
		print("OTHER TYPE AUDIT ",kind," ",spec.move," event ",event," damage ",hp-target.hp)
		game.free();current_scene=null;await process_frame
		FileAccess.open(AUDIT_DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()

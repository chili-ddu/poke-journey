extends "res://tools/material_hit_fx_review.gd"

const OUTPUT := "res://docs/blink_status_review/sv/native/"
const Subject = preload("res://tools/samples/reference_reaction_enemy.gd")
const Reaction = preload("res://tools/samples/reference_reaction_preview.gd")
const CASES := ["scratch","ember","poison","burn","paralyze","sleep","confuse"]

func full_trace(mon: Mon) -> Array:
	var out:=state_trace(mon)
	out.append_array([mon.confuse_t,mon.para_lock_t,mon.hurt_t,mon.hitstop_t,mon.flinch_t,mon.position.x,mon.position.y,mon.knock.x,mon.knock.y])
	return out

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("STARTER","charmander");OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_blink_status_review.cfg"
	var report:=[]
	var filter:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):filter=arg.trim_prefix("--case=")
	if filter!="" and FileAccess.file_exists(OUTPUT+"checks.json"):
		for row in JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"checks.json")):
			if row.case!=filter:report.append(row)
	for case_id in CASES:
		if filter!="" and case_id!=filter:continue
		var reference:=[]
		var reference_event:=-1
		for variant in ["current","sample"]:
			seed(7)
			Mon.poison_unlocked=case_id=="poison";Mon.burn_unlocked=case_id=="burn"
			var game=load("res://scenes/main.tscn").instantiate()
			root.add_child(game);current_scene=game
			game.set_process(false);game.view3d.set_process(false)
			game.stream.clear();game.banner_t=0;game.ui_root.visible=false
			var world: World=game.world
			var at:=open_cross()
			var distance:=28.0 if case_id=="scratch" else 48.0
			world.player.position=at-Vector2.RIGHT*distance
			world.no_skills=false;world.player.repel_steps=100000
			var target=Subject.new()
			target.reference_preview=variant=="sample"
			target.setup_enemy("chansey",25,world.rng)
			target.position=at;target.facing=Vector2.DOWN;target.frozen=true
			for move in target.cds:target.cds[move]=99999.0
			world.add_child(target);world.enemies.append(target)
			var input:=ReviewInput.new();input.target=target;world.player.controller=input
			if case_id in ["scratch","ember"]:
				world.player.add_learned(case_id);world.player.equip(0,case_id)
			game.view3d._cam_ready=false
			for i in 12:
				world.step_visual(1.0/60);game.view3d._process(1.0/60);await process_frame
			var preview=Reaction.new(game.view3d)
			var output: String=OUTPUT+case_id+"/"+variant+"/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
			var trace:=[];var centers:=[];var visuals:=[]
			var hp: int=target.hp
			var event_frame:=-1
			var seen_attack:=false
			var statuses:=false
			for frame in 84:
				var now:=float(frame)/30.0
				if frame==6:
					if case_id in ["scratch","ember"]:input.requested=true
					elif case_id in ["poison","burn"]:world._inflict_status(target,case_id)
					elif case_id=="paralyze":world._paralyze(target)
					elif case_id=="confuse":world.confuse(target)
					elif case_id=="sleep":world._apply_extra_status(target,{"sleep":1.0,"src":world.player})
				world.step(1.0/30)
				if target.hp<hp:
					if case_id in ["scratch","ember"]:
						preview.hit(now)
						if event_frame<0:event_frame=frame
					elif case_id in ["poison","burn"]:preview.status(case_id,now)
					hp=target.hp
				var active: bool=target.sleep_t>0 or target.para_t>0 or target.poison_t>0 or target.burn_t>0 or target.confuse_t>0
				if active and not statuses:
					preview.status(case_id,now);statuses=true;event_frame=frame
				seen_attack=seen_attack or world.player.attack_anim_t>0
				game.view3d._process(1.0/30)
				var ent: Dictionary=game.view3d._sprites[target.get_instance_id()]
				var body: Sprite3D=ent.sprite
				var pixel:=visible_body_center(body)
				var center: Vector2=game.view3d.cam.unproject_position(game.view3d.sprite_pixel_position(body,pixel))
				centers.append([center.x,center.y])
				var visual:={"visible":body.visible,"particles":0}
				if variant=="sample":
					if event_frame>=0:preview.hide_old_fx(world,game.view3d,target)
					visual=preview.draw(game.view3d,target,pixel,now)
				trace.append(full_trace(target));visuals.append(visual)
				await process_frame;await RenderingServer.frame_post_draw
				assert(DisplayServer.window_get_size()==Vector2i(384,216))
				root.get_texture().get_image().save_png(output+"%03d.png"%frame)
			assert(event_frame>=0)
			if case_id in ["scratch","ember"]:assert(seen_attack and preview.hit_events>0)
			else:assert(statuses and preview.status_events>0)
			if variant=="current":reference=trace;reference_event=event_frame
			else:assert(trace==reference and event_frame==reference_event,"Preview changed combat state")
			assert(visuals[-1].visible and visuals[-1].particles==0)
			report.append({"case":case_id,"variant":variant,"event_frame":event_frame,"trace":trace,"centers":centers,"visuals":visuals,
				"max_hp":target.max_hp,"damage":target.max_hp-target.hp,"status_events":preview.status_events,"hit_events":preview.hit_events,
				"source_attack":seen_attack,"window":[384,216],"production_changes":false})
			print("BLINK STATUS ",case_id," ",variant," event ",event_frame," damage ",target.max_hp-target.hp)
			game.free();current_scene=null;await process_frame
		FileAccess.open(OUTPUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	Mon.poison_unlocked=false;Mon.burn_unlocked=false
	quit()

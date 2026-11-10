extends "res://tools/material_hit_fx_review.gd"

const OUTPUT := "res://docs/status_motion_followup/native/"
const Motion = preload("res://tools/samples/status_motion_preview.gd")
const CASES := [
	["sleep_charmander","charmander","sleep"],["sleep_charizard","charizard","sleep"],
	["sleep_pikachu","pikachu","sleep"],["sleep_onix","onix","sleep"],
	["paralysis_block","charmeleon","block"],["confusion_self_hit","charizard","self"],
	["cure_poison","chansey","poison"],["cure_burn","pikachu","burn"],
	["cure_paralyze","charmander","paralyze"],["cure_sleep","pikachu","cure_sleep"],
	["cure_confuse","charmeleon","cure_confuse"],["confusion_expire","ekans","expire"]]

func rng_seed_for(kind: String) -> int:
	for value in range(1,1000):
		var r:=RandomNumberGenerator.new();r.seed=value
		if kind=="sleep":
			r.randf()
			if r.randi_range(Mon.SLEEP_TURNS.x,Mon.SLEEP_TURNS.y)==1:return value
		elif kind=="expire":
			if r.randi_range(Mon.CONFUSE_TURNS.x,Mon.CONFUSE_TURNS.y)==1:return value
		elif r.randf()<(.25 if kind=="block" else .5):return value
	return 1

func trace_state(p: Player,w: World) -> Array:
	var out:=state_trace(p)
	out.append_array([p.confuse_t,p.para_lock_t,p.hurt_t,p.hitstop_t,p.flinch_t,p.position.x,p.position.y,p.knock.x,p.knock.y,
		p.attack_anim_t,p.recover_t,p.sleep_t,p.burn_acc,p.poison_acc,float(w.projectiles.size()),float(w.pending_casts.size())])
	for value in p.pp:out.append(float(value))
	return out

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","0");OS.set_environment("SEED","7")
	OS.set_environment("STARTER","charmander");OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_status_motion_followup_review.cfg"
	var filter:=""
	var remaining:="--remaining" in OS.get_cmdline_user_args()
	var samples_only:="--samples-only" in OS.get_cmdline_user_args()
	var headless:=DisplayServer.get_name()=="headless"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):filter=arg.trim_prefix("--case=")
	var report:=[]
	if (filter!="" or remaining or samples_only) and FileAccess.file_exists(OUTPUT+"checks.json"):
		for row in JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"checks.json")):
			if samples_only:
				if row.variant=="current" or (filter!="" and row.case!=filter):report.append(row)
			elif remaining or row.case!=filter:report.append(row)
	for spec in CASES:
		var case_id: String=spec[0];var species: String=spec[1];var kind: String=spec[2]
		if filter!="" and case_id!=filter:continue
		if remaining and report.filter(func(row):return row.case==case_id).size()==2:continue
		var reference:=[]
		var reference_events:=[]
		if samples_only:
			for row in report:
				if row.case==case_id:reference=row.trace;reference_events=row.events
		for variant in ["current","sample"]:
			if samples_only and variant=="current":continue
			seed(7)
			Mon.poison_unlocked=true;Mon.burn_unlocked=true
			var game=load("res://scenes/main.tscn").instantiate()
			root.add_child(game);current_scene=game;game.set_process(false);game.view3d.set_process(false)
			game.stream.clear();game.banner_t=0;game.ui_root.visible=false
			var world: World=game.world;world.god=false
			var at:=open_cross();var player:=world.player
			player.setup_player(species,25,["scratch"]);player.position=at;player.facing=Vector2.DOWN
			player.bag.clear();player.repel_steps=100000
			var input:=ReviewInput.new();input.target=null;player.controller=input
			world.no_skills=false;game.view3d._cam_ready=false
			for i in 12:
				world.step_visual(1.0/60);game.view3d._process(1.0/60);await process_frame
			var preview=Motion.new(game.view3d);preview.observe(player,0.0)
			var output: String=OUTPUT+case_id+"/"+variant+"/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
			var trace:=[];var visuals:=[];var centers:=[]
			var start_hp:=player.hp;var start_pp: Array=player.pp.duplicate()
			for frame in 84:
				var now:=float(frame)/30.0
				if frame==6:
					world.rng.seed=rng_seed_for("expire" if kind=="expire" else "sleep")
					if kind in ["sleep","cure_sleep"]:world._apply_extra_status(player,{"sleep":1.0,"src":player})
					elif kind in ["self","expire","cure_confuse"]:world.confuse(player)
					elif kind in ["block","paralyze"]:world._paralyze(player)
					else:world._inflict_status(player,kind)
				if frame==28:
					if kind in ["block","self"]:
						world.rng.seed=rng_seed_for(kind);input.requested=true
					elif kind not in ["sleep","expire"]:
						world._cure("sleep" if kind=="cure_sleep" else "confuse" if kind=="cure_confuse" else kind)
				if frame==42 and kind not in ["block","self","sleep","expire"]:
					# A second cure of an absent status must not animate again.
					world._cure("sleep" if kind=="cure_sleep" else "confuse" if kind=="cure_confuse" else kind)
				world.step(1.0/30);preview.observe(player,now)
				game.view3d._process(1.0/30)
				var body: Sprite3D=game.view3d._sprites[player.get_instance_id()].sprite
				var pixel:=visible_body_center(body)
				var center: Vector2=game.view3d.cam.unproject_position(game.view3d.sprite_pixel_position(body,pixel))
				centers.append([center.x,center.y])
				var visual:={"action":player._anim_name,"release":false,"visible":body.visible}
				if variant=="sample":
					preview.hide_old_fx(world,game.view3d,player)
					visual=preview.draw(game.view3d,player,pixel,now)
				trace.append(trace_state(player,world));visuals.append(visual)
				await process_frame
				if not headless:
					await RenderingServer.frame_post_draw
					assert(DisplayServer.window_get_size()==Vector2i(384,216))
					root.get_texture().get_image().save_png(output+"%03d.png"%frame)
			var names: Array=preview.events.map(func(e):return e.kind)
			if kind=="block":assert(names.has("paralysis_block") and player.pp==start_pp and player.hp==start_hp)
			elif kind=="self":assert(names.has("confusion_self_hit") and player.hp<start_hp and world.projectiles.is_empty())
			elif kind=="sleep":assert(names.count("clear_sleep")==1)
			elif kind=="expire":assert(names.count("clear_confuse")==1)
			else:assert(names.count("clear_"+("sleep" if kind=="cure_sleep" else "confuse" if kind=="cure_confuse" else kind))==1)
			if variant=="current":reference=trace;reference_events=preview.events
			else:
				# Cached Godot JSON rounds doubles. Compare at that SAME precision;
				# keep direct in-memory equality for a fresh baseline/sample run.
				var comparison_trace: Array=JSON.parse_string(JSON.stringify(trace)) if samples_only else trace
				var comparison_events: Array=JSON.parse_string(JSON.stringify(preview.events)) if samples_only else preview.events
				if comparison_trace!=reference or comparison_events!=reference_events:
					FileAccess.open(OUTPUT+"mismatch-"+case_id+".json",FileAccess.WRITE).store_string(JSON.stringify({"reference":reference,"actual":trace,"reference_events":reference_events,"actual_events":preview.events},"  "))
					push_error("Renderer comparison mismatch "+case_id);game.free();quit(1);return
			assert(not visuals[-1].release)
			report.append({"case":case_id,"species":species,"variant":variant,"trace":trace,"visuals":visuals,"centers":centers,
				"events":preview.events,"max_hp":player.max_hp,"damage":start_hp-player.hp,"pp_before":start_pp,"pp_after":player.pp.duplicate(),
				"window":[384,216],"headless":headless,"production_changes":false})
			print("STATUS MOTION ",case_id," ",variant," events ",names," damage ",start_hp-player.hp)
			game.free();current_scene=null;await process_frame
		FileAccess.open(OUTPUT+("headless-checks.json" if headless else "checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	Mon.poison_unlocked=false;Mon.burn_unlocked=false
	quit()

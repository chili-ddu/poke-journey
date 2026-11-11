extends SceneTree
## Native proof of human hold/release, fixed floor placement, and the HUD guide.
const OUT:="res://docs/area_targeting/"
const DT:=1.0/60.0
const MOVES:=["smoke_screen","fire_spin","rock_throw","sleep_powder","poison_powder"]
var game: Node
var world: World
var view: View3D
var input: Controllers.Human
var checks: Array=[]
var failures: Array=[]
var old_poison:=false

class Dummy:
	extends Enemy
	func think(_dt: float,_world) -> void:vel=Vector2.ZERO

func _init() -> void:call_deferred("run")

func require(condition: bool,message: String) -> bool:
	if condition:return true
	failures.append(message);push_error(message)
	return false

func run() -> void:
	for pair in [["BOT","1"],["GOD","0"],["SEED","17"],["LANG_CODE","ko"],["DUNGEON","arena_viridian_forest"],["CAP_VIEW","384x216"],["CAP_AUDIO","0"]]:OS.set_environment(pair[0],pair[1])
	SaveData.path="user://area_charge_review_private.cfg"
	SaveData.slot_pattern="user://area_charge_review_%s.cfg"
	SaveData.allow_migrate=false
	Controllers.ensure_input_map()
	await CaptureWindow.park(self)
	old_poison=Mon.poison_unlocked
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for move_id in MOVES:
		if not await capture_case(move_id):
			finish(1);return
	finish(0)

func finish(exit_code: int) -> void:
	Mon.poison_unlocked=old_poison
	if is_instance_valid(game):game.free()
	var report:={"window":[384,216],"real_user_saves_used":false,"cases":checks,"failures":failures,"new_art_imported":false,"poison_unlocked_test_only":true,"accuracy_stages_test_only":true,"camera_framing_test_only":true}
	FileAccess.open(OUT+"native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("Area charge native review: ",checks.size()," cases, ",failures.size()," failures; 384x216")
	quit(exit_code)

func open_case(move_id: String) -> bool:
	if is_instance_valid(game):game.free();await process_frame
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	game.set_process(false);game.stream.clear()
	if not require(game.view3d!=null,"Native 3D view exists"):return false
	view=game.view3d;view.set_process(false)
	var old: World=game.world
	world=World.new();game.add_child(world);game.world=world;view.world=world;old.free()
	input=Controllers.Human.new();input.pad_move=Vector2.RIGHT;input.pad_active=true
	var species: String="bulbasaur" if move_id in ["sleep_powder","poison_powder"] else "charmander"
	world.setup(17,species,30,[move_id],input)
	world.player.position=Arena.tile_center(Vector2i(8,15));world.player.facing=Vector2.RIGHT
	world.player.frozen=true
	world.player.acc_stage=6 # Deterministic contact proof; no move data or damage stats changed.
	world.visibility_layer|=Look.GROUND_LAYER
	game.state="fight";game.banner_t=0.0;game.dialog_text="";game.dialog_t=0.0
	game.status_messages.clear();game.status_message_times.clear();game.status_message_active=false;game.last_small_message=""
	if not require(world.has_method("area_charge_preview"),"World exposes its charge preview"):return false
	Mon.poison_unlocked=move_id=="poison_powder"
	return true

func add_dummy(offset: Vector2) -> Dummy:
	var enemy:=Dummy.new();enemy.setup_trainer_mon("squirtle",30,["tackle"],world.rng)
	enemy.position=world.player.position+offset;enemy.frozen=true;enemy.eva_stage=-6
	world.add_child(enemy);world.enemies.append(enemy)
	return enemy

func frame_step() -> void:
	world.step(DT)
	view._process(DT)
	var max_range:=float(MoveDB.get_move(world.player.slots[0]).range)
	# Frame the actors and ground guide in the playable region above the HUD.
	view._set_arena_camera(View3D.to3d(world.player.position+Vector2(max_range*.48,0),-1.25),Vector2(40,25),9.3)
	if not require(DisplayServer.window_get_size()==Vector2i(384,216) and root.size==Vector2i(384,216),"Every simulated frame retains the minimum window size"):
		finish(1);return
	await process_frame

func frames(count: int) -> void:
	for _index in count:await frame_step()

func shot(name: String) -> bool:
	if not require(DisplayServer.window_get_size()==Vector2i(384,216) and root.size==Vector2i(384,216),"Window and viewport stay at 384x216"):return false
	for _index in 3:await process_frame
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	if not require(picture.get_size()==Vector2i(384,216),"Captured image has the required size"):return false
	picture.save_png(OUT+name+".png")
	return true

func capture_case(move_id: String) -> bool:
	if not await open_case(move_id):return false
	var reach:=float(MoveDB.get_move(move_id).range)
	var near_offset:=Vector2(28,4) if reach<60 else Vector2(42,8)
	var near:=add_dummy(near_offset)
	var far:=add_dummy(near_offset.normalized()*reach)
	var hp_before: int=far.hp
	var original_stats: Dictionary=far.stats.duplicate()
	var original_pp: int=world.player.pp[0]
	await frames(3)
	input.press_gamepad_key(KEY_Q)
	await frames(8)
	var short: Dictionary=world.area_charge_preview()
	if not require(not short.is_empty(),move_id+": held skill shows a preview"):return false
	var short_distance:=world.player.position.distance_to(short.center)
	if not await shot(move_id+"_01_short_charge"):return false
	await frames(60)
	var maximum: Dictionary=world.area_charge_preview()
	if maximum.is_empty():
		print("Charge diagnostic: ",JSON.stringify({"move":move_id,"state":game.state,"charge":str(world.get("_area_charge")),"preview":str(maximum),"held":input.skill_is_held(0),"revision":input.skill_input_revision(),"pp":world.player.pp[0],"can_act":world.player.can_act(),"can_use":world.player.can_use(0),"no_skills":world.no_skills,"hop":world.player.hop_t,"skill_lock":world.player.skill_lock_t,"recover":world.player.recover_t,"zones":world.zones.size(),"pending":world.pending_casts.size(),"input_hold":input.hold,"fishing":world.field_water.fishing}))
	if not require(not maximum.is_empty(),move_id+": maximum charge stays held"):return false
	if not require(is_equal_approx(float(maximum.progress),1.0),move_id+": charge reaches maximum"):return false
	if not require(world.player.pp[0]==original_pp,move_id+": holding spends no PP"):return false
	var locked: Vector2=maximum.center
	var max_distance:=world.player.position.distance_to(locked)
	if not require(max_distance>short_distance and absf(max_distance-reach)<.01,move_id+": time controls distance up to its own range"):return false
	if not require(locked.distance_to(near.position)>10,move_id+": maximum range does not snap to the nearest enemy"):return false
	var geometry: Dictionary=game.hud.area_charge_geometry()
	if not require(not geometry.is_empty(),move_id+": actual HUD projects the active guide"):return false
	if not await shot(move_id+"_02_max_charge"):return false
	input.release_gamepad_key(KEY_Q)
	await frame_step()
	if not require(world.area_charge_preview().is_empty(),move_id+": release removes the guide"):return false
	if not require(world.player.pp[0]==original_pp-1,move_id+": release spends PP once"):return false
	var impact_frames:=20 if move_id=="rock_throw" else (12 if move_id in ["sleep_powder","poison_powder"] else 35)
	await frames(impact_frames)
	if not await shot(move_id+"_03_impact"):return false
	if not require(far.stats==original_stats,move_id+": enemy common stats stay unchanged"):return false
	var affected: bool=far.acc_stage<0 if move_id=="smoke_screen" else (far.sleep_t>0 if move_id=="sleep_powder" else (far.poison_t>0 if move_id=="poison_powder" else far.hp<hp_before))
	if not require(affected,move_id+": the actual area effect reaches the selected landing region"):return false
	var field_center: Variant=null
	if move_id=="fire_spin":
		if not require(world.zones.size()==1,"Fire Spin has one live field"):return false
		var landing: Vector2=world.zones[0].position
		field_center=[landing.x,landing.y]
		if not require(landing.distance_to(locked)<.01,"Fire Spin lands at the locked throw position"):return false
	checks.append({"move":move_id,"short_distance":short_distance,"max_distance":max_distance,"range":reach,"radius":maximum.radius,"center":[locked.x,locked.y],"projected_center":[geometry.center.x,geometry.center.y],"pp_before":original_pp,"pp_after_release":original_pp-1,"damage":hp_before-far.hp,"sleep":far.sleep_t,"poison":far.poison_t,"accuracy_stage":far.acc_stage,"field_center":field_center,"stats_preserved":true,"image_count":4})
	var short_result:=await short_throw(move_id)
	if short_result.is_empty():return false
	checks[checks.size()-1]["short_throw"]=short_result
	return true

func short_throw(move_id: String) -> Dictionary:
	if not await open_case(move_id):return {}
	var before_pp: int=world.player.pp[0]
	await frames(3)
	input.press_gamepad_key(KEY_Q)
	await frames(8)
	var preview: Dictionary=world.area_charge_preview()
	if not require(not preview.is_empty(),move_id+": a short hold has a landing guide"):return {}
	var distance:=world.player.position.distance_to(preview.center)
	var reach:=float(MoveDB.get_move(move_id).range)
	var target:=add_dummy(Vector2(preview.center)-world.player.position)
	var hp_before: int=target.hp
	input.release_gamepad_key(KEY_Q)
	await frame_step()
	if not require(world.area_charge_preview().is_empty() and world.player.pp[0]==before_pp-1,move_id+": a short release commits exactly one throw"):return {}
	var locked: Vector2=world.pending_casts[0].locked_point if not world.pending_casts.is_empty() else preview.center
	if not require(distance<reach-1 and locked.distance_to(world.player.position)<reach-1,move_id+": a short throw does not jump to full range"):return {}
	# Include the remaining minimum wind-up before the actual area impact.
	await frames(32 if move_id in ["smoke_screen","rock_throw","fire_spin"] else 21)
	if not await shot(move_id+"_04_short_throw_impact"):return {}
	var affected: bool=target.acc_stage<0 if move_id=="smoke_screen" else (target.sleep_t>0 if move_id=="sleep_powder" else (target.poison_t>0 if move_id=="poison_powder" else target.hp<hp_before))
	if not require(affected,move_id+": a short throw applies its effect around the nearby ground point"):return {}
	return {"distance_before_release":distance,"locked_point":[locked.x,locked.y],"range":reach,"pp_before":before_pp,"pp_after":before_pp-1,"damage":hp_before-target.hp,"sleep":target.sleep_t,"poison":target.poison_t,"accuracy_stage":target.acc_stage}

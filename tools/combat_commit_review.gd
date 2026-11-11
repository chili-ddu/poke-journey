extends SceneTree
## Real HUD and combat snapshots. All input and saves belong to this fixture.
const OUT:="res://docs/combat_commit/"
const DT:=1.0/60.0
var game: Node
var world: World
var view: View3D
var human: Controllers.Human
var checks: Array=[]
var failures: Array=[]
var focus_events: Array=[]
var camera_anchor:=Vector2.ZERO
var direction:=Vector2.RIGHT

class Dummy:
	extends Enemy
	func think(_dt: float,_world) -> void:vel=Vector2.ZERO

func _init() -> void:call_deferred("run")

func require(ok: bool,message: String) -> bool:
	if ok:return true
	failures.append(message);push_error(message)
	if world!=null:print("Combat diagnostic: ",JSON.stringify({"message":message,"pos":str(world.player.position),"facing":str(world.player.facing),"dash":str(world.player.dash),"pending":str(world.pending_casts),"pp":world.player.pp[0],"revision":human.skill_input_revision(),"focus_events":focus_events}))
	return false

func run() -> void:
	for pair in [["BOT","1"],["GOD","0"],["SEED","17"],["LANG_CODE","ko"],["CAP_VIEW","384x216"],["CAP_AUDIO","0"]]:OS.set_environment(pair[0],pair[1])
	SaveData.path="user://combat_commit_review_private.cfg"
	SaveData.slot_pattern="user://combat_commit_review_%s.cfg";SaveData.allow_migrate=false
	Controllers.ensure_input_map();await CaptureWindow.park(self)
	root.focus_exited.connect(func():focus_events.append({"frame":Engine.get_process_frames(),"kind":"exit"}))
	root.focus_entered.connect(func():focus_events.append({"frame":Engine.get_process_frames(),"kind":"enter"}))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for scenario in [dash_free,dash_wall,melee_contact,committed_skull_bash,committed_solar_beam,finite_flame,native_dash]:
		if not await scenario.call():finish(1);return
	finish(0)

func finish(code: int) -> void:
	if is_instance_valid(game):game.free()
	var result:={"window":[384,216],"real_user_saves_used":false,"new_art_imported":false,"camera_framing_test_only":true,"accuracy_stages_test_only":true,"frozen_walking_test_only":true,"isolated_virtual_input_test_only":true,"focus_events":focus_events,"cases":checks,"failures":failures}
	FileAccess.open(OUT+"native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("Combat commit native review: ",checks.size()," cases, ",failures.size()," failures; 384x216")
	quit(code)

func open_case(move_id: String,place: String="arena_viridian_forest",seek_wall: bool=false) -> bool:
	if is_instance_valid(game):game.free();await process_frame
	OS.set_environment("DUNGEON",place)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	game.set_process(false);game.set_process_input(false);game.stream.clear()
	# This fixture drives Human directly. Hidden touch routers must not cancel
	# that synthetic source on unrelated native focus/context notifications.
	if is_instance_valid(game.touch_controls):game.touch_controls.game=null;game.touch_controls.set_process(false)
	if not require(game.view3d!=null,"Real 3D game view exists"):return false
	view=game.view3d;view.set_process(false)
	var old: World=game.world
	var origin: Vector2=old.player.position
	world=World.new();game.add_child(world);game.world=world;view.world=world;old.free()
	human=Controllers.Human.new();human.pad_active=true
	world.setup(17,"charmander",30,[move_id],human)
	world.player.position=origin;world.player.frozen=true;world.player.acc_stage=6
	var move:=MoveDB.get_move(move_id)
	var reach:=float(move.get("distance",move.get("range",96)))
	var lane:=find_lane(reach,seek_wall)
	if not require(not lane.is_empty(),"A real "+("wall" if seek_wall else "clear")+" lane exists on "+place):return false
	world.player.position=lane.start;direction=lane.dir;human.pad_move=direction;world.player.facing=direction
	camera_anchor=world.player.position+direction*reach*.45
	world.visibility_layer|=Look.GROUND_LAYER
	game.state="fight";game.banner_t=0.0;game.dialog_text="";game.dialog_t=0.0
	game.status_messages.clear();game.status_message_times.clear();game.status_message_active=false;game.last_small_message=""
	await frames(5,false)
	return require(world.has_method("dash_aim_preview"),"World exposes its read-only dash guide")

func find_lane(reach: float,seek_wall: bool) -> Dictionary:
	var origin:=Arena.tile_of(world.player.position)
	# Prefer a horizontal lane so even a long beam and its caster remain above
	# the ordinary bottom HUD. This is camera composition, not move behavior.
	for axis in [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]:
		for radius in 16:
			for y in range(-radius,radius+1):
				for x in range(-radius,radius+1):
					if maxi(absi(x),absi(y))!=radius:continue
					var start:=Arena.tile_center(origin+Vector2i(x,y))
					world.player.position=start
					if world.resolve_mon(world.player,start).distance_to(start)>.01:continue
					var distance:=0.0
					for step in ceili(reach/2.0):
						var want: Vector2=start+axis*minf(reach,float(step+1)*2)
						if world.resolve_mon(world.player,want).distance_to(want)>.01:break
						distance=start.distance_to(want)
					if (not seek_wall and distance>=reach-.01) or (seek_wall and distance>reach*.25 and distance<reach*.85):return {"start":start,"dir":axis}
	return {}

func dummy(offset: Vector2) -> Dummy:
	var actor:=Dummy.new();actor.setup_trainer_mon("squirtle",30,["tackle"],world.rng)
	actor.position=world.player.position+offset;actor.frozen=true;actor.eva_stage=-6
	world.add_child(actor);world.enemies.append(actor)
	return actor

func frame_step(tick: bool=true) -> void:
	if tick:world.step(DT)
	view._process(DT)
	view._set_arena_camera(View3D.to3d(camera_anchor,-1.25),Vector2(40,25),9.3)
	if not require(DisplayServer.window_get_size()==Vector2i(384,216) and root.size==Vector2i(384,216),"Window remains 384x216"):
		finish(1);return
	await process_frame

func frames(count: int,tick: bool=true) -> void:
	for _index in count:await frame_step(tick)

func shot(label: String) -> bool:
	await frames(3,false);await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	if not require(picture.get_size()==Vector2i(384,216),"Native image is 384x216"):return false
	picture.save_png(OUT+label+".png")
	return true

func dash_free() -> bool:
	if not await open_case("rollout"):return false
	var before: Dictionary=world.dash_aim_preview()
	if not require(not before.is_empty(),"Selected dash has a guide before use"):return false
	var point: Vector2=before.to
	var geometry: Dictionary=game.hud.dash_aim_geometry()
	if not require(not geometry.is_empty(),"Actual HUD projects dash corridor"):return false
	if not await shot("01_dash_ready"):return false
	var stats: Dictionary=world.player.stats.duplicate();var pp: int=world.player.pp[0]
	human.press_gamepad_key(KEY_Q);await frame_step();human.release_gamepad_key(KEY_Q)
	if not require(world.player.is_dashing() and world.player.invuln_t<=0,"Ordinary attack dash starts without adding invulnerability"):return false
	if not await shot("02_dash_active"):return false
	human.pad_move=direction.orthogonal();await frames(25)
	if not require(world.player.position.distance_to(point)<.15,"Dash stops at its displayed endpoint without changing direction"):return false
	if not require(world.player.pp[0]==pp-1 and world.player.stats==stats,"Dash spends once and preserves common stats"):return false
	if not await shot("03_dash_landing"):return false
	checks.append({"case":"dash_free","native":Arena.is_native(),"endpoint":str(point),"actual":str(world.player.position),"width":before.width,"ground_offset":str(before.get("ground_offset",Vector2.ZERO)),"projected_from":str(geometry.from),"projected_to":str(geometry.to),"pp_spent":1,"stats_preserved":true,"images":3})
	return true

func dash_wall() -> bool:
	if not await open_case("rollout","arena_viridian_forest",true):return false
	var before: Dictionary=world.dash_aim_preview();var start:=world.player.position
	if not require(not before.is_empty() and start.distance_to(before.to)<48,"Wall truncates the displayed path"):return false
	if not await shot("04_dash_wall_ready"):return false
	human.press_gamepad_key(KEY_Q);await frame_step();human.release_gamepad_key(KEY_Q);await frames(25)
	if not require(world.player.position.distance_to(before.to)<.2,"Actual wall stop matches the guide"):return false
	if not require(absf((world.player.position-start).dot(direction.orthogonal()))<.05,"Wall does not slide the dash sideways"):return false
	if not await shot("05_dash_wall_stop"):return false
	checks.append({"case":"dash_wall","endpoint":str(before.to),"actual":str(world.player.position),"distance":start.distance_to(before.to),"images":2})
	return true

func melee_contact() -> bool:
	if not await open_case("tackle"):return false
	var target:=dummy(direction*(world.player.radius+10+8)+direction.orthogonal()*3)
	var stats: Dictionary=target.stats.duplicate();var hp: int=target.hp
	human.press_gamepad_key(KEY_Q);await frame_step();human.release_gamepad_key(KEY_Q)
	var locked:=world.player.facing
	if not await shot("06_melee_windup"):return false
	human.pad_move=-direction.orthogonal()
	var locked_frames:=0
	for _index in 28:
		await frame_step()
		if world.player.attack_anim_t>0.0:
			locked_frames+=1
			if not require(locked.dot(world.player.facing)>.999,"Melee animation retains its opening attack direction"):return false
	if not require(locked_frames>0,"Melee facing is sampled during the attack, before ordinary movement may turn it again"):return false
	if not require(target.hp<hp and target.stats==stats,"Melee makes a normal contact without stat scaling"):return false
	if not require((target.position-world.player.position).dot(locked)>0,"Melee does not pass through the opponent"):return false
	if not await shot("07_melee_contact"):return false
	checks.append({"case":"melee_contact","locked_direction":str(locked),"locked_frames_observed":locked_frames,"target_stays_ahead":true,"damage":hp-target.hp,"stats_preserved":true,"images":2})
	return true

func committed_skull_bash() -> bool:
	if not await open_case("skull_bash"):return false
	var target:=dummy(direction*75+direction.orthogonal()*7)
	var pp: int=world.player.pp[0]
	human.press_gamepad_key(KEY_Q);await frame_step();human.release_gamepad_key(KEY_Q)
	if not require(world.pending_casts.size()==1,"Skull Bash commits its preparation"):return false
	var locked:=world.player.facing
	if not await shot("08_skull_bash_ready"):return false
	human.pad_move=-direction;human.press_gamepad_key(KEY_SPACE);await frame_step();human.release_gamepad_key(KEY_SPACE)
	if not require(world.player.hop_t<=0 and world.pending_casts.size()==1,"Jump cannot cancel a committed preparation"):return false
	await frames(35)
	if not require(world.player.facing.dot(locked)>.999,"The preparation keeps its opening corrected direction"):return false
	if not await shot("09_skull_bash_locked"):return false
	for _index in 150:
		await frame_step()
		if world.player.is_dashing():break
	if not require(world.player.is_dashing() and Vector2(world.player.dash.dir).dot(locked)>.999,"Skull Bash automatically launches on its locked direction"):return false
	if not await shot("10_skull_bash_launch"):return false
	await frames(40)
	if not require(world.player.pp[0]==pp-1,"Committed preparation never spends a second PP"):return false
	checks.append({"case":"skull_bash","locked_direction":str(locked),"jump_did_not_cancel":true,"pp_spent":1,"images":3})
	return true

func committed_solar_beam() -> bool:
	if not await open_case("solar_beam"):return false
	var target:=dummy(direction*90+direction.orthogonal()*8)
	human.press_gamepad_key(KEY_Q);await frame_step();human.release_gamepad_key(KEY_Q)
	var locked:=world.player.facing
	if not await shot("11_solar_beam_ready"):return false
	human.pad_move=-direction;target.position+=direction.orthogonal()*48
	for _index in 160:
		await frame_step()
		if world.pending_casts.is_empty():break
	if not require(world.player.facing.dot(locked)>.999,"Solar Beam fires on its starting direction after the target moves"):return false
	if not await shot("12_solar_beam_launch"):return false
	checks.append({"case":"solar_beam","locked_direction":str(locked),"target_moved_after_commit":true,"images":2})
	return true

func finite_flame() -> bool:
	if not await open_case("flamethrower"):return false
	var pp: int=world.player.pp[0]
	human.press_gamepad_key(KEY_Q);await frame_step();human.release_gamepad_key(KEY_Q)
	await frames(10)
	if not await shot("13_flame_single_cast"):return false
	await frames(60)
	if not require(world.bursts.is_empty() and world.player.pp[0]==pp-1,"Releasing keeps one finite attack group, not a held channel"):return false
	checks.append({"case":"flamethrower","finite_attack_group":true,"pp_spent":1,"images":1})
	return true

func native_dash() -> bool:
	if not await open_case("rollout","johto_061"):return false
	var before: Dictionary=world.dash_aim_preview()
	if not require(Arena.is_native() and before.get("ground_offset",Vector2.ZERO)==Vector2.ZERO,"HGSS native feet need no FRLG display offset"):return false
	if not await shot("14_hgss_dash_ready"):return false
	human.press_gamepad_key(KEY_Q);await frame_step();human.release_gamepad_key(KEY_Q)
	if not await shot("15_hgss_dash_active"):return false
	await frames(25)
	if not require(world.player.position.distance_to(before.to)<.2,"HGSS dash follows the same displayed movement endpoint"):return false
	if not await shot("16_hgss_dash_landing"):return false
	checks.append({"case":"native_dash","native":true,"ground_offset":str(before.get("ground_offset",Vector2.ZERO)),"endpoint":str(before.to),"actual":str(world.player.position),"images":3})
	return true

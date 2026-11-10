extends SceneTree
const Game=preload("res://scripts/game.gd")
var game: Node
var checks: Array=[]
var out:="res://docs/quest_events_review"
func _init() -> void:call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_quest_events_review.cfg"
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("LANG_CODE","ko")
	Lang.code="ko"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	if not await scene("forest_gate_south",["visited_area_saffron_city"],"forest_truce"):quit(1);return
	await shot("01_bug_catcher_marker")
	# Representative accepted stories in this isolated visual fixture only.
	for id in ["forest_truce","museum_fossils","bill_rescue","daycare_courtship","eevee_evolution","ditto_rumor"]:
		game.quests.flag("quest_%s_started"%id)
	game._open_game_menu();game.quests.open_journal()
	await shot("02_story_journal")
	if OS.get_environment("QUEST_REVIEW_JOURNAL_ONLY")=="1":
		var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out+"/checks.json"))
		for index in report.captures.size():
			if report.captures[index].image=="02_story_journal.png":report.captures[index]=checks[1]
		var file:=FileAccess.open(out+"/checks.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "));file.close()
		game.free();Game.bot_events=[]
		print("QUEST JOURNAL VISUAL REVIEW: discovered stories fit 384x216")
		quit();return
	game.free();await process_frame
	if not await scene("celadon_city_condominiums_roof",["visited_area_saffron_city"],"eevee_evolution"):quit(1);return
	await shot("03_rooftop_eevee")
	game.free();await process_frame
	if not await scene("route25_sea_cottage",["visited_area_saffron_city"],"bill_rescue"):quit(1);return
	await shot("04_bill_research_theft")
	game.quests.talk(quest_actor("bill_rescue"))
	await shot("05_bill_dialogue")
	game.free();await process_frame
	if not await scene("kanto_world",["visited_area_saffron_city","quest_ditto_rumor_stage_0"],"ditto_rumor"):quit(1);return
	await shot("06_doppelganger")
	game.free();await process_frame
	if not await scene("route5_pokemon_day_care",["visited_area_saffron_city","eevee_following"],"daycare_courtship"):quit(1);return
	await shot("07_daycare_with_eevee")
	game.free();await process_frame
	if not await scene("kanto_world",[],""):quit(1);return
	game.world.player.position=Arena.tile_center(Arena.area_rect("route1").position+Vector2i(11,12))
	game.world.cam.position=game.world.player.position;game.world.cam_pos=game.world.player.position
	game.last_small_message="";game.dialog_text=""
	if not game.quests.check_discovery():push_error("Route 1 sighting did not trigger");quit(1);return
	for _i in 35:
		game.world.step_visual(1.0/60.0);game.quests.step(1.0/60.0);game.view3d._process(1.0/60.0);await process_frame
	await shot("08_route1_mysterious_bird")
	game.free();Game.bot_events=[];Game.arena_trip={};Game.carry={};Game.destination={}
	var file:=FileAccess.open(out+"/checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"window":[root.size.x,root.size.y],"failures":0,"captures":checks},"  "))
	file.close()
	print("QUEST VISUAL REVIEW: eight 384x216 captures completed; no player save used")
	quit()
func quest_actor(id: String) -> Npc:
	for actor in game.quests.actors:
		if actor.get_meta("quest_id","")==id:return actor
	return null
func scene(place: String,flags: Array,id: String) -> bool:
	OS.set_environment("DUNGEON",place)
	Game.bot_events=flags.duplicate();Game.bot_beaten=[];Game.arena_trip={};Game.carry={};Game.destination={};Game.starter="charmander"
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	game.set_process(false);game.view3d.set_process(false);game.world.god=true
	game.banner_t=0.0;game.dialog_text="";game.dialog_t=0.0
	game.status_messages.clear();game.status_message_times.clear();game.timed_dialog_pages.clear();game.status_message_active=false;game.last_small_message=""
	var actor:=quest_actor(id)
	if actor==null and not id.is_empty():
		push_error("Quest actor missing: "+id+" in "+place);return false
	if actor!=null:game.world.player.position=game.world.resolve_mon(game.world.player,actor.position+Vector2(0,Arena.TILE*1.6))
	game.world.player.facing=Vector2.UP
	game.world.cam.position=game.world.player.position
	game.world.cam_pos=game.world.player.position
	for _i in 12:
		game.world.step_visual(1.0/60.0);game.quests.step(1.0/60.0);game.view3d._process(1.0/60.0)
		await process_frame
	return true
func shot(label: String) -> void:
	for _i in 3:
		game.view3d._process(1.0/60.0);await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.save_png(out+"/"+label+".png")
	var marker_positions: Array=[]
	for actor in game.quests.actors:
		var point: Vector2=game.hud.quest_marker_position(actor)
		if Rect2(Vector2.ZERO,Vector2(384,216)).has_point(point):marker_positions.append({"quest":actor.get_meta("quest_id",""),"x":point.x,"y":point.y})
	checks.append({"image":label+".png","size":[image.get_width(),image.get_height()],"visible_markers":marker_positions})

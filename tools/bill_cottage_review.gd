extends SceneTree

# Current BILL rescue scene; supersedes the retired collector-battle capture.
const Game = preload("res://scripts/game.gd")
const OUT := "res://docs/event_implementation_review/bill/"
var game: Node

class Still:
	extends RefCounted
	func move_dir(_world):return Vector2.ZERO
	func aim_point(world):return world.player.position+Vector2.UP*80.0
	func want_skill(_index,_world):return false
	func want_jump(_world):return false
	func want_dodge(_world):return false
	func want_item(_world):return false

func _init() -> void:
	call_deferred("run")

func _configure() -> void:
	game.set_process(false)
	game.bot=false
	game.banner_t=0.0
	game.world.god=true
	game.world.player.controller=Still.new()
	game.dialog_text="";game.dialog_t=0.0
	game.status_messages.clear();game.timed_dialog_pages.clear();game.status_message_active=false
	game.last_small_message=""
	game.road_pursuit.clear(game.world)
	game.road_pursuit.cooldown=10000.0
	assert(DisplayServer.window_get_size()==Vector2i(384,216))

func shot(name: String) -> void:
	game._update_dialogue_focus()
	for i in 12:
		game.world.step_visual(1.0/60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	SaveData.path="user://save_bill_rescue_visual_review.cfg"
	SaveData.clear()
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","1")
	OS.set_environment("LANG_CODE","ko")
	OS.set_environment("DUNGEON","route25_sea_cottage")
	Game.starter="charmander"
	Game.bot_events=["visited_area_saffron_city"]
	Game.bot_beaten=[];Game.destination={};Game.arena_trip={};Game.carry={}
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);current_scene=game
	OS.set_environment("DUNGEON","")
	_configure()
	assert(game.bill_event.phase=="idle")
	assert(game.bill_event.actor==null,"The collector event must stay retired")
	game.world.player.position=Arena.tile_center(Vector2i(9,7))
	game.world.player.facing=Vector2.UP
	game.world.cam_pos=game.world.player.position
	game.world.cam.position=game.world.cam_pos
	var actor: Npc=null
	for candidate in game.quests.actors:
		if candidate.get_meta("quest_id","")=="bill_rescue":actor=candidate
	assert(actor!=null,"The rescue marker must be present after Saffron")
	await shot("01_rescue_request")
	game._talk(actor)
	assert(game.state=="talk")
	await shot("02_research_theft")
	for i in 40:
		if game.state!="talk":break
		game._talk_next()
	assert(game.state=="encounter")
	var prior=game
	for i in 600:
		if current_scene!=prior:break
		if is_instance_valid(prior) and prior.state=="encounter":prior.advance(1.0/60.0)
		await create_timer(0.01).timeout
	assert(current_scene!=prior)
	game=current_scene;_configure()
	assert(game.quests.is_battle())
	for i in 40:
		if game.state!="talk":break
		game._talk_next()
	game.advance(1.0/60.0)
	for i in 210:
		game.advance(1.0/60.0)
		await process_frame
	game.dialog_text="";game.dialog_t=0.0
	game.status_messages.clear();game.timed_dialog_pages.clear();game.status_message_active=false
	game.last_small_message=""
	assert(game.world.remaining()>0)
	await shot("03_rocket_battle")
	SaveData.clear()
	print("Bill rescue visual review PASS: 384x216, three captures, isolated save")
	quit()

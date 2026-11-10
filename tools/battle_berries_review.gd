extends SceneTree
var game: Node
const OUT := "res://docs/battle_berries_review/"
func _init() -> void: call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	OS.set_environment("DUNGEON","pewter_mart")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.set_process(false)
	game.banner_t=0.0
	var p: Player=game.world.player
	p.bag={}
	for id in ["oran_berry","sitrus_berry","leppa_berry","cheri_berry","chesto_berry","pecha_berry","rawst_berry","persim_berry","lum_berry"]: p.add_item(id,2)
	p.equip(2,"ember")
	p.pp[0]=MoveDB.pp_of(p.slots[0])-3
	p.pp[2]=0
	game._open_bag()
	assert(game.bag_screen.pocket==ItemDB.BAG_POCKETS.find("berries"))
	await shot("01_berry_bag")
	game._on_bag_used("leppa_berry")
	assert(game.menu=="berry_pp" and game.state=="menu")
	assert(p.bag.leppa_berry==2,"Opening target selection does not consume")
	await shot("02_choose_move")
	game._resolve_menu(game.berry_slots.size())
	assert(game.menu=="bag" and p.bag.leppa_berry==2,"Cancel returns to bag without consuming")
	game._on_bag_used("leppa_berry")
	game._resolve_menu(game.berry_slots.find(0))
	assert(game.state=="town" and p.pp[0]==MoveDB.pp_of(p.slots[0]) and p.pp[2]==0,"Bag choice restores only selected move")
	assert(p.bag.leppa_berry==1)
	p.berry_cd=0.0
	game._on_hotbar_used("leppa_berry")
	assert(game.state=="town" and game.menu=="" and p.pp[2]==10,"Hotkey restores lowest PP without a selection menu")
	assert(not p.bag.has("leppa_berry"))
	game._open_shop()
	assert(game.menu_ids.has("sitrus_berry") and game.menu_ids.has("lum_berry"))
	var idx: int=game.menu_ids.find("sitrus_berry")
	p.bag={"light_ball":1}
	game._resolve_menu(idx)
	assert(game.menu=="shop_confirm")
	game._resolve_menu(0)
	assert(p.bag.get("sitrus_berry",0)==1,"New berry is obtainable through normal barter")
	game._close_menu()
	p.hp=1
	p.berry_cd=0.0
	game._on_hotbar_used("sitrus_berry")
	assert(p.hp>1 and not p.bag.has("sitrus_berry"),"New berry works through normal hotkey dispatch")
	print("Battle berries: bag, PP selection/cancel, hotkey and shop barter passed")
	game.queue_free()
	await process_frame
	quit()
func shot(label: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")

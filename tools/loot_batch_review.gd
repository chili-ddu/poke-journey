extends "res://tools/kanto_expansion_review.gd"
const BATCH_OUT := "res://docs/loot_batch_review/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BATCH_OUT))
	await CaptureWindow.park(self)
	SaveData.path="user://save_loot_batch_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	await open_fixture("viridian_forest")
	game.world.player.position=Arena.tile_center(Vector2i(5,16))
	walker.target=game.world.player.position
	game.world.player.bag.clear()
	game.world.player.reward_reserve.clear()
	game.dialog_text=""
	game.ui_root.visible=false
	var notices: Array=[]
	var saves: Array=[]
	game.world.status_message.connect(func(text):notices.append(text))
	game.world.inventory_changed.connect(func():saves.append(true))
	for i in 3:game.world.spawn_loot("oran_berry",game.world.player.position+Vector2(18+i*3,12))
	for i in 2:game.world.spawn_loot("pecha_berry",game.world.player.position+Vector2(17+i*3,20))
	await shot("five_drops")
	game.world._step_drops(0.4)
	assert(game.world.player.bag.oran_berry==3 and game.world.player.bag.pecha_berry==2)
	assert(saves.size()==1,"One inventory save notification")
	game.world.step_loot_visual(0.12)
	assert(game.world.drops.size()==2,"One flight per kind")
	assert(notices.is_empty())
	for item in game.world.drops:
		assert(item.count==(3 if item.item_id=="oran_berry" else 2))
	SaveData.store(game.world.player,[],"viridian_forest",game.world.player.position)
	var saved := SaveData.load_saved()
	assert(saved.bag.oran_berry==3 and saved.bag.pecha_berry==2,"Inventory committed before visual completion")
	await shot("two_grouped_flights")
	game.world.step_loot_visual(0.07)
	assert(notices.size()==1 and notices[0].split("\n").size()==2,"One two-line receipt")
	assert(game.dialog_text==notices[0],"Receipt uses existing dialogue box")
	game.ui_root.visible=true
	await shot("one_receipt")
	game.world.step_loot_visual(0.5)
	assert(game.world.drops.is_empty())
	assert(game.world.player.bag.oran_berry==3 and game.world.player.bag.pecha_berry==2,"No duplicate inventory transfer")
	var file := FileAccess.open(BATCH_OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"drops":5,"grouped_flights":2,"receipt_pages":notices.size(),"receipt_lines":2,"inventory_saves":saves.size(),"saved_midflight":true,"no_duplicate":true,"hd2d":game.view3d!=null},"\t"));file.close()
	print("LOOT BATCH REVIEW PASSED")
	quit()
func shot(label: String) -> void:
	game._update_dialogue_focus()
	game.queue_redraw()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(BATCH_OUT+label+".png")

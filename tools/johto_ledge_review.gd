extends "res://tools/johto_gameplay_review.gd"

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://johto_ledge_review_only.cfg"
	OS.set_environment("BOT","1");OS.set_environment("GOD","1")
	Game.skip_opening=true;Game.bot_events=[];Game.bot_beaten=[]
	var mid:=Vector2i(501,81)
	await open_fixture("johto_060",Arena.tile_center(mid+Vector2i.UP))
	var target:=Arena.tile_center(mid+Vector2i.DOWN)
	var walker=game.world.player.controller
	walker.target=target;walker.active=true
	var hopped:=false
	for i in 120:
		game.world.step(DT)
		game.world.step_visual(DT)
		if game.world.player.dash.get("hop",false):hopped=true
		await frame(false)
		if game.world.player.position.distance_to(target)<1.5:break
	walker.active=false
	if not check(hopped,"Walking down a native ledge starts the existing hop"):return
	if not check(game.world.player.position.distance_to(target)<2.0,"Native ledge lands on the far side"):return
	for i in 40:
		game.world.step(DT)
		game.world.step_visual(DT)
		await frame(false)
	await shot("11_native_ledge_landing")
	var actor: Sprite3D=game.view3d._sprites[game.world.player.get_instance_id()].sprite
	var foot: Vector2=game.view3d.cam.unproject_position(actor.position)
	var expected: Vector2=game.view3d.cam.unproject_position(View3D.to3d(game.world.player.position))
	if not check(foot.distance_to(expected)<0.1,"Rendered feet stay at the collision position"):return
	var image:=root.get_texture().get_image()
	var pixels:=0
	for y in range(int(foot.y)-36,int(foot.y)+4):
		for x in range(int(foot.x)-12,int(foot.x)+13):
			var color:=image.get_pixel(x,y)
			if color.b>color.r+0.04 and color.g>color.r+0.08 and color.b>0.45:pixels+=1
	if not check(pixels>=20,"Occluded player remains readable in the actual rendered frame"):return
	FileAccess.open(OUT+"ledge_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"automatic_hop":hopped,"native_ledge":[501,81],"landed":true,"feet_aligned":true,"occlusion_cue_pixels":pixels,"window":[384,216]}))
	game.free();await process_frame
	print("Native Johto ledge passed: ordinary World walking triggers hop and lands on the far side, 384x216")
	quit()

extends "res://tools/kanto_expansion_review.gd"
# Render the actual movement at fixed 60 Hz so a boundary-only camera jump is measurable.
func clear_tile(t: Vector2i) -> bool:
	var p := Arena.tile_center(t)
	return not Arena.solid_at(t.x,t.y) and Arena.ledge_at(t.x,t.y)==0 and Arena.warp_at(p).is_empty() and p.distance_to(Arena.resolve(p,game.world.player.radius))<0.1

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_city_boundary_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	var seams := [
		{"id":"pewter_route3","place":"kanto_south","from":"pewter_city","to":"route3","axis":Vector2i.RIGHT,"edge":48,"lo":40,"hi":42},
		{"id":"pewter_route3_restored","place":"kanto_south","from":"pewter_city","to":"route3","axis":Vector2i.RIGHT,"edge":48,"lo":42,"hi":43,"span":1},
		{"id":"route4_cerulean","place":"kanto_north","from":"route4","to":"cerulean_city","axis":Vector2i.RIGHT,"edge":216,"lo":10,"hi":30},
		{"id":"cerulean_route5","place":"kanto_north","from":"cerulean_city","to":"route5","axis":Vector2i.DOWN,"edge":40,"lo":216,"hi":264},
		{"id":"route6_vermilion","place":"kanto_east","from":"route6","to":"vermilion_city","axis":Vector2i.DOWN,"edge":40,"lo":12,"hi":36},
	]
	for seam in seams:
		await open_fixture(seam.place)
		game.ui_root.visible=false
		game.view3d.set_process(false)
		var span := int(seam.get("span",3))
		var chosen := Vector2i(-1,-1)
		for cross in range(int(seam.lo),int(seam.hi)):
			var edge := Vector2i(int(seam.edge),cross) if seam.axis==Vector2i.RIGHT else Vector2i(cross,int(seam.edge))
			var ok := true
			for step in range(-span,span+1):
				if not clear_tile(edge+seam.axis*step):ok=false;break
			if ok:chosen=edge;break
		assert(chosen.x>=0,"Open straight native boundary: "+seam.id)
		for reverse in [false,true]:
			var direction: Vector2i = -seam.axis if reverse else seam.axis
			var start: Vector2i = chosen+seam.axis*(span if reverse else -span)
			var goal: Vector2i = chosen+seam.axis*(-span if reverse else span)
			game.world.player.position=Arena.tile_center(start)
			walker.target=game.world.player.position
			game.view3d._cam_ready=false
			for i in 20:
				game.advance(1.0/60)
				game.view3d._process(1.0/60)
				await process_frame
			var label: String = "boundary_"+seam.id+("_reverse" if reverse else "_forward")
			await shot(label+"_before")
			var before_area := Arena.area_at(game.world.player.position)
			var expected: String = seam.from if reverse else seam.to
			var last_area := before_area
			var crossings := 0
			var max_camera_step := 0.0
			var last_camera: Vector3 = game.view3d.cam.position
			var initial_basis: Basis = game.view3d.cam.basis
			var initial_fov: float = game.view3d.cam.fov
			walker.target=Arena.tile_center(goal)
			var frames := 0
			while game.world.player.position.distance_to(walker.target)>0.8:
				game.advance(1.0/60)
				game.view3d._process(1.0/60)
				frames+=1
				assert(frames<600,"Boundary walk must finish")
				assert(game.state!="warp" and current_scene==game,"No scene reload at seamless city edge")
				var camera: Camera3D = game.view3d.cam
				var step := camera.position.distance_to(last_camera)
				max_camera_step=maxf(max_camera_step,step)
				assert(step<0.2,"No camera snap over one fifth of a tile in one frame")
				assert(camera.basis.is_equal_approx(initial_basis),"Field angle remains stable")
				assert(is_equal_approx(camera.fov,initial_fov),"No boundary zoom")
				last_camera=camera.position
				var area := Arena.area_at(game.world.player.position)
				if area!=last_area:
					crossings+=1
					assert(area==expected,"Correct neighboring area")
					last_area=area
					await shot(label+"_crossing")
				await process_frame
			assert(crossings==1 and last_area==expected,"Exactly one boundary change")
			await shot(label+"_after")
			results.append({"boundary":seam.id,"reverse":reverse,"from":before_area,"to":last_area,"frames":frames,"crossings":crossings,"max_camera_step_tiles":max_camera_step,"scene_reload":false,"start":[start.x,start.y],"goal":[goal.x,goal.y]})
			print("Boundary passed: ",label," max camera step=",max_camera_step)
	FileAccess.open(OUT+"city_boundary_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"seamless":results},"  "))
	print("City boundaries: ",results.size()," seamless walks passed")
	game.queue_free()
	await process_frame
	quit()

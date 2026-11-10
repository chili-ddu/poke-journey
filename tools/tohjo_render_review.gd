extends "res://tools/johto_gameplay_review.gd"

func capture(label: String) -> void:
	game.view3d._cam_ready=false
	for i in 15:await frame(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/johto_border/"+label+".png")
	var p: Player=game.world.player
	print(label," body ",p.position/Arena.TILE," ground ",Arena.ground_height(p.position)," camera ",game.view3d.cam.position)

func cull(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original: Material=node.get_active_material(i)
			if original is BaseMaterial3D:
				var material:=original.duplicate() as BaseMaterial3D
				material.cull_mode=BaseMaterial3D.CULL_BACK
				node.set_surface_override_material(i,material)
	for child in node.get_children():cull(child)

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://tohjo_render_review_only.cfg"
	OS.set_environment("BOT","1");Game.skip_opening=true
	await open_fixture("johto_126",Vector2(45.5,20.5)*Arena.TILE)
	print("Scene culling flag ",game.view3d.native_renderer.data.get("cull_back_faces",false))
	await capture("probe_tohjo_entry")
	cull(game.view3d.native_renderer)
	await capture("probe_tohjo_back_cull")
	game.world.player.position=Vector2(36.5,13.5)*Arena.TILE
	await capture("probe_tohjo_inner")
	game.free();await process_frame
	quit()

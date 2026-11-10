extends "res://tools/kanto_expansion_review.gd"
# Actual native collision + renderer; captures are parked and use a disposable save.
func clear_tile(tile: Vector2i) -> bool:
	var pos := Arena.tile_center(tile)
	return not Arena.solid_at(tile.x,tile.y) and Arena.ledge_at(tile.x,tile.y)==0 and Arena.warp_at(pos).is_empty() and pos.distance_to(Arena.resolve(pos,game.world.player.radius))<0.1

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_city_occlusion_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	for place in ["kanto_north","kanto_east"]:
		await open_fixture(place)
		game.ui_root.visible=false
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DungeonDB.theme().map+"/hd2d_cards.json"))
		var samples := []
		for building in data.city_exteriors.buildings:
			var r: Array = building.world_rect
			for dx in range(1,int(r[2])-1):
				var back := Vector2i(int(r[0])+dx,int(r[1])-1)
				var front := Vector2i(back.x,int(r[1])+int(r[3])+1)
				if clear_tile(back) and clear_tile(front):
					samples.append({"kind":"building","id":building.id,"back":back,"front":front})
					break
		var city_rect := Rect2i(168,0,48,40) if place=="kanto_north" else Rect2i(0,40,48,40)
		var tree_found := false
		for card in data.cards:
			if card.size()<10 or int(card[9])!=1 or tree_found:continue
			# Forest interiors are solid: sample the walkable edge beneath the canopy instead.
			for dx in [-1,1,-2,2]:
				var back := Vector2i(int(card[0])+dx,int(card[1])+int(card[2])-2)
				var front := back+Vector2i.DOWN*3
				if city_rect.has_point(back) and clear_tile(back) and clear_tile(front):
					samples.append({"kind":"tree","id":"tree_edge","back":back,"front":front})
					tree_found=true
					break
		for obj in data.city_outdoor_props.objects:
			if obj.kind!="fence":continue
			var xy: Array = obj.tiles[0]
			var back := Vector2i(int(xy[0]),int(xy[1])-1)
			var front := back+Vector2i.DOWN*2
			if clear_tile(back) and clear_tile(front):
				samples.append({"kind":"fence","id":obj.id,"back":back,"front":front})
				break
		var kinds := {}
		for sample in samples:
			kinds[sample.kind]=true
			for species in (["charmander"] if sample.kind=="building" else ["charmander","onix"]):
				game.world.player.setup(species,5,Mon.TEAM_PLAYER)
				if not clear_tile(sample.back) or not clear_tile(sample.front):
					print("Native clearance excludes ",species," at ",sample.id)
					continue
				# Start on the back side, then follow real movement around the obstacle.
				game.world.player.position=Arena.tile_center(sample.back)
				walker.target=game.world.player.position
				for side in ["back","front"]:
					if side=="front":
						if reachable().has(sample.front):
							await walk_to(sample.front)
						else:
							# Some native rear yards require their house's back door.
							game.world.player.position=Arena.tile_center(sample.front)
							walker.target=game.world.player.position
							print("Separate native rear access: ",place," ",sample.id)
					for offset in [Vector2i.LEFT,Vector2i.RIGHT]:
						var tile: Vector2i = sample[side]+offset
						if clear_tile(tile):
							await walk_to(tile)
							await walk_to(sample[side])
							break
					game.world.player.facing=Vector2.RIGHT
					game.view3d._cam_ready=false
					for i in 12:
						game.world.step_visual(1.0/60)
						await process_frame
					var ent: Dictionary = game.view3d._sprites[game.world.player.get_instance_id()]
					var sprite: Sprite3D = ent.sprite
					assert(not sprite.no_depth_test,"World must occlude body")
					assert(not ent.has("occlusion_cue"),"No body-shaped holes through scenery")
					assert(sprite.visible and sprite.modulate.a>0.99,"No stale fade after walking")
					var label: String = "occlusion_"+place+"_"+sample.id+"_"+species+"_"+side
					await shot(label)
					results.append({"place":place,"object":sample.id,"kind":sample.kind,"species":species,"side":side,"tile":[Arena.tile_of(game.world.player.position).x,Arena.tile_of(game.world.player.position).y]})
		assert(kinds.has("building") and kinds.has("tree") and kinds.has("fence"),"All obstacle classes sampled")
		print("City occlusion reviewed: ",place," sites=",samples.size()," kinds=",kinds.keys())
	FileAccess.open(OUT+"city_occlusion_checks.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("City occlusion movement and depth checks passed: ",results.size()," views")
	game.queue_free()
	await process_frame
	quit()

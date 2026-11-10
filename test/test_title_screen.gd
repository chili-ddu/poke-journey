extends GutTest
class SelectionTitle:
	extends TitleScreen
	var launched := ""
	func start_game(s: String) -> void: launched=s

var old_pattern: String
var old_path: String
var old_migrate: bool
var old_last: String
var old_records: Dictionary
var title: SelectionTitle

func before_each() -> void:
	old_pattern=SaveData.slot_pattern
	old_path=SaveData.path
	old_migrate=SaveData.allow_migrate
	old_last=TitleScreen.last
	old_records=TitleScreen.last_records.duplicate()
	TitleScreen.last_records={}
	SaveData.slot_pattern="user://title_ui_test_%s.cfg"
	SaveData.allow_migrate=false
	TitleScreen.last="charmander"
	for s in SaveData.STARTERS:
		for id in SaveData.record_ids(s):SaveData.reset_slot(s,id)
	var cf := ConfigFile.new()
	cf.set_value("mon","species","charmeleon")
	cf.set_value("mon","level",17)
	cf.set_value("where","map","kanto_north")
	cf.set_value("where","x",190*Arena.TILE)
	cf.set_value("where","y",22*Arena.TILE)
	cf.save(SaveData.slot_path("charmander"))
	title=SelectionTitle.new()
	add_child_autofree(title)

func after_each() -> void:
	for s in SaveData.STARTERS:
		for id in SaveData.record_ids(s):SaveData.reset_slot(s,id)
	SaveData.slot_pattern=old_pattern
	SaveData.path=old_path
	SaveData.allow_migrate=old_migrate
	TitleScreen.last=old_last
	TitleScreen.last_records=old_records

func click_record(i: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=true
	e.position=title._record_rect(i).get_center()
	title._gui_input(e)

func test_record_selection_routes_to_matching_starter_and_keeps_evolution() -> void:
	assert_eq(title._shown_species("charmander"),"charmeleon")
	var current := DungeonDB.current
	DungeonDB.set_current("kanto_north")
	assert_eq(title._places.charmander,DungeonDB.area_name("cerulean_city"))
	DungeonDB.set_current(current)
	click_record(0)
	assert_eq(title.menu_items[0].label,Lang.t("title_continue"))
	title._choose("start")
	assert_eq(title.launched,"charmander","Continue uses the selected save slot")
	title._close_menu()
	title._select_starter(2)
	click_record(0)
	assert_eq(title.menu_items[0].label,Lang.t("title_new"))
	title._choose("start")
	assert_eq(title.launched,"squirtle","Empty record starts its own starter")

func test_reset_cancel_and_navigation_do_not_modify_saved_record() -> void:
	var path := SaveData.slot_path("charmander")
	var before := FileAccess.get_file_as_bytes(path)
	click_record(0)
	title._choose("reset")
	assert_true(title.confirm)
	assert_eq(title.menu_cursor,1,"Destructive action defaults to No")
	title._choose("cancel")
	assert_eq(FileAccess.get_file_as_bytes(path),before)
	var key := InputEventKey.new()
	key.physical_keycode=KEY_RIGHT
	key.pressed=true
	title._unhandled_input(key)
	assert_eq(title.starter(),"squirtle")
	assert_eq(FileAccess.get_file_as_bytes(path),before)

func test_place_preview_migrates_old_layout_once_and_preserves_saved_bytes() -> void:
	var path:=SaveData.slot_path("charmander")
	var bytes:=FileAccess.get_file_as_bytes(path)
	var original:=Vector2(190,22)*Arena.TILE
	var current:=original+Vector2(DungeonDB.LAYOUT_SHIFT.kanto_north[1])*Arena.TILE
	var place:=DungeonDB.current
	DungeonDB.set_current("kanto_north")
	var expected:=DungeonDB.area_name("cerulean_city")
	DungeonDB.set_current(place)
	assert_eq(title._place_name("kanto_north",original,1),expected)
	assert_eq(title._place_name("kanto_north",current,2),expected,"Current coordinates cannot shift twice")
	assert_eq(FileAccess.get_file_as_bytes(path),bytes,"A title preview cannot rewrite the save")

func test_enlarged_stage_updates_evolution_without_accumulating_actors() -> void:
	title._process(0.0)
	assert_eq(title.stage.actors.size(),3)
	var actor: Sprite3D = title.stage.actors[1]
	assert_eq(actor.texture,PixelUi.ui_tex("plat/icons/charmeleon"),"Original PC box icon")
	assert_eq(title._preview_texture("charmander"),PixelUi.ui_tex("plat/front/charmeleon"),"Left preview keeps the original Pokedex portrait")
	assert_false(actor.no_depth_test)
	assert_false(actor.shaded,"Preserve native PC icon colors")
	var original := PixelUi.ui_tex("plat/box_wallpapers/05").get_image()
	var wallpaper := title.stage.box_texture.get_image()
	for point in [Vector2i(0,0),Vector2i(7,7),Vector2i(80,64),Vector2i(167,127)]:
		assert_eq(wallpaper.get_pixelv(point),original.get_pixelv(point+TitleBoxStage.SOURCE_BOX.position),"Native wallpaper and border pixels")
	assert_between(actor.region_rect.size.y*actor.pixel_size,1.0,1.851)
	for i in 10:title._process(0.01)
	assert_eq(title.stage.actors.size(),3)
	assert_eq(SaveData.path,old_path,"Reading save summaries does not switch active slot")

func test_multiple_records_switch_preview_and_delete_only_selected_file() -> void:
	var cf := ConfigFile.new()
	cf.set_value("mon","species","charizard")
	cf.set_value("mon","level",39)
	cf.save(SaveData.slot_path("charmander",2))
	title._refresh()
	click_record(1)
	assert_eq(title.record_id(),2)
	assert_eq(title._shown_species("charmander"),"charizard")
	assert_eq(title._info.charmander.level,39)
	title._choose("reset")
	title._choose("reset_yes")
	assert_false(SaveData.slot_exists("charmander",2))
	assert_true(SaveData.slot_exists("charmander",1))
	assert_eq(SaveData.peek("charmander",1).level,17)

func test_five_fixed_slots_full_capacity_and_empty_slot_reuse() -> void:
	for starter in SaveData.STARTERS:
		assert_eq(title._records[starter].size(),5,"Every Pokemon always has five slots")
	for id in range(2,6):
		var cf := ConfigFile.new()
		cf.set_value("mon","species","charmander")
		cf.set_value("mon","level",id+5)
		cf.save(SaveData.slot_path("charmander",id))
	title._refresh()
	assert_eq(SaveData.next_record_id("charmander"),0,"Five occupied slots have no allocation")
	var keep := SaveData.path
	assert_false(SaveData.use_slot("charmander",6))
	assert_eq(SaveData.path,keep,"A sixth slot cannot switch the active write path")
	click_record(4)
	assert_eq(title.record_id(),5)
	title._close_menu()
	var key := InputEventKey.new()
	key.physical_keycode=KEY_DOWN
	key.pressed=true
	title._unhandled_input(key)
	assert_eq(title.record_id(),1,"Navigation wraps within the five slots")
	# Old surplus files stay on disk, but do not create extra visible slots.
	var surplus := SaveData.slot_path("charmander",6)
	FileAccess.open(surplus,FileAccess.WRITE).store_string("[legacy]\nvalue=6\n")
	var original := FileAccess.get_file_as_bytes(surplus)
	SaveData.reset_slot("charmander",3)
	title._refresh()
	assert_eq(title._records.charmander.size(),5)
	assert_eq(FileAccess.get_file_as_bytes(surplus),original,"No legacy file is deleted")
	assert_eq(SaveData.next_record_id("charmander"),3,"Reuses the empty numbered slot")
	click_record(2)
	assert_eq(title.record_id(),3)
	assert_eq(title.menu_items[0].label,Lang.t("title_new"))
	for item in title.menu_items:assert_ne(item.key,"reset","An empty slot has nothing to delete")
	title._close_menu()
	assert_false(SaveData.slot_exists("charmander",3),"Selecting an empty slot creates no file")

func test_unreadable_record_is_not_offered_as_a_new_game() -> void:
	FileAccess.open(SaveData.slot_path("charmander",2),FileAccess.WRITE).store_string("[other]\nvalue=1\n")
	title._refresh()
	click_record(1)
	assert_eq(title.record_id(),2)
	for item in title.menu_items:assert_ne(item.key,"start","Never overwrite an unreadable record")
	assert_eq(SaveData.next_record_id("charmander"),3)

func test_wallpaper_follows_selected_record_primary_type_with_original_pixels() -> void:
	for pair in [[0,0],[1,5],[2,9]]:
		title._select_starter(int(pair[0]))
		title._process(0.0)
		assert_eq(title.stage.wallpaper_index,int(pair[1]))
		var expected := PixelUi.ui_tex("plat/box_wallpapers/%02d"%int(pair[1]))
		assert_eq(title.stage.wallpaper_texture,expected,"Header uses the same native wallpaper")
		assert_eq(title.stage.box_texture.get_image().get_data(),expected.get_image().get_region(TitleBoxStage.SOURCE_BOX).get_data(),"Entire native frame and wallpaper retain exact pixels")
	assert_eq(TitleBoxStage.wallpaper_for_species("charizard"),5,"Fire/Flying keeps the primary Fire theme")
	assert_eq(TitleBoxStage.wallpaper_for_species("unknown"),0,"Missing type falls back to native forest")

func test_box_rectangle_aligns_to_pokemon_row_and_keeps_banner_proportions() -> void:
	var camera := title.stage.camera
	var offset := camera.position-Vector3(0,0.35,0)
	assert_almost_eq(rad_to_deg(atan2(offset.x,offset.z)),45.0,0.001)
	assert_almost_eq(rad_to_deg(atan2(camera.basis.z.y,camera.basis.z.z)),40.0,0.001)
	assert_eq(camera.projection,Camera3D.PROJECTION_FRUSTUM)
	var arrays := title.stage.box_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var widths: Array[float] = []
	var row := (camera.unproject_position(title.stage.actors[2].position)-camera.unproject_position(title.stage.actors[0].position)).normalized()
	for indices in [[0,1],[5,2],[6,7]]:
		var left := camera.unproject_position(vertices[indices[0]])
		var right := camera.unproject_position(vertices[indices[1]])
		assert_almost_eq((right-left).normalized().cross(row),0.0,0.001,"Box and banner run parallel to the Pokemon row")
		assert_true(Rect2(Vector2.ZERO,Vector2(title.stage.size)).has_point(left))
		assert_true(Rect2(Vector2.ZERO,Vector2(title.stage.size)).has_point(right))
		widths.append(right.distance_to(left))
	assert_almost_eq(widths[0],widths[1],0.01,"Body upper and lower lengths match")
	assert_almost_eq(widths[0],widths[2],0.01,"Banner spans the whole upper edge")
	var depth := camera.unproject_position(vertices[5])-camera.unproject_position(vertices[0])
	assert_lt(depth.x,0.0,"Depth recedes across the ground rather than forming an upright frame")
	assert_gt(depth.y,0.0)
	assert_lt(depth.y/widths[0],0.30,"The lying floor has foreshortened screen depth")
	for index in [0,1,2,5]:assert_almost_eq(vertices[index].y,0.0,0.001,"Wallpaper is on the floor")
	var banner_height := camera.unproject_position(vertices[11]).distance_to(camera.unproject_position(vertices[6]))
	assert_almost_eq(widths[2]/banner_height,116.0/22.0,0.01,"Banner retains native aspect ratio")
	var normal := (vertices[7]-vertices[6]).cross(vertices[11]-vertices[6]).normalized()
	assert_almost_eq(rad_to_deg(acos(absf(normal.y))),90.0,0.001,"Banner stands at a right angle to the floor")
	var top := camera.unproject_position(vertices[6])
	var base := camera.unproject_position(vertices[11])
	assert_almost_eq(top.x,base.x,0.01,"Banner rises vertically from the viewer's perspective")
	assert_lt(top.y,base.y)
	var polygon := PackedVector2Array([camera.unproject_position(vertices[0]),camera.unproject_position(vertices[1]),camera.unproject_position(vertices[2]),camera.unproject_position(vertices[5])])
	for actor in title.stage.actors:
		assert_true(Geometry2D.is_point_in_polygon(camera.unproject_position(actor.position),polygon),"All Pokemon stand inside the rectangle")

func test_icon_feet_shadows_and_click_targets_follow_the_front_row() -> void:
	for time in [0.0,0.2]:
		title.t=time
		title._process(0.0)
		var feet: Array[Vector2] = []
		for actor in title.stage.actors:feet.append(title.stage.camera.unproject_position(actor.position))
		assert_almost_eq(feet[1].x-feet[0].x,feet[2].x-feet[1].x,0.01,"Horizontal gaps remain equal despite perspective")
		assert_lt(feet[0].y,feet[1].y,"Bulbasaur stands farther up")
		assert_lt(feet[1].y,feet[2].y,"Squirtle stands farther down")
		assert_almost_eq((feet[1]-feet[0]).normalized().cross((feet[2]-feet[0]).normalized()),0.0,0.001,"Feet form one straight diagonal line")
		for i in 3:
			var actor: Sprite3D = title.stage.actors[i]
			var shadow: MeshInstance3D = title.stage.contact_shadows[i]
			assert_lt(Vector2(actor.position.x,actor.position.z).distance_to(Vector2(shadow.position.x,shadow.position.z)),0.01,"Contact shadow stays below its feet")
			var uv := title.stage.icon_bounds_uv(i)
			assert_true(Rect2(0,0,1,1).encloses(uv),"All icons stay inside the visible box viewport")
			var click := title.origin()+TitleScreen.STAGE.position+uv.get_center()*TitleScreen.STAGE.size
			assert_true(title._slot_rect(i).has_point(click),"Click follows the actual projected icon")
			for other in 3:
				if other!=i:assert_false(title._slot_rect(other).has_point(click),"Neighbor cannot steal the click")

func test_visible_side_margins_balance_without_moving_pokemon_or_bobbing() -> void:
	var original_positions: Array[Vector3] = []
	for actor in title.stage.actors:original_positions.append(actor.position)
	for evolved in [false,true]:
		if evolved:
			title._info.bulbasaur={"species":"venusaur","level":40}
			title._info.squirtle={"species":"blastoise","level":40}
		title._process(0.0)
		var corners := title.stage._floor_corners()
		var side := (corners[3]-corners[0]).normalized()
		var normal := Vector2(side.y,-side.x)
		var left := title.stage._silhouette_support(0,normal).x-corners[0].dot(normal)
		var right := corners[1].dot(normal)-title.stage._silhouette_support(2,normal).y
		assert_gte(left,40.0,"Bulbasaur has at least ten UI pixels of side clearance")
		assert_gte(right,40.0,"Squirtle has at least ten UI pixels of side clearance")
		if absf(left-right)>0.05:
			# Wider boards may meet the viewport margin before exact centering.
			# Do not crop the native banner to force the two gaps to match.
			var vertices: PackedVector3Array = title.stage.box_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var touches_limit := false
			for vertex in vertices:
				var p := title.stage.camera.unproject_position(vertex)
				if p.x<=6.05 or p.y<=6.05 or p.x>=title.stage.size.x-6.05 or p.y>=title.stage.size.y-6.05:touches_limit=true
			assert_true(touches_limit,"Center as closely as possible without clipping the wider box")
		for i in 3:assert_eq(title.stage.actors[i].position,original_positions[i],"Only the box moves")
		var offset: Vector2 = title.stage._box_offset
		title._process(0.2)
		assert_eq(title.stage._box_offset,offset,"Animation frames do not move the box")

func test_clicking_records_replaces_open_menu_without_starting_or_changing_saves() -> void:
	var path := SaveData.slot_path("charmander",1)
	var before := FileAccess.get_file_as_bytes(path)
	click_record(0)
	assert_eq(title.menu_items[0].label,Lang.t("title_continue"))
	click_record(1)
	assert_true(title.menu_open)
	assert_eq(title.record_id(),2)
	assert_eq(title.menu_items[0].label,Lang.t("title_new"))
	assert_eq(title.menu_cursor,0)
	assert_eq(title.launched,"")
	assert_false(SaveData.slot_exists("charmander",2))
	click_record(0)
	assert_eq(title.record_id(),1)
	assert_eq(title.menu_items[0].label,Lang.t("title_continue"))
	assert_eq(title._shown_species("charmander"),"charmeleon")
	assert_eq(FileAccess.get_file_as_bytes(path),before)

func test_changing_record_dismisses_delete_confirmation_safely() -> void:
	click_record(0)
	title._choose("reset")
	assert_true(title.confirm)
	click_record(3)
	assert_true(title.menu_open)
	assert_false(title.confirm)
	assert_eq(title.record_id(),4)
	assert_eq(title.menu_items[0].label,Lang.t("title_new"))
	assert_true(SaveData.slot_exists("charmander",1))
	for item in title.menu_items:assert_ne(item.key,"reset_yes")

func test_loading_locks_record_selection_and_destructive_actions() -> void:
	var before := FileAccess.get_file_as_bytes(SaveData.slot_path("charmander",1))
	title.launching=true
	click_record(2)
	assert_eq(title.record_id(),1)
	title._choose("reset_yes")
	assert_eq(FileAccess.get_file_as_bytes(SaveData.slot_path("charmander",1)),before)
	var key := InputEventKey.new();key.physical_keycode=KEY_RIGHT;key.pressed=true
	title._unhandled_input(key)
	assert_eq(title.starter(),"charmander")
	assert_eq(title.launched,"")

func test_loading_failure_reveals_title_and_does_not_replace_current_scene() -> void:
	var transition := TitleScreen.GameTransition.new()
	add_child(transition)
	var previous := get_tree().current_scene
	transition.begin("res://test/missing_transition_scene.tscn")
	assert_true(transition.active)
	transition.begin("res://scenes/main.tscn")
	assert_eq(transition.scene_path,"res://test/missing_transition_scene.tscn","Duplicate start is ignored")
	var error = await transition.failed
	assert_eq(int(error),ERR_FILE_NOT_FOUND)
	assert_false(transition.active)
	assert_almost_eq(transition.overlay.modulate.a,0.0,0.001)
	assert_eq(get_tree().current_scene,previous)

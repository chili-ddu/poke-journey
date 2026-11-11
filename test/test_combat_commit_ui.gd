extends GutTest

class PreviewWorld:
	extends Node2D
	var preview: Dictionary={}
	func dash_aim_preview() -> Dictionary:return preview.duplicate(true)

class PreviewGame:
	extends Node
	var world: Node2D
	var view3d=null
	var state:="fight"
	var ui_scale:=1.0
	var monologue:=false
	var cinematic:=false

func fixture() -> Dictionary:
	var game:=PreviewGame.new();add_child_autofree(game)
	var world:=PreviewWorld.new();game.add_child(world);game.world=world
	var hud:=Hud.new();hud.game=game;autofree(hud)
	return {"game":game,"world":world,"hud":hud}

func preview(from:=Vector2(80,90),to:=Vector2(160,90)) -> Dictionary:
	return {"from":from,"to":to,"width":8.0,"move_id":"take_down","active":false}

func test_inactive_modal_and_cinematic_dash_have_no_guide() -> void:
	var f:=fixture()
	assert_true(f.hud.has_method("dash_aim_geometry"),"HUD exposes read-only dash projection")
	if not f.hud.has_method("dash_aim_geometry"):return
	assert_true(f.hud.dash_aim_geometry().is_empty())
	f.world.preview=preview()
	for state in ["talk","menu","evolve","warp","gameover"]:
		f.game.state=state
		assert_true(f.hud.dash_aim_geometry().is_empty(),state)
	f.game.state="fight";f.game.monologue=true
	assert_true(f.hud.dash_aim_geometry().is_empty())
	f.game.monologue=false;f.game.cinematic=true
	assert_true(f.hud.dash_aim_geometry().is_empty())

func test_dash_corridor_and_endpoint_use_world_width_and_ui_scale_read_only() -> void:
	var f:=fixture();f.game.ui_scale=2.0;f.world.preview=preview()
	assert_true(f.hud.has_method("dash_aim_geometry"),"HUD exposes read-only dash projection")
	if not f.hud.has_method("dash_aim_geometry"):return
	var before: Dictionary=f.world.preview.duplicate(true)
	var geometry: Dictionary=f.hud.dash_aim_geometry()
	assert_eq(geometry.from,Vector2(40,45))
	assert_eq(geometry.to,Vector2(80,45))
	assert_eq(geometry.left,PackedVector2Array([Vector2(40,41),Vector2(80,41)]))
	assert_eq(geometry.right,PackedVector2Array([Vector2(40,49),Vector2(80,49)]))
	assert_eq(geometry.ring.size(),25)
	for point in geometry.ring:assert_almost_eq(point.distance_to(geometry.to),4.0,.001)
	assert_eq(f.world.preview,before,"HUD does not mutate path, targeting, or readiness")
	assert_false(geometry.active)

func test_active_and_zero_length_paths_have_finite_geometry_and_endpoint() -> void:
	var f:=fixture();f.world.preview=preview(Vector2(100,80),Vector2(100,80))
	f.world.preview.active=true
	assert_true(f.hud.has_method("dash_aim_geometry"),"HUD exposes read-only dash projection")
	if not f.hud.has_method("dash_aim_geometry"):return
	var geometry: Dictionary=f.hud.dash_aim_geometry()
	assert_true(geometry.active)
	assert_true(geometry.from.is_finite() and geometry.to.is_finite())
	assert_eq(geometry.from,geometry.to)
	assert_eq(geometry.ring.size(),25)
	assert_true(geometry.arrow.is_empty(),"An already blocked path has no misleading arrow")

func test_legacy_feet_offset_projects_both_ends_without_relocating_physics() -> void:
	var f:=fixture();f.world.preview=preview()
	f.world.preview.ground_offset=Vector2(0,8)
	var before: Dictionary=f.world.preview.duplicate(true)
	var geometry: Dictionary=f.hud.dash_aim_geometry()
	assert_eq(geometry.from,Vector2(80,98))
	assert_eq(geometry.to,Vector2(160,98))
	assert_eq(f.world.preview,before)

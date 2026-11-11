extends GutTest

class PreviewWorld:
	extends Node2D
	var preview: Dictionary={}
	func area_charge_preview() -> Dictionary:return preview.duplicate(true)

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
	var hud:=Hud.new();hud.game=game
	# Geometry is read-only and can be checked without drawing a live game HUD.
	autofree(hud)
	return {"game":game,"world":world,"hud":hud}

func test_inactive_and_paused_charge_have_no_preview() -> void:
	var f:=fixture()
	assert_true(f.hud.area_charge_geometry().is_empty())
	f.world.preview={"center":Vector2(100,80),"radius":24.0,"progress":0.5,"range":60.0}
	for state in ["talk","menu","evolve","warp","gameover"]:
		f.game.state=state
		assert_true(f.hud.area_charge_geometry().is_empty(),state)

func test_ground_circle_matches_cast_center_radius_and_ui_scale() -> void:
	var f:=fixture()
	f.game.ui_scale=2.0
	f.world.preview={"center":Vector2(100,80),"radius":24.0,"progress":0.5,"range":60.0}
	var before: Dictionary=f.world.preview.duplicate(true)
	var geometry: Dictionary=f.hud.area_charge_geometry()
	assert_eq(geometry.center,Vector2(50,40))
	assert_eq(geometry.ring.size(),33)
	for point in geometry.ring:assert_almost_eq(point.distance_to(geometry.center),12.0,0.001)
	assert_almost_eq(geometry.progress,0.5,0.001)
	assert_eq(f.world.preview,before,"Rendering must not change charge state or targeting")

func test_visual_ground_offset_moves_the_guide_without_changing_hit_center() -> void:
	var f:=fixture()
	f.world.preview={"center":Vector2(100,80),"radius":24.0,"progress":2.0,"range":96.0,"ground_offset":Vector2(0,8)}
	var geometry: Dictionary=f.hud.area_charge_geometry()
	assert_eq(geometry.center,Vector2(100,88))
	assert_eq(f.world.preview.center,Vector2(100,80))
	assert_eq(geometry.progress,1.0)

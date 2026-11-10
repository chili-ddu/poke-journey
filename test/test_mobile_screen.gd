extends GutTest

func test_phone_ratios_keep_game_aspect_and_separate_lower_controls() -> void:
	for surface in [Vector2(360,800),Vector2(390,844),Vector2(430,932),Vector2(768,1024),Vector2(844,390),Vector2(384,216)]:
		var result := MobileScreenLayout.calculate(surface,Vector2(384,216))
		var display: Rect2 = result.display
		var controls: Rect2 = result.controls
		assert_almost_eq(display.size.x/display.size.y,16.0/9.0,0.001)
		assert_gt(display.position.y,0.0,"Display sits slightly below the top")
		assert_almost_eq(display.end.y,controls.position.y,0.001)
		assert_false(display.intersects(controls))
		assert_gt(controls.size.y,0.0)
		assert_almost_eq(controls.end.y,surface.y,0.001)
		assert_true(Rect2(Vector2.ZERO,surface).encloses(display))

func test_notch_and_home_indicator_safe_area_are_respected() -> void:
	var safe := Rect2(0,44,390,766)
	var result := MobileScreenLayout.calculate(Vector2(390,844),Vector2(384,216),safe)
	assert_true(safe.encloses(result.display))
	assert_true(safe.encloses(result.controls))
	assert_gt(result.display.position.y,44.0)
	assert_eq(result.controls.end.y,810.0)

func test_empty_surface_cannot_produce_an_active_pad() -> void:
	var result := MobileScreenLayout.calculate(Vector2.ZERO,Vector2(384,216))
	assert_false(result.display.has_area())
	assert_false(result.controls.has_area())

func test_embedded_frame_keeps_logical_game_size_and_exposes_only_lower_pad() -> void:
	var surface := SubViewport.new()
	surface.size = Vector2i(390,844)
	add_child_autofree(surface)
	var frame := MobileGameFrame.new()
	frame.use_display_safe_area = false
	surface.add_child(frame)
	var original := Node2D.new()
	add_child(original)
	frame.adopt(original,Vector2i(384,216))
	await get_tree().process_frame
	assert_same(original.get_parent(),frame.client)
	assert_eq(frame.client.get_visible_rect().size,Vector2(384,216))
	assert_eq(frame.client.size_2d_override,Vector2i(384,216))
	assert_eq(frame.pad.control_area,frame.layout.controls)
	assert_gt(frame.pad.stick_center.y,frame.layout.display.end.y)
	assert_false(frame.layout.display.intersects(frame.pad.control_area))
	assert_same(MobileGameFrame.unwrap(frame),original)
	assert_same(MobileGameFrame.unwrap(original),original)

func test_desktop_autoload_is_inert() -> void:
	if TouchControls.mobile_platform():return
	assert_false(get_tree().root.get_node("MobileScreen").active)
	assert_false(ViewScale.mobile_mode(get_tree()))

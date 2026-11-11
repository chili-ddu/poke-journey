extends GutTest

func test_starter_balls_follow_opening_state_and_table_height() -> void:
	var w := World.new()
	add_child_autofree(w)
	var balls := StarterBalls.new()
	balls.setup("charmander")
	balls.intro = true
	w.add_child(balls)
	var view := View3D.new()
	add_child_autofree(view)
	view.set_process(false)
	view.world = w
	view.root3d = Node3D.new()
	view.add_child(view.root3d)
	view.cam = Camera3D.new()
	view.root3d.add_child(view.cam)
	view._starter_table_height = 0.6875
	var seen := {}
	view._sync_starter_balls(seen)
	var entries: Dictionary = view._sprites[balls.get_instance_id()]
	for id in StarterBalls.TILES:
		assert_true(entries[id].visible, "세 스타팅 볼이 모두 표시된다")
		assert_gt(entries[id].position.y, 0.6875, "탁자에 묻히지 않는다")
	assert_almost_eq(entries.charmander.pixel_size,BallRelease.PIXEL/Arena.TILE,0.00001)
	var before: Basis = entries.charmander.basis
	balls.wobble = 0.4
	view._sync_starter_balls(seen)
	assert_ne(entries.charmander.basis, before, "선택한 볼은 흔들린다")
	assert_eq(entries.bulbasaur.rotation.z, 0.0, "다른 볼은 흔들리지 않는다")
	view.cam.rotation.x = deg_to_rad(-40.0)
	for angle in [-0.63, -0.35, 0.0, 0.35, 0.63]:
		balls.wobble = angle
		view._sync_starter_balls(seen)
		var basis: Basis = entries.charmander.basis
		assert_almost_eq(basis.x.length(), 1.0, 0.0001, "흔들려도 가로 크기 고정")
		assert_almost_eq(basis.y.length(), 1.0, 0.0001, "흔들려도 세로 크기 고정")
		assert_almost_eq(basis.z.dot(view.cam.global_basis.z), 1.0, 0.0001, "화면 평면에서 회전해 찌그러지지 않는다")
	balls.taken = true
	view._sync_starter_balls(seen)
	assert_false(entries.charmander.visible, "열린 볼은 사라진다")
	assert_true(entries.squirtle.visible, "나머지 볼은 유지된다")
	assert_eq(entries.size(), 3, "동기화해도 노드를 중복 생성하지 않는다")

func test_opening_uses_same_ball_size_and_surface_for_shell_and_light() -> void:
	var view := View3D.new()
	add_child_autofree(view)
	view.cam = Camera3D.new()
	view.add_child(view.cam)
	view.cam.rotation.x = deg_to_rad(-40)
	view._starter_table_height = 0.6875
	var support := Vector2(252,108)
	var ground := BallRelease.center_3d(view,support,false)
	var table := BallRelease.center_3d(view,support,true)
	assert_almost_eq(table.y-ground.y,0.6875+0.015,0.0001)
	assert_eq(table.x,ground.x)
	assert_eq(table.z,ground.z)
	var bottom := ground-view.cam.global_basis.y*5.0*BallRelease.PIXEL/Arena.TILE
	assert_lt(bottom.distance_to(View3D.to3d(support)),0.0001)
	assert_eq(BallRelease.growth(0.0),0.0)
	assert_eq(BallRelease.growth(BallRelease.GROWN),1.0)

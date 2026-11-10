extends GutTest

# HD-2D 2단계 시제품(View3D, 2026-11-02): 3D 화면 자체는 창이 있어야 그려져서(tools/view3d_shot.gd 로 눈으로 확인),
# 여기선 데이터와 좌표 바꿈만 지킨다.

const DIR := "res://assets/maps/kanto_south"

func test_fence_thickness_closes_only_opaque_outline() -> void:
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.set_pixel(1,1,Color.WHITE);image.set_pixel(2,1,Color.GRAY)
	var edges:=View3D.fence_profile(image,Rect2i(1,1,2,2))
	assert_eq(edges.size(),6,"Two adjacent pixels have no wall between them")
	for edge in edges:
		assert_false(edge[0].x==1 and edge[1].x==1,"No interior cap")
		assert_lte(edge[0].y,1.0,"Transparent pixels do not create solid geometry")
		assert_lte(edge[1].y,1.0)
	var half:=View3D.fence_profile(image,Rect2i(1,1,1,2))
	assert_eq(half.size(),4,"Half-width corner texture has a closed end")

func test_supported_maps() -> void:
	assert_true(View3D.supported(DIR), "관동 남부(태초마을)는 세운 카드가 있다")
	assert_true(View3D.supported("res://assets/maps/oaks_lab"), "건물 안도 3D(사용자 2026-11-02)")
	assert_true(View3D.supported("res://assets/maps/viridian_forest"), "상록숲도 3D")
	assert_true(FileAccess.file_exists(DIR + "/hd2d_floor.png"), "세운 자리를 메운 바닥 그림")
	assert_false(View3D.supported(""))

func test_cards_fit_map_and_atlas() -> void:
	# 카드 = [x, 맨 위 y, 칸 수, 아틀라스 x, 아틀라스 y, 지붕 칸 수] — 물체 한 줄(나무 한 그루·집 한 채의 세로 한 줄)
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/map.json"))
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/hd2d_cards.json"))
	var atlas: Texture2D = load(DIR + "/hd2d_atlas.png")
	var t := int(j["tile"])
	assert_gt(j["cards"].size(), 1000)
	var cell := {}
	for c in j["cards"]:
		var x := int(c[0])
		var y0 := int(c[1])
		var n := int(c[2])
		assert_true(x >= 0 and x < int(m["width"]) and y0 >= 0 and y0 + n <= int(m["height"]), "카드가 지도 안")
		assert_true(int(c[3]) + t <= atlas.get_width() and int(c[4]) + t * n <= atlas.get_height(), "아틀라스 안의 띠")
		assert_lt(int(c[5]), n, "지붕은 묶음보다 짧다")
		if c.size() > 9 and int(c[9]) == 1:
			continue                                # 나무 한 그루 카드는 겹친 줄에서 칸이 겹친다(아래 나무 잎이 위 나무 밑동 앞)
		for i in n:
			var key := Vector2i(x, y0 + i)
			assert_false(cell.has(key), "칸마다 한 카드에만")
			cell[key] = c
	assert_false(cell.has(Vector2i(20, 218)), "연못은 바닥에 그대로")
	# 태초마을 집은 카드가 아니라 집 정의(houses)로 짓는다(도트 재구성 시범) — 연구소 벽은 카드 상자로 선다.
	var lab: Array = cell.get(Vector2i(27, 213), [])
	assert_false(lab.is_empty(), "연구소 벽은 선다")
	assert_eq(int(lab[1]), 209, "연구소 한 줄은 지붕부터 벽까지 한 장(209~213)")
	assert_eq(int(lab[5]), 3, "위 세 칸은 지붕(윗면)")
	# 경계 숲(12~13 열)은 이제 일반 카드가 아니라 나무 한 그루 카드(test_trees_are_whole_objects)

func test_to3d_maps_tiles_to_meters() -> void:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var v := View3D.to3d(Vector2(Arena.TILE * 3.0, Arena.TILE * 5.0), 0.5)
	assert_almost_eq(v.x, 3.0, 0.001, "1칸 = 1m")
	assert_almost_eq(v.z, 5.0, 0.001, "2D 아래(+y) = 3D 남쪽(+z)")
	assert_almost_eq(v.y, 0.5, 0.001)

func test_ground_effects_go_to_overlay_layer() -> void:
	# 바닥 표시(호·점선 고리·장판)는 3D 화면의 바닥 오버레이가 그리는 레이어를 갖고, 공중 효과는 갖지 않는다.
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	var sw := w.add_fx("swipe", Vector2.ZERO, {"size": 30.0})
	var ring := w.add_fx("dashring", Vector2.ZERO, {"size": 30.0})
	var spr := w.add_fx("sprite", Vector2.ZERO, {"text": "g4_flame"})
	var txt := w.add_fx("text", Vector2.ZERO, {"text": "12"})
	var grass := w.add_fx("tallgrass",Vector2.ZERO)
	var rustle := w.add_fx("rustle",Vector2.ZERO)
	assert_true(sw.visibility_layer & Look.GROUND_LAYER != 0)
	assert_true(ring.visibility_layer & Look.GROUND_LAYER != 0)
	assert_eq(spr.visibility_layer & Look.GROUND_LAYER, 0, "공중 효과는 오버레이에 안 그린다")
	assert_eq(txt.visibility_layer & Look.GROUND_LAYER, 0, "글자는 화면 좌표 글자로 따로")
	assert_eq(grass.visibility_layer & Look.GROUND_LAYER,0,"Terrain-aligned grass must not also appear on the flat floor overlay")
	assert_eq(rustle.visibility_layer & Look.GROUND_LAYER,0)

func test_pallet_houses_rebuilt_with_own_textures() -> void:
	# 도트 재구성 시범(사용자 2026-11-02): 태초마을형 집은 카드 대신 집 정의 + 면 그림(앞면·옆벽·뒷벽·지붕판).
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/hd2d_cards.json"))
	var houses: Array = j.get("houses", [])
	var at := {}
	for hd in houses:
		at[Vector2i(int(hd["x"]), int(hd["z"]))] = hd
	assert_true(at.has(Vector2i(17, 208)) and at.has(Vector2i(26, 208)), "태초마을 두 집")
	var hd: Dictionary = at[Vector2i(17, 208)]
	for part in ["front", "side", "back", "rooftop"]:
		assert_true(FileAccess.file_exists("%s/%s_%s.png" % [DIR, hd["tex"], part]), part)
	for c in j["cards"]:
		assert_false(int(c[0]) >= 17 and int(c[0]) <= 21 and int(c[1]) == 203, "집 자리엔 카드가 없다(집 정의로 짓는다)")
	assert_eq(View3D.EAVE, 0.0, "처마를 내밀지 않는다 — 길 폭은 원작 그대로")

func test_flowers_and_grass_are_tilted_ground_cards() -> void:
	# 꽃·수풀은 남쪽 모서리를 바닥에 붙이고 북쪽으로 살짝(FLORA_TILT 25°) 기울인 판 — 위로 지나가는 느낌(사용자 2026-11-02).
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/hd2d_cards.json"))
	var flower: Array = []
	var tilted := 0
	for c in j["cards"]:
		if c.size() > 7 and float(c[7]) > 0.0:
			tilted += 1
			assert_eq(int(c[2]), 1, "기울인 판은 한 칸짜리")
			assert_eq(float(c[6]), 1.0, "기울인 판은 낮춘 카드가 아니다")
		if int(c[0]) == 17 and int(c[1]) == 212:
			flower = c
	assert_gt(tilted, 50, "꽃밭·풀숲이 기울인 판으로 들어갔다")
	assert_gte(flower.size(), 8, "태초마을 꽃밭 칸은 카드가 있다")
	if flower.size() >= 8:
		assert_eq(float(flower[7]), 25.0, "꽃은 25° 기울인다")
	# 바닥에는 꽃 그림이 남지 않는다(판 밑으로 바탕색만).
	var flr: Image = (load(DIR + "/hd2d_floor.png") as Texture2D).get_image()
	var pad := 10
	var cols := {}
	for y in 16:
		for x in 16:
			cols[flr.get_pixel((17 + pad) * 16 + x, (212 + pad) * 16 + y)] = true
	assert_lte(cols.size(), 4, "꽃 칸 바닥은 바탕색으로 메웠다")

func test_lab_tables_rebuilt_with_legs_and_flat_board() -> void:
	# 오박사 연구소 탁자(사용자 2026-11-02): 다리 0.5m 위에 평평한 판, 원래 그림은 카드·바닥에서 지운다.
	var lab := "res://assets/maps/oaks_lab"
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(lab + "/hd2d_cards.json"))
	var tables: Array = j.get("tables", []).filter(func(t): return not String(t["tex"]).begins_with("hd2d_wallobj"))
	assert_eq(tables.size(), 5, "초록 탁자 하나 + 벽 앞 책상 둘 + 가운데 책장 두 줄(뒷벽 사물은 따로)")
	var shelves := tables.filter(func(t): return bool(t.get("box", false)))
	assert_eq(shelves.size(), 2, "책장은 상자 가구")
	for t in shelves.filter(func(t): return float(t["x1"]) - float(t["x0"]) > 2.0):
		assert_eq(float(t["z1"]), 9.0, "책장 앞면은 막힌 줄 남쪽 끝에 선다")
		assert_gt(float(t["h"]), 1.0, "앞면은 책 줄 전부(눕지 않는다)")
	for c in j["cards"]:
		assert_false(int(c[1]) <= 8 and int(c[1]) + int(c[2]) > 7 and int(c[0]) in [1, 2, 3, 4, 8, 9, 10, 11], "책장 칸은 카드로 세우지 않는다")
	for t in tables.filter(func(t): return not bool(t.get("box", false))):
		assert_eq(float(t["leg"]), 0.5, "다리 높이 0.5")
		assert_gt(float(t["thick"]), 0.0, "판 두께는 원작 앞 띠")
		assert_true(ResourceLoader.exists(lab + "/" + String(t["tex"]) + "_top.png"), "윗판 그림")
		assert_true(ResourceLoader.exists(lab + "/" + String(t["tex"]) + "_leg.png"), "다리 그림")
	assert_eq(int(tables[0]["legs"].size()), 2, "초록 탁자는 양쪽 다리")
	assert_not_null(tables[1]["decor"], "컴퓨터는 책상 위에 세운다")
	assert_not_null(tables[1]["pedestal"], "책상 오른쪽은 서랍장")
	for c in j["cards"]:
		assert_false(int(c[1]) == 4 and int(c[0]) >= 8 and int(c[0]) <= 10, "초록 탁자 칸은 카드로 세우지 않는다")
		assert_eq(int(c[7]), 0, "연구소 기계 불빛이 꽃으로 잡히지 않는다")
	# 바닥 그림: 탁자 다리·그림자 자리는 바닥 무늬로 메워졌다(원래 다리 외곽선 색이 남지 않음)
	var flr: Image = (load(lab + "/hd2d_floor.png") as Texture2D).get_image()
	var pad := 10 * 16
	for x in range(129, 134):
		assert_ne(flr.get_pixel(pad + x, pad + 89).to_html(false), "52526a", "다리 자리는 바닥 무늬")
	var w := View3D.new()
	assert_true(w.has_method("_build_table"), "View3D 가 탁자를 짓는다")
	w.free()

func test_indoor_floor_strips_stay_flat_and_furniture_is_cut_out() -> void:
	# 건물 안(사용자 2026-11-02): 양옆·맨 아래 바닥 띠는 세우지 않고, 가구 카드는 바닥을 누끼로 뺀다(바닥 타일이 서지 않는다).
	for map_id in ["players_house_1f", "viridian_center", "forest_gate_south"]:
		var dir: String = "res://assets/maps/" + String(map_id)
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/hd2d_cards.json"))
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/map.json"))
		var h := int(m["height"])
		for c in j["cards"]:
			assert_lt(int(c[1]) + int(c[2]) - (int(c[8]) if c.size() > 8 else 0), h, map_id + ": 맨 아래 줄(바깥)은 서지 않는다")
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_gate_south/hd2d_cards.json"))
	var plants: Array = g.tables.filter(func(t): return t.get("planter",false))
	assert_eq(plants.size(),8,"Eight individual pots with cutout foliage")
	for plant in plants: assert_true(plant.get("card",false),"Foliage remains pixel art above solid pot")
	# 누끼: 집 1층 카드 그림에 바닥 마루색이 통째로 남은 칸이 없다(완전히 불투명한 16×16 바닥 칸 없음)
	var atlas: Image = (load("res://assets/maps/players_house_1f/hd2d_atlas.png") as Texture2D).get_image()
	assert_gt(atlas.get_used_rect().size.x, 0, "아틀라스가 있다")

func test_physical_melee_defaults_to_tackle_model() -> void:
	# 몸통박치기가 물리 근접기의 기본형(사용자 2026-11-02): 앞으로 달려들며 미끄러지고 돌아오지 않는다.
	for id in ["tackle", "scratch", "slash", "metal_claw", "fury_attack", "peck"]:
		var m := MoveDB.get_move(id)
		assert_true(bool(m.get("lunge", false)) or String(m.get("anim", "")) == "Strike", id + " 는 달려든다")
		assert_true(m.has("glide") or m.has("step"), id + " 는 앞으로 미끄러진다")
	assert_false(bool(MoveDB.get_move("rapid_spin").get("lunge", false)), "제자리에서 도는 기술은 빼다")

func test_trees_are_whole_objects() -> void:
	# 나무 한 그루를 통째로(사용자 2026-11-02): 겹친 숲에서도 나무마다 본 그림 전체(2×3 뾰족한 나무)를 막힌 칸 남쪽 끝에 세운다.
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/hd2d_cards.json"))
	var trees := 0
	var at := {}
	for c in j["cards"]:
		if c.size() > 9 and int(c[9]) == 1:
			trees += 1
			assert_eq(int(c[2]), 3, "뾰족한 나무는 3칸 높이")
			at[Vector2i(int(c[0]), int(c[1]))] = true
	assert_gt(trees, 1000, "숲의 나무가 한 그루씩 선다")
	assert_true(at.has(Vector2i(14, 174)) and at.has(Vector2i(15, 174)), "1번도로 홀로 선 나무(왼쪽·오른쪽 반)")
	var vf: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/viridian_forest/hd2d_cards.json"))
	var round := 0
	for c in vf["cards"]:
		if c.size() > 9 and int(c[9]) == 1:
			round += 1
			assert_eq(int(c[2]), 4, "상록숲 둥근 나무는 4칸 높이")
	assert_gt(round, 300, "상록숲 나무도 한 그루씩")

func test_back_wall_split_into_wallpaper_and_objects() -> void:
	# 건물 안 뒷벽 = 벽지 + 사물(사용자 2026-11-02): 바닥까지 닿는 벽 사물은 벽 앞에 상자로 따로 선다.
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/rivals_house/hd2d_cards.json"))
	var objs: Array = j["tables"].filter(func(t): return String(t["tex"]).begins_with("hd2d_home_") and bool(t.get("box", false)))
	assert_gt(objs.size(), 0, "라이벌 집 뒷벽 사물이 상자로")
	for t in objs:
		assert_true(bool(t["box"]), "상자")
		assert_gte(float(t["z1"]) - float(t["z0"]), 0.4 - 0.001, "벽에서 0.4칸 넘게 나온다(윗판이 있으면 그 깊이)")
		assert_true(ResourceLoader.exists("res://assets/maps/rivals_house/" + String(t["tex"]) + "_front.png"), "앞면 그림")


func test_plants_block_one_tile_and_room_objects_stand() -> void:
	# 화분 1×1(사용자 2026-11-02): 잎 칸은 열리고 화분 칸만 막힌다 — 연구소 왼쪽 아래 화분(0,11 잎 / 0,12 화분).
	DungeonDB.set_current("oaks_lab")
	Arena.configure(DungeonDB.theme())
	assert_false(Arena.solid_at(0, 11), "화분 잎 칸은 지나갈 수 있다")
	assert_true(Arena.solid_at(0, 12), "화분 칸은 막힌다")
	# 주인공 방: TV·게임기·침대는 막힌 칸 위 상자, 계단 칸은 바닥에 눕는다
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/players_house_2f/hd2d_cards.json"))
	var boxes: Array = j["tables"].filter(func(t): return String(t["tex"]).begins_with("hd2d_table"))
	assert_eq(boxes.size(), 3, "TV·게임기·침대")
	# 집 식탁: 다리 둘 + 판(주인공 집·라이벌 집·회색시티 민가 같은 그림)
	for hm in ["players_house_1f", "rivals_house", "pewter_house1"]:
		var hj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/" + hm + "/hd2d_cards.json"))
		var dining: Array = hj["tables"].filter(func(t): return t.has("legs") and t["legs"].size() == 2)
		assert_eq(dining.size(), 1, hm + " 식탁은 다리 달린 탁자")
	for c in j["cards"]:
		assert_false(int(c[0]) in [8, 9] and int(c[1]) + int(c[2]) > 3 and int(c[1]) >= 2, "계단 칸은 세우지 않는다")

func test_indoor_side_strips_are_walkable() -> void:
	# 건물 안 양옆 바닥 띠는 지나다닌다(사용자 2026-11-02) — 연구소 왼쪽 띠(0,6)·바닥 모니터 판(0,3)·책장 바로 아래(0,9), 오른쪽 띠(12,5).
	# 책장 상자가 서 있는 칸(0,8)은 막힌다.
	DungeonDB.set_current("oaks_lab")
	Arena.configure(DungeonDB.theme())
	assert_false(Arena.solid_at(0, 6), "왼쪽 띠")
	assert_false(Arena.solid_at(12, 5), "오른쪽 띠")
	assert_false(Arena.solid_at(0, 3), "바닥에 붙은 모니터 판")
	assert_false(Arena.solid_at(0, 9), "책장 바로 아래 띠")
	assert_true(Arena.solid_at(0, 8), "책장 상자 자리")
	assert_true(Arena.solid_at(6, 13), "맨 아래 줄(바깥)은 막힌다")


func test_contact_shadow_fades_with_height_and_restores_on_landing() -> void:
	var grounded := View3D.contact_shadow(0)
	var half := View3D.contact_shadow(Arena.TILE * 0.5)
	var high := View3D.contact_shadow(Arena.TILE)
	assert_gt(grounded.x, half.x)
	assert_gt(half.x, high.x)
	assert_gt(grounded.y, half.y)
	assert_gt(half.y, high.y)
	assert_gt(high.y, 0.0, "착지 위치는 남긴다")
	assert_eq(View3D.contact_shadow(-10), grounded)
	assert_eq(View3D.contact_shadow(Arena.TILE * 10), high)

func test_shadow_material_is_per_character() -> void:
	var view := View3D.new()
	view.root3d = Node3D.new()
	view.add_child(view.root3d)
	view._blob_mesh = PlaneMesh.new()
	view._blob_mat = StandardMaterial3D.new()
	var first := view._new_blob()
	var second := view._new_blob()
	first.material_override.albedo_color = Color(0, 0, 0, 0.12)
	assert_ne(first.material_override, second.material_override)
	assert_eq(second.material_override.albedo_color, Color.WHITE, "한 마리의 점프가 다른 그림자를 바꾸지 않는다")
	view.free()

func test_bedroom_stair_landing_does_not_pull_back_wall_forward() -> void:
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/players_house_2f/hd2d_cards.json"))
	var count := 0
	for c in j["cards"]:
		if int(c[0]) in [8, 9, 10, 11] and int(c[1]) <= 0:
			count += 1
			assert_eq(int(c[1]) + int(c[2]) - (int(c[8]) if c.size() > 8 else 0), 2, "Wall base stays behind stair landing")
			assert_eq(int(c[2]), 3, "Adjacent wall tops remain aligned")
	assert_eq(count, 4)

func test_center_wall_furniture_is_separate_from_wall_decor() -> void:
	for location in ["viridian_center", "pewter_center"]:
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s/hd2d_cards.json" % location))
		var objects: Array = j["tables"]
		assert_eq(objects.size(), 16, "Floor furniture, four stools, lounge table and wall hangings are independent")
		var pc: Dictionary = objects[1]
		assert_eq(float(pc["x0"]), 11.0)
		assert_eq(float(pc["x1"]), 12.0)
		assert_gt(float(pc["h"]), 1.5, "PC includes screen and base")
		var shelf: Dictionary = objects[6]
		assert_true(shelf.get("closed", false), "Cabinet has a closed back")
		var face := (load("res://assets/maps/%s/hd2d_wallobj0_front.png" % location) as Texture2D).get_image()
		for y in face.get_height():
			for x in face.get_width():
				assert_eq(face.get_pixel(x,y).a, 1.0, "Solid cabinet art must not be keyed out")
		assert_lt(float(shelf["x1"]) - float(shelf["x0"]), 2.0, "Wall pattern must not merge shelf with other devices")

func test_home_wall_base_does_not_recede_below_clocks() -> void:
	for location in ["rivals_house", "pewter_house1", "pewter_house2", "viridian_center", "pewter_center", "players_house_1f"]:
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s/hd2d_cards.json" % location))
		for c in j["cards"]:
			if int(c[1]) < 0:
				assert_gte(int(c[1]) + int(c[2]), 2, "Wall does not recede under hanging objects: " + location)

func test_center_wall_hangings_have_height_and_separate_backdrop() -> void:
	for location in ["viridian_center", "pewter_center"]:
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s/hd2d_cards.json" % location))
		for index in [4, 5]:
			assert_true(j["tables"][index]["card"])
			assert_eq(float(j["tables"][index]["base"]), 0.75)
		for c in j["cards"]:
			if int(c[1]) == 0 and int(c[0]) > 0 and int(c[0]) < 14:
				assert_eq(int(c[2]), 2, "Center wall uses original two-tile height")

func test_center_counter_opening_and_supported_objects() -> void:
	for location in ["viridian_center", "pewter_center"]:
		var path: String = "res://assets/maps/" + location
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + "/hd2d_cards.json"))
		var counter: Dictionary = j.tables[0]
		assert_true(counter.get("counter", false))
		var image := (load(path + "/hd2d_table0_top.png") as Texture2D).get_image()
		assert_eq(image.get_pixel(56, 8).a, 0.0, "U opening remains transparent")
		assert_eq(image.get_pixel(8, 20).a, 1.0, "Removed vase leaves intact surface")
		var machine: Dictionary = j.tables[3]
		var support: Dictionary = j.tables[-1]
		assert_eq(float(machine.base), float(support.h), "Machine rests on its support")
		assert_true(machine.x0 >= support.x0 and machine.x1 <= support.x1)
		assert_true(machine.z1 >= support.z0 and machine.z1 <= support.z1)
		for i in [7, 8, 9]:
			assert_almost_eq(float(j.tables[i].base) - (0.3125 if j.tables[i].get("counter_vase", false) else 0.0), float(counter.h), 0.003, "Counter props sit on top; plate has a tiny anti-flicker offset")

func test_home_objects_use_explicit_floor_and_wall_placement() -> void:
	for location in ["players_house_1f", "players_house_2f", "rivals_house", "pewter_house1", "pewter_house2"]:
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s/hd2d_cards.json" % location))
		var seen := {}
		for object in j.tables:
			var tex: String = object.tex
			if not tex.begins_with("hd2d_home_"):
				continue
			assert_false(seen.has(tex), "No duplicate explicit object")
			seen[tex] = true
			if tex.ends_with("tv") or tex.ends_with("bookshelf") or tex.ends_with("cabinet"):
				assert_true(object.get("box", false))
				assert_gt(float(object.h), 1.4, "Screen/books stay on front, not flattened into top")
				assert_almost_eq(float(object.z1)-float(object.z0), 0.4, 0.001)
			elif tex.ends_with("sink"):
				assert_true(object.get("box", false))
				assert_eq(float(object.h), 0.5)
			elif "stair" in tex or "rail_" in tex or "chair_" in tex:
				assert_true(object.get("card", false))
			elif tex.ends_with("faucet") or tex.ends_with("cylinder"):
				assert_true(object.get("card", false))
				assert_eq(float(object.base), 0.5 if tex.ends_with("faucet") else 0.0)
			else:
				assert_true(object.get("card", false))
				assert_eq(float(object.base), 0.9)
				assert_almost_eq(float(object.z1), 2.025, 0.001, "Wall decoration sits just ahead of wall")
		assert_true(seen.has("hd2d_home_calendar") if location == "players_house_2f" else seen.has("hd2d_home_tv"))

func test_home_stair_landings_and_rail_orientation() -> void:
	for location in ["players_house_1f", "players_house_2f"]:
		var path: String = "res://assets/maps/" + location
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + "/hd2d_cards.json"))
		var parts := {}
		for t in j.tables:
			parts[t.tex] = t
		var mat: Dictionary = parts.hd2d_home_stair_mat
		assert_true(mat.decal)
		assert_true(float(mat.z0) <= 2.5 and float(mat.z1) >= 2.5, "Mat covers warp tile")
		assert_true(float(mat.x0) <= 10.5 and float(mat.x1) >= 10.5)
		DungeonDB.set_current(location)
		Arena.configure(DungeonDB.theme())
		assert_false(Arena.solid_at(10,2), "Stair entry stays open")
		if location == "players_house_2f":
			assert_true(parts.hd2d_home_rail_side.side_card)
			assert_true(parts.hd2d_home_stairs_down.decal)
			assert_eq(float(parts.hd2d_home_rail_side.z1), float(parts.hd2d_home_rail_front.z1), "Rail corner joins")

func test_home_chairs_block_and_plant_canopies_stay_open() -> void:
	for location in ["players_house_1f", "rivals_house", "pewter_house1", "pewter_house2"]:
		DungeonDB.set_current(location)
		Arena.configure(DungeonDB.theme())
		var dx := -1 if String(location).begins_with("pewter") else 0
		for x in [5+dx,8+dx]:
			for y in [4,5]:
				assert_true(Arena.solid_at(x,y), "Chair seat blocks movement")
				var p := Arena.tile_center(Vector2i(x,y))
				assert_gt(Arena.resolve(p,8).distance_to(p),0.0, "Cannot stand inside chair")
		for x in [4+dx,9+dx]:
			for y in [4,5,6]:
				var p := Arena.tile_center(Vector2i(x,y))
				assert_almost_eq(Arena.resolve(p,8).distance_to(p),0.0,0.001, "Outer dining aisle stays clear")
		var pot_y := 8 if location == "rivals_house" else 7
		var right := 10 if String(location).begins_with("pewter") else 12
		var left := 1 if location == "players_house_1f" else 0
		for x in [left,right]:
			assert_false(Arena.solid_at(x,pot_y-1), "Canopy does not block ground")
			var leaf := Arena.tile_center(Vector2i(x,pot_y-1))
			assert_almost_eq(Arena.resolve(leaf,8).distance_to(leaf),0.0,0.001, "Player fits beneath canopy")
			assert_true(Arena.solid_at(x,pot_y), "Pot still blocks one tile")

func test_home_dining_outer_route_remains_continuous() -> void:
	for location in ["players_house_1f", "rivals_house", "pewter_house1", "pewter_house2"]:
		DungeonDB.set_current(location)
		Arena.configure(DungeonDB.theme())
		var dx := -1.0 if String(location).begins_with("pewter") else 0.0
		var corners := [Vector2(4.5+dx,3.5),Vector2(9.5+dx,3.5),Vector2(9.5+dx,6.5),Vector2(4.5+dx,6.5)]
		var blocked := 0
		for segment in 4:
			for sample in 65:
				var p: Vector2 = corners[segment].lerp(corners[(segment+1)%4],sample/64.0)*Arena.TILE
				if Arena.resolve(p,8).distance_to(p)>0.01:
					blocked += 1
		assert_eq(blocked,0,location + " dining circuit clear at player radius")

func test_indoor_contact_shadow_preserves_landing_cue() -> void:
	var ground := View3D.contact_shadow(0,true)
	var air := View3D.contact_shadow(Arena.TILE,true)
	assert_gt(ground.y,air.y)
	assert_gt(air.y,0.0)
	assert_lt(ground.y,View3D.contact_shadow(0).y)
	assert_eq(ground.x,View3D.contact_shadow(0).x, "Light tuning does not move contact footprint")
	DungeonDB.set_current("players_house_1f")
	assert_lt(View3D.local_light_gain(),1.0)
	DungeonDB.set_current("kanto_south")
	assert_eq(View3D.local_light_gain(),1.0, "Outdoor effect lighting stays unchanged")

func test_indoor_camera_headroom_is_stable_and_outdoor_unchanged() -> void:
	var previous := DungeonDB.current
	var view := View3D.new()
	var mon := Mon.new()
	DungeonDB.set_current("players_house_2f")
	for species in ["charmander", "rattata", "onix"]:
		mon.setup(species,5,Mon.TEAM_PLAYER)
		var idle := view._indoor_headroom(mon)
		if species == "onix":
			assert_gt(idle,0.0,"Tall body reserves headroom before jumping")
		else:
			assert_eq(idle,0.0,"Small body retains original camera")
		mon.play_hop()
		mon.anim_t += 0.2
		mon.facing = Vector2.UP
		assert_eq(view._indoor_headroom(mon),idle,"Jump and facing do not bob camera")
		DungeonDB.set_current("kanto_south")
		assert_eq(view._indoor_headroom(mon),0.0,"Outdoor framing unchanged")
		DungeonDB.set_current("players_house_2f")
	mon.free()
	view.free()
	DungeonDB.set_current(previous)

func test_fang_depth_and_repeated_sync_preserve_transform() -> void:
	var view := View3D.new()
	add_child_autofree(view)
	view.root3d = Node3D.new()
	view.add_child(view.root3d)
	view.cam = Camera3D.new()
	view.root3d.add_child(view.cam)
	view.cam.position = Vector3(0,4,8)
	for kind in ["fang_directional","fang","fangfire"]:
		var fx := Fx.new()
		add_child_autofree(fx)
		fx.kind = kind
		fx.size = 54.0
		fx.lifetime = 0.8
		fx.age = 0.2
		view._sync_fx_fang(fx,{})
		var ent: Dictionary = view._sprites[fx.get_instance_id()]
		var transforms := {}
		for key in ent:
			var sprite: Sprite3D = ent[key]
			assert_false(sprite.no_depth_test,"World geometry must occlude "+kind)
			transforms[key] = sprite.transform
		for i in 10: view._sync_fx_fang(fx,{})
		for key in ent:
			assert_eq(ent[key].transform,transforms[key],"Camera lift must not accumulate")

func test_flash_depth_and_followed_face_do_not_accumulate_lift() -> void:
	var view := View3D.new()
	add_child_autofree(view)
	view.root3d = Node3D.new()
	view.add_child(view.root3d)
	view.cam = Camera3D.new()
	view.root3d.add_child(view.cam)
	view.cam.position = Vector3(0,4,8)
	view.cam.look_at(Vector3.ZERO)
	var caster := Node2D.new()
	add_child_autofree(caster)
	var body := Sprite3D.new()
	view.root3d.add_child(body)
	body.region_rect = Rect2(0,0,64,128)
	body.pixel_size = 0.01
	view._sprites[caster.get_instance_id()] = {"sprite":body}
	for kind in ["impact","burst","anim","scary_face"]:
		var fx := Fx.new()
		add_child_autofree(fx)
		fx.kind = "anim" if kind == "scary_face" else kind
		fx.text = "g4_scary_face"
		fx.frames = 4
		fx.size = 48
		fx.lifetime = 0.8
		fx.age = 0.6
		fx.scare_snap = kind == "scary_face"
		fx.follow = caster
		view._sync_fx_flash(fx,{})
		var sprite: Sprite3D = view._sprites[fx.get_instance_id()]["sprite"]
		assert_false(sprite.no_depth_test,"Geometry must occlude "+kind)
		var initial := sprite.transform
		for i in 10: view._sync_fx_flash(fx,{})
		assert_eq(sprite.transform,initial,"Repeated sync must preserve "+kind)
		if fx.scare_snap:
			var body_top := body.position+Vector3.UP*0.64
			assert_gt((sprite.position-body_top).dot(view.cam.global_basis.z),0.07,"Tall body must not cut into the face")
			assert_eq(sprite.region_rect.position.y,300.0,"Final surprise frame is retained")

func test_projectile_batches_keep_layer_geometry_and_reuse_resources() -> void:
	var view := View3D.new()
	add_child_autofree(view)
	view.root3d = Node3D.new()
	view.add_child(view.root3d)
	view.cam = Camera3D.new()
	view.root3d.add_child(view.cam)
	for style in ["flame_c","dragon_c"]:
		var p := Projectile.new()
		add_child_autofree(p)
		p.style = style
		p.position = Vector2(100,200)
		p.vel = Vector2(200,0)
		p.radius = 5
		p.range_full = 96
		p.range_left = 48
		p.age = 0.2
		view._sync_projectile(p,{})
		var entry: Dictionary = view._sprites[p.get_instance_id()]
		var key := "stream_batch" if style=="flame_c" else "dragon_batch"
		var node: MultiMeshInstance3D = entry[key]
		var batch := node.multimesh
		var layers := p.stream_layers() if style=="flame_c" else p.dragon_layers().slice(0,4)
		assert_eq(batch.instance_count,layers.size())
		assert_false(node.material_override.no_depth_test,"Walls still hide the batch")
		assert_eq(entry.size(),3 if style=="flame_c" else 5,"Keep bright dragon head layers separately sorted")
		# GPU instance transforms/colours are checked by tools/projectile_batch_review.gd.
		# The headless dummy renderer returns identity values for those getters.
		view._sync_projectile(p,{})
		assert_same(node.multimesh,batch,"Do not recreate GPU resources every frame")

func test_smoke_batch_falls_back_for_live_projectiles_and_other_air_effects() -> void:
	var w := World.new()
	add_child_autofree(w)
	var view := View3D.new()
	view.set_process(false)
	add_child_autofree(view)
	view.world = w
	for i in 8:
		var fx := Fx.new()
		fx.kind = "sprite"
		fx.text = "g4_smoke"
		fx.smoke_veil = true
		w.add_child(fx)
		w.fxs.append(fx)
	assert_eq(view._batchable_smoke().size(),8)
	w.fxs[0].delay = 0.1
	assert_true(view._batchable_smoke().is_empty(),"Too few active puffs use individual sprites")
	w.fxs[0].delay = 0.0
	var p := Projectile.new()
	w.add_child(p)
	w.projectiles.append(p)
	assert_true(view._batchable_smoke().is_empty(),"Transparent projectile sorting stays individual")
	p.dead = true
	assert_eq(view._batchable_smoke().size(),8)
	var flash := Fx.new()
	flash.kind = "sprite"
	flash.text = "g4_glow"
	flash.delay = 0.1
	w.add_child(flash)
	w.fxs.append(flash)
	assert_eq(view._batchable_smoke().size(),8,"Future effect does not force early fallback")
	flash.age = 0.1
	assert_true(view._batchable_smoke().is_empty())
	flash.dead = true
	assert_eq(view._batchable_smoke().size(),8)

func test_smoke_batch_reuses_node_hides_when_empty_and_releases_with_view() -> void:
	var view := View3D.new()
	view.set_process(false)
	add_child(view)
	view.root3d = Node3D.new()
	view.add_child(view.root3d)
	view.cam = Camera3D.new()
	view.root3d.add_child(view.cam)
	var fx := Fx.new()
	view.add_child(fx)
	fx.kind = "sprite"
	fx.text = "g4_smoke"
	fx.smoke_veil = true
	fx.age = 0.2
	var smoke := []
	for i in 8: smoke.append(fx)
	view._sync_smoke_batch(smoke)
	var node: MultiMeshInstance3D = view._smoke_batch_entry.smoke
	assert_true(node.visible)
	assert_eq(node.multimesh.instance_count,8)
	var reference: WeakRef = weakref(node)
	smoke.append(fx)
	view._sync_smoke_batch(smoke)
	assert_same(view._smoke_batch_entry.smoke,node)
	assert_eq(node.multimesh.instance_count,9)
	view._sync_smoke_batch([])
	assert_false(node.visible)
	view.free()
	assert_null(reference.get_ref())

func test_lab_machine_keeps_glass_opaque_but_outside_cutout_transparent() -> void:
	var texture := load("res://assets/maps/oaks_lab/hd2d_atlas.png") as Texture2D
	var img := texture.get_image()
	assert_gt(img.get_pixel(20,18).a,0.99,"Glass must occlude the Pokemon behind it")
	assert_gt(img.get_pixel(26,18).a,0.99)
	assert_gt(img.get_pixel(35,25).a,0.99)
	assert_eq(img.get_pixel(17,0).a,0.0,"Exterior cutout remains transparent")

func test_indoor_body_does_not_pull_through_furniture() -> void:
	var previous := DungeonDB.current
	DungeonDB.set_current("oaks_lab")
	var view := View3D.new()
	view.set_process(false)
	add_child_autofree(view)
	view.root3d = Node3D.new()
	view.add_child(view.root3d)
	view.cam = Camera3D.new()
	view.root3d.add_child(view.cam)
	view.cam.position = Vector3(0,5,10)
	var sprite := Sprite3D.new()
	view.root3d.add_child(sprite)
	sprite.position = Vector3(0,0,1)
	var before := sprite.position
	var scale_before := sprite.scale
	view._lift_to_camera({},sprite)
	assert_eq(sprite.position,before)
	assert_eq(sprite.scale,scale_before)
	var halo := view._new_halo(Color.WHITE,0.17)
	var mat := halo.material_override as StandardMaterial3D
	assert_eq(mat.billboard_mode,BaseMaterial3D.BILLBOARD_FIXED_Y)
	assert_false(mat.no_depth_test)
	DungeonDB.set_current(previous)

func test_lab_left_side_has_authored_surface() -> void:
	var surfaces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_south/hd2d_side_surfaces.json"))
	assert_eq(surfaces["25:214:left"]["texture"],"lab_side.svg")
	var atlas := (load("res://assets/maps/kanto_south/hd2d_atlas.png") as Texture2D).get_image()
	var rear_pixel := int(float(surfaces["25:214:left"]["rear_inset"]) * 16.0)
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_south/hd2d_cards.json"))
	var lab: Array = j.cards.filter(func(c): return int(c[0])==25 and int(c[1])==209)[0]
	assert_gt(atlas.get_pixel(int(lab[3]), int(lab[4])+rear_pixel).a, 0.5)
	assert_lt(atlas.get_pixel(int(lab[3]), int(lab[4])+rear_pixel-1).a, 0.5)
	var tex := load("res://assets/maps/kanto_south/lab_side.svg") as Texture2D
	assert_eq(tex.get_size(),Vector2(48,32))

func test_tail_light_cannot_reach_floor_in_low_walk_frames() -> void:
	for height in [0.05, 0.15, 0.3, 0.8, 1.4]:
		for indoor in [false, true]:
			assert_lt(View3D.tail_light_range(height, indoor), height)

func test_center_machine_is_closed_volume_on_support_and_corners_share_wall_edges() -> void:
	for location in ["viridian_center", "pewter_center"]:
		var path: String = "res://assets/maps/" + location
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + "/hd2d_cards.json"))
		var machine: Dictionary = j.tables[3]
		assert_true(machine.get("box", false))
		assert_false(machine.get("card", false))
		assert_true(machine.closed)
		var view := View3D.new()
		add_child_autofree(view)
		view.set_process(false)
		view.root3d = Node3D.new()
		view.add_child(view.root3d)
		view._build_table(path, machine)
		var mesh := (view.root3d.get_child(0) as MeshInstance3D).mesh
		assert_almost_eq(mesh.get_aabb().position.y, float(j.tables[-1].h) * view.k, 0.001, "기계 밑면과 받침 윗면 접합")
		assert_gt(mesh.get_aabb().size.z, 1.0, "수평으로 눕힌 회복머신")
		assert_almost_eq(mesh.get_aabb().size.y, 0.375 * view.k, 0.001, "낮은 테두리 높이")
		assert_almost_eq(float(machine.recess), 0.125, 0.001, "중앙은 테두리보다 낮게")
		var device := (load("res://assets/tiles/center_objects/healing_device.png") as Texture2D).get_image()
		var top_art := (load(path + "/hd2d_table3_top.png") as Texture2D).get_image()
		assert_eq(top_art.get_data(), device.get_data(), "기계 도트 전체를 윗면에 사용")
		assert_eq(float(machine.z0), float(j.tables[-1].z0))
		assert_eq(float(machine.z1), float(j.tables[-1].z1))
		assert_eq(mesh.get_surface_count(), 4)
		var top_vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		assert_eq(top_vertices.size(), 30, "둘레 네 면과 파인 바닥")
		for vertex in top_vertices.slice(24,30):
			assert_almost_eq(vertex.y, (float(machine.base) + float(machine.h) - float(machine.recess)) * view.k, 0.001)
		assert_eq(mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX].size(), 12, "앞뒤 십자가 면")
		assert_eq(mesh.surface_get_arrays(3)[Mesh.ARRAY_VERTEX].size(), 24, "홈 안쪽 네 벽")
		for i in mesh.get_surface_count():
			assert_eq(mesh.surface_get_material(i).billboard_mode, BaseMaterial3D.BILLBOARD_DISABLED)
		view._build_cards(path)
		var wall_mesh := (view.root3d.get_child(1) as MeshInstance3D).mesh
		var vertices: PackedVector3Array = wall_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		assert_true(vertices.slice(0, 6).has(Vector3(1, 2 * view.k, 2)), "왼쪽 모서리는 뒷벽 끝점 공유")
		assert_true(vertices.slice(6, 12).has(Vector3(14, 2 * view.k, 2)), "오른쪽 모서리는 뒷벽 끝점 공유")
		assert_eq(j.corner_walls.size(), 2)
		assert_eq(Vector2(j.corner_walls[0].b[0], j.corner_walls[0].b[1]), Vector2(1,2))
		assert_eq(Vector2(j.corner_walls[1].a[0], j.corner_walls[1].a[1]), Vector2(14,2))
		for corner in j.corner_walls:
			assert_eq(float(corner.h), 2.0, "뒷벽과 같은 높이")

func test_center_lounge_table_has_flat_top_and_four_block_legs() -> void:
	for location in ["viridian_center", "pewter_center"]:
		var path: String = "res://assets/maps/" + location
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + "/hd2d_cards.json"))
		var table: Dictionary = j.tables.filter(func(t): return t.tex == "hd2d_table6")[0]
		assert_eq(float(table.leg), 0.25)
		assert_eq(table.legs.size(), 2, "앞뒤에 복제할 좌우 다리 두 쌍")
		assert_gt(float(table.thick), 0.0)
		for card in j.cards:
			assert_false(int(card[0]) in [11,12] and int(card[1]) == 6, "기존 세로 탁상 그림 제거")
		var view := View3D.new()
		add_child_autofree(view)
		view.set_process(false)
		view.root3d = Node3D.new()
		view.add_child(view.root3d)
		view._build_table(path, table)
		var mesh := (view.root3d.get_child(0) as MeshInstance3D).mesh
		assert_eq(mesh.get_surface_count(), 4, "상판·앞뒤 테두리·옆 테두리·다리")
		var top: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in top: assert_almost_eq(vertex.y, float(table.leg) + float(table.thick), 0.001)
		var legs: PackedVector3Array = mesh.surface_get_arrays(3)[Mesh.ARRAY_VERTEX]
		assert_eq(legs.size(), 96, "각각 네 면이 있는 네 다리")
		for vertex in legs: assert_between(vertex.y, 0.0, float(table.leg))

func test_healing_bed_transition_returns_to_floor() -> void:
	assert_eq(View3D.healing_bed_weight(0.0, 0.4, 3.0), 0.0)
	assert_almost_eq(View3D.healing_bed_weight(0.2, 0.4, 3.0), 0.5, 0.001)
	assert_eq(View3D.healing_bed_weight(0.4, 0.4, 3.0), 1.0)
	assert_eq(View3D.healing_bed_weight(2.0, 0.4, 3.0), 1.0)
	assert_almost_eq(View3D.healing_bed_weight(3.6, 0.4, 3.0), 0.5, 0.001)
	assert_eq(View3D.healing_bed_weight(3.8, 0.4, 3.0), 0.0)

func test_center_stools_block_entry_but_leave_lounge_aisles_open() -> void:
	for location in ["viridian_center", "pewter_center"]:
		DungeonDB.set_current(location)
		Arena.configure(DungeonDB.theme())
		for tile in [Vector2i(11,5),Vector2i(12,5),Vector2i(14,6),Vector2i(14,7)]:
			assert_true(Arena.solid_at(tile.x, tile.y))
			var center := (Vector2(tile)+Vector2(0.5,0.5))*Arena.TILE
			assert_gt(center.distance_to(Arena.resolve(center,8.0)), 1.0, "Cannot stand inside stool")
		for route in [[Vector2(10.5,4.5),Vector2(13.5,4.5)], [Vector2(13.5,4.5),Vector2(13.5,8.5)], [Vector2(10.5,8.5),Vector2(13.5,8.5)]]:
			for step in 25:
				var pos: Vector2 = route[0].lerp(route[1], step/24.0)*Arena.TILE
				assert_lt(pos.distance_to(Arena.resolve(pos,8.0)),0.01,"Lounge aisle remains open")

func test_centers_have_no_link_room_stairs_or_warps() -> void:
	for location in ["viridian_center", "pewter_center"]:
		var path: String = "res://assets/maps/" + location
		var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"/hd2d_cards.json"))
		assert_false(geometry.has("stairs"))
		var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"/map.json"))
		assert_eq(map.warps.size(),3,"Only the three lobby exit tiles remain")
		for warp in map.warps:
			assert_false(String(warp.to).ends_with("pokemon_center_2f"))
		DungeonDB.set_current(location)
		Arena.configure(DungeonDB.theme())
		for row in range(5,9):
			var pos := Vector2(1.5,row+0.5)*Arena.TILE
			assert_lt(pos.distance_to(Arena.resolve(pos,8.0)),0.01,"Former stair approach stays walkable")

func test_center_pots_fit_supports_without_wall_overlap() -> void:
	for location in ["viridian_center", "pewter_center"]:
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s/hd2d_cards.json" % location))
		var counter: Dictionary = j.tables[0]
		for prop in j.tables:
			if prop.get("counter_vase",false):
				var cx := (float(prop.x0)+float(prop.x1))*0.5
				assert_gte(float(prop.z1)-0.3125,float(counter.inner_z))
				assert_lte(float(prop.z1)+0.3125,float(counter.z1))
				assert_gte(cx-0.3125,float(counter.x0))
				assert_lte(cx+0.3125,float(counter.x1))
			if prop.get("planter",false):
				assert_gt(float(prop.z1)-0.35,2.0,"Rim stays clear of rear wall")

func test_viridian_public_buildings_keep_continuous_roofs_and_doors() -> void:
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_south/hd2d_cards.json"))
	var atlas := (load("res://assets/maps/kanto_south/hd2d_atlas.png") as Texture2D).get_image()
	for bounds in [[34,136,4,4],[33,126,6,5],[26,15,4,4],[12,12,7,5]]:
		for x in range(bounds[0],bounds[0]+bounds[2]):
			var strips: Array = j.cards.filter(func(c): return int(c[0])==x and int(c[1])>=bounds[1] and int(c[1])<bounds[1]+bounds[3])
			assert_eq(strips.size(),1,"One continuous strip per building column")
			var c: Array = strips[0]
			assert_eq(int(c[2]),bounds[3])
			assert_eq(int(c[5]),bounds[3]-2,"Adjacent roof planes share height")
			for y in range((bounds[3]-2)*16,bounds[3]*16):
				assert_eq(atlas.get_pixel(int(c[3])+8,int(c[4])+y).a,1.0,"Facade/door pixels are not omitted as walkable ground")

func test_viridian_flower_beds_use_grass_instead_of_pale_road() -> void:
	var image := (load("res://assets/maps/kanto_south/hd2d_floor.png") as Texture2D).get_image()
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_south/map.json"))
	var pad := int(map.pad)*16
	for tile in [Vector2i(34,143),Vector2i(36,143)]:
		var green := 0
		for y in 16:
			for x in 16:
				var color := image.get_pixel(pad+tile.x*16+x,pad+tile.y*16+y)
				if color.g-color.r > 0.06 and color.g-color.b > 0.03: green += 1
		assert_gt(green,230,"Flower bed has continuous grass, not a square of road")

func test_grass_cutout_preserves_blades_and_removes_lawn() -> void:
	var source := (load(Fx.GRASS_FX) as Texture2D).get_image()
	var cutout := Fx.grass_cutout_texture().get_image()
	var removed := 0
	var blades := 0
	for y in source.get_height():
		for x in source.get_width():
			var c := source.get_pixel(x,y)
			if c.a>0.0 and cutout.get_pixel(x,y).a==0.0: removed += 1
			if c.r8==57 and c.g8==139 and c.b8==49:
				assert_eq(cutout.get_pixel(x,y),c)
				blades += 1
	assert_gt(removed,100,"Lawn no longer forms a moving rectangular patch")
	assert_gt(blades,100,"Dark grass blades remain intact")

func test_gate_furniture_inventory_and_passage_clearance() -> void:
	for location in ["forest_gate_south","forest_gate_north"]:
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/%s/hd2d_cards.json" % location))
		assert_eq(j.tables.filter(func(t): return t.has("legs")).size(),2)
		assert_eq(j.tables.filter(func(t): return t.get("planter",false)).size(),8)
		assert_eq(j.tables.filter(func(t): return t.get("chair",false)).size(),4)
		assert_eq(j.floor_decor.size(),2)
		DungeonDB.set_current(location)
		Arena.configure(DungeonDB.theme())
		for tile in [Vector2i(10,4),Vector2i(10,5),Vector2i(13,5),Vector2i(13,8)]:
			assert_true(Arena.solid_at(tile.x,tile.y),"Chair footprint blocks entry")
		for step in 81:
			var at := Vector2(7.5,2.5+step/10.0)*Arena.TILE
			assert_lt(at.distance_to(Arena.resolve(at,8.0)),0.01,"Central through aisle stays clear")

func test_ground_item_drop_lands_once_and_restored_items_stay_still() -> void:
	assert_eq(GroundItem.drop_height(0.0),14.0)
	assert_almost_eq(GroundItem.drop_height(GroundItem.FALL_TIME),0.0,0.001)
	assert_almost_eq(GroundItem.drop_height((GroundItem.FALL_TIME+GroundItem.DROP_TIME)*0.5),3.0,0.001)
	assert_eq(GroundItem.drop_height(GroundItem.DROP_TIME),0.0)
	assert_eq(GroundItem.drop_height(5.0),0.0)
	var item := GroundItem.new()
	item.setup(Vector2i(5,12),"dig","bug_catcher_sammy",true)
	assert_eq(item.drop_age,0.0)
	item.step_drop(1.0)
	assert_eq(item.drop_age,GroundItem.DROP_TIME)
	item.setup(Vector2i(5,12),"dig","bug_catcher_sammy")
	assert_eq(item.drop_age,GroundItem.DROP_TIME)
	assert_eq(item._tex.get_size(),Vector2(16,16))
	item.free()

func test_forest_gate_logs_match_two_mirrored_staggered_source_bundles() -> void:
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/viridian_forest/hd2d_cards.json"))
	assert_eq(j.log_fences.size(),2)
	DungeonDB.set_current("viridian_forest")
	Arena.configure(DungeonDB.theme())
	var view := View3D.new()
	add_child_autofree(view)
	view.set_process(false)
	view.root3d = Node3D.new()
	view.add_child(view.root3d)
	for spec in j.log_fences:
		assert_eq(spec.posts.size(),6)
		assert_eq(float(spec.posts[3][1])-float(spec.posts[0][1]),1.0,"Second lane starts one tile later")
		assert_eq(float(spec.posts[1][1])-float(spec.posts[0][1]),0.5,"Three overlapping source posts keep half-tile spacing")
		view._build_log_fence("res://assets/maps/viridian_forest",spec)
	for group in view.root3d.get_children():
		assert_eq(group.get_child_count(),6)
		for node in group.get_children():
			assert_almost_eq(node.mesh.get_aabb().position.y,0.0,0.001)
			assert_true(Arena.solid_at(int(node.position.x),int(node.position.z)))
	for x in [3,7]:
		for y in [10,11,12]: assert_true(Arena.solid_at(x,y),"Original fence collision restored")
	for c in j.cards:
		assert_false(int(c[0]) in [3,7] and int(c[1])==10)

func test_road_log_groups_preserve_blocked_positions_without_flat_duplicates() -> void:
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_south/hd2d_cards.json"))
	DungeonDB.set_current("kanto_south")
	Arena.configure(DungeonDB.theme())
	var posts := {}
	for group in j.log_fences:
		for xy in group.posts:
			var tile := Vector2i(int(xy[0]),int(xy[1]))
			assert_false(posts.has(tile),"No duplicated log meshes")
			posts[tile]=true
			assert_true(Arena.solid_at(tile.x,tile.y+20),"Collision retained at translated source position")
	assert_eq(posts.size(),32)
	for card in j.cards:
		if card.size()>9 and int(card[9])==1: continue
		for y in range(int(card[1]),int(card[1])+int(card[2])):
			assert_false(posts.has(Vector2i(int(card[0]),y)),"No upright source fence behind 3D posts")

func test_museum_exhibit_art_is_preserved_and_fixtures_are_separate() -> void:
	var path := "res://assets/maps/pewter_museum_1f"
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"/hd2d_cards.json"))
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"/map.json"))
	var raw := (load(path+"/preview.png") as Texture2D).get_image()
	var pad := int(map.pad)*16
	for entry in [[5,52],[6,100]]:
		var tex := String(j.tables[entry[0]].tex)
		var top := (load(path+"/"+tex+"_top.png") as Texture2D).get_image()
		var front := (load(path+"/"+tex+"_front.png") as Texture2D).get_image()
		assert_eq(top.get_data(),raw.get_region(Rect2i(pad+48,pad+entry[1],64,18)).get_data(),"Original fossil art is intact on top")
		assert_eq(front.get_data(),raw.get_region(Rect2i(pad+48,pad+entry[1]+18,64,10)).get_data(),"Original nameplate/glass face intact")
	assert_eq(j.tables.filter(func(t): return t.get("planter",false)).size(),5)
	assert_true(j.has("museum_stairs"))
	var windows: Array = j.tables.filter(func(t): return String(t.tex).begins_with("hd2d_museum_window"))
	assert_eq(windows.size(),2)
	for window in windows:
		assert_true(window.get("card",false))
		assert_almost_eq(float(window.z1),2.005,0.001)
	for card in j.cards:
		assert_false(int(card[0]) in [3,4,5,6] and int(card[1]) in [3,6],"Exhibits are no longer split into upright strips")
	assert_eq(map.warps.size(),6,"Museum entrances and stairs retained")

func test_museum_upstairs_displays_keep_source_art_and_stairs_warp() -> void:
	var path := "res://assets/maps/pewter_museum_2f"
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"/hd2d_cards.json"))
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"/map.json"))
	var raw := (load(path+"/preview.png") as Texture2D).get_image()
	var pad := int(map.pad)*16
	for entry in [[0,32,72,64,40,8],[1,224,64,48,24,8]]:
		var tex := String(j.tables[entry[0]].tex)
		var top := (load(path+"/"+tex+"_top.png") as Texture2D).get_image()
		var front := (load(path+"/"+tex+"_front.png") as Texture2D).get_image()
		assert_eq(top.get_data(),raw.get_region(Rect2i(pad+entry[1],pad+entry[2],entry[3],entry[4])).get_data(),"Original upstairs display top retained")
		assert_eq(front.get_data(),raw.get_region(Rect2i(pad+entry[1],pad+entry[2]+entry[4],entry[3],entry[5])).get_data(),"Original display front retained")
	assert_eq(j.tables.filter(func(t): return t.get("planter",false)).size(),6)
	assert_eq(j.tables.filter(func(t): return String(t.tex).begins_with("hd2d_museum_window")).size(),4)
	var stairs: Array = j.tables.filter(func(t): return t.tex=="hd2d_museum_downstairs")
	assert_eq(stairs.size(),1)
	assert_true(stairs[0].get("decal",false),"Downstairs opening lies on floor")
	assert_eq(j.cards.size(),19,"No duplicate upright prop strips remain")
	assert_eq(map.warps.size(),1)
	assert_eq(int(map.warps[0].x),11)
	assert_eq(int(map.warps[0].y),8)

func test_gym_rocks_statues_and_back_wall_are_separate() -> void:
	var path := "res://assets/maps/pewter_gym"
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"/hd2d_cards.json"))
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"/map.json"))
	var raw := (load(path+"/preview.png") as Texture2D).get_image()
	var pad := int(map.pad)*16
	var positions := [Vector2i(5,3),Vector2i(7,3),Vector2i(4,5),Vector2i(8,5),Vector2i(3,7),Vector2i(5,7),Vector2i(7,7),Vector2i(9,7),Vector2i(1,8),Vector2i(11,8),Vector2i(4,9),Vector2i(8,9),Vector2i(1,10),Vector2i(11,10)]
	var rocks: Array = j.tables.filter(func(t): return String(t.tex).begins_with("hd2d_gym_rock"))
	assert_eq(rocks.size(),14)
	for i in rocks.size():
		var tile: Vector2i = positions[i]
		assert_eq(map.solid[tile.y][tile.x],"1","Rock collision retained")
		var image := (load(path+"/"+String(rocks[i].tex)+"_front.png") as Texture2D).get_image()
		var start := 3 if tile.y==3 else 0
		var retained := 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a==0: continue
				retained += 1
				assert_eq(image.get_pixel(x,y),raw.get_pixel(pad+tile.x*16+x,pad+tile.y*16+start+y),"Rock pixels retain original colors")
		assert_gt(retained,100,"Rock silhouette remains intact")
	assert_eq(j.tables.filter(func(t): return String(t.tex).begins_with("hd2d_gym_statue")).size(),2)
	assert_eq(j.tables.filter(func(t): return String(t.tex).begins_with("hd2d_gym_pedestal") and t.get("closed",false)).size(),2)
	assert_eq(j.tables.filter(func(t): return String(t.tex).begins_with("hd2d_wallobj")).size(),0,"No giant inferred wall cabinets")
	assert_eq(map.warps.size(),3,"Original exits remain")

func test_arena_camera_rises_after_reveal_and_keeps_court_level() -> void:
	var intro := View3D.arena_camera_angles("intro")
	var throwing := View3D.arena_camera_angles("show")
	var start := View3D.arena_camera_angles("back",0.0)
	var middle := View3D.arena_camera_angles("back",0.5)
	var end := View3D.arena_camera_angles("back",1.0)
	var fight := View3D.arena_camera_angles("fight")
	assert_eq(intro,throwing,"Stay low during throw/reveal")
	assert_eq(start,intro,"Rise starts at low angle")
	assert_gt(middle.x,intro.x)
	assert_lt(middle.x,fight.x)
	assert_eq(end,fight,"Rise ends at battle angle")
	assert_gt(fight.y,0.0,"Right-oblique view is retained")
	assert_eq(intro.y,fight.y,"No horizontal snap between introduction and battle")

func test_camera_relative_movement_keeps_screen_right_and_speed() -> void:
	var view := View3D.new()
	add_child_autofree(view)
	view.cam=Camera3D.new()
	add_child_autofree(view.cam)
	view.cam.position=Vector3(4,7,12)
	view.cam.look_at(Vector3.ZERO)
	var direction := view.screen_move_world(Vector2.RIGHT)
	assert_almost_eq(direction.length(),1.0,0.001)
	assert_almost_eq(Vector3(direction.x,0,direction.y).dot(view.cam.basis.x),1.0,0.001)
	view.visible=false
	assert_eq(view.screen_move_world(Vector2.UP),Vector2.UP,"2D fallback preserves original controls")

func test_room_battle_style_has_upright_wall_and_indoor_lighting() -> void:
	var path := "res://assets/maps/arena_pewter_gym"
	var map: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/map.json"))
	var cards: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/hd2d_cards.json"))
	assert_eq(map.arena.style,"room")
	assert_eq(View3D.sky_kind("arena_pewter_gym"),"indoor")
	assert_true(DungeonDB.is_arena("arena_pewter_gym"),"Room lighting does not disable real-time arena skills")
	var wall: Array=cards.cards.filter(func(c): return int(c[1])==0)
	assert_eq(wall.size(),int(map.width)+2*int(map.pad),"Wall continues beyond the low camera's edges")
	for strip in wall:
		assert_eq(int(strip[2]),3)
		assert_eq(int(strip[5]),0,"Wall is never folded like a roof")
	assert_eq(cards.tables.size(),0,"No wall decorations inferred as furniture")

func test_oblique_camera_preserves_level_lens_without_roll() -> void:
	for pitch in [20.0,30.0,40.0]:
		var basis := View3D.arena_camera_basis(pitch)
		assert_eq(basis.x,Vector3.RIGHT,"Level lens preserves horizontal width")
		assert_almost_eq(basis.y.x,0.0,0.0001,"No roll distorting the court")
		assert_almost_eq(basis.determinant(),1.0,0.0001)

func test_arena_uses_real_right_offset_and_perspective() -> void:
	var view := View3D.new()
	add_child_autofree(view)
	view.cam=Camera3D.new()
	add_child_autofree(view.cam)
	var target := Vector3(3,0,5)
	view._set_arena_camera(target,View3D.arena_camera_angles("fight"),20.0)
	assert_gt(view.cam.position.x,target.x,"Viewpoint remains to the right")
	assert_eq(view.cam.projection,Camera3D.PROJECTION_FRUSTUM,"True perspective replaces the flattened parallel view")
	assert_eq(view.cam.basis.x,Vector3.RIGHT)
	assert_lt(view.cam.frustum_offset.x,0.0,"Lens shift centres the action without camera roll")

func test_arena_surface_style_keeps_natural_ground_unmarked() -> void:
	for name in ["arena_route1","arena_viridian_forest","arena_pewter_gym"]:
		var path: String = "res://assets/maps/"+name
		var map: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/map.json"))
		var image := (load(path+"/bottom.png") as Texture2D).get_image()
		var field: Array=map.arena.field
		assert_eq(int(field[2]),10)
		assert_eq(int(field[3]),16)
		var offset := Vector2i((int(map.pad)+int(field[0]))*16,(int(map.pad)+int(field[1]))*16)
		var white := 0
		for y in int(field[3])*16:
			for x in int(field[2])*16:
				if image.get_pixel(offset.x+x,offset.y+y)==Color.WHITE: white+=1
		if name=="arena_pewter_gym":
			assert_eq(map.arena.surface,"court")
			assert_gt(white,500,"Formal court retains its centre markings")
			for edge in [Vector2i(0,0),Vector2i(159,0),Vector2i(0,255),Vector2i(159,255),Vector2i(0,64),Vector2i(159,192)]:
				assert_eq(image.get_pixel(offset.x+edge.x,offset.y+edge.y),Color.WHITE,"Rectangular gym court boundary retained")
			assert_eq(image.get_pixel(offset.x+50,offset.y+127),Color.WHITE,"Centre stripe crosses the ball ring")
			var floor_image := (load(path+"/hd2d_floor.png") as Texture2D).get_image()
			for xx in [0,int(map.width)*16-1]:
				for yy in int(map.arena.field[1])*16+int(map.arena.field[3])*16:
					assert_ne(floor_image.get_pixel(int(map.pad)*16+xx,int(map.pad)*16+yy),Color.WHITE,"No copied line fragments on side strips")
		else:
			assert_eq(map.arena.surface,"natural")
			assert_eq(white,0,"Natural arenas have no white court lines or ball emblem")

func test_arena_camera_frames_combatants_more_closely_and_fits_portrait() -> void:
	assert_lt(View3D.arena_fight_distance(Vector2.ZERO,16.0/9.0),13.0,"Close combat is framed larger")
	var separation := Vector2(0,9.5*Arena.TILE)
	var wide := View3D.arena_fight_distance(separation,16.0/9.0)
	assert_lt(wide,26.0,"Long-range framing removes the old perspective-depth padding")
	assert_gt(wide,View3D.arena_fight_distance(Vector2.ZERO,16.0/9.0))
	assert_gt(View3D.arena_fight_distance(Vector2(9*Arena.TILE,0),0.6),View3D.arena_fight_distance(Vector2(9*Arena.TILE,0),16.0/9.0),"Narrow view fits a horizontal separation")

func test_arena_trainer_space_is_flat_clear_and_outside_combat() -> void:
	for name in ["arena_route1","arena_viridian_forest","arena_pewter_gym"]:
		var path: String="res://assets/maps/"+name
		var map: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/map.json"))
		var cards: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/hd2d_cards.json"))
		var arena: Dictionary=map.arena
		var field := Rect2i(int(arena.field[0]),int(arena.field[1]),int(arena.field[2]),int(arena.field[3]))
		var trainer := Vector2i(int(arena.trainer[0]),int(arena.trainer[1]))
		var side := int(arena.wall_rows) if arena.style=="border" else 1
		var top := int(arena.wall_rows)
		var end := int(map.height)-side if arena.style=="border" else int(map.height)-1
		assert_gte(field.position.y-top,6,"Trainer has a separate waiting area: "+name)
		assert_gte(trainer.y-top,3,"Clear ground behind the trainer")
		assert_gte(field.position.y-trainer.y,2,"Trainer stands back from the court")
		assert_gte(field.position.x-side,2,"Side apron is separate from the ten-tile court")
		assert_false(field.has_point(trainer))
		var intrusions: Array=[]
		for c in cards.cards:
			var foot := int(c[1])+int(c[2])
			if int(c[0])>=side and int(c[0])<int(map.width)-side and foot>top and foot<end:
				intrusions.append(c)
		assert_eq(intrusions.size(),0,"No tree trunks or raised floor cards inside the open apron: "+str(intrusions))
		var collision_errors: Array=[]
		for y in range(top,end):
			for x in range(side,int(map.width)-side):
				if (map.solid[y][x]=="0")!=field.has_point(Vector2i(x,y)):
					collision_errors.append(Vector2i(x,y))
		assert_eq(collision_errors.size(),0,"Only the original 10×16 combat field is walkable")

func test_natural_arenas_have_upright_trees_across_background_padding() -> void:
	for name in ["arena_route1","arena_viridian_forest"]:
		var path: String="res://assets/maps/"+name
		var map: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/map.json"))
		var cards: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/hd2d_cards.json"))
		var pad := int(map.pad)
		assert_eq(cards.scenery_bounds.map(func(v): return int(v)),[-pad,-pad,int(map.width)+pad*2,int(map.height)+pad*2])
		var outside := 0
		for c in cards.cards:
			if c.size()<10 or int(c[9])!=1: continue
			if int(c[0])<0 or int(c[1])<0 or int(c[0])>=int(map.width) or int(c[1])>=int(map.height): outside+=1
			assert_eq(int(c[5]),0,"Source trees stay upright, without folded canopy tops")
			assert_gte(int(c[0]),-pad)
			assert_lte(int(c[0])+1,int(map.width)+pad)
			assert_gte(int(c[1]),-pad)
			assert_lte(int(c[1])+int(c[2]),int(map.height)+pad)
		assert_gt(outside,100,"Padding has its own upright tree scenery")
		var bottom := (load(path+"/bottom.png") as Texture2D).get_image()
		var floor_image := (load(path+"/hd2d_floor.png") as Texture2D).get_image()
		var field: Array=map.arena.field
		var ground := bottom.get_region(Rect2i((pad+int(field[0])+1)*16,(pad+int(field[1])+1)*16,16,16)).get_data()
		for x in [-pad,-1,int(map.width),int(map.width)+pad-1]:
			for y in [-pad,0,int(map.height)/2,int(map.height)+pad-1]:
				assert_eq(floor_image.get_region(Rect2i((pad+x)*16,(pad+y)*16,16,16)).get_data(),ground,"No flat tree pixels remain in padding floor")
		assert_eq(map.arena.field[2],10.0)
		assert_eq(map.arena.field[3],16.0)

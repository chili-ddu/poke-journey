extends GutTest
const Palette = preload("res://scripts/view/item_palette.gd")

func test_world_icons_preserve_alpha_shape_and_bag_resources() -> void:
	var count := 0
	for id in ItemDB.all_items():
		var original := ItemDB.icon(id)
		if original==null: continue
		count+=1
		var source := original.get_image()
		var bytes := source.get_data()
		var polished := Palette.texture(original)
		assert_eq(polished.get_size(),original.get_size())
		assert_same(ItemDB.icon(id),original,"Bag icon resource stays original")
		var result := polished.get_image().get_data()
		var same := bytes.size()==result.size()
		if same:
			for p in range(3,bytes.size(),4):
				if bytes[p]!=result[p]: same=false;break
		assert_true(same,"Icon alpha/layout preserved: "+String(id))
		assert_eq(source.get_data(),bytes)
	assert_gt(count,20)

func test_world_ball_cache_original_switch_and_flight_state() -> void:
	var original: Texture2D=load("res://assets/fx/item_ball.png")
	var polished := Palette.ground_ball()
	assert_ne(polished,original)
	assert_same(polished,Palette.ground_ball())
	assert_eq(polished.get_size(),original.get_size())
	var previous := Palette.enabled
	Palette.enabled=false
	assert_same(Palette.ground_ball(),original)
	Palette.enabled=previous
	var loot := LootItem.new()
	loot.setup("oran_berry",Vector2(20,30))
	assert_true(loot.texture.get_meta("world_item_palette",false))
	assert_eq(loot.position,Vector2(20,30))
	assert_eq(loot.flight,-1.0)
	assert_eq(loot.count,1)
	loot.update_visual(LootItem.FALL_TIME)
	assert_eq(loot.draw_at,loot.position)
	loot.free()

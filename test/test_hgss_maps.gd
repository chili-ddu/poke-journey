extends GutTest

const Collection = preload("res://scripts/johto/hgss_map_collection.gd")
const Preview = preload("res://scripts/johto/hgss_map_preview.gd")
var collection: RefCounted

func before_each() -> void:
	collection = Collection.new()

func test_all_twenty_roads_and_ten_towns_exist() -> void:
	var names: Array = []
	for h in collection.manifest.headers.values(): names.append(h.constant)
	for road in range(29, 49): assert_has(names, "MAP_ROUTE_%d" % road)
	for town in ["NEW_BARK", "CHERRYGROVE", "VIOLET", "AZALEA", "GOLDENROD", "ECRUTEAK", "OLIVINE", "CIANWOOD", "MAHOGANY", "BLACKTHORN"]:
		assert_has(names, "MAP_" + town)
	assert_eq(collection.manifest.headers.size(), 301)

func test_every_location_has_native_geometry_and_a_walkable_spawn() -> void:
	for key in collection.manifest.headers:
		var id := int(key)
		var scene: Dictionary = collection.scene_data(collection.scene_for(id))
		assert_false(scene.chunks.is_empty(), str(id))
		var at: Vector2 = collection.spawn(id)
		assert_true(at.is_finite(), "spawn " + str(id))
		if at.is_finite():
			assert_true(collection.can_stand(scene, Vector2i(at.floor())), "clear spawn " + str(id))
			assert_eq(collection.header_at(scene, Vector2i(at.floor())), id, "spawn stays in selected location " + str(id))

func test_all_in_scope_portals_resolve_to_the_original_anchor() -> void:
	var resolved := 0
	for sid in collection.manifest.scenes:
		var scene: Dictionary = collection.scene_data(sid)
		for warp in scene.warps:
			if String(warp.to).is_empty(): continue
			var arrival: Dictionary = collection.arrival(int(warp.to_header), int(warp.to_index))
			assert_false(arrival.is_empty(), str(warp))
			assert_eq(int(arrival.header), int(warp.to_header))
			assert_eq(int(arrival.index), int(warp.to_index))
			assert_true(collection.can_stand(scene, Vector2i(int(warp.x), int(warp.z))))
			resolved += 1
	assert_eq(resolved, 786)

func terrain_fixture() -> Dictionary:
	var values: Array = []
	values.resize(1024)
	values.fill(32768)
	for x in [1, 2, 4, 5]: values[32 + x] = 0
	values[32 + 6] = 21
	values[32 + 7] = 32768 + 21
	return {"chunk_index": {Vector2i.ZERO: {"attributes": values}}, "portal_index": {}}

func test_original_permission_bit_and_water_are_respected() -> void:
	var data := terrain_fixture()
	assert_true(collection.can_stand(data, Vector2i(1, 1)))
	assert_false(collection.can_stand(data, Vector2i(3, 1)))
	assert_false(collection.can_stand(data, Vector2i(6, 1)))
	assert_true(collection.can_stand(data, Vector2i(6, 1), true))
	assert_false(collection.can_stand(data, Vector2i(7, 1), true))
	assert_false(collection.can_stand(data, Vector2i(-1, 0), true))
	assert_false(collection.can_stand(data, Vector2i(32, 0), true))

func test_hgss_variable_preamble_does_not_shift_real_door_permissions() -> void:
	var mainland: Dictionary = collection.scene_data(collection.scene_for(60))
	assert_eq(collection.attributes(mainland, Vector2i(684, 393)), 0x8069, "original lab door behavior")
	assert_eq(collection.attributes(mainland, Vector2i(684, 394)), 0x0400, "clear tile immediately outside lab")
	assert_eq(collection.attributes(mainland, Vector2i(684, 395)), 0x0000, "clear path outside lab")
	assert_true(collection.can_stand(mainland, Vector2i(684, 393)), "door policy opens registered portal")
	assert_true(collection.can_stand(mainland, Vector2i(684, 394)))

func test_large_movement_cannot_tunnel_through_a_wall() -> void:
	var preview := Preview.new()
	preview.data = terrain_fixture()
	preview.position_2d = Vector2(1.5, 1.5)
	preview.move_by(Vector2(5.0, 0))
	assert_between(preview.position_2d.x, 2.0, 2.83)
	assert_eq(preview.position_2d.y, 1.5)
	preview.free()

func test_unknown_or_dynamic_portal_never_invents_a_destination() -> void:
	assert_eq(collection.scene_for(4095), "")
	assert_true(collection.arrival(4095, 0).is_empty())
	assert_true(collection.arrival(60, 999).is_empty())

func test_shared_entrances_use_the_first_in_scope_original_variant() -> void:
	var ship: Dictionary = collection.scene_data(collection.scene_for(307))
	var exit: Dictionary = collection.portal(ship, Vector2i(24, 19))
	assert_eq(int(exit.index), 0, "Olivine exit takes priority over out-of-scope Vermilion exit")
	assert_false(String(exit.to).is_empty())
	var mainland: Dictionary = collection.scene_data(collection.scene_for(60))
	var ruins: Dictionary = collection.portal(mainland, Vector2i(430, 284))
	assert_eq(int(ruins.index), 8, "normal ruins entrance takes priority over Sinjoh story variant")

func test_pallet_sample_uses_a_separate_collection_without_replacing_johto() -> void:
	var pallet := Collection.new("res://assets/maps/hgss_pallet_sample/")
	assert_eq(pallet.manifest.headers.size(), 6)
	assert_eq(collection.manifest.headers.size(), 301)
	assert_eq(collection.scene_for(49), "")
	assert_false(pallet.scene_for(49).is_empty())
	assert_eq(pallet.scene_for(60), "")
	for key in pallet.manifest.headers:
		var id := int(key)
		var at: Vector2 = pallet.spawn(id)
		assert_true(at.is_finite())
		assert_eq(pallet.header_at(pallet.scene_data(pallet.scene_for(id)), Vector2i(at.floor())), id)

func test_pallet_lab_original_door_has_a_resolved_return_to_town() -> void:
	var pallet := Collection.new("res://assets/maps/hgss_pallet_sample/")
	var town: Dictionary = pallet.scene_data(pallet.scene_for(49))
	var door: Dictionary = pallet.portal(town, Vector2i(1045, 373))
	assert_eq(int(door.to_header), 505)
	assert_false(pallet.arrival(505, int(door.to_index)).is_empty())
	assert_true(pallet.can_stand(town, Vector2i(1045, 374)))
	var lab: Dictionary = pallet.scene_data(pallet.scene_for(505))
	var back: Dictionary = lab.warps[0]
	assert_eq(int(back.to_header), 49)
	assert_false(pallet.arrival(49, int(back.to_index)).is_empty())

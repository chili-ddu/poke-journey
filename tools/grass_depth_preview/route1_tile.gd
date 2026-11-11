extends View3D

# Review the Route 1 metatile at its original width. Foreshortening the card
# keeps its screen footprint the same as the map square beneath it.
var visible_fraction := 1.0

var restored_atlas := false
var step_texture: Texture2D

func _draw_cards(map_dir: String, scenery: Dictionary, cards: Array, fragments: Array, parent: Node3D, boxes: Dictionary = {}) -> void:
	# This preview uses the Route 1 metatile from the FireRed map source.
	# Only the two lawn colors connected to the tile border were cut out.
	if not restored_atlas and _card_atlas != null:
		var packed := load(map_dir.path_join("card_atlas.res"))
		var offsets: Dictionary = packed.get_meta("offsets")
		var at: Vector2i = offsets[Vector2i(880,288)]
		var image := _card_atlas.get_image()
		var leaf := Image.load_from_file("res://tools/grass_depth_preview/route1_grass_cutout.png")
		if MapPalette.enabled: leaf = MapPalette.surface(leaf)
		image.blit_rect(leaf, Rect2i(0,0,16,16), at)
		_card_atlas = ImageTexture.create_from_image(image)
		restored_atlas = true
	super._draw_cards(map_dir, scenery, cards, fragments, parent, boxes)

func _build_layered_flora(st: SurfaceTool, x: float, z: float, u0: float, u1: float, v0: float, v1: float, local_tile := Vector2i(-1,-1)) -> void:
	var is_static := _ground_static_geometry
	var tile := Vector2i(int(x), int(z)-1) if is_static else local_tile
	if not Arena.is_grass(tile):
		super._build_layered_flora(st, x, z, u0, u1, v0, v1, local_tile)
		return
	var angle := deg_to_rad(FLORA_TILT_DEG)
	var elevation := deg_to_rad(elev_deg)
	var length := sin(elevation) / sin(elevation + angle)
	var up := Vector3(0, sin(angle), -cos(angle)) * length * visible_fraction
	_flora_quad(st, flora_ground_frame(tile), Vector3(-0.5, 0.015, 0.5), Vector3.RIGHT, up,
		u0, u1, v0, v1, true, not is_static)

func _sync_fx_grass(f: Fx, seen: Dictionary) -> void:
	if f.kind != "tallgrass" or kanto_terrain == null:
		super._sync_fx_grass(f, seen)
		return
	if not kanto_terrain.shows_grass_at(f.tile): return
	if step_texture == null:
		var image := (load(Fx.GRASS_FX) as Texture2D).get_image()
		for y in image.get_height():
			for x in image.get_width():
				var color := image.get_pixel(x,y)
				if Vector3i(color.r8,color.g8,color.b8) in [Vector3i(115,205,164), Vector3i(65,180,139)]:
					image.set_pixel(x,y,Color.TRANSPARENT)
		step_texture = MapPalette.texture(ImageTexture.create_from_image(image))
	# FireRed field-effect keys, held for ten 60 Hz ticks each. Use the
	# existing short-character crop on the entry key, keeping its root fixed.
	var sequence := [1, 2, 3, 4, 0]
	var key: int = 0 if f.settled else sequence[mini(int(f.age / Fx.GRASS_FRAME_T), 4)]
	var top := Fx.FRAME1_TOP if key == 1 else 0
	visible_fraction = (16.0 - top) / 16.0
	var visual := {"tex": step_texture, "src": Rect2(0, key*16+top, 16, 16-top)}
	_sync_layered_grass(_entry(f, seen), f.tile, visual)
	visible_fraction = 1.0

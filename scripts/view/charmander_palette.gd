extends RefCounted

# Display-only palette: keep the source pixels, offsets and flame marker intact.
# The same transform is used after optical-flow interpolation, so subframes
# cannot flash back to the source colors. Shiny sheets keep their own palette.
const COLORS := {
	0xff875f: 0xf8a060, # peach highlight -> warm orange
	0xd73f00: 0xd96835, # saturated red midtone -> copper
	0x9f0000: 0x934338, # red shadow -> muted warm shadow
	0xdfb700: 0xe4be73, # belly
	0xa76f00: 0xad814a,
	0x4f5f97: 0x3c526a, # eye shadows
	0xbfcff7: 0xc3dce4,
	0x6787af: 0x6a94a3,
}
static var _frames := {}
static var _images := {}

static func process(source: Image) -> Image:
	var image: Image = source.duplicate()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var result: Image = image.duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a == 0.0: continue
			var rgb := (c.r8 << 16) | (c.g8 << 8) | c.b8
			if COLORS.has(rgb):
				var mapped := Color.hex((int(COLORS[rgb]) << 8) | c.a8)
				result.set_pixel(x, y, mapped)
			elif rgb == 0:
				# Keep eyes/mouth dark; soften only the exposed silhouette.
				var edge := false
				var upper_edge := false
				for delta in [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]:
					var p: Vector2i = Vector2i(x, y) + delta
					if p.x < 0 or p.y < 0 or p.x >= image.get_width() or p.y >= image.get_height() or image.get_pixelv(p).a == 0.0:
						edge = true
						if delta == Vector2i.UP: upper_edge = true
				var ink := Color("704139") if upper_edge else Color("432c32") if edge else Color("231e29")
				ink.a = c.a
				result.set_pixel(x, y, ink)
	return result

static func frame(visual: Dictionary) -> Dictionary:
	var tex: Texture2D = visual.tex
	var region: Rect2 = visual.src
	var key := "%d:%s" % [tex.get_instance_id(), str(region)]
	if not _frames.has(key):
		var id := tex.get_instance_id()
		if not _images.has(id):
			if _images.size() >= 8: _images.erase(_images.keys()[0])
			var image := tex.get_image()
			if image.is_compressed(): image.decompress()
			_images[id] = image
		var image: Image = _images[id]
		var polished := ImageTexture.create_from_image(process(image.get_region(Rect2i(region))))
		polished.set_meta("authored_palette", true)
		_frames[key] = polished
	var result := visual.duplicate()
	result.tex = _frames[key]
	result.src = Rect2(Vector2.ZERO, region.size)
	return result

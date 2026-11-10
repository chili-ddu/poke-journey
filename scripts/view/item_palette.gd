extends RefCounted

# World-only treatment: bag/shop icons keep their original ItemDB resources.
static var enabled := OS.get_environment("ITEM_ART") != "original"
static var _cache := {}
const LIMIT := 96
const BALL_COLORS := {
	0x000000:0x3b3038, 0xe66a4a:0xd17659, 0x943929:0x884f42,
	0x521000:0x58382f, 0x4a4a5a:0x4d4b59, 0xc5c5d5:0xbec2cd,
	0xffffff:0xf1ebdd,
}

static func surface(source: Image, ball: bool = false) -> Image:
	var result := source.duplicate() as Image
	if result.is_compressed(): result.decompress()
	result.convert(Image.FORMAT_RGBA8)
	for y in result.get_height():
		for x in result.get_width():
			var c := result.get_pixel(x,y)
			if c.a==0.0: continue
			var rgb := (c.r8<<16)|(c.g8<<8)|c.b8
			if ball and BALL_COLORS.has(rgb):
				result.set_pixel(x,y,Color.hex((int(BALL_COLORS[rgb])<<8)|c.a8))
			elif rgb==0x313131 or rgb==0:
				result.set_pixel(x,y,Color8(49,47,56,c.a8))
			else:
				# Keep the authored shade steps; only tame intense candy colors and
				# near-white highlights, without adding bloom or expanding the shape.
				var luma := c.r*0.299+c.g*0.587+c.b*0.114
				var tone := Vector3(c.r,c.g,c.b).lerp(Vector3.ONE*luma,0.10)
				if minf(c.r,minf(c.g,c.b))>0.93: tone*=Vector3(0.96,0.95,0.91)
				result.set_pixel(x,y,Color(tone.x,tone.y,tone.z,c.a))
	return result

static func texture(source: Texture2D, ball: bool = false) -> Texture2D:
	if source==null or not enabled: return source
	var key := "%d:%s"%[source.get_instance_id(),ball]
	if not _cache.has(key):
		if _cache.size()>=LIMIT: _cache.erase(_cache.keys()[0])
		var polished := ImageTexture.create_from_image(surface(source.get_image(),ball))
		polished.set_meta("world_item_palette",true)
		_cache[key]={"source":source,"texture":polished}
	return _cache[key].texture

static func ground_ball() -> Texture2D:
	return texture(load("res://assets/fx/item_ball.png"),true)

extends RefCounted

# Environment-only color pass. Preserve source pixels, alpha, UVs and silhouettes;
# native 3D normals and shadows still supply the directional lighting.
static var enabled := OS.get_environment("MAP_ART") != "original"
const CACHE_LIMIT := 24
static var _cache := {}

static func surface(source: Image) -> Image:
	var result := source.duplicate() as Image
	if result.is_compressed(): result.decompress()
	# The post pass adds saturation again: leave room for warm sunlight without
	# turning grass lime-green or paths lemon-yellow.
	result.adjust_bcs(0.98, 1.04, 0.80)
	return result

static func texture(source: Texture2D) -> Texture2D:
	if not enabled or source == null: return source
	if source.get_meta("map_palette",false): return source
	var key := source.get_instance_id()
	if _cache.has(key): return _cache[key].texture
	var result := ImageTexture.create_from_image(surface(source.get_image()))
	result.set_meta("map_palette",true)
	if _cache.size() >= CACHE_LIMIT: _cache.erase(_cache.keys()[0])
	# Retain the source too, so a recycled ObjectID cannot select another image.
	_cache[key] = {"source":source,"texture":result}
	return result

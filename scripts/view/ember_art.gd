extends RefCounted

# One colored, animated flame for mouth, flight, contact and floor remnants.
# Cropped from pixelfx fire/spirit-flame; provenance/options live beside it.
const PATH := "res://assets/fx/pixelfx/flame.png"
const FRAME := Vector2i(24,40)
const COUNT := 90
const FPS := 30.0
static var _image: Image
static var _frames := {}

static func texture(time: float, phase: float = 0.0) -> Texture2D:
	var index := posmod(int(floor(time*FPS+phase*float(COUNT)/TAU)),COUNT)
	if not _frames.has(index):
		if _image == null:
			var atlas: Texture2D = load(PATH)
			_image = atlas.get_image()
			if _image.is_compressed(): _image.decompress()
		_frames[index] = ImageTexture.create_from_image(_image.get_region(Rect2i(0,index*FRAME.y,FRAME.x,FRAME.y)))
	return _frames[index]

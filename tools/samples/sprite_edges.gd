extends RefCounted

# Scale2x uses only existing neighboring colors. The GPU gets twice the
# pixels, while the texture's logical size stays in original sprite units.
static var enabled := true
static var _frames := {}
static var _images := {}

static func process(source: Image) -> Image:
	var image: Image = source.duplicate()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	var pixels := image.get_data().to_int32_array()
	var out := PackedInt32Array()
	out.resize(w*h*4)
	for y in h:
		for x in w:
			var e := pixels[y*w+x]
			var b := pixels[maxi(y-1,0)*w+x]
			var d := pixels[y*w+maxi(x-1,0)]
			var f := pixels[y*w+mini(x+1,w-1)]
			var hh := pixels[mini(y+1,h-1)*w+x]
			var i := y*4*w+x*2
			var edge := b!=hh and d!=f
			out[i]=d if edge and d==b else e
			out[i+1]=f if edge and b==f else e
			out[i+w*2]=d if edge and d==hh else e
			out[i+w*2+1]=f if edge and hh==f else e
	return Image.create_from_data(w*2,h*2,false,Image.FORMAT_RGBA8,out.to_byte_array())

static func frame(visual: Dictionary) -> Dictionary:
	if not enabled or OS.get_environment("SPRITE_EDGES")=="original": return visual
	var tex: Texture2D=visual.tex
	var rect := Rect2i(visual.src)
	var key := "%d:%s"%[tex.get_instance_id(),str(rect)]
	if not _frames.has(key):
		if _frames.size()>=2048: _frames.erase(_frames.keys()[0])
		var id := tex.get_instance_id()
		if not _images.has(id):
			if _images.size()>=8: _images.erase(_images.keys()[0])
			var image := tex.get_image()
			if image.is_compressed(): image.decompress()
			_images[id]={"source":tex,"image":image}
		var source: Image=_images[id].image
		var expanded := ImageTexture.create_from_image(process(source.get_region(rect)))
		expanded.set_size_override(rect.size)
		_frames[key]={"source":tex,"tex":expanded}
	var result := visual.duplicate()
	result.tex=_frames[key].tex
	result.src=Rect2(Vector2.ZERO,rect.size)
	return result

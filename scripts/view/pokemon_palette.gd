extends RefCounted

# Shared PMD color ramps: recolor existing pixels, never redraw a silhouette.
# Charmander retains its separately approved palette. Shiny art opts out.
static var enabled := OS.get_environment("MON_ART") != "original"
const COLORS := {
	0xd7efa7:0xcbdcaa, 0x9fcf6f:0x9cbd7c, 0x5fb727:0x6b9d49, 0x278700:0x43733d,
	0x7fcfff:0x95cadd, 0x1f9fe7:0x539fbe, 0x0067b7:0x3c6c93,
	0xffc7d7:0xf0c8d3, 0xff8faf:0xdf9db4, 0xe73f67:0xbd6483,
	0xb797df:0xb5a0cc, 0x8f67bf:0x937cad, 0x572f9f:0x655089,
	0xb7cfff:0xb9cce7, 0x879fff:0x8e9ed3, 0x5767b7:0x606f9c,
	0xd797df:0xcaa0ce, 0xaf6fb7:0xa47da9, 0x873f87:0x7f557f,
	0xff9747:0xe8a060, 0xdf771f:0xca8445, 0xa75f1f:0x9c6c42, 0x773f00:0x694b35,
	0xffc75f:0xeac575, 0xbf8737:0xb18b50, 0xdfaf67:0xcfb17c, 0xbf7727:0xac7d4c,
	0xfff79f:0xeee1ab, 0xd7bf67:0xc6b57b, 0xb78727:0xa38a4d,
	0xdfb700:0xd4b45a, 0xa76f00:0x9c793f,
	0xd7dfdf:0xd4dce0, 0x979fa7:0x9aa5af, 0x47676f:0x536773,
	0xd73f00:0xc75c38, 0x9f0000:0x8f3938, 0xff875f:0xe99a79,
}
const FRAME_LIMIT := 2048
static var _frames := {}
static var _images := {}

static func process(source: Image, dex: int) -> Image:
	var src := source.duplicate() as Image
	if src.is_compressed(): src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var out := src.duplicate() as Image
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x,y)
			if c.a==0.0: continue
			var rgb := (c.r8<<16)|(c.g8<<8)|c.b8
			if rgb==0:
				var edge := false
				var lit := false
				var sum := Vector3.ZERO
				var count := 0
				for dy in range(-1,2):
					for dx in range(-1,2):
						if dx==0 and dy==0: continue
						var p := Vector2i(x+dx,y+dy)
						if p.x<0 or p.y<0 or p.x>=src.get_width() or p.y>=src.get_height() or src.get_pixelv(p).a==0.0:
							if abs(dx)+abs(dy)==1:
								edge=true
								if dx<0 or dy<0: lit=true
							continue
						var near := src.get_pixelv(p)
						if maxf(near.r,maxf(near.g,near.b))>0.15:
							sum+=Vector3(near.r,near.g,near.b)
							count+=1
				# Keep internal facial ink exactly black. Exposed outlines inherit
				# the adjacent fur/leaf/shell hue, with a darker lower/right edge.
				if edge and count>0:
					var ink := sum/float(count)*(0.56 if lit else 0.34)
					out.set_pixel(x,y,Color(ink.x,ink.y,ink.z,c.a))
			elif rgb==0xfff700:
				# Look uses this exact marker to locate the fire-tail light.
				if dex not in [5,6]: out.set_pixel(x,y,Color8(239,216,83,c.a8))
			elif COLORS.has(rgb):
				out.set_pixel(x,y,Color.hex((int(COLORS[rgb])<<8)|c.a8))
	return out

static func frame(visual: Dictionary, dex: int) -> Dictionary:
	if not enabled: return visual
	var tex: Texture2D=visual.tex
	var region: Rect2=visual.src
	var id := tex.get_instance_id()
	var key := "%d:%d:%s"%[dex,id,str(region)]
	if not _frames.has(key):
		if not _images.has(id):
			if _images.size()>=8: _images.erase(_images.keys()[0])
			var image := tex.get_image()
			if image.is_compressed(): image.decompress()
			_images[id]=image
		var cell: Image=_images[id].get_region(Rect2i(region))
		var polished := ImageTexture.create_from_image(process(cell,dex))
		polished.set_meta("authored_palette",true)
		if _frames.size()>=FRAME_LIMIT: _frames.erase(_frames.keys()[0])
		_frames[key]=polished
	var result := visual.duplicate()
	result.tex=_frames[key]
	result.src=Rect2(Vector2.ZERO,region.size)
	return result

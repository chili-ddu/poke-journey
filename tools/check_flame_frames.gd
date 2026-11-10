extends SceneTree
# 걷기·공격 시트의 모든 방향/프레임에서 검출된 꼬리불 위치를 검사한다.
func _init() -> void:
	var total := 0
	var missing := 0
	var off := 0
	for dex in [4, 5, 6]:
		var data := MonSprite.load_set(dex)
		for anim in ["Walk", "Attack", "Strike"]:
			if not data.has(anim): continue
			var a: Dictionary = data[anim]
			var tex: Texture2D = a["tex"]
			var img := tex.get_image()
			for row in int(a["rows"]):
				for frame in a["durations"].size():
					total += 1
					var src := Rect2(frame * int(a["fw"]), row * int(a["fh"]), a["fw"], a["fh"])
					var p := Look.flame_point(tex, src)
					if p.x < 0:
						missing += 1
						continue
					var nearest := INF
					for y in int(src.size.y):
						for x in int(src.size.x):
							var c := img.get_pixel(int(src.position.x) + x, int(src.position.y) + y)
							if c.a > 0.5 and absf(c.r - Look.FLAME_COLOR.r) < 0.02 and absf(c.g - Look.FLAME_COLOR.g) < 0.02 and c.b < 0.1:
								nearest = minf(nearest, p.distance_to(Vector2(x + 0.5, y + 0.5)))
					if nearest > 2.0:
						off += 1
						print("OFF ", dex, " ", anim, " row=", row, " frame=", frame, " distance=", nearest)
	print("flame audit frames=", total, " missing=", missing, " off=", off)
	quit(1 if off > 0 else 0)

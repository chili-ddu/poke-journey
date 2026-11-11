extends "res://tools/grass_depth_preview/route1_tile.gd"

# Fold the single FireRed metatile around its root. Every source texel has
# one place on this continuous surface, including across the centre crease.
func _build_layered_flora(st: SurfaceTool, x: float, z: float, u0: float, u1: float, v0: float, v1: float, local_tile := Vector2i(-1,-1)) -> void:
	var terrain := _ground_static_geometry
	var tile := Vector2i(int(x), int(z)-1) if terrain else local_tile
	if not Arena.is_grass(tile):
		super._build_layered_flora(st, x, z, u0, u1, v0, v1, local_tile)
		return
	var ground := flora_ground_frame(tile)
	var crop_top := 1.0 - visible_fraction
	# The raised step effect draws only foreground leaves in front of the
	# Pokemon. Rear tips stay on the terrain mesh at their true depth.
	var first_row := crop_top if terrain else maxf(7.0/16.0, crop_top)
	var rows := [first_row]
	for row in [0.5, 0.8125, 1.0]:
		if row > first_row: rows.append(row)
	for i in range(rows.size()-1):
		for col in 4:
			var corners := [Vector2(col*0.25,rows[i]),Vector2((col+1)*0.25,rows[i]),
				Vector2((col+1)*0.25,rows[i+1]),Vector2(col*0.25,rows[i+1])]
			var points := PackedVector3Array()
			for uv: Vector2 in corners:
				points.append(_leaf_point(ground, uv, terrain))
			for triangle in [[0,1,2],[0,2,3]]:
				var normal := (points[triangle[2]]-points[triangle[0]]).cross(points[triangle[1]]-points[triangle[0]]).normalized()
				for index in triangle:
					var uv: Vector2 = corners[index]
					st.set_normal(normal)
					st.set_uv(Vector2(lerpf(u0,u1,uv.x),lerpf(v0,v1,(uv.y-crop_top)/visible_fraction)))
					st.add_vertex(points[index])

func _leaf_point(ground: Transform3D, uv: Vector2, terrain: bool) -> Vector3:
	var side := absf(2.0 * uv.x - 1.0)
	var rise := 1.0 - uv.y
	# Lower rows lie close to the turf. Above them, the middle blades stand
	# higher while the outer ones recede, shaping both the light and silhouette.
	var height := 0.015 + rise * rise * lerpf(0.66,0.41,side)
	var back := rise * lerpf(0.39,0.63,side)
	var at := ground * Vector3(uv.x - 0.5, 0, 0.5 - back)
	at.y = Arena.ground_height(Vector2(at.x,at.z) * Arena.TILE) + height
	return at if terrain else ground.affine_inverse() * at

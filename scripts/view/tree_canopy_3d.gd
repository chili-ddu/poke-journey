extends RefCounted

# One continuous source image per tree, bent into a crown with a fixed trunk.
const CROWN_WIDTH := 1.12
const FRONT_DEPTH := 0.24
const REAR_DEPTH := 0.28
const PRESERVE_OUTLINE := 0.8
const ROWS := [0.0,0.1,0.22,0.45,0.7,0.88,1.0]
const COLUMN_STEPS := 2

static func groups(cards: Array) -> Array:
	# The generator emits each whole tree's source columns consecutively. A
	# repeated first UV starts the next tree, including a contiguous forest row.
	# Optional tree-card slot 10 resizes that whole tree around its common root.
	var columns := cards.filter(func(c):return c.size()>9 and int(c[9])==1)
	var result := []
	var cursor := 0
	while cursor<columns.size():
		var first: Array=columns[cursor]
		var parts: Array=[first]
		cursor+=1
		while cursor<columns.size():
			var next: Array=columns[cursor]
			if int(next[0])!=int(first[0])+parts.size() or next[1]!=first[1] or next[2]!=first[2]:break
			if next[3]==first[3] and next[4]==first[4]:break
			parts.append(next)
			cursor+=1
		result.append({"x":float(first[0]),"z":float(first[1])+float(first[2])-float(first[8]),"width":parts.size(),"height":float(first[2]),"columns":parts,"scale":float(first[10]) if first.size()>10 else 1.0})
	return result

static func root_of(tree: Dictionary, elevated: bool) -> Vector3:
	var at := Vector2(float(tree.x)+float(tree.width)*0.5,float(tree.z))
	return Vector3(at.x,Arena.ground_height(at*Arena.TILE) if elevated else 0.0,at.y)

static func point(root: Vector3, width: float, height: float, across: float, above_root: float, stand: float, view_slope: float) -> Vector3:
	var h := clampf(above_root,0.0,height)
	var crown := smoothstep(0.3,0.9,h)
	var depth_weight := crown*(1.0-smoothstep(height-0.6,height,h))
	var horizontal := (across-width*0.5)/(width*0.5)
	var spread := lerpf(1.0,CROWN_WIDTH,crown)
	var depth := (FRONT_DEPTH*(1.0-horizontal*horizontal)-REAR_DEPTH*horizontal*horizontal)*width*0.5*depth_weight
	# Most of the depth follows the viewing ray so a round native crown does
	# not flatten into a cylinder. A small projected overlap remains visible.
	return root+Vector3((across-width*0.5)*spread,h*stand+depth*view_slope*PRESERVE_OUTLINE,depth)

static func _normal(root: Vector3, width: float, height: float, across: float, h: float, stand: float, view_slope: float) -> Vector3:
	var across_axis := point(root,width,height,across+0.01,h,stand,view_slope)-point(root,width,height,across-0.01,h,stand,view_slope)
	var up_axis := point(root,width,height,across,h+0.01,stand,view_slope)-point(root,width,height,across,h-0.01,stand,view_slope)
	return across_axis.cross(up_axis).normalized()

static func build(cards: Array, atlas: Texture2D, stand: float, elevated: bool, view_slope: float, native: Texture2D = null) -> MeshInstance3D:
	var trees := groups(cards)
	if trees.is_empty():return null
	var size := atlas.get_size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var source_columns := 0
	var scaled_trees := 0
	var max_tree_scale := 1.0
	for tree in trees:
		# One ground query for the entire tree. Every source column shares it.
		var root := root_of(tree,elevated)
		var width := float(tree.width)
		var height := float(tree.height)
		var tree_scale := float(tree.scale)
		if not is_equal_approx(tree_scale,1.0):scaled_trees+=1
		max_tree_scale=maxf(max_tree_scale,tree_scale)
		var vertices := {}
		var normals := {}
		for row in ROWS.size():
			var h: float=height*float(ROWS[row])
			for x in int(tree.width)*COLUMN_STEPS+1:
				var across := float(x)/COLUMN_STEPS
				var key := Vector2i(x,row)
				vertices[key]=point(root,width,height,across,h,stand,view_slope)
				# Resize whole native trees around their shared root. Uniform scale
				# preserves source proportions, normals and all source-column joins.
				if tree_scale!=1.0:vertices[key]=root+((vertices[key] as Vector3)-root)*tree_scale
				normals[key]=_normal(root,width,height,across,h,stand,view_slope)
		for column in int(tree.width):
			var source: Array=tree.columns[column]
			source_columns+=1
			for row in ROWS.size()-1:
				for part in COLUMN_STEPS:
					var x := column*COLUMN_STEPS+part
					var keys := [Vector2i(x,row+1),Vector2i(x+1,row+1),Vector2i(x+1,row),Vector2i(x,row)]
					var u0 := (float(source[3])+float(part)*16.0/COLUMN_STEPS)/size.x
					var u1 := (float(source[3])+float(part+1)*16.0/COLUMN_STEPS)/size.x
					var v0 := (float(source[4])+(1.0-float(ROWS[row+1]))*height*16.0)/size.y
					var v1 := (float(source[4])+(1.0-float(ROWS[row]))*height*16.0)/size.y
					if native != null:
						u0=(float(column)+float(part)/COLUMN_STEPS)/width
						u1=(float(column)+float(part+1)/COLUMN_STEPS)/width
						v0=1.0-float(ROWS[row+1])
						v1=1.0-float(ROWS[row])
					var uv := [Vector2(u0,v0),Vector2(u1,v0),Vector2(u1,v1),Vector2(u0,v1)]
					for index in [0,1,2,0,2,3]:
						st.set_normal(normals[keys[index]])
						st.set_uv(uv[index])
						st.add_vertex(vertices[keys[index]])
	var node := MeshInstance3D.new()
	node.name="TreeCanopies"
	st.index()
	node.mesh=st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_texture=native if native != null else atlas
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold=0.5
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.roughness=1.0
	material.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
	material.metallic_specular=0.0
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.set_meta("trees",trees.size())
	node.set_meta("native_hgss",native != null)
	node.set_meta("source_columns",source_columns)
	node.set_meta("scaled_trees",scaled_trees)
	node.set_meta("max_tree_scale",max_tree_scale)
	node.set_meta("crown_width",CROWN_WIDTH)
	node.set_meta("front_depth",FRONT_DEPTH)
	node.set_meta("rear_depth",REAR_DEPTH)
	return node

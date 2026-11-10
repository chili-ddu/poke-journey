extends RefCounted

# Native bark pixels on small solid branches. Decorative geometry stays above
# the impassable lip or underneath the lining, outside the playable interior.
static func build(data: Dictionary, atlas: Texture2D) -> MeshInstance3D:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for beam: Dictionary in data.beams:
		var a:=Vector3(float(beam.a[0]),float(beam.a[1]),float(beam.a[2]))
		var b:=Vector3(float(beam.b[0]),float(beam.b[1]),float(beam.b[2]))
		var along:=(b-a).normalized()
		var side:=along.cross(Vector3.UP).normalized()*float(beam.width)
		var up:=side.normalized().cross(along).normalized()*float(beam.height)
		var section: Array=[Vector2(-.35,-.5),Vector2(.35,-.5),Vector2(.5,-.25),Vector2(.5,.25),Vector2(.35,.5),Vector2(-.35,.5),Vector2(-.5,.25),Vector2(-.5,-.25)]
		var points: Array=[]
		for end in 2:
			for offset: Vector2 in section:
				points.append((a if end==0 else b)+(side*offset.x+up*offset.y)*(1.0 if end==0 else float(beam.get("taper",.7))))
		var faces: Array=[]
		for i in 8:faces.append([i,i+8,(i+1)%8+8,(i+1)%8])
		for face: Array in faces:
			var rect: Array=data.bark_uv
			var uv_rect:=Rect2(float(rect[0])/atlas.get_width(),float(rect[1])/atlas.get_height(),float(rect[2])/atlas.get_width(),float(rect[3])/atlas.get_height())
			var uv: Array=[uv_rect.position,Vector2(uv_rect.end.x,uv_rect.position.y),uv_rect.end,Vector2(uv_rect.position.x,uv_rect.end.y)]
			var normal: Vector3=((points[face[1]] as Vector3)-(points[face[0]] as Vector3)).cross((points[face[2]] as Vector3)-(points[face[0]] as Vector3)).normalized()
			for i in [0,1,2,0,2,3]:
				surface.set_normal(normal);surface.set_uv(uv[i]);surface.add_vertex(points[face[i]])
		for end in 2:
			for i in range(1,7):
				for index in ([0,i,i+1] if end==0 else [0,i+1,i]):
					surface.set_normal(-along if end==0 else along)
					var offset: Vector2=section[index]+Vector2(.5,.5)
					surface.set_uv(Vector2(float(data.end_uv[0])+offset.x*float(data.end_uv[2]),float(data.end_uv[1])+offset.y*float(data.end_uv[3]))/Vector2(atlas.get_size()))
					surface.add_vertex(points[end*8+index])
	var mesh:=MeshInstance3D.new()
	mesh.name="NestBranches"
	mesh.mesh=surface.commit()
	var material:=StandardMaterial3D.new()
	material.albedo_texture=atlas
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.roughness=1.0
	material.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
	mesh.material_override=material
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh.set_meta("branches",data.beams.size())
	return mesh

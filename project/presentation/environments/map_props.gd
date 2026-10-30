extends RefCounted
const Art=preload("res://presentation/generated_assets.gd")
static var cache:Dictionary={}
static func mesh(asset_id:String) -> ArrayMesh:
	if cache.has(asset_id):return cache[asset_id]
	var root=Art.instance(asset_id)
	if root==null:return null
	var groups:Dictionary={}
	collect(root,Transform3D.IDENTITY,groups)
	var output:=ArrayMesh.new()
	for group in groups.values():
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in group.parts:surface.append_from(part.mesh,part.surface,part.transform)
		var material:Material=group.material
		if material is StandardMaterial3D:
			material=material.duplicate()
			material.metallic=0.0
			material.roughness=.92
			if asset_id in ["map_ridge_rock","map_cliff"]:
				var c:Color=material.albedo_color
				material.albedo_color=Color("536f4b") if c.g>c.r+.05 else Color("888374")
		surface.set_material(material)
		surface.commit(output)
	root.free()
	cache[asset_id]=output
	return output
static func collect(node:Node3D,parent_transform:Transform3D,groups:Dictionary)->void:
	var transform_value:=parent_transform*node.transform
	if node is MeshInstance3D and node.mesh!=null:
		for index in node.mesh.get_surface_count():
			var material:Material=node.get_active_material(index)
			if material is StandardMaterial3D:
				var source_name:String=material.resource_name.to_lower()
				if "leaf" in source_name:
					material=material.duplicate()
					material.albedo_color=Color("346b4d")
					material.metallic=0.0
				elif "bark" in source_name:
					material=material.duplicate()
					material.albedo_color=Color("795d43")
					material.metallic=0.0
				elif "rock" in source_name or "stone" in source_name:
					material=material.duplicate()
					material.albedo_color=Color("8e9986")
					material.metallic=0.0
			var key:int=material.get_instance_id() if material!=null else 0
			if not groups.has(key):groups[key]={"material":material,"parts":[]}
			groups[key].parts.append({"mesh":node.mesh,"surface":index,"transform":transform_value})
	for child in node.get_children():
		if child is Node3D:collect(child,transform_value,groups)
static func batch(parent:Node3D,asset_id:String,transforms:Array)->void:
	var model:=mesh(asset_id)
	if model==null or transforms.is_empty():return
	var instance:=MultiMeshInstance3D.new()
	instance.name=asset_id
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.mesh=model
	multi.instance_count=transforms.size()
	for i in transforms.size():multi.set_instance_transform(i,transforms[i])
	instance.multimesh=multi
	instance.visibility_range_end=1100
	parent.add_child(instance)

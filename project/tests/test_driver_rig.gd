extends RefCounted
const Art = preload("res://presentation/generated_assets.gd")

func run_test() -> Dictionary:
	var errors:Array[String]=[]
	for i in 3:
		var driver:=Art.instance("driver_%d" % i)
		var skeleton:=driver.find_child("Skeleton3D",true,false) as Skeleton3D
		if skeleton==null:
			errors.append("No Skeleton3D in driver %d" % i);driver.free();continue
		for side in ["Left","Right"]:
			for part in ["UpperArm","ForeArm","Hand","Grip"]:
				if skeleton.find_bone(side+part)<0:errors.append("Missing arm chain "+side+part)
		var meshes:=driver.find_children("*","MeshInstance3D",true,false)
		for mesh in meshes:
			if mesh.skin==null:errors.append("Missing Skin in driver %d" % i);continue
			for surface in mesh.mesh.get_surface_count():
				var arrays:Array=mesh.mesh.surface_get_arrays(surface)
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
				if weights.size()!=vertices.size()*4:
					errors.append("Expected four weights per vertex");continue
				for vertex in vertices.size():
					var total:=0.0
					for influence in 4:total+=weights[vertex*4+influence]
					if absf(total-1.0)>0.001:errors.append("Unnormalized skin weights");break
		driver.free()
	return {"ok":errors.is_empty(),"message":"; ".join(errors)}

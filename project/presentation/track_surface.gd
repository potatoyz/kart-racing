extends Node3D

const Course = preload("res://mechanic/course.gd")
const Model = preload("res://presentation/models.gd")
var course = Course.new()

func _ready() -> void:
	var half: float = course.width*0.5
	var asphalt := ShaderMaterial.new()
	asphalt.shader = preload("res://presentation/asphalt.gdshader")
	add_surface("Asphalt",sweep([Vector2(-half-0.3,0.065),Vector2(half+0.3,0.065)],1.0,false),asphalt)
	if course.id != "sunny_coast":
		var floor_body := StaticBody3D.new()
		floor_body.name = "TrackFloor"
		floor_body.collision_layer = 1
		floor_body.collision_mask = 2
		var floor_shape := CollisionShape3D.new()
		var floor_mesh := ConcavePolygonShape3D.new()
		floor_mesh.set_faces(sweep([Vector2(-half-0.4,0.065),Vector2(half+0.4,0.065)],1.0,false).get_faces())
		floor_mesh.backface_collision = true
		floor_shape.shape = floor_mesh
		floor_body.add_child(floor_shape)
		add_child(floor_body)
	var curb_material := stripe_material(Color("f8edd6"),Color("ef866f"))
	var paint := stripe_material(Color("eee8c9"),Color(1,1,1,0))
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	paint.alpha_scissor_threshold = 0.5
	add_surface("CenterMarkings",sweep([Vector2(-0.08,0.074),Vector2(0.08,0.074)],1.0,false),paint)
	var rail_material := Model.material(Color("e6f0ea")).duplicate() as StandardMaterial3D
	rail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0,1.0]:
		var suffix := "Inner" if side > 0.0 else "Outer"
		add_surface("Curb"+suffix,sweep([Vector2(half-0.35,0.065),Vector2(half-0.35,0.20),Vector2(half+0.45,0.20),Vector2(half+0.45,0.065)],side,true),curb_material)
		add_surface("Rail"+suffix,sweep([Vector2(half+0.65,0.06),Vector2(half+0.65,0.70),Vector2(half+0.72,0.84),Vector2(half+0.99,0.84),Vector2(half+1.06,0.70),Vector2(half+1.06,0.06)],side,true),rail_material)
		var wall_mesh := sweep([Vector2(course.wall_inner,Course.WALL_BOTTOM),Vector2(course.wall_inner,Course.WALL_TOP),Vector2(course.wall_outer,Course.WALL_TOP),Vector2(course.wall_outer,Course.WALL_BOTTOM)],side,true)
		var wall := StaticBody3D.new()
		wall.name = "AirWall"+suffix
		wall.collision_layer = 4
		wall.collision_mask = 2
		var collision := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(wall_mesh.get_faces())
		shape.backface_collision = true
		collision.shape = shape
		wall.add_child(collision)
		add_child(wall)

func add_surface(label: String, mesh: ArrayMesh, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)

func stripe_material(a: Color, b: Color) -> StandardMaterial3D:
	var image := Image.create(4,1,false,Image.FORMAT_RGBA8)
	for x in 4: image.set_pixel(x,0,a if x < 2 else b)
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.texture_repeat = true
	material.roughness = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

# Each face is one indexed periodic strip. Coincident closing rings use the
# exact same cached coordinates/normals, with separate UVs for repeating paint.
# No rotated boxes, endpoint overlap, miter gaps, or coarse chord geometry.
func sweep(profile: Array[Vector2], side: float, closed: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var faces := profile.size() if closed else profile.size()-1
	for face in faces:
		var a := profile[face]
		var b := profile[(face+1)%profile.size()]
		var edge := b-a
		var normal := Vector2(-edge.y,edge.x).normalized()
		var base := vertices.size()
		for i in range(course.baked_count+1):
			var index: int = i%course.baked_count
			var center: Vector3 = course.baked_points[index]
			var right: Vector3 = course.baked_right[index]*side
			vertices.append(center+right*a.x+Vector3.UP*a.y)
			vertices.append(center+right*b.x+Vector3.UP*b.y)
			var world_normal := right*normal.x+Vector3.UP*normal.y
			normals.append(world_normal)
			normals.append(world_normal)
			uv.append(Vector2(course.distances[i]/8.0,0))
			uv.append(Vector2(course.distances[i]/8.0,1))
			if i < course.baked_count:
				var v := base+i*2
				indices.append_array(PackedInt32Array([v,v+2,v+1,v+1,v+2,v+3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

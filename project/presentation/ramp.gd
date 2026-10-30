extends StaticBody3D

const Model = preload("res://presentation/models.gd")

func _init(road_width: float = 18.0) -> void:
	var half := road_width*0.5-1.0
	# Full-width, shallow takeoff. Forward is -Z. Physics and art share vertices.
	var vertices := PackedVector3Array([
		Vector3(-half,-0.25,7),Vector3(half,-0.25,7),Vector3(-half,-0.25,-7),Vector3(half,-0.25,-7),
		Vector3(-half,0.0,7),Vector3(half,0.0,7),Vector3(-half,1.5,-7),Vector3(half,1.5,-7)])
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	collision.shape = shape
	add_child(collision)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [4,6,5,5,6,7,0,2,4,4,2,6,1,5,3,5,7,3,2,3,6,6,3,7]:
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var mat := Model.material(Color("d4ad57")).duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	add_child(mesh)
	for z in [3.0,0.0,-3.0]:
		var y: float = (7.0-z)/14.0*1.5
		var stripe := Model.box(self,Vector3(half*2.0-0.2,0.025,0.4),Vector3(0,y+0.025,z),Color("fff2bc"))
		stripe.rotation.x = atan(1.5/14.0)
	for x in [-half+0.3,half-0.3]:
		var edge := Model.box(self,Vector3(0.25,0.12,14.1),Vector3(x,0.79,0),Color("ff965d"))
		edge.rotation.x = atan(1.5/14.0)
	var sign := Label3D.new()
	sign.text = "AIR  /  J → J"
	sign.position = Vector3(0,2.6,-7)
	sign.font_size = 75
	sign.pixel_size = 0.012
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)

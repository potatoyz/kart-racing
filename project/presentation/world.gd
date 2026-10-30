extends Node3D

const Model = preload("res://presentation/models.gd")
const Art = preload("res://presentation/generated_assets.gd")
const Course = preload("res://mechanic/course.gd")
var course = Course.new()

func _ready() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("459dd0")
	sky_material.sky_horizon_color = Color("cce7e8")
	sky_material.ground_bottom_color = Color("8fbbad")
	sky_material.ground_horizon_color = Color("d4edf0")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("e0eff7")
	settings.ambient_light_energy = 0.45
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	settings.fog_enabled = true
	settings.fog_light_color = Color("c7e1df")
	settings.fog_density = 0.0008
	settings.fog_sky_affect = 0.2
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("fff1ce")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)
	if course.id != "sunny_coast":
		build_expansion()
		return
	var water := Model.box(self, Vector3(2000, 0.2, 2000), Vector3(0, -2.0, 0), Color("4dbdc8"))
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://presentation/coastal_water.gdshader")
	water.material_override = water_material
	var island := Model.cylinder(self, Vector3(0, -1.4, 0), 169, 2.0, Color("ead8a4"))
	island.mesh.radial_segments = 128
	island.scale.z = 1.15
	var grass := Model.cylinder(self, Vector3(0, -0.45, 0), 158, 1.0, Color("83af91"))
	grass.mesh.radial_segments = 128
	var grass_material := ShaderMaterial.new()
	grass_material.shader = preload("res://presentation/coastal_ground.gdshader")
	grass.material_override = grass_material
	static_box(Vector3(330, 1, 360), Vector3(0, -0.44, 0), 0.0)
	var track = preload("res://presentation/track_surface.gd").new()
	track.name = "SmoothTrack"
	track.course = course
	add_child(track)
	for i in range(4,course.point_count,8):
		var mid: Vector3 = course.sample(float(i)+0.5)
		var direction: Vector3 = course.tangent_at(float(i)+0.5)
		var side := direction.cross(Vector3.UP)
		var yaw := atan2(-direction.x,-direction.z)
		for j in 2:
			var sign_pos := mid+side*(12.5+j*1.3)+Vector3.UP*1.8
			var sign_node := Model.box(self,Vector3(1,1.1,0.2),sign_pos,Color("ffbd44"))
			sign_node.rotation.y = yaw
			var label := Label3D.new()
			label.text = "›"
			label.font_size = 110
			label.modulate = Color("244253")
			label.position.z = 0.12
			sign_node.add_child(label)
	build_start()
	for s in course.ramps:
		var ramp = preload("res://presentation/ramp.gd").new(course.width)
		ramp.position = course.at_distance(s) + Vector3.UP * 0.04
		ramp.rotation.y = course.yaw_at(s)
		add_child(ramp)
	var rng := RandomNumberGenerator.new()
	rng.seed = 27
	for i in 75:
		var p := Vector3(rng.randf_range(-147,147), 0, rng.randf_range(-147,147))
		if course.nearest(p).distance < 23.0 or p.length() < 16.0: continue
		if i % 3 == 0: building(p, rng)
		else: palm(p, rng.randf_range(0.75, 1.6))
	for i in 18:
		var angle := float(i) * TAU / 18.0
		var point := Vector3(cos(angle)*155.0,0,sin(angle)*170.0)
		if course.nearest(point).distance > 23.0:
			prop("coastal_rocks",point,angle,rng.randf_range(0.8,1.65))
	for point in [Vector3(-125,0,-105),Vector3(125,0,115)]:
		if course.nearest(point).distance > 25.0:
			prop("lighthouse",point,0.4,1.0)
	for i in 14:
		var cloud := Model.ball(self, Vector3(-250 + i * 40, 75 + (i % 3) * 7, -250 + (i % 4) * 90), Vector3(35, 9, 17), Color("f8faf0"))
		Model.ball(cloud, Vector3(0.25, 0.2, 0), Vector3(0.7, 1.3, 0.8), Color("f8faf0"))
	Model.cylinder(self, Vector3(0, 0.05, 0), 6.5, 0.25, Color("eae5d2"))
	Model.cylinder(self, Vector3(0, 0.2, 0), 5.5, 0.12, Color("738e95"))

func static_box(size: Vector3, pos: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func build_start() -> void:
	var root := Node3D.new()
	root.position = course.at(0)
	root.rotation.y = course.heading(0)
	add_child(root)
	for x in [-course.width*0.5-1.0, course.width*0.5+1.0]:
		Model.box(root, Vector3(0.7, 9.2, 0.7), Vector3(x, 4.6, 0), Color("f4e5bd"))
	Model.box(root, Vector3(course.width+3.0, 1.6, 0.7), Vector3(0, 9.0, 0), Color("14a5b5"))
	var label := Label3D.new()
	label.text = course.definition.english + "  /  START"
	label.font_size = 95
	label.pixel_size = 0.009
	label.position = Vector3(0, 9.05, 0.4)
	root.add_child(label)
	for x in int(course.width):
		for z in 3:
			Model.box(root, Vector3(1, 0.015, 1), Vector3(x - course.width*0.5+0.5, 0.075, z - 1), Color("eef1de") if (x + z) % 2 == 0 else Color("263c4e"))

func palm(pos: Vector3, size: float) -> void:
	if prop("palm",pos,pos.x * 0.08,size): return
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * size
	add_child(root)
	var trunk := Model.cylinder(root, Vector3(0, 2.6, 0), 0.3, 5.2, Color("ba9e71"))
	trunk.rotation.z = 0.08
	for i in 5:
		var leaf := Model.ball(root, Vector3(0.1, 5.1, 0), Vector3(0.8, 0.28, 4.8), Color("469e79"))
		leaf.rotation.y = i * TAU / 5.0

func building(pos: Vector3, rng: RandomNumberGenerator) -> void:
	if prop("beach_hut",pos,rng.randf_range(-PI,PI),rng.randf_range(0.85,1.25)): return
	var height := rng.randf_range(5, 12)
	var color: Color = [Color("f2c898"), Color("f0a99a"), Color("b5d9d3")][rng.randi_range(0,2)]
	Model.box(self, Vector3(6, height, 6), pos + Vector3.UP * height * 0.5, color)
	Model.box(self, Vector3(6.6, 0.4, 6.6), pos + Vector3.UP * height, Color("f7e7bf"))
	for level in int(height / 2):
		for x in [-1.6, 1.6]:
			Model.box(self, Vector3(1.1, 1.0, 0.08), pos + Vector3(x, 1.5 + level * 2.0, 3.03), Color("528d9c"))

func prop(asset_id: String, pos: Vector3, yaw: float, size_value: float) -> bool:
	var visual := Art.instance(asset_id)
	if visual == null: return false
	visual.position = pos
	visual.rotation.y = yaw
	visual.scale = Vector3.ONE * size_value
	add_child(visual)
	return true

func build_expansion() -> void:
	var terrain = preload("res://presentation/environments/map_environment.gd").new()
	terrain.course = course
	add_child(terrain)
	var track = preload("res://presentation/track_surface.gd").new()
	track.name = "SmoothTrack"
	track.course = course
	add_child(track)
	build_start()
	for s in course.ramps:
		var ramp = preload("res://presentation/ramp.gd").new(course.width)
		ramp.position = course.at_distance(s)+Vector3.UP*0.04
		ramp.rotation.y = course.yaw_at(s)
		add_child(ramp)
	# Signs follow curvature; repeated arrows warn before tight corners.
	for i in range(40,int(course.length),22):
		var s := float(i)
		var bend: float = course.curvature_at(s+14.0)
		if absf(bend)<0.012: continue
		var side: Vector3 = course.direction_at(s).cross(Vector3.UP)
		var position: Vector3 = course.at_distance(s)+side*signf(bend)*(course.width*0.5+2.7)
		var post := Model.box(self,Vector3(0.16,2.4,0.16),position+Vector3.UP*1.2,Color("476075"))
		var board := Model.box(self,Vector3(2.9,1.2,0.12),position+Vector3.UP*2.3,Color("ffbd44"))
		board.rotation.y = course.yaw_at(s)
		var sign := Label3D.new()
		sign.text = "‹‹" if bend>0 else "››"
		sign.font_size = 90
		sign.pixel_size = 0.014
		sign.modulate = Color("17394d")
		sign.position.z = 0.08
		board.add_child(sign)

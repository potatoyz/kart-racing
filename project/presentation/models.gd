extends RefCounted

const Art = preload("res://presentation/generated_assets.gd")

static var palette := [Color("15b9c5"), Color("ff805d"), Color("ffd24c")]
static var fabrics := [Color("f7f3df"), Color("fc817e"), Color("a68bdf")]
static var materials: Dictionary = {}

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key := str(color) + str(glow)
	if materials.has(key): return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.3
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials[key] = m
	return m

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, bevel: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material(color, bevel)
	parent.add_child(node)
	return node

static func ball(parent: Node3D, pos: Vector3, scale_value: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 16
	mesh.rings = 8
	node.mesh = mesh
	node.position = pos
	node.scale = scale_value
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = pos
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func driver(kind: int, seated: bool = true) -> Node3D:
	var generated := Art.instance("driver_%d" % kind)
	if generated != null: return generated
	var root := Node3D.new()
	var cloth: Color = fabrics[kind]
	box(root, Vector3(0.58, 0.65, 0.4), Vector3(0, 0.7, 0), cloth)
	ball(root, Vector3(0, 1.25, 0), Vector3(0.72, 0.65, 0.68), palette[kind])
	ball(root, Vector3(0, 1.23, -0.22), Vector3(0.6, 0.3, 0.32), Color("183444"))
	box(root, Vector3(0.16, 0.08, 0.63), Vector3(0, 1.58, 0), Color.WHITE)
	for sign_value in [-1, 1]:
		var arm := box(root, Vector3(0.19, 0.5, 0.2), Vector3(sign_value * 0.39, 0.72, -0.1), cloth)
		arm.rotation.x = -0.8 if seated else 0.08
		box(root, Vector3(0.22, 0.5, 0.23), Vector3(sign_value * 0.18, 0.22, -0.12 if seated else 0.0), Color("254557"))
		box(root, Vector3(0.25, 0.15, 0.4), Vector3(sign_value * 0.18, 0.06, -0.13), cloth)
	if kind == 1:
		box(root, Vector3(0.48, 0.14, 0.6), Vector3(0.0, 0.97, 0.28), Color("fff3c9"))
	if kind == 2:
		for x in [-0.2, 0.2]:
			var ear := box(root, Vector3(0.18, 0.42, 0.2), Vector3(x, 1.65, 0.05), cloth)
			ear.rotation.z = x
	return root

static func car(kind: int, outfit: int) -> Node3D:
	var generated := Art.instance("car_%d" % kind)
	if generated != null:
		var root := Node3D.new()
		root.add_child(generated)
		var entry: Dictionary = Art.catalogue()["car_%d" % kind]
		var seat: Array = entry.get("seat", [0,0.4,0.15])
		var racer := driver(outfit)
		racer.name = "Driver"
		racer.position = Vector3(seat[0],seat[1],seat[2])
		var adjustment: Array = entry.get("driver_seat_offsets",{}).get(str(outfit),[0,0,0])
		racer.position += Vector3(adjustment[0],adjustment[1],adjustment[2])
		racer.scale = Vector3.ONE * float(entry.get("driver_scale", 1.0))
		root.add_child(racer)
		var wheels: Array = []
		for wheel in generated.find_children("Wheel*","Node3D",true,false):
			var radii: Dictionary = entry.get("wheel_radii", {})
			wheels.append({"pivot":wheel,"spin":wheel.get_child(0),"radius":float(radii.get(str(wheel.name),0.37)),"front":"Front" in str(wheel.name)})
		root.set_meta("wheels",wheels)
		if entry.has("steering_control"):
			var controller = preload("res://presentation/steering_driver.gd").new()
			controller.name = "SteeringController"
			controller.vehicle_art = generated
			controller.racer = racer
			controller.spec = entry.steering_control
			root.add_child(controller)
		add_effects(root)
		return root
	var root := Node3D.new()
	var color: Color = palette[kind]
	var width := 1.65 if kind != 2 else 1.5
	box(root, Vector3(width, 0.45, 3.2), Vector3(0, 0.55, 0), color)
	box(root, Vector3(width * 0.83, 0.28, 1.25), Vector3(0, 0.85, -0.9), color)
	box(root, Vector3(0.24, 0.02, 1.3), Vector3(0, 1.0, -0.9), Color("f4f3df"))
	box(root, Vector3(width * 0.83, 0.35, 0.6), Vector3(0, 0.83, 1.05), color)
	box(root, Vector3(1.25, 0.15, 0.25), Vector3(0, 0.73, -1.62), Color("17354a"))
	for x in [-0.55, 0.55]:
		box(root, Vector3(0.32, 0.12, 0.05), Vector3(x, 0.83, -1.54), Color("fff2a2"), true)
		box(root, Vector3(0.27, 0.12, 0.05), Vector3(x, 0.8, 1.62), Color("ff5261"))
	for x in [-0.89, 0.89]:
		for z in [-1.04, 1.0]:
			var wheel := cylinder(root, Vector3(x, 0.42, z), 0.43, 0.26, Color("203440"))
			wheel.rotation.z = PI / 2.0
			var hub := cylinder(root, Vector3(x * 1.14, 0.42, z), 0.22, 0.03, Color("f4f3df"))
			hub.rotation.z = PI / 2.0
	if kind != 2:
		for x in [-0.6, 0.6]: box(root, Vector3(0.1, 0.45, 0.15), Vector3(x, 1.02, 1.35), Color("234052"))
		box(root, Vector3(2.0, 0.12, 0.42), Vector3(0, 1.3 if kind == 1 else 1.23, 1.4), color)
	var person := driver(outfit)
	person.position = Vector3(0, 0.65, 0.15)
	person.scale = Vector3.ONE * 0.8
	root.add_child(person)
	add_effects(root)
	return root

static func add_effects(root: Node3D) -> void:
	var flame := ball(root, Vector3(0, 0.6, 2.1), Vector3(0.6, 0.5, 1.8), Color("56e9ef"))
	flame.name = "Flame"
	flame.visible = false
	var shield := ball(root, Vector3(0, 1.0, 0), Vector3(3.1, 2.8, 4.5), Color(0.2, 0.8, 1.0, 0.23))
	shield.name = "Shield"
	shield.visible = false

static func animate_car(root: Node3D, state: Dictionary, dt: float) -> void:
	var yaw: float = state.visual_yaw
	var previous: float = root.get_meta("previous_visual_yaw",yaw)
	root.set_meta("previous_visual_yaw",yaw)
	var steering := 0.0
	if absf(float(state.speed)) > 0.5 and dt > 0.0:
		steering = clampf(atan(angle_difference(previous,yaw)*2.1/(float(state.speed)*dt)),-0.48,0.48)
	if state.has("steer_input"): steering = -float(state.steer_input)*0.48
	var previous_steer: float = root.get_meta("visual_steer",steering)
	steering = lerpf(previous_steer,steering,1.0-exp(-18.0*dt))
	root.set_meta("visual_steer",steering)
	for wheel in root.get_meta("wheels",[]):
		wheel.spin.rotation.z = fposmod(wheel.spin.rotation.z-float(state.speed)*dt/wheel.radius,TAU)
		if wheel.front: wheel.pivot.rotation.y = steering
	var controller := root.get_node_or_null("SteeringController")
	if controller != null: controller.set_steering(steering/0.48)

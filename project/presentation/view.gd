extends Node3D

const Model = preload("res://presentation/models.gd")
const ChaseHeading = preload("res://presentation/chase_heading.gd")
const VFX = preload("res://presentation/vfx/race_vfx.gd")
var vfx
var legacy_vfx:=false
var api: Node
var course
var camera: Camera3D
var cars: Array[Node3D] = []
var boxes: Array[Node3D] = []
var shots: Array[Node3D] = []
var garage: Node3D
var preview_key := ""
var car_key := ""
var cut := true
var trail_timer := 0.0
var trails: Array = []
var chase_yaw := 0.0
var heading = ChaseHeading.new()

func _ready() -> void:
	# Vehicles provide interpolated poses. Proxy visuals and this one camera
	# writer must not be automatically interpolated again.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera = Camera3D.new()
	camera.current = true
	camera.far = 900
	add_child(camera)
	garage = Node3D.new()
	add_child(garage)
	legacy_vfx="--vfx-before" in OS.get_cmdline_user_args()
	if not legacy_vfx:
		vfx=VFX.new()
		vfx.name="RaceVFX"
		add_child(vfx)
		vfx.course = course if course != null else vfx.course
	api.event_emitted.connect(on_event)

func on_event(key: String, data: Dictionary) -> void:
	if vfx!=null:vfx.on_event(key,data)
	if key in ["race_reset", "garage_entered", "track_changed"] or (key == "reset" and int(data.get("racer", -1)) == 0):
		cut = true
		for trail in trails: trail.node.queue_free()
		trails.clear()

func _process(dt: float) -> void:
	var s: Dictionary = api.snapshot()
	if s.cars.is_empty(): return
	var show_garage: bool = s.phase == "garage"
	# Garage preview now has its own lit viewport, independent of the race camera.
	garage.visible = false
	# Equip updates the selection before the next race spawns its vehicles.
	# Build the visual key from the actual racers, so the grid uses their models.
	var new_car_key := ""
	for racer in s.cars: new_car_key += "%d:%d/" % [racer.type,racer.outfit]
	if cars.size() != s.cars.size() or car_key != new_car_key:
		for node in cars: node.free()
		cars.clear()
		for car in s.cars:
			var node := Model.car(int(car.type), int(car.outfit))
			add_child(node)
			cars.append(node)
		car_key = new_car_key
		if vfx!=null:vfx.bind_cars(cars,s.cars)
	for i in cars.size():
		var c: Dictionary = s.cars[i]
		cars[i].visible = not show_garage and (i == 0 or (not c.finished and camera.position.distance_to(c.position) > 4.0))
		cars[i].global_position = c.visual_position
		cars[i].rotation.y = c.visual_yaw
		cars[i].rotation.x = c.tilt
		cars[i].rotation.z = clampf(float(c.slip_angle)*0.10,-0.055,0.055) if c.grounded else 0.0
		if not s.paused: Model.animate_car(cars[i],c,dt)
		cars[i].get_node("Flame").visible = legacy_vfx and (c.boost > 0.0 or c.mini_boost > 0.0) and not s.paused
		var flame := cars[i].get_node("Flame") as MeshInstance3D
		flame.scale = Vector3(0.75,0.6,2.6) if c.boost > 0.0 else Vector3(0.50,0.4,1.5)
		flame.material_override = Model.material(Color("56e9ef") if c.boost > 0.0 or c.tricks.last_technique == "air_boost" else Color("ffbd63"),true)
		cars[i].get_node("Shield").visible = c.shield > 0.0 or c.protection > 0.0
	while boxes.size() > s.boxes.size(): boxes.pop_back().free()
	while boxes.size() < s.boxes.size():
		var node := Node3D.new()
		Model.box(node, Vector3(1.5,1.5,1.5), Vector3.ZERO, Color("b395e4"))
		var label := Label3D.new()
		label.text = "?"
		label.font_size = 100
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = 0.05
		node.add_child(label)
		add_child(node)
		boxes.append(node)
	for i in boxes.size():
		boxes[i].visible = not show_garage and s.mode == "item" and s.boxes[i].cooldown <= 0.0
		boxes[i].position = s.boxes[i].position + Vector3.UP * 1.4
		if not s.paused: boxes[i].rotation.y += dt
	while shots.size() < s.projectiles.size():
		var node := Model.ball(self, Vector3.ZERO, Vector3(0.5,0.5,1.5), Color("ff9b4d"))
		shots.append(node)
	for i in shots.size():
		shots[i].visible = i < s.projectiles.size() and not show_garage
		if i < s.projectiles.size(): shots[i].position = s.projectiles[i].position
	var p: Dictionary = s.cars[0]
	chase_yaw = heading.step(p,dt,cut,s.paused)
	var forward := Vector3(-sin(chase_yaw),0,-cos(chase_yaw))
	var desired: Vector3 = p.visual_position - forward * 10.5 + Vector3.UP * 6.1
	var focus: Vector3 = p.visual_position + forward * 4.0 + Vector3.UP * 1.0
	if show_garage:
		desired = Vector3(9.5, 6.0, 12.5)
		focus = Vector3(0.8, 0.9, 0)
	else:
		# Sweep camera volume from focus at the car, avoiding scenery/walls.
		var sphere := SphereShape3D.new()
		sphere.radius = 0.35
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform.origin = p.visual_position + Vector3.UP * 1.7
		query.motion = desired - query.transform.origin
		query.collision_mask = 1
		var sweep := get_world_3d().direct_space_state.cast_motion(query)
		if sweep[0] < 1.0: desired = query.transform.origin + query.motion * maxf(0.1, sweep[0] - 0.03)
	if cut:
		camera.position = desired
		cut = false
	elif not s.paused:
		camera.position = camera.position.lerp(desired,1.0-exp(-40.0*dt))
	camera.look_at(focus)
	if vfx!=null:vfx.update_effects(s,camera,dt)
	var target_fov := 46.0 if show_garage else (73.0 if p.boost > 0.0 and not s.reduced_motion else 65.0)
	if not show_garage and vfx!=null:target_fov=vfx.speed_fx.fov_target()
	# Pause keeps the current lens; boost entry/exit use the same continuous envelope.
	if not s.paused:camera.fov=lerpf(camera.fov,target_fov,1.0-exp(-5.0*dt))
	if legacy_vfx and not s.paused and not show_garage:
		trail_timer += dt
		if p.drifting and p.grounded and trail_timer > 0.06:
			trail_timer = 0.0
			for side in [-0.8,0.8]:
				var pos: Vector3 = p.position + forward.cross(Vector3.UP) * side - forward * 1.0
				pos.y = 0.075
				var trail := Model.box(self,Vector3(0.2,0.015,0.8),pos,Color("354d59"))
				trail.rotation.y = p.yaw
				trails.append({"node": trail, "life": 5.0})
		for i in range(trails.size()-1,-1,-1):
			trails[i].life -= dt
			if trails[i].life <= 0.0:
				trails[i].node.queue_free()
				trails.remove_at(i)

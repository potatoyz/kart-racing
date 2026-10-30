extends SceneTree

# Native physics regression for car contacts; no rendering or player saves.
# Run: Godot --headless --path project --fixed-fps 60 --script res://tests/collision_qa.gd
const Vehicle = preload("res://mechanic/vehicle.gd")
var failures: Array[String] = []
var cases: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func box(parent: Node3D, size: Vector3, at: Vector3, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)

func scenario(label: String, options: Dictionary = {}) -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	box(stage,Vector3(200,1,200),Vector3(0,-0.5,0),1)
	var wall: bool = options.get("wall",false)
	if wall: box(stage,Vector3(20,4,1),Vector3(0,2,-5.2),4)
	var cars: Array = []
	var initial_speeds: Array = options.get("speeds",[40.0,20.0])
	for i in initial_speeds.size():
		var car = Vehicle.new()
		stage.add_child(car)
		car.reset_to(Vector3(0,0.02,-3.5*i),0.0)
		car.car_type = 1 if i == 0 else 0
		car.racer_id = i
		car.speed = initial_speeds[i]
		car.travel = car.forward()*car.speed
		cars.append(car)
	if options.get("side",false):
		cars[0].position = Vector3(-1.9,0.02,0)
		cars[0].rotation.y = -0.1
		cars[0].travel = cars[0].forward()*cars[0].speed
		cars[1].position.z = -1.0
	if options.get("head_on",false):
		cars[1].position.z = -6.0
		cars[1].rotation.y = PI
		cars[1].travel = cars[1].forward()*cars[1].speed
	if options.get("boost",false): cars[0].boost = 2.1
	if options.get("equal",false): cars[1].position.z = -2.91
	if wall and cars.size() > 1: cars[1].position.z = -3.2
	await physics_frame
	await physics_frame
	var rear_start: Vector3 = cars[0].position
	var front_start: Vector3 = cars[-1].position
	var min_rear := 1000.0
	var min_step := 1000.0
	var max_front := 0.0
	var contacts := 0
	var first_hit: Dictionary = {}
	var minimum_gap := 1000.0
	var steps := int(options.get("steps",60))
	var order := range(cars.size())
	if options.get("reverse_order",false): order.reverse()
	for frame in steps:
		await physics_frame
		var before: Vector3 = cars[0].position
		for i in order:
			var throttle := 1.0 if options.get("throttle",false) else 0.0
			# Straighten after the initial side touch: a glancing pass, not a
			# full second of steering into the neighbour with the throttle off.
			var steer := -1.0 if options.get("side",false) and i == 0 and frame >= 3 and frame < 7 else 0.0
			cars[i].drive(1.0/60.0,throttle,steer,false,false)
			for index in cars[i].get_slide_collision_count():
				var collider: Object = cars[i].get_slide_collision(index).get_collider()
				if collider in cars:
					contacts += 1
					if first_hit.is_empty():
						first_hit = {"rear":cars[0].speed,"front":cars[-1].speed,"frame":frame}
		min_rear = minf(min_rear,cars[0].speed)
		min_step = minf(min_step,cars[0].position.distance_to(before))
		max_front = maxf(max_front,cars[-1].speed)
		if cars.size() > 1 and not options.get("side",false) and not options.get("head_on",false):
			for i in cars.size()-1:
				minimum_gap = minf(minimum_gap,cars[i].position.z-cars[i+1].position.z)
		for car in cars:
			expect(car.position.is_finite() and car.travel.is_finite(),label+": finite motion")
	var rear_advance: float = rear_start.z-cars[0].position.z
	var front_advance: float = front_start.z-cars[-1].position.z
	if cars.size() > 1: expect(contacts > 0,label+": fixture must actually collide")
	if wall:
		for car in cars: expect(car.position.z >= -3.26,label+": wall prevents penetration")
		expect(absf(cars[0].speed) < 1.0,label+": a blocked car must eventually stop")
	elif options.get("head_on",false):
		expect(absf(cars[0].speed) < 12.0 and absf(cars[1].speed) < 12.0,label+": head-on impact dissipates speed")
	elif options.get("side",false):
		expect(min_rear > 30.0 and rear_advance > 30.0,label+": glancing contact preserves forward motion")
	else:
		expect(min_rear > float(options.get("min_speed",15.0)),label+": rear car must keep moving")
		expect(rear_advance > float(options.get("min_distance",12.0)),label+": preserved speed must produce real displacement")
		expect(minimum_gap >= 2.88,label+": cars cannot pass through each other")
		if not options.get("equal",false):
			expect(max_front > float(initial_speeds[-1])+2.0,label+": front car receives momentum")
		if options.get("boost",false): expect(cars[0].boost > 0.0,label+": a bump must not cancel nitro")
	cases.append({"name":label,"contacts":contacts,"first_hit":first_hit,"min_rear_speed":min_rear,"max_front_speed":max_front,"rear_advance_m":rear_advance,"front_advance_m":front_advance,"min_step_m":min_step,"minimum_gap_m":minimum_gap})
	stage.free()
	await physics_frame

func run() -> void:
	await scenario("rear_end")
	await scenario("rear_end_reverse_order",{"reverse_order":true})
	await scenario("parked_car",{"speeds":[40.0,0.0],"min_speed":10.0})
	await scenario("equal_speed_contact",{"speeds":[35.0,35.0],"equal":true,"min_speed":27.0})
	await scenario("sustained_push",{"speeds":[48.0,25.0],"throttle":true,"steps":180,"min_speed":30.0,"min_distance":90.0})
	await scenario("nitro_bump",{"speeds":[60.0,35.0],"boost":true,"min_speed":38.0,"min_distance":35.0})
	await scenario("side_swipe",{"speeds":[40.0,38.0],"side":true})
	await scenario("three_car_chain",{"speeds":[40.0,20.0,10.0],"min_speed":12.0})
	await scenario("head_on",{"speeds":[40.0,40.0],"head_on":true})
	await scenario("static_wall",{"speeds":[40.0],"wall":true})
	await scenario("car_pinned_to_wall",{"speeds":[40.0,0.0],"wall":true})
	var report := {"ok":failures.is_empty(),"failures":failures,"cases":cases,"fixture":"Native CharacterBody3D drive() at 60 Hz, accelerated headless physics; no rendering or player input."}
	var output := ProjectSettings.globalize_path("res://reports/collisions.json")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("COLLISION_QA ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

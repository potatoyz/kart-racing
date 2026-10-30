extends RefCounted

const Vehicle = preload("res://mechanic/vehicle.gd")
const Course = preload("res://mechanic/course.gd")
var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func motion_yaw(car) -> float:
	return atan2(-car.travel.x,-car.travel.z)

func circle(car_type: int, hz: int, drift: bool, boost: bool = false) -> Dictionary:
	var car = Vehicle.new()
	car.car_type = car_type
	car.speed = float(car.STATS[car_type].top)+(18.0 if boost else 0.0)
	car.boost = 10.0 if boost else 0.0
	car.travel = Vector3(0,0,-car.speed)
	var rate := 0.0
	for frame in hz*4:
		var previous := motion_yaw(car)
		car.integrate_motor(1.0/hz,1.0,1.0,drift,false)
		rate = absf(wrapf(motion_yaw(car)-previous,-PI,PI))*hz
	var result := {"speed":car.speed,"radius":car.speed/rate,"rate":rate}
	car.free()
	return result

func run_test() -> Dictionary:
	failures.clear()
	var course = Course.new()
	var tightest := INF
	for i in Course.BAKED_COUNT:
		var u := float(i)/Course.SUBDIVISIONS
		var v := float(i+1)/Course.SUBDIVISIONS
		var turn: float = absf(course.tangent_at(u).signed_angle_to(course.tangent_at(v),Vector3.UP))
		tightest = minf(tightest,course.sample(u).distance_to(course.sample(v))/maxf(turn,0.000001))
	var measurements: Array = []
	for hz in [30,60,120]:
		for car_type in 3:
			var normal := circle(car_type,hz,false)
			var drift := circle(car_type,hz,true)
			var boost := circle(car_type,hz,false,true)
			var original_radius: float = Vehicle.STATS[car_type].top/Vehicle.STATS[car_type].steer
			expect(normal.radius < original_radius*1.20,"ordinary steering became unusably wide again")
			expect(normal.radius < tightest,"ordinary driving must remain usable on the current map")
			expect(normal.rate > float(Vehicle.STATS[car_type].steer)*0.85,"ordinary yaw authority was excessively reduced")
			expect(normal.speed > float(Vehicle.STATS[car_type].top)*0.90 and normal.speed < float(Vehicle.STATS[car_type].top)*0.95,"sustained full steer needs a modest, bounded speed cost")
			expect(drift.radius < normal.radius*0.9,"drift should allow a tighter established line")
			expect(boost.radius > normal.radius*1.25 and boost.radius < normal.radius*1.7,"boost steering lost its arcade control range")
			measurements.append({"hz":hz,"car":car_type,"grip":normal,"drift":drift,"boost":boost})
		var car = Vehicle.new()
		car.speed = 43.0
		car.travel = Vector3(0,0,-43)
		# Short keyboard corrections retain authority and barely lose speed.
		for frame in roundi(hz*0.1): car.integrate_motor(1.0/hz,1.0,1.0,false,false)
		expect(car.speed > 43.0*0.975,"a short steering tap loses too much speed")
		expect(absf(car.rotation.y) > deg_to_rad(8.0),"a short steering tap barely turns the car")
		var released_yaw: float = car.rotation.y
		for frame in roundi(hz*0.3): car.integrate_motor(1.0/hz,1.0,0.0,false,false)
		expect(absf(car.rotation.y-released_yaw) < 0.001,"ordinary steering keeps turning after key release")
		for frame in hz*2: car.integrate_motor(1.0/hz,1.0,0.2,false,false)
		expect(car.speed > 43.0*0.99,"gentle steering has a full-turn speed penalty")
		# Reversing direction must not reset accumulated steering loss.
		for frame in hz*2: car.integrate_motor(1.0/hz,1.0,1.0 if int(frame/5)%2 == 0 else -1.0,false,false)
		expect(car.speed < 43.0*0.95,"alternating steering bypasses sustained-turn loss")
		# Shift release into grip must never produce the former one-frame snap.
		for frame in hz: car.integrate_motor(1.0/hz,1.0,1.0,true,false)
		var reached_grip := false
		for frame in hz*3:
			var before := motion_yaw(car)
			var was_grip: bool = car.drift_phase == "grip"
			car.integrate_motor(1.0/hz,1.0,1.0,false,false)
			if was_grip:
				reached_grip = true
				var turn_rate: float = absf(wrapf(motion_yaw(car)-before,-PI,PI))*hz
				expect(turn_rate < 4.0,"drift exit snapped the actual velocity direction")
		expect(reached_grip,"recovery did not finish")
		car.reset_to(Vector3.ZERO,0.0)
		car.speed = 20.0
		car.travel = Vector3(0,0,-20)
		car.integrate_motor(1.0/hz,0.0,1.0,false,false)
		expect(absf(car.yaw_rate) > 1.3,"low-speed steering became unnecessarily sluggish")
		car.reset_to(Vector3.ZERO,0.0)
		car.speed = -9.0
		car.travel = Vector3(0,0,9)
		car.integrate_motor(1.0/hz,-1.0,1.0,false,false)
		expect(car.yaw_rate > 0.0 and car.travel.z > 0.0,"reverse steering or velocity direction broke")
		car.free()
	for i in 3:
		expect(absf(measurements[i].grip.radius-measurements[i+6].grip.radius) < 0.1,"ordinary turning depends on physics frequency")
	print("CORNERING_METRICS ",JSON.stringify(measurements))
	return {"ok":failures.is_empty(),"message":"; ".join(failures),"measurements":measurements,"tightest_radius":tightest}

extends RefCounted

const Vehicle = preload("res://mechanic/vehicle.gd")
var failures: Array[String] = []

func step(car, seconds: float, hz: int, steer: float, shift: bool) -> void:
	for i in roundi(seconds*hz):
		car.integrate_motor(1.0/hz,1.0,steer,shift,false)
		car.position += car.travel/hz

func warm_drift(hz: int):
	var car = Vehicle.new()
	step(car,3.0,hz,0.0,false)
	step(car,0.9,hz,0.7,true)
	return car

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func recovery(counter: bool, hz: int) -> Dictionary:
	var car = warm_drift(hz)
	var duration := 0.0
	while duration < 2.0:
		step(car,1.0/hz,hz,-0.7 if counter and duration < 0.24 else 0.0,false)
		duration += 1.0/hz
		if car.drift_phase == "grip": break
	var result := {"time":duration,"stock":car.tricks.mini_stock,"slip":car.slip_angle,"position":car.position,"speed":car.speed}
	car.free()
	return result

func run_test() -> Dictionary:
	var metrics: Dictionary = {}
	for hz in [30,60,120]:
		var car = warm_drift(hz)
		var slip_before: float = absf(car.slip_angle)
		var speed_before: float = car.speed
		var motion_before: Vector3 = car.travel
		step(car,1.0/hz,hz,0.0,false)
		expect(car.drift_phase == "recover" and car.drifting,"Shift release enters recovery at %d Hz"%hz)
		expect(absf(car.slip_angle) > slip_before*0.7,"release preserves lateral slip at %d Hz"%hz)
		expect(car.travel.distance_to(motion_before) < 3.0 and car.speed >= speed_before*0.95,"no velocity snap or abrupt braking at %d Hz"%hz)
		car.free()
		var neutral := recovery(false,hz)
		var counter := recovery(true,hz)
		expect(counter.time < neutral.time,"countersteer recovers faster at %d Hz"%hz)
		expect(counter.stock == 2 and neutral.stock == 1,"actual long drift distinguishes double from single at %d Hz"%hz)
		metrics[str(hz)] = {"neutral_seconds":neutral.time,"counter_seconds":counter.time,"release_slip_radians":slip_before}
	var samples: Array = []
	for hz in [30,60,120]:
		var car = warm_drift(hz)
		step(car,0.2,hz,-0.7,false)
		step(car,1.0,hz,0.0,false)
		samples.append({"position":car.position,"yaw":car.rotation.y,"speed":car.speed})
		car.free()
	for index in [0,2]:
		expect(samples[index].position.distance_to(samples[1].position) < 2.0,"comparable path across physics frequencies")
		expect(absf(samples[index].yaw-samples[1].yaw) < 0.06,"comparable heading across physics frequencies")
	var stopped = Vehicle.new()
	for i in 120: stopped.integrate_motor(1.0/60.0,0.0,1.0,true,false)
	expect(stopped.charge == 0.0 and stopped.tricks.mini_stock == 0,"stationary steering cannot farm boosts")
	stopped.free()
	var earning = Vehicle.new()
	step(earning,3.0,60,0.0,false)
	for i in 4:
		step(earning,0.9,60,0.7,true)
		step(earning,0.24,60,-0.7,false)
		step(earning,0.7,60,0.0,false)
	expect(earning.nitro > 0,"real repeated drift fills a usable nitro canister")
	var stock: int = earning.nitro
	expect(earning.use_nitro() and earning.nitro == stock-1 and earning.boost > 0.0,"earned nitro drives the big boost")
	earning.free()
	print("HANDLING_METRICS ",JSON.stringify(metrics))
	return {"ok":failures.is_empty(),"failures":failures,"metrics":metrics,"message":"; ".join(failures)}

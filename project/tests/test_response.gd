extends RefCounted

const Vehicle = preload("res://mechanic/vehicle.gd")

func motion_yaw(car) -> float:
	return atan2(-car.travel.x,-car.travel.z)

func measure(hz: int) -> Dictionary:
	var car = Vehicle.new()
	var dt := 1.0/hz
	car.speed = 43.0
	car.travel = Vector3(0,0,-43)
	var target: float = car.STATS[0].steer*0.90
	var body90 := -1.0
	var motion90 := -1.0
	for frame in hz:
		var before := motion_yaw(car)
		car.integrate_motor(dt,1.0,1.0,false,false)
		var rate := -wrapf(motion_yaw(car)-before,-PI,PI)/dt
		if body90 < 0.0 and -car.yaw_rate >= target*0.9: body90 = (frame+1)*dt
		if motion90 < 0.0 and rate >= target*0.9: motion90 = (frame+1)*dt
	var steady_slip: float = absf(car.slip_angle)
	var released_yaw: float = car.rotation.y
	for frame in roundi(hz*0.3): car.integrate_motor(dt,1.0,0.0,false,false)
	var overshoot := absf(car.rotation.y-released_yaw)
	for frame in roundi(hz*0.5): car.integrate_motor(dt,1.0,1.0,false,false)
	var reverse90 := -1.0
	for frame in hz:
		var before := motion_yaw(car)
		car.integrate_motor(dt,1.0,-1.0,false,false)
		var rate := wrapf(motion_yaw(car)-before,-PI,PI)/dt
		if reverse90 < 0.0 and rate >= target*0.9: reverse90 = (frame+1)*dt
	car.free()
	return {"hz":hz,"body_90_seconds":body90,"motion_90_seconds":motion90,"reverse_90_seconds":reverse90,"released_extra_turn_degrees":rad_to_deg(overshoot),"ordinary_slip_degrees":rad_to_deg(steady_slip)}

func run_test() -> Dictionary:
	var measurements: Array = []
	var failures: Array[String] = []
	for hz in [30,60,120]:
		var result := measure(hz)
		measurements.append(result)
		if result.body_90_seconds < 0.0 or result.body_90_seconds > 1.0/hz+0.0001: failures.append("ordinary steering must act on first physics step at %d Hz"%hz)
		if result.motion_90_seconds < 0.0 or result.motion_90_seconds > 0.051: failures.append("ordinary motion direction responds too slowly at %d Hz"%hz)
		if result.reverse_90_seconds < 0.0 or result.reverse_90_seconds > 0.071: failures.append("counter input responds too slowly at %d Hz"%hz)
		if result.released_extra_turn_degrees > 1.0: failures.append("ordinary steering keeps turning after release at %d Hz"%hz)
		if result.ordinary_slip_degrees > 2.0: failures.append("ordinary driving has excessive permanent slip at %d Hz"%hz)
	print("RESPONSE_METRICS ",JSON.stringify(measurements))
	return {"ok":failures.is_empty(),"message":"; ".join(failures),"measurements":measurements}

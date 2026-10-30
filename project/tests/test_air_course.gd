extends RefCounted

const Race = preload("res://mechanic/race.gd")

func run_test() -> Dictionary:
	var failures: Array[String] = []
	var race = Race.new()
	race.save_enabled = false
	race.spawn_racers()
	race.phase = "racing"
	var car = race.racers[0]
	car.passed = 3
	car.reset_cooldown = 0.0
	race.reset_car(car)
	var ramp: Vector3 = race.course.at(24)
	if (car.position-ramp).dot(race.course.tangent(24)) > -8.0: failures.append("ramp reset must be before wedge, never inside collision")
	if car.passed != 3 or car.tricks.landing_window > 0.0: failures.append("reset must not reward progress or landing")
	var cp: Vector3 = race.course.at(32)
	var direction: Vector3 = race.course.tangent(32)
	car.last_position = cp-direction+Vector3.UP*5.0
	car.position = cp+direction+Vector3.UP*5.0
	race.check_gate(car)
	if car.passed != 4: failures.append("legitimate airborne checkpoint must count")
	cp = race.course.at(40)
	direction = race.course.tangent(40)
	for height in [-4.0,10.0]:
		car.last_position = cp-direction+Vector3.UP*height
		car.position = cp+direction+Vector3.UP*height
		race.check_gate(car)
		if car.passed != 4: failures.append("underground or excessive altitude must not count")
	race.free()
	return {"ok":failures.is_empty(),"message":"; ".join(failures)}

extends RefCounted

const Heading = preload("res://presentation/chase_heading.gd")

func run_test() -> Dictionary:
	var failures: Array[String] = []
	for hz in [30,60,120]:
		var dt: float = 1.0/hz
		var rig = Heading.new()
		var p := {"yaw":0.0,"visual_yaw":0.0,"travel":Vector3(0,0,-40),"grounded":true,"drift_phase":"grip","tricks":{"air_time":0.0}}
		rig.step(p,dt,true,false)
		p.visual_yaw = 0.2
		if absf(rig.step(p,dt,false,false)-0.2) > 0.00001: failures.append("ordinary steering gained camera lag")
		p.visual_yaw = 0.6
		p.drift_phase = "drift"
		for frame in hz: rig.step(p,dt,false,false)
		if absf(rig.offset) < 0.40: failures.append("fixture did not build a meaningful drift offset")
		p.drift_phase = "grip"
		p.travel = Vector3(-sin(0.6),0,-cos(0.6))*40.0
		p["mini_boost"] = 0.65
		var max_step := 0.0
		for frame in int(hz/2):
			var previous: float = rig.offset
			rig.step(p,dt,false,false)
			max_step = maxf(max_step,absf(wrapf(rig.offset-previous,-PI,PI)))
		if max_step > Heading.MAX_OFFSET_RATE*dt+0.00001: failures.append("drift exit/spray snapped the camera at %d Hz"%hz)
		if absf(rig.offset) > 0.003: failures.append("drift camera offset did not settle")
		var before: float = rig.yaw
		p.visual_yaw += 0.5
		if rig.step(p,dt,false,true) != before: failures.append("paused camera continued tweening")
		if absf(rig.step(p,dt,true,false)-float(p.visual_yaw)) > 0.00001: failures.append("reset did not cut to new pose")
		# One-frame floor loss must not switch to a different camera direction.
		p.grounded = false
		p.tricks.air_time = dt
		p.travel = Vector3(0,0,-40)
		if absf(rig.step(p,dt,false,false)-float(p.visual_yaw)) > 0.00001: failures.append("ground contact chatter changed camera offset")
		# Heading wrap is a small turn, never an almost-360-degree correction.
		p.drift_phase = "drift"
		p.visual_yaw = PI-0.03
		p.travel = Vector3(-sin(-PI+0.03),0,-cos(-PI+0.03))*40.0
		rig.step(p,dt,true,false)
		if absf(rig.offset) > 0.1: failures.append("angle wrap caused a camera spin")
	return {"ok":failures.is_empty(),"message":"; ".join(failures)}

extends "res://tests/skills_qa.gd"
func _ready()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	log_file=FileAccess.open(output+"/events.jsonl",FileAccess.WRITE)
	api.event_emitted.connect(on_event)
	setup.call_deferred()
func setup()->void:
	super.setup()
	if stage>=4:return
	var c=api.course
	var s:=0.0
	if stage==3:s=c.ramps[0]-24.0
	else:
		for sample in range(40,int(c.length),2):
			var curvature:float=c.curvature_at(float(sample))
			if curvature<-.020 and curvature>-.045:s=float(sample);break
	var car=api.racers[0]
	var lane:Vector3=c.direction_at(s).cross(Vector3.UP)*(2.0 if stage<3 else 0.0)
	car.reset_to(c.at_distance(s)+lane+Vector3.UP*.07,c.yaw_at(s))
	car.speed=38.0 if stage==3 else 27.0
	car.travel=car.forward()*car.speed
	car.nitro=1 if stage in [1,2] else 0
	car.passed=0
	for i in c.gate_count:
		if c.gates[i]<s:car.passed=i
	api.emit_event("reset",{"racer":0})
	log_file.store_line(JSON.stringify({"map_fixture":c.id,"stage":stage,"distance":s,"passed":car.passed,"speed":car.speed,"nitro":car.nitro}))

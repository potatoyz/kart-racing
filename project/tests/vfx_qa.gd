extends Node3D
## Authored stress fixtures; actual physics-surface queries and native rendering.
const World=preload("res://presentation/world.gd")
const Model=preload("res://presentation/models.gd")
const FX=preload("res://presentation/vfx/race_vfx.gd")
const Course=preload("res://mechanic/course.gd")
var course=Course.new()
var camera:Camera3D
var fx
var cars:Array[Node3D]=[]
var states:Array=[]
var mode:="check"
var clock:=0.0
var seq:=0
var started:=false
var done:=false
var failures:Array[String]=[]
var samples:Array=[]
var frame_times:Array[float]=[]
var fx_times:Array[float]=[]
var capture_clock:=0.0
var frame_index:=0
var output:=""
var frozen:Dictionary={}
var air_marks:=-1
var node_count:=0
var last_stage:=-1
var probe_stages:Dictionary={}
var initial_pulses:=0
var gallery_car:=-1
var gallery_pulse:=0

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--vfx-mode="):mode=argument.trim_prefix("--vfx-mode=")
	output=ProjectSettings.globalize_path("res://../evidence/vfx_v8")
	DirAccess.make_dir_recursive_absolute(output+"/check_frames")
	add_child(World.new())
	camera=Camera3D.new();camera.current=true;camera.fov=60;add_child(camera)
	for i in 6:
		var car:=Model.car(i%3,i%3);cars.append(car);add_child(car)
		states.append({"type":i%3,"outfit":i%3,"boost":1.0,"mini_boost":0.0,"grounded":true,"finished":false,"drifting":true,"slip_angle":0.28,"speed":40.0,"travel":Vector3.ZERO,"visual_yaw":0.0,"steer_input":0.5})
	fx=FX.new();add_child(fx);fx.bind_cars(cars,states)
	fx.enabled=mode!="bench-off"
	if mode.begins_with("bench"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps=0
	await get_tree().physics_frame
	await get_tree().process_frame
	for i in 6:trigger("nitro_used",i)
	# Replaying an event must not produce a second pulse.
	initial_pulses=fx.vehicles[0].jet.pulse_count
	fx.on_event("nitro_used",{"racer":0,"seq":1})
	if fx.vehicles[0].jet.pulse_count!=initial_pulses:failures.append("duplicate event retriggered a pulse")
	node_count=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if mode=="stress":
		await stress()
	else:started=true

func trigger(key:String,racer:int) -> void:
	seq+=1;fx.on_event(key,{"racer":racer,"seq":seq})

func pose_scene(time:float,stage:int,dt:float) -> void:
	for i in 6:
		var u:=time*4.5+float(i)*0.7
		var direction:Vector3=course.tangent_at(u)
		var side:=direction.cross(Vector3.UP)
		cars[i].position=course.sample(u)+side*(-2.3 if i%2==0 else 2.3)+Vector3.UP*0.061
		cars[i].rotation.y=atan2(-direction.x,-direction.z)+0.23
		states[i].travel=direction*40.0
		states[i].visual_yaw=cars[i].rotation.y
		states[i].grounded=true
		states[i].drifting=true
		states[i].boost=1.0
		states[i].mini_boost=0.0
		if i==0:
			if stage==2:cars[i].position.y=2.2;states[i].grounded=false
			if stage==4:cars[i].position+=side*17.0
			if stage==5:cars[i].position=Vector3(161,0.061,0)
			if stage==6:states[i].drifting=false;states[i].boost=0.0
		Model.animate_car(cars[i],states[i],dt)
	var focus:Vector3=cars[0].position if mode=="check" else course.sample(time*4.5+1.75)
	camera.position=focus+Vector3(8,12,20)
	camera.look_at(focus)

func _process(dt:float) -> void:
	if not started or done:return
	clock+=dt
	if mode=="gallery":
		gallery(dt)
		return
	var bench:=mode.begins_with("bench")
	var stage:=0
	if not bench:
		stage=0 if clock<2.8 else 1 if clock<3.4 else 0 if clock<4.3 else 2 if clock<5.4 else 3 if clock<6.6 else 4 if clock<7.6 else 5 if clock<8.6 else 6 if clock<9.0 else 7 if clock<10.5 else 8
	if stage!=1:pose_scene(clock,stage,dt)
	if stage!=last_stage:
		if stage==1:frozen={"clock":fx.clock,"positions":fx.smoke.positions.duplicate(),"count":fx.smoke.count,"jet":fx.vehicles[0].jet.level}
		if stage==2:air_marks=fx.player_marks.written
		if last_stage==2 and fx.player_marks.written!=air_marks:failures.append("airborne tires generated marks")
		if stage==3:trigger("landing_boost",0)
		if stage==6:
			fx.clear_racer(0)
			for i in fx.smoke.count:
				if fx.smoke.owners[i]==0:failures.append("reset retained old smoke")
		if stage==8:fx.clear()
		last_stage=stage
	var snapshot:={"cars":states,"paused":stage==1,"phase":"garage" if stage==8 else "racing","reduced_motion":stage==7}
	fx.update_effects(snapshot,camera,dt)
	if stage==1:
		if fx.clock!=frozen.clock or fx.smoke.count!=frozen.count or fx.smoke.positions!=frozen.positions or fx.vehicles[0].jet.level!=frozen.jet:
			if "pause changed VFX state" not in failures:failures.append("pause changed VFX state")
	if stage==7 and fx.sparks.count!=0 and "reduced motion retained sparks" not in failures:failures.append("reduced motion retained sparks")
	if stage==8 and (fx.smoke.count+fx.sparks.count>0 or fx.player_marks.active_count()+fx.ai_marks.active_count()>0):
		if "garage did not clear effects" not in failures:failures.append("garage did not clear effects")
	if bench:
		if clock>3.0:frame_times.append(dt*1000.0);fx_times.append(float(fx.step_us)/1000.0)
		if clock>=15.0:finish()
	else:
		capture_clock+=dt
		if capture_clock>=0.125:
			capture_clock=0.0
			var stats:Dictionary=fx.diagnostics()
			samples.append({"time":clock,"stage":stage,"stats":stats})
			capture.call_deferred(stage)
		if clock>=11.5:
			if fx.player_marks.written<50:failures.append("insufficient drift marks")
			if fx.surface_counts.grass<1 or fx.surface_counts.sand<1:failures.append("off-road dust not exercised")
			finish()

func capture(stage:int) -> void:
	await RenderingServer.frame_post_draw
	if done:return
	var image:=get_viewport().get_texture().get_image()
	image.resize(960,540)
	image.save_jpg(output+"/check_frames/frame_%05d.jpg" % frame_index,0.9)
	frame_index+=1
	if not probe_stages.has(stage):
		probe_stages[stage]=true
		image.save_png(output+"/stage_%d.png" % stage)

func gallery(dt:float) -> void:
	var selected:=mini(2,int(clock/4.5))
	var local_time:=fmod(clock,4.5)
	if selected!=gallery_car:
		cars[0].free()
		cars[0]=Model.car(selected,selected)
		add_child(cars[0])
		states[0].type=selected;states[0].outfit=selected
		fx.bind_cars(cars,states)
		gallery_car=selected;gallery_pulse=0
		trigger("nitro_used",0)
	# Repeat the same flat road section for every car; keep the gallery out of ramps.
	pose_scene((40.0+local_time*3.8)/4.5,0,dt)
	for i in 6:
		cars[i].visible=i==0
		states[i].finished=i!=0
	states[0].boost=1.0 if local_time<2.5 else 0.0
	states[0].mini_boost=0.7 if local_time>=2.8 and local_time<4.2 else 0.0
	if local_time>=2.8 and gallery_pulse==0:trigger("small_boost",0);gallery_pulse=1
	if local_time>=3.04 and gallery_pulse==1:trigger("double_boost",0);gallery_pulse=2
	var car:=cars[0]
	camera.position=car.to_global(Vector3(2.3,2.4,6.5))
	camera.look_at(car.to_global(Vector3(0,0.6,1.1)))
	fx.update_effects({"cars":states,"paused":false,"phase":"racing","reduced_motion":false},camera,dt)
	capture_clock+=dt
	if capture_clock>0.10:
		capture_clock=0.0
		gallery_capture.call_deferred(selected,local_time)
	if clock>=13.4:finish()

func gallery_capture(car_index:int,local_time:float) -> void:
	await RenderingServer.frame_post_draw
	if done:return
	var image:=get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(output+"/gallery_frames")
	image.resize(960,540)
	image.save_jpg(output+"/gallery_frames/frame_%05d.jpg" % frame_index,0.92)
	frame_index+=1
	var kind:="nitro" if local_time<2.5 else "small"
	var key:="%d_%s" % [car_index,kind]
	if local_time>1.0 and (kind=="nitro" or local_time>3.1) and not probe_stages.has(key):
		probe_stages[key]=true
		image.save_png(output+"/car_%d_%s.png" % [car_index,kind])

func stress() -> void:
	# Ten minutes of simulation, with a frame boundary every simulated second.
	var peak_particles:=0
	for step in 18000:
		clock+=1.0/30.0
		pose_scene(clock,0,1.0/30.0)
		fx.update_effects({"cars":states,"paused":false,"phase":"racing","reduced_motion":false},camera,1.0/30.0)
		peak_particles=maxi(peak_particles,fx.smoke.count+fx.sparks.count)
		if step%30==0:await get_tree().process_frame
	if peak_particles>512:failures.append("particle budget exceeded")
	if fx.player_marks.active_count()+fx.ai_marks.active_count()>4096:failures.append("mark budget exceeded")
	if int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))!=node_count:failures.append("node count grew")
	finish()

func stats(values:Array[float]) -> Dictionary:
	if values.is_empty():return {}
	var sorted:=values.duplicate();sorted.sort()
	var total:=0.0
	for value in values:total+=value
	return {"samples":values.size(),"mean_ms":total/values.size(),"median_ms":sorted[sorted.size()/2],"p95_ms":sorted[int((sorted.size()-1)*0.95)]}

func finish() -> void:
	done=true
	var report:={"ok":failures.is_empty(),"mode":mode,"failures":failures,"duration":clock,"frames":frame_index,
		"frame_time":stats(frame_times),"vfx_cpu":stats(fx_times),"stats":fx.diagnostics(),"samples":samples,
		"node_count_start":node_count,"node_count_end":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"fixture":"Authored six-car stress poses; real surface raycasts. Bench has no frame capture; stress time is accelerated simulation."}
	var file:=FileAccess.open(output+"/"+mode+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("VFX_QA_COMPLETE ",JSON.stringify({"ok":report.ok,"failures":failures,"mode":mode,"stats":report.stats,"frame_time":report.frame_time,"vfx_cpu":report.vfx_cpu}))
	get_tree().quit(0 if report.ok else 1)

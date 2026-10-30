extends Node

var api: Node
var stage := -1
var clock := 0.0
var total := 0.0
var output := ""
var capture_clock := 0.0
var frame_index := 0
var first_spray := -1.0
var nitro_sent := false
var second_sent := false
var events: Dictionary = {}
var combos: Array[String] = []
var maximum_height := 0.0
var premature_double := false
var log_file: FileAccess
var camera_mode := false
var camera_trace: FileAccess
var vfx_record:=false
var vfx_samples:Array=[]

func _ready() -> void:
	camera_mode = "--camera-qa" in OS.get_cmdline_user_args()
	output = ProjectSettings.globalize_path("res://../evidence/"+("camera_qa" if camera_mode else "skills_qa"))
	vfx_record="--vfx-record" in OS.get_cmdline_user_args()
	if vfx_record:output=ProjectSettings.globalize_path("res://../evidence/vfx_v8/"+("before" if "--vfx-before" in OS.get_cmdline_user_args() else "after"))
	DirAccess.make_dir_recursive_absolute(output)
	log_file = FileAccess.open(output+"/events.jsonl",FileAccess.WRITE)
	if camera_mode: camera_trace = FileAccess.open(output+"/camera.jsonl",FileAccess.WRITE)
	api.event_emitted.connect(on_event)
	setup.call_deferred()

func setup() -> void:
	stage += 1
	clock = 0.0
	first_spray = -1.0
	nitro_sent = false
	second_sent = false
	for action in ["accelerate","left","right","drift"]: Input.action_release(action)
	if stage >= 4:
		finish()
		return
	api.command("restart",{"mode":"speed"})
	api.phase = "racing"
	api.external_driver = false
	api.auto_techniques = false
	var index := 21 if stage == 3 else 5
	var car = api.racers[0]
	var lane: Vector3 = api.course.tangent(index).cross(Vector3.UP)*(-3.0 if stage < 3 else 0.0)
	car.reset_to(api.course.at(index)+lane+Vector3.UP*0.07,api.course.heading(index))
	car.speed = 38.0 if stage == 3 else 30.0
	car.travel = car.forward()*car.speed
	car.nitro = 1 if stage in [1,2] else 0
	for other in api.racers.slice(1):
		other.finished = true
		other.collision_layer = 0
		other.collision_mask = 0
	api.notify_user(["技巧测试：长漂反打 → 双喷","技巧测试：CWW","技巧测试：WCW","技巧测试：空喷 → 落地喷"][stage])
	# Fixture placement and a single nitro in combo cases are explicit setup.
	log_file.store_line(JSON.stringify({"fixture":stage,"start_index":index,"speed":car.speed,"nitro":car.nitro}))
	if stage == 3: api.external_driver = true

func _physics_process(dt: float) -> void:
	if stage < 0 or stage >= 4: return
	clock += dt
	total += dt
	var car = api.racers[0]
	maximum_height = maxf(maximum_height,car.position.y)
	if stage < 3:
		Input.action_press("accelerate")
		if clock < 0.25:
			Input.action_release("drift")
			Input.action_release("right")
		elif clock < 1.25:
			Input.action_press("drift")
			Input.action_press("right",0.65)
		elif clock < 1.45:
			Input.action_release("drift")
			Input.action_release("right")
			Input.action_press("left",0.65)
		else:
			Input.action_release("left")
		if first_spray >= 0.0:
			if stage == 2 and not nitro_sent and clock-first_spray > 0.08:
				nitro_sent = true
				press(KEY_CTRL)
			if not second_sent and clock-first_spray > 0.24:
				second_sent = true
				press(KEY_J)
			if second_sent and clock-first_spray > 0.35:
				api.external_driver = true
				Input.action_release("accelerate")
	if clock > (6.5 if stage == 3 else 4.0): setup.call_deferred()

func on_event(key: String, data: Dictionary) -> void:
	if int(data.get("racer",0)) != 0: return
	events[key] = int(events.get(key,0))+1
	log_file.store_line(JSON.stringify({"time":total,"stage":stage,"event":key,"data":data}))
	var combo: String = str(data.get("combo",""))
	if not combo.is_empty() and combo not in combos: combos.append(combo)
	if key in ["mini_ready","double_ready"] and stage < 3:
		if stage == 1:
			press.call_deferred(KEY_CTRL)
		press.call_deferred(KEY_J)
	if key == "small_boost" and first_spray < 0.0:
		first_spray = clock
		# Native repeat event must NOT spend the second spray.
		var repeat := InputEventKey.new()
		repeat.keycode = KEY_J
		repeat.physical_keycode = KEY_J
		repeat.pressed = true
		repeat.echo = true
		get_tree().create_timer(0.20).timeout.connect(func(): Input.parse_input_event(repeat))
	if key == "double_boost" and clock-first_spray < 0.23:
		premature_double = true
	if stage == 3 and key in ["air_ready","landing_ready"]: press.call_deferred(KEY_J)

func press(key: int) -> void:
	print("SKILLS_KEY ",JSON.stringify({"stage":stage,"clock":clock,"key":OS.get_keycode_string(key)}))
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	get_viewport().push_input(event,true)
	var release := InputEventKey.new()
	release.keycode = key
	release.physical_keycode = key
	get_tree().create_timer(0.04).timeout.connect(func(): get_viewport().push_input(release,true))

func _process(dt: float) -> void:
	if stage < 0 or stage >= 4: return
	capture_clock += dt
	if camera_mode:
		var camera := get_viewport().get_camera_3d()
		var p: Dictionary = api.snapshot().cars[0]
		var yaw: float = camera.get_parent().chase_yaw
		camera_trace.store_line(JSON.stringify({"time":total,"dt":dt,"stage":stage,"phase":p.drift_phase,"grounded":p.grounded,"mini":p.mini_boost,"boost":p.boost,"player_yaw":p.get("visual_yaw",p.yaw),"player_position":p.get("visual_position",p.position),"camera_position":camera.global_position,"camera_yaw":yaw,"camera_rotation":camera.global_rotation,"fov":camera.fov,"speed":p.speed,"cut":camera.get_parent().cut}))
	if camera_mode or capture_clock > 0.125:
		capture_clock = 0.0
		if vfx_record:
			var fx=get_parent().get_node("RaceView").vfx
			if fx!=null:vfx_samples.append({"time":total,"stage":stage,"stats":fx.diagnostics()})
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(800,450)
	image.save_png(output+"/frame_%05d.png"%frame_index)
	frame_index += 1

func finish() -> void:
	var ok: bool = events.get("double_boost",0) >= 3 and events.get("air_boost",0) >= 1 and events.get("landing_boost",0) >= 1 and "CWW 连喷" in combos and "WCW 连喷" in combos and maximum_height > 1.0 and not premature_double
	var report := {"ok":ok,"error":"" if ok else "missing required native technique event or repeated key spent a reward","events":events,"combos":combos,"maximum_height":maximum_height,"repeat_key_ignored":not premature_double,"frames":frame_index,"duration":total,"fixture":"staged position/speed; combo cases begin with one nitro; actual native physics and keyboard events"}
	if vfx_record:report["vfx_samples"]=vfx_samples
	var file := FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	log_file.close()
	if camera_mode: camera_trace.close()
	print("SKILLS_COMPLETE ",JSON.stringify(report))
	get_tree().quit(0 if ok else 1)

extends Node

var api: Node
var clock := 0.0
var stage := 0
var frame_clock := 0.0
var frame_index := 0
var output := ""
var events: Dictionary = {}
var stage_clock := 0.0
var finished_modes: Array = []
var used_reset := false
var paused_once := false
var log_file: FileAccess
var input_counts: Dictionary = {}
var manual_finished := false
var grip_samples := 0
var grip_max_error := 0.0
var grip_max_reach_excess := 0.0
var vfx_peak_particles:=0
var vfx_peak_marks:=0
var vfx_pause_failed:=false
var vfx_last_clock:=0.0
var vfx_was_paused:=false

func _ready() -> void:
	output = ProjectSettings.globalize_path("res://../evidence/qa")
	DirAccess.make_dir_recursive_absolute(output)
	log_file = FileAccess.open(output + "/events.jsonl",FileAccess.WRITE)
	api.event_emitted.connect(func(key: String, data: Dictionary):
		events[key] = int(events.get(key,0)) + 1
		log_file.store_line(JSON.stringify({"time":clock,"event":key,"data":data}))
		if key == "nitro_ready" and int(data.get("racer",-1)) == 0: press_key.call_deferred(KEY_SPACE)
		if key == "item_picked" and int(data.get("racer",-1)) == 0: press_key.call_deferred(KEY_E))

func _process(dt: float) -> void:
	clock += dt
	stage_clock += dt
	frame_clock += dt
	if frame_clock >= 0.25:
		frame_clock = 0.0
		capture.call_deferred()
	var s: Dictionary = api.snapshot()
	var fx=get_parent().get_node("RaceView").vfx
	if fx!=null:
		if s.paused and vfx_was_paused and not is_equal_approx(fx.clock,vfx_last_clock):vfx_pause_failed=true
		vfx_last_clock=fx.clock;vfx_was_paused=s.paused
		if frame_clock==0.0:
			var data:Dictionary=fx.diagnostics()
			vfx_peak_particles=maxi(vfx_peak_particles,int(data.smoke)+int(data.sparks))
			vfx_peak_marks=maxi(vfx_peak_marks,int(data.marks))
	if s.phase in ["countdown","racing"]:
		for visual in get_parent().get_node("RaceView").cars:
			var steering = visual.get_node_or_null("SteeringController")
			if steering == null: continue
			for measurement in steering.grip_metrics().values():
				grip_samples += 1
				grip_max_error = maxf(grip_max_error,float(measurement.error))
				grip_max_reach_excess = maxf(grip_max_reach_excess,float(measurement.reach_excess))
	match stage:
		0:
			if stage_clock > 1.5:
				click_button("下一辆 ›")
				click_button("›")
				next_stage()
		1:
			if stage_clock > 1.5:
				click_button("装备当前搭配")
				click_button("竞速赛  →")
				api.external_driver = false
				next_stage()
		2, 5:
			if stage_clock > 1.0 and s.phase == "garage":
				finish(false,"garage UI click did not start race")
			if s.phase == "racing":
				if not manual_finished:
					Input.action_press("accelerate")
					if s.elapsed > 2.0:
						Input.action_press("right")
						Input.action_press("drift")
					if s.elapsed > 2.6:
						Input.action_release("accelerate")
						Input.action_release("right")
						Input.action_release("drift")
						manual_finished = true
						api.external_driver = true
						input_counts["manual_throttle_steer_drift"] = 1
				if s.elapsed > 9.0 and not used_reset:
					press_key(KEY_R)
					used_reset = true
				if s.elapsed > 13.0 and not paused_once:
					press_key(KEY_ESCAPE)
					paused_once = true
					get_tree().create_timer(1.2).timeout.connect(func(): press_key(KEY_ESCAPE))
			if s.phase == "results":
				finished_modes.append(s.mode)
				next_stage()
			elif stage_clock > 170.0:
				finish(false,"AI failed to finish within 170 seconds")
		3:
			if stage_clock > 2.5:
				click_button("返回车库")
				next_stage()
		4:
			if stage_clock > 1.5:
				click_button("道具赛  →")
				api.external_driver = true
				used_reset = false
				paused_once = false
				next_stage()
		6:
			if stage_clock > 2.5: finish(true,"")
	if int(clock) % 5 == 0 and frame_clock == 0.0:
		var info: Array = []
		for car in s.cars: info.append({"id":car.id,"passed":car.passed,"speed":car.speed,"position":str(car.position)})
		print("QA_PROGRESS ",JSON.stringify({"clock":clock,"stage":stage,"cars":info}))

func next_stage() -> void:
	stage += 1
	stage_clock = 0.0

func capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(800,450)
	image.save_png(output + "/frame_%05d.png" % frame_index)
	frame_index += 1

func finish(ok: bool, error: String) -> void:
	if grip_samples == 0 or grip_max_error > 0.012 or grip_max_reach_excess > 0.005:
		ok=false
		error="Driving hand-contact check failed"
	if vfx_pause_failed or vfx_peak_particles>512 or vfx_peak_marks>4096:
		ok=false;error="VFX pause or capacity check failed"
	var report := {"ok":ok,"error":error,"modes":finished_modes,"frames":frame_index,"events":events,"input_counts":input_counts,"duration":clock,"driver":"native input + autonomous QA; not a human playtest","grip_samples":grip_samples,"grip_max_error":grip_max_error,"grip_max_reach_excess":grip_max_reach_excess}
	report["vfx"]={"peak_particles":vfx_peak_particles,"peak_marks":vfx_peak_marks,"pause_frozen":not vfx_pause_failed}
	var f := FileAccess.open(output + "/report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	log_file.close()
	print("QA_COMPLETE ",JSON.stringify(report))
	get_tree().quit(0 if ok else 1)

func press_key(key: int) -> void:
	input_counts[OS.get_keycode_string(key)] = int(input_counts.get(OS.get_keycode_string(key),0)) + 1
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = key
	release.physical_keycode = key
	Input.parse_input_event(release)

func click_button(text: String) -> void:
	for node in get_tree().root.find_children("*","Button",true,false):
		if node.text == text and node.is_visible_in_tree():
			input_counts[text] = int(input_counts.get(text,0)) + 1
			var point: Vector2 = node.get_global_transform_with_canvas() * (node.size * 0.5)
			var motion := InputEventMouseMotion.new()
			motion.position = point
			get_viewport().push_input(motion,true)
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			get_viewport().push_input(event,true)
			var release := InputEventMouseButton.new()
			release.position = point
			release.button_index = MOUSE_BUTTON_LEFT
			get_viewport().push_input(release,true)
			return
	push_error("QA button not found: " + text)

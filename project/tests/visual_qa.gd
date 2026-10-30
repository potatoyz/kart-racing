extends Node
## Real UI input and live rendering; no player profile writes.

var api: Node
var output := ""
var frame_clock := 0.0
var frame_index := 0
var events: Array[String] = []
var fps_samples: Array[float] = []
var recording := true

func _ready() -> void:
	output = ProjectSettings.globalize_path("res://../evidence/visual_qa")
	DirAccess.make_dir_recursive_absolute(output+"/frames")
	await wait_for(1.5)
	await capture("garage_0")
	var showroom = get_parent().get_node("Hud").showroom
	drag_showroom(showroom,80.0)
	await wait_for(0.5)
	if absf(showroom.turn) < 0.1: fail("Showroom drag did not rotate the car"); return
	await capture("garage_rotated")
	drag_showroom(showroom,-80.0)
	for i in 2:
		click("下一辆 ›")
		click("›")
		await wait_for(1.2)
		await capture("garage_%d" % (i+1))
	click("装备当前搭配")
	await wait_for(0.2)
	if api.snapshot().selected_car != 2 or api.snapshot().selected_outfit != 2: fail("Equip did not apply preview"); return
	click("竞速赛  →")
	await wait_for(4.5)
	if api.snapshot().phase != "racing": fail("Start button did not start a race"); return
	var visuals = get_parent().get_node("RaceView").cars
	var racers: Array = api.snapshot().cars
	for i in racers.size():
		if visuals[i].get_child(0).get_meta("generated_asset","") != "car_%d" % int(racers[i].type):
			fail("Race model does not match equipped vehicle"); return
		if visuals[i].get_node("Driver").get_meta("generated_asset","") != "driver_%d" % int(racers[i].outfit):
			fail("Race driver does not match equipped outfit"); return
	api.external_driver = true
	await wait_for(4.0)
	await capture("race")
	key(KEY_ESCAPE)
	await wait_for(0.3)
	if not api.snapshot().paused: fail("Pause did not open"); return
	# The pause overlay must block the race HUD button behind it.
	click("Ⅱ")
	await wait_for(0.2)
	if not api.snapshot().paused: fail("Pause overlay allowed click-through"); return
	var paused_time: float = api.snapshot().elapsed
	await wait_for(0.8)
	if not is_equal_approx(paused_time,float(api.snapshot().elapsed)): fail("Pause advanced race time"); return
	await capture("pause")
	click("低动态模式：开启")
	click("游戏声音：开启")
	await wait_for(0.3)
	if api.snapshot().reduced_motion or not api.snapshot().muted: fail("Settings click failed"); return
	click("低动态模式：关闭")
	click("游戏声音：关闭")
	click("继续比赛")
	await wait_for(2.0)
	if api.snapshot().paused: fail("Resume failed"); return
	key(KEY_ESCAPE)
	await wait_for(0.2)
	click("返回车库")
	await wait_for(1.2)
	if api.snapshot().phase != "garage": fail("Return to garage failed"); return
	DisplayServer.window_set_size(Vector2i(1600,900))
	await wait_for(1.0)
	await capture("garage_1600")
	var f := FileAccess.open(output+"/report.json",FileAccess.WRITE)
	var fps_total := 0.0
	for value in fps_samples: fps_total += value
	f.store_string(JSON.stringify({"ok":true,"frames":frame_index,"actions":events,"mean_render_fps":fps_total/maxi(1,fps_samples.size()),"note":"Native input and render checks, not a manual driving assessment."},"  "))
	recording = false
	print("VISUAL_QA_COMPLETE")
	get_tree().quit()

func _process(dt: float) -> void:
	frame_clock += dt
	if frame_clock >= 0.25 and recording:
		frame_clock = 0.0
		fps_samples.append(Engine.get_frames_per_second())
		record_frame.call_deferred()

func record_frame() -> void:
	await RenderingServer.frame_post_draw
	if not recording: return
	var image := get_viewport().get_texture().get_image()
	image.resize(960,540)
	image.save_jpg(output+"/frames/frame_%05d.jpg" % frame_index,0.84)
	frame_index += 1

func wait_for(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(label_text: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+label_text+".png")
	events.append("capture:"+label_text)

func click(text: String) -> void:
	for node in get_tree().root.find_children("*","Button",true,false):
		if node.text == text and node.is_visible_in_tree():
			var point: Vector2 = node.get_global_transform_with_canvas() * (node.size*0.5)
			var motion := InputEventMouseMotion.new()
			motion.position = point
			get_viewport().push_input(motion,true)
			for pressed in [true,false]:
				var event := InputEventMouseButton.new()
				event.position = point
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				get_viewport().push_input(event,true)
			events.append("click:"+text)
			return
	fail("Button not found: "+text)

func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)

func drag_showroom(control: Control, distance: float) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size*0.5)
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	get_viewport().push_input(press,true)
	var motion := InputEventMouseMotion.new()
	motion.position = point+Vector2(distance,0)
	motion.relative = Vector2(distance,0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion,true)
	var release := InputEventMouseButton.new()
	release.position = motion.position
	release.button_index = MOUSE_BUTTON_LEFT
	get_viewport().push_input(release,true)
	events.append("drag_showroom:%s" % distance)

func fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)

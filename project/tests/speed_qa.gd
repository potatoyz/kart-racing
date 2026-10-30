extends Node3D
## Native rendered review: real race, camera, HUD and physics; explicit speed/nitro fixtures.
const Race = preload("res://mechanic/race.gd")
const View = preload("res://presentation/view.gd")
const World = preload("res://presentation/world.gd")
const Hud = preload("res://presentation/hud.gd")
var race
var view
var stage := -1
var elapsed := 0.0
var captured := false
var sent := false
var onset_captured := false
var frozen := {}
var errors: Array[String] = []
var samples: Array = []
var output := "res://../evidence/speed_v10"
var stages := ["slow", "fast", "nitro", "small", "reduced", "pause", "reset", "garage", "car_1", "car_2", "coast", "results"]
var frame_index := 0
var capture_clock := 0.0
var ready_to_run := false
var motion_tracks := {}
var motion_report := {}
var motion_shots := 0

func _ready() -> void:
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output + "/frames")
	add_child(World.new())
	race = Race.new(); race.save_enabled = false; add_child(race)
	view = View.new(); view.api = race; add_child(view)
	var hud := Hud.new(); hud.api = race; add_child(hud)
	# The standalone review uses the normal simulation's AI driver for the player.
	for action in ["accelerate", "brake", "left", "right", "drift"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	await get_tree().process_frame
	next_stage()
	ready_to_run = true

func next_stage() -> void:
	stage += 1; elapsed = 0.0; captured = false; sent = false; onset_captured = false; motion_shots = 0
	if stage >= stages.size():
		ready_to_run = false
		for kind in ["nitro", "reduced"]:
			if float(motion_report.get(kind, 0.0)) < 5.0: errors.append("wind did not sweep past the car: " + kind)
		var report := {"ok": errors.is_empty(), "failures": errors, "samples": samples, "frames": frame_index, "relative_wind_travel_m": motion_report,
			"fixture": "Real race/camera/HUD; initial car speed, route position and nitro inventory are preset; player uses the built-in AI driver."}
		var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		print("SPEED_QA_COMPLETE ", JSON.stringify(report))
		get_tree().quit(0 if errors.is_empty() else 1)
		return
	if stages[stage] == "coast": return
	if stages[stage] == "results":
		race.phase = "results"
		return
	if stages[stage] == "pause":
		race.reduced_motion = false
		race.racers[0].boost = 1.8
		return
	if stages[stage] == "reset":
		race.paused = false
		race.command("reset")
		if view.vfx.speed_fx.boost_power != 0.0 or view.vfx.speed_fx.overlay.visible or view.vfx.speed_fx.wind.count != 0: errors.append("reset retained speed effects")
		return
	if stages[stage] == "garage":
		race.command("garage")
		return
	if stage >= 8: race.selected_car = stage - 7
	race.command("restart", {"mode": "item" if stage == 9 else "speed"})
	race.phase = "racing"; race.paused = false
	race.reduced_motion = stages[stage] == "reduced"
	race.muted = true; race.external_driver = stages[stage] != "slow"; race.auto_techniques = false
	var car = race.racers[0]
	car.reset_to(race.course.at(5) + Vector3.UP * 0.07, race.course.heading(5))
	car.speed = 8.0 if stages[stage] == "slow" else 40.0
	car.travel = car.forward() * car.speed
	car.nitro = 0
	car.protection = 0.0
	for other in race.racers.slice(1):
		other.finished = true; other.collision_layer = 0; other.collision_mask = 0
	view.cut = true

func _process(dt: float) -> void:
	if not ready_to_run: return
	elapsed += dt
	var kind: String = stages[stage]
	if elapsed >= 0.30 and not sent:
		sent = true
		if kind in ["nitro", "reduced", "car_1"]:
			race.racers[0].nitro = 1
			var result: Dictionary = race.command("nitro")
			if not result.ok: errors.append("nitro command rejected: " + kind)
		if kind == "car_2":
			race.racers[0].item = "boost"
			if not race.command("item").ok: errors.append("item booster command rejected")
		if kind == "small":
			race.racers[0].mini_boost = 0.8
			view.vfx.on_event("small_boost", {"racer": 0, "seq": 900000})
		if kind == "pause":
			race.paused = true
			frozen = {"clock": view.vfx.speed_fx.flow_clock, "fov": view.camera.fov, "boost": view.vfx.speed_fx.boost_power,
				"wind_positions": view.vfx.speed_fx.wind.positions.duplicate(), "wind_ages": view.vfx.speed_fx.wind.ages.duplicate()}
	if kind == "nitro" and elapsed > 0.42 and not onset_captured:
		onset_captured = true
		capture.call_deferred("nitro_onset")
	if kind == "pause" and sent:
		if frozen.clock != view.vfx.speed_fx.flow_clock or frozen.fov != view.camera.fov or frozen.boost != view.vfx.speed_fx.boost_power or frozen.wind_positions != view.vfx.speed_fx.wind.positions or frozen.wind_ages != view.vfx.speed_fx.wind.ages:
			if "pause animated speed effects or lens" not in errors: errors.append("pause animated speed effects or lens")
	if kind in ["nitro", "reduced"]:
		var wind = view.vfx.speed_fx.wind
		for i in wind.count:
			var id: int = wind.ids[i]
			var relative: Vector3 = view.cars[0].to_local(wind.positions[i])
			if not motion_tracks.has(id): motion_tracks[id] = relative.z
			motion_report[kind] = maxf(float(motion_report.get(kind, 0.0)), relative.z - float(motion_tracks[id]))
		if kind == "nitro" and motion_shots < 3 and elapsed >= 0.72 + float(motion_shots) * 0.10:
			capture.call_deferred("motion_%d" % motion_shots)
			motion_shots += 1
	if elapsed > 1.05 and not captured:
		captured = true
		var stats: Dictionary = view.vfx.speed_fx.diagnostics()
		stats["stage"] = kind; stats["fov"] = view.camera.fov; stats["car"] = race.racers[0].car_type
		samples.append(stats)
		if kind in ["nitro", "car_1", "car_2"] and (stats.boost < 0.9 or not stats.overlay): errors.append("missing nitro response: " + kind)
		if kind in ["slow", "garage", "results"] and stats.overlay: errors.append("unexpected screen effect: " + kind)
		if kind == "fast" and (stats.boost > 0.01 or stats.speed < 0.2): errors.append("normal-speed fixture is not normal driving")
		if kind == "small" and stats.boost >= 0.6: errors.append("small boost as strong as nitro")
		if kind == "coast" and stats.boost > 0.08: errors.append("nitro did not fade out")
		if kind == "reduced" and (not stats.reduced or stats.fov_target != 65.0): errors.append("reduced motion ignored")
		capture.call_deferred(kind)
	capture_clock += dt
	if capture_clock >= 1.0 / 60.0:
		capture_clock = 0.0
		capture.call_deferred("")
	if elapsed >= 2.2: next_stage()

func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	if not ready_to_run: return
	var image := get_viewport().get_texture().get_image()
	if not name_value.is_empty(): image.save_png(output + "/" + name_value + ".png")
	else:
		image.resize(1280, 720)
		image.save_jpg(output + "/frames/frame_%05d.jpg" % frame_index, 0.90)
		frame_index += 1

func _exit_tree() -> void:
	preload("res://presentation/vfx/vehicle_jet.gd").clear_cache()
	preload("res://presentation/generated_assets.gd").clear_cache()
	preload("res://presentation/models.gd").materials.clear()

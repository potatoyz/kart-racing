extends Node3D

signal event_emitted(event_name: String, payload: Dictionary)
const Course = preload("res://mechanic/course.gd")
const Vehicle = preload("res://mechanic/vehicle.gd")
const Catalog = preload("res://mechanic/tracks/catalog.gd")
var course = Course.new()
var selected_track_id := "sunny_coast"
var courses: Dictionary = {}
var track_catalog: Array = []
var best_by_track: Dictionary = {}
# Assembly supplies this callback; rules never import a presentation module.
var track_loader: Callable
var qa_continue_after_finish := false
var reset_counts: Dictionary = {}
var qa_seed := 20261021
var racers: Array = []
var phase := "garage"
var mode := "speed"
var selected_car := 0
var selected_outfit := 0
var preview_car := 0
var preview_outfit := 0
var reduced_motion := true
var muted := false
var paused := false
var elapsed := 0.0
var countdown := 3.5
var best := {"speed": 0.0, "item": 0.0}
var boxes: Array = []
var projectiles: Array = []
var finish_order: Array[int] = []
var message := "欢迎来到晴空海岸"
var message_time := 0.0
var rng := RandomNumberGenerator.new()
var injected_input: Dictionary = {}
var external_driver := false
var auto_techniques := true
var save_enabled := true
var profile_path := "user://profile.cfg"
var event_seq := 0

func _init() -> void:
	for id in Catalog.IDS:
		var geometry = course if id == "sunny_coast" else Course.new(id)
		courses[id] = geometry
		track_catalog.append(geometry.public_info())
		best_by_track[id] = {"speed":0.0,"item":0.0}

func _ready() -> void:
	rng.seed = qa_seed
	load_profile()
	spawn_racers()

func spawn_racers() -> void:
	for car in racers: car.free()
	racers.clear()
	for i in 6:
		var car = Vehicle.new()
		car.racer_id = i
		car.car_type = selected_car if i == 0 else i % 3
		car.outfit = selected_outfit if i == 0 else (i + 1) % 3
		add_child(car)
		var side := course.tangent(0).cross(Vector3.UP)
		car.reset_to(course.at(0) - course.tangent(0) * (7.0 + (i / 2) * 5.0) + side * (-3.0 if i % 2 == 0 else 3.0) + Vector3.UP * 0.15, course.heading(0))
		racers.append(car)
	boxes.clear()
	for s in course.item_rows:
		for lane in [-course.width*0.22, 0.0, course.width*0.22]:
			boxes.append({"position": course.at_distance(s) + course.direction_at(s).cross(Vector3.UP)*lane, "cooldown":0.0})
	reset_counts.clear()
	projectiles.clear()
	finish_order.clear()

func emit_event(key: String, data: Dictionary = {}) -> void:
	event_seq += 1
	data["seq"] = event_seq
	event_emitted.emit(key, data)

func notify_user(text: String) -> void:
	message = text
	message_time = 2.5

func _physics_process(dt: float) -> void:
	if paused or phase == "garage" or (phase == "results" and not qa_continue_after_finish): return
	if phase == "countdown":
		var previous := ceili(countdown)
		countdown -= dt
		if ceili(countdown) != previous: emit_event("countdown", {"number": ceili(countdown)})
		if countdown <= 0.0:
			phase = "racing"
			emit_event("race_started")
		return
	elapsed += dt
	message_time = maxf(0.0, message_time - dt)
	for box in boxes: box.cooldown = maxf(0.0, float(box.cooldown) - dt)
	for i in racers.size():
		var car = racers[i]
		if car.finished: continue
		car.gate_stall += dt
		var near: Dictionary = course.nearest(car.position,car.passed)
		var controls: Dictionary
		if i == 0 and not external_driver:
			controls = {"throttle": Input.get_axis("brake", "accelerate"), "steer": Input.get_axis("left", "right"), "drift": Input.is_action_pressed("drift")}
		elif i == 0 and not injected_input.is_empty():
			controls = injected_input
		else:
			controls = ai_controls(car, near)
		var events: Array = car.drive(dt, float(controls.get("throttle", 0.0)), float(controls.get("steer", 0.0)), bool(controls.get("drift", false)), near.distance > course.width*0.5+0.8)
		for key in events: emit_event(key, {"racer": i, "combo":car.tricks.combo_label, "slip":car.slip_angle})
		check_gate(car)
		if mode == "item":
			pickup(car)
			if i > 0 or external_driver:
				car.ai_item_clock += dt
				if car.ai_item_clock > 1.7:
					car.ai_item_clock = 0.0
					use_item(car)
		if i > 0 or external_driver:
			if i > 0 or auto_techniques:
				var t: Dictionary = car.tricks.snapshot()
				if t.mini_window > 0.0 or (t.double_window > 0.0 and t.double_wait <= 0.0) or t.air_window > 0.0 or t.landing_window > 0.0:
					var spray: String = car.use_small_boost()
					if not spray.is_empty(): emit_event(spray,{"racer":i,"combo":car.tricks.combo_label})
			if car.nitro > 0 and absf(float(controls.steer)) < 0.4 and bool(controls.get("boost_safe",true)):
				if car.use_nitro(): emit_event("nitro_used", {"racer": i})
		car.stuck = car.stuck + dt if car.speed < 3.0 else 0.0
		if near.distance > 32.0 or car.position.y < -3.0 or ((i > 0 or external_driver) and (car.stuck > 5.0 or car.gate_stall > 15.0)): reset_car(car)
	update_projectiles(dt)

func ai_controls(car, near: Dictionary) -> Dictionary:
	if course.id == "sunny_coast": return coast_ai(car,near)
	var s: float = near.s
	var speed: float = absf(car.speed)
	var look := clampf(7.0+speed*0.28,9.0,23.0)
	var target: Vector3 = course.at_distance(s+look)
	var side: Vector3 = course.direction_at(s+look).cross(Vector3.UP)
	var lane: float = (float(car.racer_id%3)-1.0)*course.width*0.13
	target += side*lane
	var direction: Vector3 = (target-car.position).normalized()
	var angle: float = car.forward().signed_angle_to(direction,Vector3.UP)
	var velocity_error: float = car.travel.normalized().signed_angle_to(direction,Vector3.UP) if speed > 5.0 else angle
	var steer := clampf(-angle*2.9-velocity_error*0.5,-1.0,1.0)
	var desired_speed := 48.0
	var max_curvature := 0.0
	for distance_ahead in [0.0,10.0,20.0,35.0,55.0,80.0]:
		var curvature: float = absf(course.curvature_at(s+distance_ahead))
		max_curvature = maxf(max_curvature,curvature)
		var corner_speed := minf(48.0,float(car.STATS[car.car_type].steer)*0.66/maxf(curvature,0.001))
		var reachable := sqrt(corner_speed*corner_speed+2.0*20.0*maxf(0.0,distance_ahead-8.0))
		desired_speed = minf(desired_speed,reachable)
	if near.distance > course.width*0.32: desired_speed = minf(desired_speed,24.0)
	var throttle := -1.0 if speed > desired_speed+0.6 else 1.0
	return {"throttle":throttle,"steer":steer,"drift":false,"boost_safe":max_curvature < 0.009 and near.distance < course.width*0.25}

func coast_ai(car, near: Dictionary) -> Dictionary:
	var look_ahead := 3+int(car.speed/17.0)
	var target: Vector3 = course.at(int(near.index)+look_ahead)
	var side: Vector3 = course.tangent(int(near.index)+look_ahead).cross(Vector3.UP)
	target += side*(-2.8+float(car.racer_id%3)*2.8)
	var direction: Vector3 = (target-car.position).normalized()
	var angle: float = car.forward().signed_angle_to(direction,Vector3.UP)
	var velocity_error: float = car.travel.normalized().signed_angle_to(direction,Vector3.UP) if car.travel.length()>5.0 else angle
	var steer := clampf(-angle*1.6-velocity_error*0.55,-1.0,1.0)
	var drift: bool = car.drift_phase == "drift" and car.drift_duration < 0.55
	if car.drift_phase == "grip": drift = absf(angle)>0.28 and absf(angle)<0.45 and near.distance<2.0 and car.speed>26.0 and car.speed<44.0
	return {"throttle":-0.15 if absf(velocity_error)>0.5 and car.speed>32.0 else 1.0,"steer":steer,"drift":drift}

func check_gate(car) -> void:
	if car.finished: return
	var s: float = course.gate_distance(car.passed+1)
	var p: Vector3 = course.at_distance(s)
	var direction: Vector3 = course.direction_at(s)
	var before: float = (car.last_position-p).dot(direction)
	var after: float = (car.position-p).dot(direction)
	if before >= 0.0 or after < 0.0: return
	var crossing: Vector3 = car.last_position.lerp(car.position,-before/maxf(after-before,0.0001))
	var side: float = absf((crossing-p).dot(direction.cross(Vector3.UP)))
	if side >= course.wall_inner+1.35 or crossing.y <= -0.5 or crossing.y >= 8.0: return
	car.passed += 1
	car.gate_stall = 0.0
	emit_event("checkpoint",{"racer":car.racer_id,"passed":car.passed})
	if car.passed%course.gate_count == 0:
		emit_event("lap_completed",{"racer":car.racer_id})
		if car.racer_id == 0: notify_user("最后一圈！" if car.passed == course.gate_count*(course.lap_count-1) else "完成一圈")
	if car.passed >= course.gate_count*course.lap_count:
		car.finished = true
		car.finish_time = elapsed
		car.collision_layer = 0
		car.collision_mask = 0
		car.speed = 0.0
		car.travel = Vector3.ZERO
		finish_order.append(car.racer_id)
		if car.racer_id == 0:
			phase = "results"
			if float(best[mode]) == 0.0 or elapsed < float(best[mode]):
				best[mode] = elapsed
				best_by_track[selected_track_id] = best.duplicate()
				save_profile()
			emit_event("race_finished",{"rank":finish_order.size(),"time":elapsed,"track_id":selected_track_id})

func reset_car(car) -> bool:
	if car.reset_cooldown > 0.0 or car.finished: return false
	var s: float = course.safe_distance(car.passed)
	var side: Vector3 = course.direction_at(s).cross(Vector3.UP)
	car.reset_to(course.at_distance(s)+side*((float(car.racer_id%3)-1.0)*minf(3.0,course.width*0.2))+Vector3.UP*0.15,course.yaw_at(s))
	reset_counts[car.racer_id] = int(reset_counts.get(car.racer_id,0))+1
	emit_event("reset", {"racer": car.racer_id})
	if car.racer_id == 0: notify_user("已回到安全点 · 进度保持")
	return true

func pickup(car) -> void:
	if not car.item.is_empty(): return
	for box in boxes:
		if box.cooldown <= 0.0 and car.position.distance_to(box.position) < 3.2:
			car.item = ["missile", "shield", "boost"][rng.randi_range(0, 2)]
			box.cooldown = 4.0
			emit_event("item_picked", {"racer": car.racer_id, "item": car.item})
			return

func use_item(car) -> bool:
	if car.item.is_empty() or car.finished or car.stun > 0.0: return false
	var item: String = car.item
	if item == "missile":
		var target = null
		var closest := 90.0
		for other in racers:
			if other == car or other.finished: continue
			var delta: Vector3 = other.position - car.position
			if delta.length() < closest and delta.normalized().dot(car.forward()) > 0.25:
				closest = delta.length()
				target = other
		if target == null:
			if car.racer_id == 0: notify_user("前方范围内没有目标")
			return false
		projectiles.append({"position": car.position + Vector3.UP, "target": target.racer_id, "source": car.racer_id, "life": 3.0})
	elif item == "shield": car.shield = 6.0
	elif item == "boost": car.boost = 2.3
	car.item = ""
	emit_event("item_used", {"racer": car.racer_id, "item": item})
	return true

func update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var target = racers[int(shot.target)]
		shot.life -= dt
		shot.position = shot.position.move_toward(target.position + Vector3.UP, 82.0 * dt)
		if shot.position.distance_to(target.position + Vector3.UP) < 1.7:
			if target.shield > 0.0:
				target.shield = 0.0
				emit_event("shield_blocked", {"racer": target.racer_id})
			elif target.protection <= 0.0 and not target.finished:
				target.stun = 1.3
				target.cancel_techniques()
				target.speed *= 0.4
				emit_event("hit_confirmed", {"racer": target.racer_id})
			projectiles.remove_at(i)
		elif shot.life <= 0.0:
			projectiles.remove_at(i)

func progress(car) -> float:
	if car.finished: return 100000.0-finish_order.find(car.racer_id)
	var near: Dictionary = course.nearest(car.position,car.passed)
	var start: float = course.gate_distance(car.passed)
	var span: float = fposmod(course.gate_distance(car.passed+1)-start,course.length)
	var offset: float = fposmod(float(near.s)-start,course.length)
	if offset > span+15.0: offset = 0.0
	return float(car.passed)/course.gate_count*course.length+clampf(offset,0.0,span-0.001)

func select_track(track_id: String) -> bool:
	if phase != "garage" or not Catalog.contains(track_id): return false
	if track_id == selected_track_id: return true
	var next = courses[track_id]
	if track_loader.is_valid() and not bool(track_loader.call(next)):
		notify_user("赛道加载失败，请重试")
		return false
	best_by_track[selected_track_id] = best.duplicate()
	course = next
	selected_track_id = track_id
	best = best_by_track[track_id].duplicate()
	spawn_racers()
	save_profile()
	emit_event("track_changed",{"track_id":track_id})
	notify_user("已选择 · "+str(course.definition.name))
	return true

func snapshot() -> Dictionary:
	var ordered: Array = racers.duplicate()
	var ranking: Dictionary = {}
	for car in racers: ranking[car.racer_id] = progress(car)
	ordered.sort_custom(func(a, b): return ranking[a.racer_id] > ranking[b.racer_id])
	var cars: Array = []
	for car in racers:
		var visual_transform: Transform3D = car.get_global_transform_interpolated() if car.is_inside_tree() else car.transform
		cars.append({"id": car.racer_id, "position": car.position, "yaw": car.rotation.y, "speed": car.speed, "type": car.car_type, "outfit": car.outfit, "drifting": car.drifting, "boost": car.boost, "mini_boost": car.mini_boost, "charge": car.charge, "nitro": car.nitro, "shield": car.shield, "stun": car.stun, "protection": car.protection, "passed": car.passed, "item": car.item, "finished": car.finished, "finish_time": car.finish_time, "rank": ordered.find(car) + 1, "travel":car.travel,"grounded":car.grounded,"tilt":car.tilt,"drift_phase":car.drift_phase,"slip_angle":car.slip_angle,"tricks":car.tricks.snapshot()})
		cars[-1]["visual_position"] = visual_transform.origin
		cars[-1]["visual_yaw"] = atan2(visual_transform.basis.z.x,visual_transform.basis.z.z)
		cars[-1]["steer_input"] = car.steer_input
		cars[-1]["lap"] = mini(course.lap_count,int(car.passed)/course.gate_count+1)
	return {"track_catalog":track_catalog,"selected_track_id":selected_track_id,"active_track_id":course.id,"track_name":course.definition.name,"difficulty":course.definition.difficulty,"lap_count":course.lap_count,"track":course.public_info(),"best_by_track":best_by_track.duplicate(true),"phase": phase, "mode": mode, "paused": paused, "elapsed": elapsed, "countdown": countdown, "cars": cars, "boxes": boxes.duplicate(true), "projectiles": projectiles.duplicate(true), "selected_car": selected_car, "selected_outfit": selected_outfit, "preview_car": preview_car, "preview_outfit": preview_outfit, "best": best.duplicate(), "reduced_motion": reduced_motion, "muted": muted, "message": message if message_time > 0.0 else "", "car_catalog": Vehicle.STATS.duplicate(true)}

func command(action: String, data: Dictionary = {}) -> Dictionary:
	var ok := true
	match action:
		"select_track":
			ok = select_track(str(data.get("track_id","")))
		"preview_car":
			if phase != "garage": return {"ok": false}
			preview_car = clampi(int(data.get("index", 0)), 0, 2)
		"preview_outfit":
			if phase != "garage": return {"ok": false}
			preview_outfit = clampi(int(data.get("index", 0)), 0, 2)
		"equip":
			if phase != "garage": return {"ok": false}
			selected_car = preview_car
			selected_outfit = preview_outfit
			save_profile()
			emit_event("equipped")
		"start", "restart":
			if action == "start" and phase != "garage": return {"ok": false}
			if action == "restart" and phase not in ["racing","countdown","results"]: return {"ok":false}
			var requested_mode: String = str(data.get("mode", mode))
			if requested_mode not in ["speed", "item"]: return {"ok": false}
			mode = requested_mode
			spawn_racers()
			phase = "countdown"
			paused = false
			elapsed = 0.0
			countdown = 3.5
			message = ""
			message_time = 0.0
			injected_input.clear()
			emit_event("race_reset")
		"garage":
			phase = "garage"
			paused = false
			projectiles.clear()
			external_driver = false
			emit_event("garage_entered")
		"pause":
			if phase not in ["racing", "countdown"]: return {"ok": false}
			paused = bool(data.get("value", not paused))
			emit_event("pause_changed")
		"nitro", "small_boost", "item", "reset":
			if phase != "racing" or paused: return {"ok": false}
			if action == "nitro":
				ok = racers[0].use_nitro()
				if ok: emit_event("nitro_used", {"racer": 0,"combo":racers[0].tricks.combo_label})
			elif action == "small_boost":
				var key: String = racers[0].use_small_boost()
				ok = not key.is_empty()
				if ok: emit_event(key,{"racer":0,"combo":racers[0].tricks.combo_label})
			elif action == "item": ok = mode == "item" and use_item(racers[0])
			else: ok = reset_car(racers[0])
		"settings":
			reduced_motion = bool(data.get("reduced_motion", reduced_motion))
			muted = bool(data.get("muted", muted))
			save_profile()
		"apply_input":
			external_driver = true
			injected_input = data.duplicate()
		_: ok = false
	return {"ok": ok}

func save_profile() -> void:
	if not save_enabled: return
	var file := ConfigFile.new()
	file.set_value("profile", "car", selected_car)
	file.set_value("profile", "outfit", selected_outfit)
	best_by_track[selected_track_id] = best.duplicate()
	file.set_value("profile", "version", 2)
	file.set_value("profile", "selected_track_id", selected_track_id)
	file.set_value("profile", "best_by_track", best_by_track)
	# Keep the legacy key bound exclusively to the original coast.
	file.set_value("profile", "best", best_by_track["sunny_coast"])
	file.set_value("profile", "muted", muted)
	file.set_value("profile", "reduced_motion", reduced_motion)
	if file.save(profile_path) != OK: notify_user("设置已应用，但本地保存失败")

func load_profile() -> void:
	if not save_enabled: return
	var file := ConfigFile.new()
	if file.load(profile_path) != OK: return
	selected_car = clampi(int(file.get_value("profile", "car", 0)), 0, 2)
	selected_outfit = clampi(int(file.get_value("profile", "outfit", 0)), 0, 2)
	preview_car = selected_car
	preview_outfit = selected_outfit
	var saved = file.get_value("profile","best_by_track",{})
	if saved is Dictionary:
		for id in Catalog.IDS:
			if saved.has(id): best_by_track[id] = clean_record(saved[id])
		# Fill a missing coast record only. Never reapply legacy data over v2.
		if not saved.has("sunny_coast"): best_by_track["sunny_coast"] = clean_record(file.get_value("profile","best",{}))
	else: best_by_track["sunny_coast"] = clean_record(file.get_value("profile","best",{}))
	var id := str(file.get_value("profile","selected_track_id","sunny_coast"))
	selected_track_id = id if Catalog.contains(id) else "sunny_coast"
	course = courses[selected_track_id]
	best = best_by_track[selected_track_id].duplicate()
	muted = bool(file.get_value("profile", "muted", false))
	reduced_motion = bool(file.get_value("profile", "reduced_motion", true))

func clean_record(value) -> Dictionary:
	var result := {"speed":0.0,"item":0.0}
	if value is Dictionary:
		for key in result:
			var number = value.get(key,0.0)
			if (number is float or number is int) and is_finite(float(number)): result[key] = maxf(0.0,float(number))
	return result

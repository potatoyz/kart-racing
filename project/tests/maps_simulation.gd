extends SceneTree
const Race = preload("res://mechanic/race.gd")
const World = preload("res://presentation/world.gd")
var race
var world
var output := ""
var events: Dictionary = {}
func _initialize() -> void:
	run.call_deferred()
func install_world(geometry) -> bool:
	if is_instance_valid(world): world.free()
	world = World.new()
	world.course = geometry
	root.add_child(world)
	return true
func run() -> void:
	var track := "harbor_loop"
	var mode := "speed"
	var car_type := 0
	var seed_value := 20261021
	var basic := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="): track = arg.get_slice("=",1)
		if arg.begins_with("--mode="): mode = arg.get_slice("=",1)
		if arg.begins_with("--car="): car_type = int(arg.get_slice("=",1))
		if arg.begins_with("--seed="): seed_value = int(arg.get_slice("=",1))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg == "--basic": basic = true
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../evidence/maps_v11/simulation.json")
	race = Race.new()
	race.save_enabled = false
	race.qa_seed = seed_value
	race.qa_continue_after_finish = true
	root.add_child(race)
	race.track_loader = install_world
	install_world(race.course)
	race.command("select_track",{"track_id":track})
	race.command("preview_car",{"index":car_type})
	race.command("equip")
	race.command("start",{"mode":mode})
	race.external_driver = true
	race.auto_techniques = not basic
	race.event_emitted.connect(func(key:String,_data:Dictionary):events[key]=int(events.get(key,0))+1)
	var started := Time.get_ticks_msec()
	var frames := 0
	var trace: Array = []
	while race.elapsed < 270.0 and race.finish_order.size()<6:
		await physics_frame
		frames += 1
		if frames%600 == 0:
			var row: Array = []
			for car in race.racers:row.append({"id":car.racer_id,"passed":car.passed,"speed":snappedf(car.speed,0.1),"pos":[snappedf(car.position.x,0.1),snappedf(car.position.y,0.1),snappedf(car.position.z,0.1)]})
			trace.append({"time":race.elapsed,"cars":row})
	var cars: Array = []
	for car in race.racers: cars.append({"id":car.racer_id,"type":car.car_type,"finished":car.finished,"time":car.finish_time,"passed":car.passed,"resets":race.reset_counts.get(car.racer_id,0)})
	var report := {"ok":race.finish_order.size()==6,"track":track,"mode":mode,"car":car_type,"seed":seed_value,"length_m":race.course.length,"width_m":race.course.width,"elapsed":race.elapsed,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"frames":frames,"cars":cars,"events":events,"trace":trace,"driver":"unmodified vehicle motor and native physics, autonomous controls, temporary in-memory profile"}
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("MAPS_SIM_COMPLETE ",JSON.stringify({"ok":report.ok,"track":track,"elapsed":race.elapsed,"cars":cars}))
	world.free();race.free()
	preload("res://presentation/generated_assets.gd").clear_cache()
	preload("res://presentation/models.gd").materials.clear()
	quit(0 if report.ok else 1)

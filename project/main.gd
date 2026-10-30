extends Node3D

const Race = preload("res://mechanic/race.gd")
const World = preload("res://presentation/world.gd")
const View = preload("res://presentation/view.gd")
const Hud = preload("res://presentation/hud.gd")
const Audio = preload("res://presentation/audio.gd")
var race: Node3D
var world: Node3D

func _ready() -> void:
	bind("accelerate",[KEY_W,KEY_UP])
	bind("brake",[KEY_S,KEY_DOWN])
	bind("left",[KEY_A,KEY_LEFT])
	bind("right",[KEY_D,KEY_RIGHT])
	bind("drift",[KEY_SHIFT])
	bind("nitro",[KEY_SPACE,KEY_CTRL])
	bind("small_boost",[KEY_J,KEY_W])
	bind("item",[KEY_E])
	bind("reset",[KEY_R])
	bind("pause",[KEY_ESCAPE])
	race = Race.new()
	race.name = "Race"
	if "--qa" in OS.get_cmdline_user_args() or "--skills-qa" in OS.get_cmdline_user_args() or "--boundary-qa" in OS.get_cmdline_user_args() or "--camera-qa" in OS.get_cmdline_user_args() or "--visual-qa" in OS.get_cmdline_user_args() or "--maps-qa" in OS.get_cmdline_user_args(): race.save_enabled = false
	add_child(race)
	replace_world(race.course)
	race.track_loader = replace_world
	var view := View.new()
	view.name = "RaceView"
	view.api = race
	view.course = race.course
	add_child(view)
	var hud := Hud.new()
	hud.name = "Hud"
	hud.api = race
	add_child(hud)
	var audio := Audio.new()
	audio.api = race
	add_child(audio)
	if "--visual-qa" in OS.get_cmdline_user_args():
		var driver = load("res://tests/visual_qa.gd").new()
		driver.api = race
		add_child(driver)
	elif "--qa" in OS.get_cmdline_user_args():
		var driver = load("res://tests/qa_driver.gd").new()
		driver.api = race
		add_child(driver)
	elif "--skills-qa" in OS.get_cmdline_user_args() or "--camera-qa" in OS.get_cmdline_user_args():
		var driver = load("res://tests/skills_qa.gd").new()
		driver.api = race
		add_child(driver)
	elif "--boundary-qa" in OS.get_cmdline_user_args():
		var driver = load("res://tests/boundary_qa.gd").new()
		driver.api = race
		add_child(driver)

func bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action,event)

func _exit_tree() -> void:
	preload("res://presentation/vfx/vehicle_jet.gd").clear_cache()
	preload("res://presentation/generated_assets.gd").clear_cache()
	preload("res://presentation/models.gd").materials.clear()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	for action in ["nitro","small_boost","item","reset","pause"]:
		if event.is_action_pressed(action):
			var result: Dictionary = race.command(action)
			if "--skills-qa" in OS.get_cmdline_user_args():
				print("SKILLS_INPUT ",JSON.stringify({"action":action,"result":result,"tricks":race.snapshot().cars[0].tricks}))
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(race) and not ("--qa" in OS.get_cmdline_user_args() or "--skills-qa" in OS.get_cmdline_user_args() or "--boundary-qa" in OS.get_cmdline_user_args() or "--camera-qa" in OS.get_cmdline_user_args() or "--visual-qa" in OS.get_cmdline_user_args() or "--maps-qa" in OS.get_cmdline_user_args()):
		race.command("pause",{"value":true})

func replace_world(geometry) -> bool:
	if geometry == null or geometry.length <= 0.0: return false
	var next := World.new()
	next.course = geometry
	next.name = "TrackWorld"
	if is_instance_valid(world):
		remove_child(world)
		world.free()
	world = next
	add_child(world)
	var view := get_node_or_null("RaceView")
	if view != null:
		view.course = geometry
		if view.vfx != null: view.vfx.course = geometry
	return true

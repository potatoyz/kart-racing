extends Node

signal glide_step_done

const Course = preload("res://mechanic/course.gd")
var api: Node
var output := ""
var frame_index := 0
var capture_clock := 0.0
var duration := 0.0
var cases: Array = []
var failures: Array[String] = []
var running := true
var gliding := false
var glide_side := 0.0
var glide_steps: Array[float] = []
var glide_distances: Array[float] = []
var glide_trace: Array = []

func _ready() -> void:
	output = ProjectSettings.globalize_path("res://../evidence/boundary_qa")
	DirAccess.make_dir_recursive_absolute(output)
	run.call_deferred()

func run() -> void:
	api.command("start",{"mode":"speed"})
	api.phase = "racing"
	api.set_physics_process(false)
	for other in api.racers.slice(1):
		other.finished = true
		other.collision_layer = 0
		other.collision_mask = 0
	var car = api.racers[0]
	car.collision_mask = 4
	await get_tree().physics_frame
	await get_tree().physics_frame
	await overview()
	for u in [0.0,0.01,6.5,12.0,24.0,36.5,48.0,60.0,72.0,82.0,95.97,95.999]:
		for side in [-1.0,1.0]:
			for height in [0.08,2.5,8.0,12.5]:
				var tangent: Vector3 = api.course.tangent_at(u)
				var outward: Vector3 = tangent.cross(Vector3.UP)*side
				car.reset_to(api.course.sample(u)+outward*7.0+Vector3.UP*height,atan2(-tangent.x,-tangent.z))
				api.emit_event("reset",{"racer":0})
				api.notify_user("空气墙测试 · %.1f m 高度"%height)
				await get_tree().physics_frame
				var hit: KinematicCollision3D = car.move_and_collide(outward*20.0,false,0.001)
				var distance: float = api.course.nearest(car.position).distance
				var wall_name := str(hit.get_collider().name) if hit != null else ""
				var ok: bool = hit != null and wall_name.begins_with("AirWall") and distance <= 9.05 and absf(hit.get_normal().y) < 0.01
				cases.append({"u":u,"side":side,"height":height,"sweep_metres":20,"blocked":ok,"distance":distance,"collider":wall_name})
				if not ok: failures.append("failed outward sweep: "+str(cases[-1]))
				await get_tree().physics_frame
	# Pass through the finish-line wrap with no transverse cap in the lane.
	car.reset_to(api.course.sample(95.0)+Vector3.UP*0.1,api.course.heading(0))
	await get_tree().physics_frame
	var crossing: KinematicCollision3D = car.move_and_collide(api.course.sample(1.0)+Vector3.UP*0.1-car.position)
	if crossing != null: failures.append("wall blocks longitudinal finish crossing")
	var glides: Array = []
	for side in [-1.0,1.0]:
		var start := 94.0
		var tangent: Vector3 = api.course.tangent_at(start)
		car.reset_to(api.course.sample(start)+tangent.cross(Vector3.UP)*side*8.6+Vector3.UP*0.15,atan2(-tangent.x,-tangent.z))
		api.emit_event("reset",{"racer":0})
		api.notify_user("空气墙测试 · 贴边滑行穿过首尾接缝")
		await get_tree().physics_frame
		glide_steps.clear()
		glide_distances.clear()
		glide_trace.clear()
		glide_side = side
		gliding = true
		for frame in 90:
			await glide_step_done
		gliding = false
		var min_step: float = glide_steps.min()
		var max_distance: float = glide_distances.max()
		var finish_near: Dictionary = api.course.nearest(car.position)
		var advance := fposmod(float(finish_near.index)+float(finish_near.fraction)-start,96.0)
		var ok: bool = advance > 5.0 and advance < 20.0 and min_step > 0.2 and max_distance < 9.05
		glides.append({"side":side,"advance_logical_indices":advance,"minimum_step_m":min_step,"max_distance_m":max_distance,"ok":ok,"trace":glide_trace.duplicate(true)})
		if not ok: failures.append("wall glide stuck or escaped: "+str(glides[-1]))
	running = false
	var report := {"ok":failures.is_empty(),"error":"; ".join(failures),"sweeps":cases,"glides":glides,"finish_crossing_clear":crossing==null,"duration":duration,"frames":frame_index,"fixture":"Native vehicle collider swept laterally 20 metres against actual layer-4 track walls; gravity/race disabled for isolated measurements"}
	var file := FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("BOUNDARY_COMPLETE ",JSON.stringify({"ok":report.ok,"error":report.error,"sweeps":cases.size(),"glides":glides}))
	get_tree().quit(0 if failures.is_empty() else 1)

func _physics_process(_dt: float) -> void:
	if not gliding: return
	var car = api.racers[0]
	var near: Dictionary = api.course.nearest(car.position)
	var tangent: Vector3 = api.course.tangent_at(float(near.index)+float(near.fraction))
	car.rotation.y = atan2(-tangent.x,-tangent.z)
	car.speed = 45.0
	car.travel = tangent*45.0
	car.velocity = tangent*45.0+tangent.cross(Vector3.UP)*glide_side*10.0
	var before: Vector3 = car.position
	car.move_on_track()
	glide_steps.append(car.position.distance_to(before))
	glide_distances.append(float(api.course.nearest(car.position).distance))
	if glide_steps[-1] < 0.2 and glide_trace.size() < 3:
		var contacts: Array = []
		for i in car.get_slide_collision_count():
			var hit: KinematicCollision3D = car.get_slide_collision(i)
			contacts.append({"normal":str(hit.get_normal()),"remainder":str(hit.get_remainder()),"travel":str(hit.get_travel())})
		glide_trace.append({"dt":_dt,"velocity":str(car.velocity),"max_slides":car.max_slides,"wall_min_slide_angle":car.wall_min_slide_angle,"contacts":contacts})
	glide_step_done.emit()

func overview() -> void:
	var root := get_parent()
	var previous := get_viewport().get_camera_3d()
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 350.0
	camera.far = 600.0
	camera.position = Vector3(0,260,0)
	camera.look_at(Vector3.ZERO,Vector3.FORWARD)
	camera.current = true
	for node in root.get_children():
		if node is CanvasLayer: node.visible = false
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/track-overview.png")
	previous.current = true
	camera.queue_free()
	for node in root.get_children():
		if node is CanvasLayer: node.visible = true

func _process(dt: float) -> void:
	duration += dt
	capture_clock += dt
	if running and capture_clock >= 0.125:
		capture_clock = 0.0
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(800,450)
	image.save_png(output+"/frame_%05d.png"%frame_index)
	frame_index += 1

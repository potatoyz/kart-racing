extends Node3D

const Model = preload("res://presentation/models.gd")
var camera: Camera3D
var output := ""
var frame_index := 0

func _ready() -> void:
	output=ProjectSettings.globalize_path("res://../evidence/rig_v7/qa")
	DirAccess.make_dir_recursive_absolute(output+"/frames")
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("b5cbd3")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("d7e9ef")
	settings.ambient_light_energy=0.7
	var sky:=Sky.new()
	var sky_material:=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("bedde8")
	sky_material.sky_horizon_color=Color("e6ebdf")
	sky.sky_material=sky_material
	settings.sky=sky
	settings.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	env.environment=settings
	add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-30,0)
	sun.light_energy=0.8
	add_child(sun)
	var fill:=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-25,140,0)
	fill.light_energy=0.45
	add_child(fill)
	camera=Camera3D.new()
	camera.current=true
	camera.fov=35
	add_child(camera)
	var full := "--all-rigs" in OS.get_cmdline_user_args()
	var cases:Array=[]
	var failures:Array=[]
	for car_index in (3 if full else 1):
		for driver_index in (3 if full else 1):
			var car:=Model.car(car_index,driver_index)
			add_child(car)
			var control=car.get_node_or_null("SteeringController")
			if control==null:
				failures.append("missing controller %d/%d" % [car_index,driver_index]);car.free();continue
			var maximum:=0.0
			var unreachable:=0.0
			var angular_error:=0.0
			var bone_error:=0.0
			var elbow_step:=0.0
			var previous_elbows:Dictionary={}
			var samples:Array=[]
			camera.position=Vector3(1.75,1.9,-2.1)
			camera.look_at(Vector3(0,1.0,-0.05))
			await get_tree().process_frame
			for frame in 121:
				var steer:=sin(float(frame)*TAU/120.0)
				car.position=Vector3(20.0*steer,0.2*sin(frame*0.07),35.0*cos(frame*0.04))
				car.rotation=Vector3(0.03*steer,0.5*steer,0.02*sin(frame*0.06))
				camera.position=car.to_global(Vector3(1.75,1.9,-2.1))
				camera.look_at(car.to_global(Vector3(0,1.0,-0.05)))
				control.set_steering(steer)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var metrics:Dictionary=control.grip_metrics()
				if metrics.size()!=2:
					failures.append("missing arm metrics %d/%d" % [car_index,driver_index]);break
				for side in metrics:
					maximum=maxf(maximum,float(metrics[side].error))
					unreachable=maxf(unreachable,float(metrics[side].reach_excess))
					angular_error=maxf(angular_error,float(metrics[side].angular_error_degrees))
					bone_error=maxf(bone_error,float(metrics[side].bone_length_error))
					var local_elbow:Vector3=car.to_local(metrics[side].elbow)
					if previous_elbows.has(side): elbow_step=maxf(elbow_step,local_elbow.distance_to(previous_elbows[side]))
					previous_elbows[side]=local_elbow
				samples.append({"steer":steer,"metrics":metrics})
				if frame%4==0:
					get_viewport().get_texture().get_image().save_jpg(output+"/frames/frame_%05d.jpg" % frame_index,0.9)
					frame_index+=1
				if frame in [0,30,90]:
					get_viewport().get_texture().get_image().save_png(output+"/car%d_driver%d_%d.png" % [car_index,driver_index,frame])
			if maximum>0.012 or unreachable>0.005:failures.append("hand reach/contact failed %d/%d: %.5f / %.5f" % [car_index,driver_index,maximum,unreachable])
			if angular_error>0.15 or bone_error>0.0001 or elbow_step>0.06:failures.append("orientation/length/continuity failed %d/%d" % [car_index,driver_index])
			cases.append({"car":car_index,"driver":driver_index,"max_error":maximum,"reach_excess":unreachable,"max_angular_error_degrees":angular_error,"max_bone_length_error":bone_error,"max_elbow_step":elbow_step,"samples":samples})
			car.free()
	var report:={"ok":failures.is_empty(),"failures":failures,"cases":cases,"frames":frame_index}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("RIG_QA_COMPLETE ",JSON.stringify({"ok":report.ok,"failures":failures,"frames":frame_index}))
	get_tree().quit(0 if failures.is_empty() else 1)

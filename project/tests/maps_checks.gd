extends SceneTree
const Race=preload("res://mechanic/race.gd")
const World=preload("res://presentation/world.gd")
var race
var world
var output:=""
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message)
func install_world(geometry)->bool:
	if is_instance_valid(world):world.free()
	world=World.new();world.course=geometry;root.add_child(world)
	return true
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	race=Race.new();race.save_enabled=false;root.add_child(race)
	race.set_physics_process(false);race.track_loader=install_world
	install_world(race.course)
	var reports:Array=[]
	for id in ["sunny_coast","harbor_loop","ridge_hairpins"]:
		race.command("garage");race.command("select_track",{"track_id":id});race.command("start",{"mode":"speed"})
		var c=race.course
		var car=race.racers[0]
		for other in race.racers.slice(1):other.collision_layer=0;other.collision_mask=0
		car.collision_mask=4
		await physics_frame;await physics_frame
		var sweeps:Array=[]
		for i in 12:
			var s:float=(float(i)/12.0)*c.length
			for side in [-1.0,1.0]:
				for height in [.08,2.5,8.0,12.5]:
					var tangent:Vector3=c.direction_at(s)
					var outward:Vector3=tangent.cross(Vector3.UP)*side
					car.reset_to(c.at_distance(s)+outward*(c.width*.5-2.0)+Vector3.UP*height,c.yaw_at(s))
					await physics_frame
					var hit:KinematicCollision3D=car.move_and_collide(outward*20.0,false,.001)
					var distance:float=c.nearest(car.position).distance
					var ok:bool=hit!=null and str(hit.get_collider().name).begins_with("AirWall") and distance<c.wall_inner-.5
					sweeps.append({"s":s,"side":side,"height":height,"distance":distance,"ok":ok})
					check(ok,id+" boundary "+str(sweeps[-1]))
		var glides:Array=[]
		for fraction in [.99,.28]:
			for side in [-1.0,1.0]:
				var s:float=c.length*fraction
				car.reset_to(c.at_distance(s)+c.direction_at(s).cross(Vector3.UP)*side*(c.wall_inner-1.0)+Vector3.UP*.15,c.yaw_at(s))
				var min_step:=INF;var max_distance:=0.0
				for frame in 90:
					await physics_frame
					var near:Dictionary=c.nearest(car.position)
					var tangent:Vector3=c.direction_at(near.s)
					car.rotation.y=c.yaw_at(near.s);car.speed=45;car.travel=tangent*45
					car.velocity=tangent*45+tangent.cross(Vector3.UP)*side*10
					var before:Vector3=car.position
					car.move_on_track()
					min_step=minf(min_step,car.position.distance_to(before))
					max_distance=maxf(max_distance,c.nearest(car.position).distance)
				var ok:bool=min_step>.2 and max_distance<c.wall_inner-.5
				glides.append({"fraction":fraction,"side":side,"minimum_step":min_step,"maximum_offset":max_distance,"ok":ok})
				check(ok,id+" wall glide "+str(glides[-1]))
		var floor_checks:=0
		for i in 40:
			var pos:Vector3=c.at_distance(c.length*i/40.0)
			var query:=PhysicsRayQueryParameters3D.create(pos+Vector3.UP*5,pos-Vector3.UP*5,1)
			var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.position.y>=0.0,id+" missing driveable floor "+str(i))
			floor_checks+=1
		var outlines:Array=[]
		for side in [-1.0,0.0,1.0]:
			var outline:Array=[]
			for i in range(0,c.baked_count,4):
				var pos:Vector3=c.baked_points[i]+c.baked_right[i]*side*c.wall_outer
				outline.append([pos.x,pos.z])
			outlines.append(outline)
		for gate in c.gate_count:
			car.finished=false;car.passed=gate;car.reset_cooldown=0
			race.reset_car(car)
			check(car.passed==gate and c.nearest(car.position).distance<c.width*.4,id+" safe reset "+str(gate))
			for ramp in c.ramps:check(absf(wrapf(c.nearest(car.position).s-ramp,-c.length*.5,c.length*.5))>8.0,id+" reset inside ramp")
		reports.append({"id":id,"sweeps":sweeps,"glides":glides,"floor_checks":floor_checks,"outlines":outlines})
	var node_counts:Dictionary={}
	for cycle in 10:
		for id in ["sunny_coast","harbor_loop","ridge_hairpins"]:
			race.command("garage");race.command("select_track",{"track_id":id})
			await physics_frame
			var count:int=world.find_children("*","",true,false).size()
			if node_counts.has(id):check(node_counts[id]==count,"map node count grew: "+id)
			else:node_counts[id]=count
			check(race.projectiles.is_empty() and race.racers[0].passed==0,"switch resets transient race state")
	var report:Dictionary={"ok":failures.is_empty(),"failures":failures,"tracks":reports,"switch_cycles":10,"world_node_counts":node_counts,"profile":"save_disabled"}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("MAPS_CHECKS_COMPLETE ",JSON.stringify({"ok":report.ok,"failures":failures,"switch_cycles":10}))
	world.free();race.free()
	preload("res://presentation/environments/map_props.gd").cache.clear()
	preload("res://presentation/generated_assets.gd").clear_cache()
	preload("res://presentation/models.gd").materials.clear()
	quit(0 if failures.is_empty() else 1)

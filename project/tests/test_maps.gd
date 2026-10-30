extends RefCounted
const Race=preload("res://mechanic/race.gd")
const Course=preload("res://mechanic/course.gd")
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message)
func run_test()->Dictionary:
	var race=Race.new();race.save_enabled=false
	var measurements:Array=[]
	for id in Course.Catalog.IDS:
		race.command("garage")
		check(race.command("select_track",{"track_id":id}).ok,id+" selectable")
		var c=race.course
		var max_step:=0.0;var max_angle:=0.0;var max_error:=0.0;var max_curvature:=0.0
		for i in c.baked_count:
			var a:Vector3=c.baked_points[i];var b:Vector3=c.baked_points[(i+1)%c.baked_count]
			max_step=maxf(max_step,a.distance_to(b))
			max_angle=maxf(max_angle,c.baked_right[i].angle_to(c.baked_right[(i+1)%c.baked_count]))
			max_error=maxf(max_error,((a+b)*0.5).distance_to(c.sample((float(i)+0.5)/c.SUBDIVISIONS)))
		for s in range(0,int(c.length),2):max_curvature=maxf(max_curvature,absf(c.curvature_at(float(s))))
		check(max_step<=0.6,id+" sample step")
		check(rad_to_deg(max_angle)<=1.0,id+" tangent continuity "+str(rad_to_deg(max_angle)))
		check(max_error<0.01,id+" chord error")
		check(c.sample(0.0).distance_to(c.sample(float(c.point_count)))<0.0001,id+" loop position")
		check(c.tangent_at(-0.0001).dot(c.tangent_at(0.0001))>0.9999,id+" seam tangent")
		check(max_curvature*c.wall_outer<0.9,id+" offset road must not fold")
		measurements.append({"id":id,"length":c.length,"samples":c.baked_count,"max_step":max_step,"max_angle":rad_to_deg(max_angle),"max_chord_error":max_error,"min_radius":1.0/max_curvature})
		race.command("start",{"mode":"speed"});race.phase="racing"
		check(not race.command("select_track",{"track_id":"sunny_coast"}).ok,"cannot switch mid-race")
		var car=race.racers[0]
		for gate in c.gate_count*c.lap_count:
			var s:float=c.gate_distance(gate+1)
			var pos:Vector3=c.at_distance(s);var tangent:Vector3=c.direction_at(s)
			car.last_position=pos+tangent;car.position=pos-tangent
			race.check_gate(car)
			check(car.passed==gate,id+" reverse gate")
			car.last_position=pos-tangent+Vector3.UP*4;car.position=pos+tangent+Vector3.UP*4
			race.check_gate(car)
			check(car.passed==gate+1,id+" forward airborne gate")
		check(race.phase=="results" and car.finished,id+" dynamic lap count")
		race.command("restart")
		check(race.course.id==id and race.racers[0].passed==0,id+" restart retains map")
		race.command("garage")
	var old_id:String=race.selected_track_id
	check(not race.command("select_track",{"track_id":"missing"}).ok and race.selected_track_id==old_id,"invalid ID preserves map")
	race.track_loader=func(_next):return false
	check(not race.command("select_track",{"track_id":"sunny_coast"}).ok and race.selected_track_id==old_id,"load failure preserves map")
	race.free()
	print("MAP_GEOMETRY ",JSON.stringify(measurements))
	return {"ok":failures.is_empty(),"message":"; ".join(failures),"measurements":measurements}

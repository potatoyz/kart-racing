extends RefCounted

const Catalog = preload("res://mechanic/tracks/catalog.gd")
# Constants preserve the original coast's regression fixtures; runtime uses instance data.
const COUNT := 96
const WIDTH := 18.0
const GATES := 12
const RAMP_INDICES := [24,82]
const SUBDIVISIONS := 16
const BAKED_COUNT := COUNT * SUBDIVISIONS
const WALL_INNER := 9.65
const WALL_OUTER := 10.45
const WALL_BOTTOM := -3.0
const WALL_TOP := 14.0
var id := "sunny_coast"
var definition: Dictionary
var width := WIDTH
var gate_count := GATES
var lap_count := 3
var point_count := COUNT
var baked_count := BAKED_COUNT
var wall_inner := WALL_INNER
var wall_outer := WALL_OUTER
var length := 0.0
var bounds := Rect2()
var points: Array[Vector3] = []
var baked_points := PackedVector3Array()
var baked_right := PackedVector3Array()
var distances := PackedFloat32Array()
var gates := PackedFloat32Array()
var ramps := PackedFloat32Array()
var item_rows := PackedFloat32Array()
var gate_segments: Array = []
var curve: Curve3D

func _init(track_id: String = "sunny_coast") -> void:
	definition = Catalog.definition(track_id)
	id = definition.id
	width = definition.width
	gate_count = definition.gates
	lap_count = definition.laps
	wall_inner = width*0.5+0.65
	wall_outer = wall_inner+0.8
	if id != "sunny_coast":
		build_curve()
		length = curve.get_baked_length()
		point_count = ceili(length/5.0)
		baked_count = point_count*SUBDIVISIONS
	for i in point_count: points.append(sample(float(i)))
	for i in baked_count:
		var u := float(i)/SUBDIVISIONS
		baked_points.append(sample(u))
		baked_right.append(tangent_at(u).cross(Vector3.UP))
	distances.append(0.0)
	bounds = Rect2(Vector2(baked_points[0].x,baked_points[0].z),Vector2.ZERO)
	for i in baked_count:
		distances.append(distances[-1]+baked_points[i].distance_to(baked_points[(i+1)%baked_count]))
		bounds = bounds.expand(Vector2(baked_points[i].x,baked_points[i].z))
	length = distances[-1]
	for i in gate_count: gates.append(distance_at_index(float(i)*point_count/gate_count))
	for gate in gate_count:
		var candidates := PackedInt32Array()
		var start: float = gates[gate]
		var span := fposmod(gates[(gate+1)%gate_count]-start,length)
		for i in point_count:
			if fposmod(distance_at_index(float(i))-start+20.0,length) <= span+45.0: candidates.append(i)
		gate_segments.append(candidates)
	if id == "sunny_coast":
		for i in RAMP_INDICES: ramps.append(distance_at_index(float(i)))
		for i in [14,38,62,83]: item_rows.append(distance_at_index(float(i)))
	else:
		for f in definition.ramp_fractions: ramps.append(float(f)*length)
		for f in definition.box_fractions: item_rows.append(float(f)*length)

func build_curve() -> void:
	curve = Curve3D.new()
	curve.bake_interval = 0.12
	var vertices: Array = definition.vertices
	var entries: Array[Vector3] = []
	var exits: Array[Vector3] = []
	var incoming: Array[Vector3] = []
	var outgoing: Array[Vector3] = []
	var handles: Array[float] = []
	var scale_value: float = definition.scale
	for i in vertices.size():
		var v: Vector2 = vertices[i]*scale_value
		var prev: Vector2 = vertices[posmod(i-1,vertices.size())]*scale_value
		var next: Vector2 = vertices[(i+1)%vertices.size()]*scale_value
		var a := (v-prev).normalized()
		var b := (next-v).normalized()
		var angle := acos(clampf(a.dot(b),-1.0,1.0))
		var cut := minf(float(definition.radius)*tan(angle*0.5),minf(v.distance_to(prev),v.distance_to(next))*0.46)
		var radius := cut/maxf(0.001,tan(angle*0.5))
		var entry := v-a*cut
		var leaving := v+b*cut
		entries.append(Vector3(entry.x,0,entry.y))
		exits.append(Vector3(leaving.x,0,leaving.y))
		incoming.append(Vector3(a.x,0,a.y))
		outgoing.append(Vector3(b.x,0,b.y))
		handles.append(4.0/3.0*tan(angle*0.25)*radius)
	var start := (exits[-1]+entries[0])*0.5
	curve.add_point(start,-incoming[0]*start.distance_to(exits[-1])/3.0,incoming[0]*start.distance_to(entries[0])/3.0)
	for i in vertices.size():
		var previous: Vector3 = start if i == 0 else exits[i-1]
		var next: Vector3 = start if i == vertices.size()-1 else entries[i+1]
		curve.add_point(entries[i],-incoming[i]*entries[i].distance_to(previous)/3.0,incoming[i]*handles[i])
		curve.add_point(exits[i],-outgoing[i]*handles[i],outgoing[i]*exits[i].distance_to(next)/3.0)
	curve.add_point(start,curve.get_point_in(0),curve.get_point_out(0))

func sample(index: float) -> Vector3:
	if curve != null: return curve.sample_baked(fposmod(index,float(point_count))/point_count*curve.get_baked_length(),true)
	var t := TAU*fposmod(index,float(COUNT))/COUNT
	return Vector3(sin(t)*(91.0+16.0*sin(3.0*t)),0.0,-cos(t)*121.0)

func tangent_at(index: float) -> Vector3:
	if curve != null: return (sample(index+0.003)-sample(index-0.003)).normalized()
	var t := TAU*fposmod(index,float(COUNT))/COUNT
	return Vector3(cos(t)*(91.0+16.0*sin(3.0*t))+48.0*sin(t)*cos(3.0*t),0.0,121.0*sin(t)).normalized()

func at(index: int) -> Vector3:
	return points[posmod(index,point_count)]
func tangent(index: int) -> Vector3:
	return tangent_at(float(index))
func heading(index: int) -> float:
	var f := tangent(index)
	return atan2(-f.x,-f.z)
func distance_at_index(index: float) -> float:
	var u := fposmod(index,float(point_count))*SUBDIVISIONS
	var i := int(u)
	return lerpf(distances[i],distances[i+1],u-i)
func index_at_distance(s: float) -> float:
	s = fposmod(s,length)
	var lo := 0
	var hi := baked_count
	while hi-lo > 1:
		var mid := (lo+hi)/2
		if distances[mid] <= s: lo = mid
		else: hi = mid
	return (lo+(s-distances[lo])/maxf(0.00001,distances[lo+1]-distances[lo]))/SUBDIVISIONS
func at_distance(s: float) -> Vector3:
	return sample(index_at_distance(s))
func direction_at(s: float) -> Vector3:
	return tangent_at(index_at_distance(s))
func yaw_at(s: float) -> float:
	var f := direction_at(s)
	return atan2(-f.x,-f.z)
func curvature_at(s: float) -> float:
	return direction_at(s-2.0).signed_angle_to(direction_at(s+2.0),Vector3.UP)/4.0
func gate_distance(passed: int) -> float:
	return gates[posmod(passed,gate_count)]
func safe_distance(passed: int) -> float:
	var s := gate_distance(passed)+3.0
	for ramp in ramps:
		if absf(wrapf(s-ramp,-length*0.5,length*0.5)) < 18.0: s = ramp-19.0
	return s

func nearest(p: Vector3, passed_gate: int = -1) -> Dictionary:
	var flat := Vector3(p.x,0,p.z)
	var best := INF
	var coarse := 0
	var candidates = gate_segments[posmod(passed_gate,gate_count)] if passed_gate >= 0 else range(point_count)
	for i in candidates:
		var a := at(i)
		var ab := at(i+1)-a
		var f := clampf((flat-a).dot(ab)/ab.length_squared(),0.0,1.0)
		var d := flat.distance_squared_to(a+ab*f)
		if d < best:
			best = d
			coarse = i
	best = INF
	var result := {"index":0,"fraction":0.0,"distance":0.0,"point":at(0),"s":0.0}
	for j in range((coarse-1)*SUBDIVISIONS,(coarse+2)*SUBDIVISIONS):
		var i := posmod(j,baked_count)
		var a := baked_points[i]
		var ab := baked_points[(i+1)%baked_count]-a
		var f := clampf((flat-a).dot(ab)/ab.length_squared(),0.0,1.0)
		var q := a+ab*f
		var d := flat.distance_squared_to(q)
		if d < best:
			best = d
			var u := fposmod(float(i)+f,float(baked_count))/SUBDIVISIONS
			result = {"index":int(u),"fraction":fmod(u,1.0),"distance":sqrt(d),"point":q,"s":lerpf(distances[i],distances[i+1],f)}
	return result

func public_info() -> Dictionary:
	return {"id":id,"name":definition.name,"english":definition.english,"difficulty":definition.difficulty,"level":definition.level,"description":definition.description,"color":definition.color,"length":length,"width":width,"laps":lap_count,"outline":points.duplicate(),"bounds":bounds}

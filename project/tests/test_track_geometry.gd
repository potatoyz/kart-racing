extends RefCounted

const Course = preload("res://mechanic/course.gd")
const Track = preload("res://presentation/track_surface.gd")

func run_test() -> Dictionary:
	var failures: Array[String] = []
	var c = Course.new()
	if c.sample(0.0).distance_to(c.sample(96.0)) > 0.000001: failures.append("curve is not position-periodic")
	if c.tangent_at(-0.00001).dot(c.tangent_at(0.00001)) < 0.999999: failures.append("seam tangent is discontinuous")
	var max_step := 0.0
	var max_angle := 0.0
	var max_error := 0.0
	for i in Course.BAKED_COUNT:
		var a: Vector3 = c.baked_points[i]
		var b: Vector3 = c.baked_points[(i+1)%Course.BAKED_COUNT]
		max_step = maxf(max_step,a.distance_to(b))
		max_angle = maxf(max_angle,c.baked_right[i].angle_to(c.baked_right[(i+1)%Course.BAKED_COUNT]))
		max_error = maxf(max_error,((a+b)*0.5).distance_to(c.sample((float(i)+0.5)/Course.SUBDIVISIONS)))
	if max_step > 0.75: failures.append("baked strip is too coarse")
	if rad_to_deg(max_angle) > 1.5: failures.append("visible curve has excessive corner angle")
	if max_error > 0.005: failures.append("curve approximation error exceeds five millimetres")
	for i in range(0,96,3):
		var u := float(i)+0.37
		for offset in [-8.8,0.0,8.8]:
			var p: Vector3 = c.sample(u)+c.tangent_at(u).cross(Vector3.UP)*offset
			var near: Dictionary = c.nearest(p)
			if absf(float(near.distance)-absf(offset)) > 0.015: failures.append("logic/geometry nearest-point mismatch at " + str(u))
	var track = Track.new()
	track.course = c
	var profile: Array[Vector2] = [Vector2(Course.WALL_INNER,Course.WALL_BOTTOM),Vector2(Course.WALL_INNER,Course.WALL_TOP),Vector2(Course.WALL_OUTER,Course.WALL_TOP),Vector2(Course.WALL_OUTER,Course.WALL_BOTTOM)]
	var bad_edges := 0
	for side in [-1.0,1.0]:
		var mesh: ArrayMesh = track.sweep(profile,side,true)
		var triangles := mesh.get_faces()
		var vertex_ids: Dictionary = {}
		var edges: Dictionary = {}
		for index in range(0,triangles.size(),3):
			var ids: Array[int] = []
			for v in 3:
				var point := triangles[index+v]
				if not vertex_ids.has(point): vertex_ids[point] = vertex_ids.size()
				ids.append(vertex_ids[point])
			for edge in 3:
				var a := ids[edge]
				var b := ids[(edge+1)%3]
				var key := Vector2i(mini(a,b),maxi(a,b))
				edges[key] = int(edges.get(key,0))+1
		for count in edges.values():
			if int(count) != 2: bad_edges += 1
	if bad_edges != 0: failures.append("air-wall collision shell has open/non-manifold edges")
	track.free()
	var metrics := {"samples":Course.BAKED_COUNT,"max_segment_m":max_step,"max_tangent_step_degrees":rad_to_deg(max_angle),"max_curve_chord_error_m":max_error,"unpaired_edges":bad_edges}
	print("TRACK_GEOMETRY ",JSON.stringify(metrics))
	return {"ok":failures.is_empty(),"message":"; ".join(failures),"metrics":metrics}

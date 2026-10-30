extends RefCounted
const Wind = preload("res://presentation/vfx/wind_pool.gd")

func run_test() -> Dictionary:
	var errors: Array[String] = []
	var wind = Wind.new(); wind._ready()
	var travel := Vector3(0, 0, -60)
	wind.emit_wisp(Transform3D.IDENTITY, travel, 1.0, 1.0, false, true)
	var first: Vector3 = wind.positions[0]
	var basis: Basis = wind.bases[0]
	if first.z > -2.0: errors.append("wind was not born in front of the car")
	wind.advance(0.10)
	var car_origin := travel * 0.10
	var relative: Vector3 = wind.positions[0] - car_origin
	if relative.z - first.z < 5.0: errors.append("wind is pinned to car instead of passing it")
	if wind.positions[0].distance_to(first) < 0.1: errors.append("world wind has no advection")
	var position: Vector3 = wind.positions[0]
	var turned := Transform3D(Basis(Vector3.UP, PI / 2.0), car_origin)
	wind.update_wind(turned, Vector3(-60, 0, 0), 0.0, 0.0, false, 0.0, 0.0)
	if wind.positions[0] != position or wind.bases[0] != basis: errors.append("steering rotated an existing wake")
	wind.advance(1.0); wind.upload()
	if wind.count != 0 or wind.multi.visible_instance_count != 0: errors.append("expired wind retained geometry")
	for i in Wind.CAPACITY * 2: wind.emit_wisp(Transform3D.IDENTITY, travel, 1, 1, false)
	if wind.count != Wind.CAPACITY: errors.append("wind pool budget failed")
	wind.clear()
	wind.update_wind(Transform3D.IDENTITY, Vector3.ZERO, 1, 1, false, 1, 0.5)
	if wind.count != 0: errors.append("stationary vehicle emitted wind")
	var counts: Array[int] = []
	for hz in [30, 60, 120]:
		wind.clear()
		var start: int = wind.emitted
		for frame in hz:
			wind.update_wind(Transform3D.IDENTITY, travel, 1, 1, false, 0, 1.0 / float(hz))
		counts.append(wind.emitted - start)
	if absi(counts[0] - counts[2]) > 1: errors.append("emission rate depends on frame rate")
	wind.clear()
	var start: int = wind.emitted
	for frame in 60: wind.update_wind(Transform3D.IDENTITY, travel, 1, 1, true, 0, 1.0 / 60.0)
	if wind.emitted - start < 20 or wind.emitted - start >= counts[1]: errors.append("reduced mode lacks moving wind or density reduction")
	wind.free()
	return {"ok": errors.is_empty(), "message": "; ".join(errors)}

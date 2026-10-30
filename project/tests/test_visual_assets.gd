extends RefCounted

const Art = preload("res://presentation/generated_assets.gd")
const Model = preload("res://presentation/models.gd")

func run_test() -> Dictionary:
	var failures: Array[String] = []
	for asset_id in ["car_0","car_1","car_2","driver_0","driver_1","driver_2","palm","beach_hut","lighthouse","coastal_rocks","menu_coast","track_card","driver_portrait_0","driver_portrait_1","driver_portrait_2"]:
		if not Art.available(asset_id): failures.append("Missing generated resource: "+asset_id)
	for car in 3:
		for outfit in 3:
			var node := Model.car(car,outfit)
			var driver := node.get_node_or_null("Driver")
			if driver == null or driver.get_meta("generated_asset","") != "driver_%d" % outfit:
				failures.append("Driver fallback used in %d/%d" % [car,outfit])
			var wheels: Array = node.get_meta("wheels",[])
			if wheels.size()!=4: failures.append("Expected four animated wheels in car %d" % car)
			var centers: Array[Vector3] = []
			# Ground contact is measured at rest. A rotated wheel's bounding BOX
			# contains empty corners below the actual circular tire.
			node.get_node("Flame").free()
			node.get_node("Shield").free()
			var bounds := Art.mesh_bounds(node)
			if absf(bounds.position.y)>0.03 or bounds.size.y>2.5 or bounds.size.z>4.0:
				failures.append("Unreasonable composed car bounds %d/%d: %s" % [car,outfit,bounds])
			for wheel in wheels:
				centers.append(wheel.pivot.position)
				if wheel.radius < 0.25 or wheel.radius > 0.55: failures.append("Wheel scale outside car budget")
			Model.animate_car(node,{"speed":10.0,"visual_yaw":0.0},1.0/60.0)
			Model.animate_car(node,{"speed":10.0,"visual_yaw":0.015},1.0/60.0)
			for i in wheels.size():
				if is_zero_approx(wheels[i].spin.rotation.z): failures.append("Wheel did not roll")
				if not wheels[i].pivot.position.is_equal_approx(centers[i]): failures.append("Wheel pivot drifted from axle")
				if wheels[i].front and is_zero_approx(wheels[i].pivot.rotation.y): failures.append("Front wheel did not steer")
			node.free()
	return {"ok":failures.is_empty(),"message":"; ".join(failures),"combinations":9,"failures":failures}

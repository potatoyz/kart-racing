extends RefCounted
## Presentation-only catalogue. Accepted transforms are shared by every consumer.

const CATALOGUE := "res://assets/visual_v6.json"
static var entries: Dictionary = {}
static var scenes: Dictionary = {}
static var initialized := false

static func catalogue() -> Dictionary:
	if not initialized:
		initialized = true
		if FileAccess.file_exists(CATALOGUE):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
			if parsed is Dictionary: entries = parsed.get("assets", {})
		if FileAccess.file_exists("res://assets/maps_v11.json"):
			var maps = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps_v11.json"))
			if maps is Dictionary: entries.merge(maps.get("assets",{}),true)
	return entries

static func available(asset_id: String) -> bool:
	var entry: Dictionary = catalogue().get(asset_id, {})
	return entry.get("enabled", false) and ResourceLoader.exists(entry.get("path", ""))

static func instance(asset_id: String) -> Node3D:
	if not available(asset_id): return null
	var entry: Dictionary = catalogue()[asset_id]
	var path: String = entry.path
	if not scenes.has(path): scenes[path] = load(path)
	var packed := scenes[path] as PackedScene
	if packed == null: return null
	var root := Node3D.new()
	root.name = asset_id
	root.set_meta("generated_asset", asset_id)
	var orientation := Node3D.new()
	var rotation_values: Array = entry.get("rotation_degrees", [0,0,0])
	orientation.rotation_degrees = Vector3(rotation_values[0], rotation_values[1], rotation_values[2])
	root.add_child(orientation)
	var visual := packed.instantiate() as Node3D
	orientation.add_child(visual)
	var bounds := mesh_bounds(orientation)
	var axis: int = int(entry.get("size_axis", 1))
	var factor: float = float(entry.get("size", 1.0)) / maxf(bounds.size[axis], 0.001)
	orientation.scale = Vector3.ONE * factor
	orientation.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	root.set_meta("visual_size", bounds.size * factor)
	return root

static func mesh_bounds(node: Node3D, transform_value: Transform3D = Transform3D.IDENTITY) -> AABB:
	var combined := transform_value * node.transform
	var bounds := AABB()
	var has_bounds := false
	if node is MeshInstance3D and node.mesh != null:
		bounds = combined * node.get_aabb()
		has_bounds = true
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := mesh_bounds(child, combined)
			if child_bounds.size.length_squared() > 0.0:
				bounds = bounds.merge(child_bounds) if has_bounds else child_bounds
				has_bounds = true
	return bounds

static func texture(asset_id: String) -> Texture2D:
	if not available(asset_id): return null
	return load(str(catalogue()[asset_id].path)) as Texture2D

static func clear_cache() -> void:
	scenes.clear()
	entries.clear()
	initialized = false

extends Node3D
## World-space wind packets. Steering cannot drag old wind around with the car.
const CAPACITY := 80
var count := 0
var emitted := 0
var credit := 0.0
var multi: MultiMesh
var rng := RandomNumberGenerator.new()
var positions := PackedVector3Array()
var velocities := PackedVector3Array()
var bases: Array[Basis] = []
var ages := PackedFloat32Array()
var lives := PackedFloat32Array()
var seeds := PackedFloat32Array()
var lengths := PackedFloat32Array()
var widths := PackedFloat32Array()
var colors := PackedColorArray()
var ids := PackedInt32Array()

func _ready() -> void:
	rng.seed = 601028
	positions.resize(CAPACITY); velocities.resize(CAPACITY); bases.resize(CAPACITY)
	ages.resize(CAPACITY); lives.resize(CAPACITY); seeds.resize(CAPACITY)
	lengths.resize(CAPACITY); widths.resize(CAPACITY); colors.resize(CAPACITY); ids.resize(CAPACITY)
	multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true; multi.use_custom_data = true
	multi.instance_count = CAPACITY
	multi.visible_instance_count = 0
	multi.custom_aabb = AABB(Vector3(-450, -20, -450), Vector3(900, 160, 900))
	multi.mesh = ribbon_mesh()
	var material := ShaderMaterial.new()
	material.shader = preload("res://presentation/vfx/airflow.gdshader")
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi; instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

static func ribbon_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for section in 13:
		for edge in 2:
			vertices.append(Vector3(float(edge) - 0.5, 0, float(section) / 12.0))
			uv.append(Vector2(float(edge), float(section) / 12.0))
	for section in 12:
		for index in [0, 2, 1, 1, 2, 3]: indices.append(section * 2 + index)
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func emit_wisp(pose: Transform3D, travel: Vector3, power: float, boost: float, reduced: bool, near_body: bool = false) -> void:
	if count >= CAPACITY: return
	var speed := travel.length()
	if speed < 8.0: return
	var basis := Basis.looking_at(travel.normalized(), Vector3.UP)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var close := near_body or rng.randf() < 0.72
	var front := rng.randf_range(2.5, 7.5) if close else rng.randf_range(8.0, 17.0)
	var lateral := rng.randf_range(1.45, 3.0) if close else rng.randf_range(3.5, 7.0)
	var height := rng.randf_range(0.4, 1.65) if close else rng.randf_range(0.5, 3.7)
	var i := count
	positions[i] = pose.origin + basis * Vector3(side * lateral, height, -front)
	velocities[i] = travel * rng.randf_range(0.03, 0.12) + basis.x * side * rng.randf_range(0.3, 1.2)
	bases[i] = basis; ages[i] = 0.0
	lives[i] = clampf((front + rng.randf_range(6.0, 9.0)) / (speed * 0.92), 0.18, 0.8)
	seeds[i] = rng.randf()
	lengths[i] = rng.randf_range(0.65, 1.45) * (1.0 + boost * 0.9)
	widths[i] = rng.randf_range(0.022, 0.052) * (0.85 if reduced else 1.0)
	var tint := Color("c8e6ef").lerp(Color("8cdeff"), boost * 0.65)
	tint.a = power * rng.randf_range(0.45, 0.85) * (0.55 if reduced else 1.0)
	colors[i] = tint
	emitted += 1; ids[i] = emitted; count += 1

func erase(i: int) -> void:
	count -= 1
	if i == count: return
	positions[i] = positions[count]; velocities[i] = velocities[count]; bases[i] = bases[count]
	ages[i] = ages[count]; lives[i] = lives[count]; seeds[i] = seeds[count]
	lengths[i] = lengths[count]; widths[i] = widths[count]; colors[i] = colors[count]; ids[i] = ids[count]

func advance(dt: float) -> void:
	for i in range(count - 1, -1, -1):
		ages[i] += dt
		if ages[i] >= lives[i]: erase(i)
	for i in count: positions[i] += velocities[i] * dt

func update_wind(pose: Transform3D, travel: Vector3, speed_power: float, boost: float, reduced: bool, launch: float, dt: float) -> void:
	advance(dt)
	var strength := minf(1.0, speed_power * 0.85 + boost * 0.80)
	if strength > 0.04 and travel.length() > 8.0:
		credit += dt * (24.0 * speed_power + 76.0 * boost) * (0.34 if reduced else 1.0)
		var births := mini(int(credit), 12)
		credit -= float(births)
		for i in births: emit_wisp(pose, travel, strength, boost, reduced)
		if launch > 0.0:
			for i in (3 if reduced else 9): emit_wisp(pose, travel, maxf(strength, launch), boost, reduced, true)
	else: credit = 0.0
	upload()

func upload() -> void:
	for i in count:
		multi.set_instance_transform(i, Transform3D(bases[i], positions[i]))
		multi.set_instance_color(i, colors[i])
		multi.set_instance_custom_data(i, Color(ages[i] / lives[i], seeds[i], lengths[i], widths[i]))
	multi.visible_instance_count = count

func clear() -> void:
	count = 0; credit = 0.0
	if multi != null: multi.visible_instance_count = 0

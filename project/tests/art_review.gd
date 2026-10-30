extends Node3D

const Art = preload("res://presentation/generated_assets.gd")
var camera: Camera3D

func _ready() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("e1e8ed")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("e2edff")
	settings.ambient_light_energy = 0.7
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("b4d9e5")
	sky_material.sky_horizon_color = Color("f0f2dd")
	sky_material.ground_bottom_color = Color("698590")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.environment = settings
	add_child(env)
	for angle in [Vector3(-35,-25,0),Vector3(-25,140,0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = angle
		light.light_energy = 0.8
		add_child(light)
	camera = Camera3D.new()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.1
	add_child(camera)
	var ids: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset-ids="): ids = arg.trim_prefix("--asset-ids=").split(",")
	for asset_id in ids:
		await review_asset(asset_id)
	print("ART_REVIEW_COMPLETE")
	get_tree().quit()

func review_asset(asset_id: String) -> void:
	var resource: String = Art.catalogue().get(asset_id,{}).get("path","res://assets/imported/visual_v6/%s.glb" % asset_id)
	var object: Node3D
	if asset_id.begins_with("combo_"):
		var parts := asset_id.split("_")
		object = preload("res://presentation/models.gd").car(int(parts[1]),int(parts[2]))
		object.get_node("Flame").free()
		object.get_node("Shield").free()
	else:
		var scene := load(resource) as PackedScene
		if scene == null:
			push_error("Missing asset " + resource)
			return
		object = scene.instantiate() as Node3D
	add_child(object)
	var bounds := Art.mesh_bounds(object)
	var factor := 4.0 / maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	object.scale = Vector3.ONE * factor
	object.position = -bounds.get_center() * factor
	var output := ProjectSettings.globalize_path("res://../evidence/art_review/"+asset_id)
	DirAccess.make_dir_recursive_absolute(output)
	var record := FileAccess.open(output+"/bounds.json",FileAccess.WRITE)
	record.store_string(JSON.stringify({"position":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]},"  "))
	var views := {"plus_z":Vector3(0,0,10),"minus_z":Vector3(0,0,-10),"plus_x":Vector3(10,0,0),"minus_x":Vector3(-10,0,0),"top":Vector3(0,10,0.001),"perspective":Vector3(7,4,8)}
	for view in views:
		camera.position = views[view]
		camera.look_at(Vector3.ZERO)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture := get_viewport().get_texture().get_image()
		capture.save_png(output+"/"+view+".png")
	object.free()

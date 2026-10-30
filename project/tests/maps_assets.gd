extends SceneTree
const Props=preload("res://presentation/environments/map_props.gd")
var output:=""
func _initialize()->void:run.call_deferred()
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("a8bdc2")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.65
	environment.environment=settings;world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);sun.light_energy=.85;world.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.far=300;world.add_child(camera);camera.current=true
	var records:Array=[]
	for id in ["warehouse","container","crane","harbor_lamp","lookout","mountain_gate","pine_tall","pine_round","ridge_rock","cliff"]:
		var instance:=MeshInstance3D.new();instance.mesh=Props.mesh("map_"+id);world.add_child(instance)
		var bounds:AABB=instance.mesh.get_aabb()
		var center:=bounds.get_center();var extent:=maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
		camera.size=extent*1.2
		var directions:Dictionary={"front":Vector3(0,.3,-1),"back":Vector3(0,.3,1),"left":Vector3(-1,.3,0),"right":Vector3(1,.3,0),"top":Vector3.UP}
		for label in directions:
			camera.position=center+directions[label].normalized()*extent*2.0
			camera.look_at(center,Vector3.FORWARD if label=="top" else Vector3.UP)
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/"+id+"_"+label+".png")
		var triangles:=0
		for surface in instance.mesh.get_surface_count():
			var arrays:Array=instance.mesh.surface_get_arrays(surface)
			triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
		records.append({"id":id,"size":[bounds.size.x,bounds.size.y,bounds.size.z],"triangles":triangles,"surfaces":instance.mesh.get_surface_count(),"front_axis":"-z","views":directions.keys()})
		instance.free()
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify({"ok":true,"assets":records,"capture":"five native orthographic views; visual review pending"},"  "));file.close()
	print("MAPS_ASSETS_COMPLETE")
	world.free();Props.cache.clear();preload("res://presentation/generated_assets.gd").clear_cache()
	quit()

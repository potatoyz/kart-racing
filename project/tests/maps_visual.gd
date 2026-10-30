extends SceneTree
var game
var output := ""
func _initialize() -> void:
	run.call_deferred()
func wait_frames(count:int) -> void:
	for i in count:await process_frame
func capture(name:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await wait_frames(20)
	var race=game.race
	var view=game.get_node("RaceView")
	var hud=game.get_node("Hud")
	hud.picker.open()
	await wait_frames(5)
	await capture("map_select")
	hud.picker.cancel()
	for id in ["sunny_coast","harbor_loop","ridge_hairpins"]:
		race.command("garage")
		race.command("select_track",{"track_id":id})
		await wait_frames(10)
		var camera:=Camera3D.new()
		game.add_child(camera)
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		var bounds:Rect2=race.course.bounds
		var center:Vector2=bounds.get_center()
		camera.size=maxf(bounds.size.y+90.0,(bounds.size.x+90.0)/(1280.0/720.0))
		camera.far=1800.0
		camera.position=Vector3(center.x,600,center.y)
		camera.look_at(Vector3(center.x,0,center.y),Vector3.FORWARD)
		camera.current=true
		hud.visible=false;view.set_process(false)
		await wait_frames(3)
		await capture(id+"_overview")
		view.camera.current=true;camera.free();hud.visible=true;view.set_process(true)
		race.command("start",{"mode":"speed"})
		race.external_driver=true
		for frame in 480:await physics_frame
		await capture(id+"_driving")
		hud.visible=false
		await wait_frames(2)
		await capture(id+"_clean")
		hud.visible=true
		race.command("pause",{"value":true})
		await wait_frames(3)
		await capture(id+"_pause")
		race.command("garage")
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":true,"tracks":3,"capture":"native Godot viewport","runtime_errors_must_be_checked_in_log":true}))
	file.close()
	print("MAPS_VISUAL_COMPLETE")
	game.free()
	quit()

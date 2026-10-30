extends SceneTree
var output:=""
func _initialize()->void:run.call_deferred()
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	var race=game.race
	var rows:Array=[]
	for id in ["sunny_coast","harbor_loop","ridge_hairpins"]:
		for reduced in [true,false]:
			race.command("garage");race.command("select_track",{"track_id":id})
			race.command("settings",{"reduced_motion":reduced})
			race.command("start",{"mode":"item"});race.external_driver=true
			while race.elapsed<7.0:await process_frame
			# All six jets and the player's speed effects are stressed identically.
			for car in race.racers:car.boost=5.0
			var values:Array[float]=[]
			var previous:=Time.get_ticks_usec()
			for frame in 360:
				await process_frame
				var now:=Time.get_ticks_usec()
				values.append((now-previous)/1000.0)
				previous=now
			values.sort()
			rows.append({"track":id,"mode":"item","cars":6,"reduced_motion":reduced,"frames":values.size(),"median_ms":values[values.size()/2],"p95_ms":values[int(values.size()*.95)],"max_ms":values[-1]})
			print("MAPS_PERF_PROGRESS ",JSON.stringify(rows[-1]))
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":true,"cases":rows,"capture":false,"vsync":false,"fixed_fps":false,"resolution":str(root.size),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"measurement":"Wall time between rendered process frames, 7s warmup, 360 frames; all six boost fixtures; no screenshot or video capture. Targets evaluated separately."},"  "));file.close()
	print("MAPS_PERFORMANCE_COMPLETE")
	game.free();preload("res://presentation/environments/map_props.gd").cache.clear();quit()

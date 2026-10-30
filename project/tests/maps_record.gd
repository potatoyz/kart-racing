extends SceneTree
var game
var output:=""
var recording:=false
var capture_pending:=false
var frame_clock:=0.0
var frame_index:=0
var actions:Array=[]
var matches:Array=[]
var failures:Array[String]=[]
var event_counts:Dictionary={}
func _initialize()->void:run.call_deferred()
func _process(dt:float)->bool:
	if recording:
		frame_clock+=dt
		if frame_clock>=.1 and not capture_pending:
			frame_clock-=.1
			capture_frame()
	return false
func capture_frame()->void:
	capture_pending=true
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();image.resize(800,450)
	image.save_png(output+"/frames/frame_%05d.png"%frame_index)
	frame_index+=1;capture_pending=false
func wait_frames(count:int)->void:
	for i in count:await process_frame
func check(value:bool,message:String)->void:
	if not value:
		failures.append(message)
		print("MAPS_INPUT_FAILURE ",message)
		var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"ok":false,"failures":failures,"actions":actions,"frames":frame_index},"  "));file.close()
		recording=false
		quit(1)
func key(code:int,pressed:bool)->void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
	if pressed:actions.append({"key":OS.get_keycode_string(code),"frame":frame_index})
func tap(code:int)->void:
	key(code,true);key(code,false)
	await wait_frames(2)
func click(node:Button)->void:
	var point:Vector2=node.get_global_transform_with_canvas()*(node.size*.5)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point;root.push_input(event,true)
	actions.append({"click":node.text if not node.text.is_empty() else node.name,"frame":frame_index})
	await wait_frames(3)
func click_text(text:String)->void:
	for node in root.find_children("*","Button",true,false):
		if node.text==text and node.is_visible_in_tree():
			await click(node);return
	failures.append("missing visible button "+text)
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output+"/frames")
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await wait_frames(12)
	var race=game.race;var hud=game.get_node("Hud")
	race.event_emitted.connect(func(name:String,_data:Dictionary):event_counts[name]=int(event_counts.get(name,0))+1)
	recording=true
	# Actual keyboard cancellation must not apply the previewed selection.
	await click(hud.track_button);await tap(KEY_RIGHT);await tap(KEY_ESCAPE)
	check(race.selected_track_id=="sunny_coast","Esc cancels the map preview")
	for track in ["harbor_loop","ridge_hairpins"]:
		await click(hud.track_button)
		var wanted:=1 if track=="harbor_loop" else 2
		for i in 3:
			if hud.picker.preview==wanted:break
			await tap(KEY_RIGHT)
		await shot(track+"_picker")
		await tap(KEY_ENTER)
		check(race.selected_track_id==track,"keyboard confirms "+track)
		for mode in ["speed","item"]:
			await click_text("竞速赛  →" if mode=="speed" else "道具赛  →")
			check(race.phase=="countdown" and race.mode==mode,"mode button starts countdown")
			var guard:=0
			while race.phase=="countdown" and guard<360:
				await physics_frame;guard+=1
			check(race.phase=="racing","countdown completes")
			# Exercise native held throttle, drift, opposite steering and recovery.
			key(KEY_W,true)
			for frame in 90:await physics_frame
			key(KEY_D,true);key(KEY_SHIFT,true)
			for frame in 42:await physics_frame
			key(KEY_SHIFT,false);key(KEY_D,false);key(KEY_A,true)
			for frame in 15:await physics_frame
			key(KEY_A,false);key(KEY_W,false)
			await tap(KEY_J)
			var before:int=race.racers[0].passed
			await tap(KEY_R)
			check(race.racers[0].passed==before,"R preserves progress")
			race.external_driver=true
			var paused_once:=false;var nitro_once:=false;var item_once:=false
			while race.phase!="results" and race.elapsed<220:
				await physics_frame
				if race.elapsed>10 and not paused_once:
					await tap(KEY_ESCAPE)
					var frozen:float=race.elapsed
					for frame in 30:await physics_frame
					check(race.paused and is_equal_approx(race.elapsed,frozen),"Esc freezes race")
					await shot(track+"_"+mode+"_pause")
					await tap(KEY_ESCAPE);paused_once=true
				if race.elapsed>13 and not nitro_once:
					# Explicit fixture for reproducible keyboard/VFX coverage only.
					race.racers[0].nitro=maxi(1,race.racers[0].nitro)
					await tap(KEY_SPACE);nitro_once=true
				if mode=="item" and race.elapsed>20 and not item_once:
					race.racers[0].item="shield"
					await tap(KEY_E);item_once=true
			check(race.phase=="results",track+" "+mode+" completes three laps")
			await wait_frames(5)
			await shot(track+"_"+mode+"_result")
			matches.append({"track":track,"mode":mode,"phase":race.phase,"time":race.racers[0].finish_time,"passed":race.racers[0].passed,"rank":race.snapshot().cars[0].rank,"resets":race.reset_counts.duplicate(),"best":race.best.duplicate()})
			print("MAPS_RECORD_PROGRESS ",JSON.stringify(matches[-1]))
			# Native result restart, then pause/return, verifies the full UI loop.
			await click_text("再来一局")
			check(race.phase=="countdown" and race.selected_track_id==track and race.mode==mode,"restart retains track/mode")
			await tap(KEY_ESCAPE);await click_text("返回车库")
			check(race.phase=="garage","pause returns to garage")
	recording=false
	await wait_frames(3)
	var report:Dictionary={"ok":failures.is_empty(),"failures":failures,"matches":matches,"frames":frame_index,"fps":10,"events":event_counts,"actions":actions,"driver":"native mouse/key operations plus autonomous racing; not a human playtest","fixtures":"One nitro can per race; shield provided in item races for repeatable E-key coverage. No position/velocity injection; normal race rules and physics. Player profile saving disabled."}
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("MAPS_RECORD_COMPLETE ",JSON.stringify({"ok":report.ok,"frames":frame_index,"failures":failures}))
	game.free();preload("res://presentation/environments/map_props.gd").cache.clear()
	quit(0 if failures.is_empty() else 1)

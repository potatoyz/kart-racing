extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	var track:="harbor_loop"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):track=arg.trim_prefix("--track=")
	game.race.command("select_track",{"track_id":track})
	game.race.command("preview_car",{"index":2})
	game.race.command("equip")
	game.race.command("start",{"mode":"speed"})
	var driver=preload("res://tests/maps_technique_driver.gd").new()
	driver.api=game.race;game.add_child(driver)

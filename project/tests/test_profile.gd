extends RefCounted

const Race = preload("res://mechanic/race.gd")

func run_test() -> Dictionary:
	var path := "user://test_profile_%s.cfg" % Time.get_ticks_usec()
	var writer = Race.new()
	writer.profile_path = path
	writer.selected_car = 2
	writer.selected_outfit = 1
	writer.best = {"speed":67.5,"item":82.7}
	writer.muted = true
	writer.reduced_motion = false
	writer.save_profile()
	var reader = Race.new()
	reader.profile_path = path
	reader.load_profile()
	var roundtrip: bool = reader.selected_car == 2 and reader.selected_outfit == 1 and reader.best.speed == 67.5 and reader.muted and not reader.reduced_motion
	var broken := FileAccess.open(path,FileAccess.WRITE)
	broken.store_string("THIS IS NOT A VALID CONFIG [")
	broken.close()
	var fallback = Race.new()
	fallback.profile_path = path
	fallback.load_profile()
	var safe_defaults: bool = fallback.selected_car == 0 and fallback.best.speed == 0.0
	writer.free()
	reader.free()
	fallback.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return {"ok":roundtrip and safe_defaults,"roundtrip":roundtrip,"corrupt_file_defaults":safe_defaults}

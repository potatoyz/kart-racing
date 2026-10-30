extends RefCounted

func run_test() -> Dictionary:
	var bad: Array[String] = []
	for path in ["res://main.gd","res://presentation/world.gd","res://presentation/models.gd","res://presentation/hud.gd","res://presentation/view.gd","res://tests/qa_driver.gd"]:
		var script = load(path)
		if script == null or not script.can_instantiate(): bad.append(path)
	return {"ok":bad.is_empty(),"failed_sources":bad}

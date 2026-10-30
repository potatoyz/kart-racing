extends RefCounted

const Race = preload("res://mechanic/race.gd")
var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run_test() -> Dictionary:
	var race = Race.new()
	race.save_enabled = false
	race.spawn_racers()
	expect(race.command("start",{"mode":"speed"}).ok,"start speed mode")
	expect(race.phase == "countdown" and race.racers.size() == 6,"six racers at countdown")
	var player = race.racers[0]
	expect(not race.command("nitro").ok,"countdown rejects nitro")
	race.phase = "racing"
	expect(not race.command("nitro").ok,"empty nitro rejected")
	player.nitro = 1
	expect(race.command("nitro").ok and player.nitro == 0 and player.boost > 0,"nitro consumed and active")
	expect(not race.command("nitro").ok,"repeat nitro rejected")
	player.passed = 5
	player.reset_cooldown = 0.0
	player.position = Vector3(300,0,300)
	expect(race.command("reset").ok,"reset accepted")
	expect(player.passed == 5 and player.speed == 0.0 and player.boost == 0.0,"reset preserves progress and clears motion")
	expect(not race.command("reset").ok,"reset cooldown")
	race.command("pause",{"value":true})
	var time_before: float = race.elapsed
	race._physics_process(1.0)
	expect(race.elapsed == time_before and not race.command("reset").ok,"pause freezes clock and commands")
	race.command("pause",{"value":false})
	player.passed = 0
	var cp: Vector3 = race.course.at(8)
	var direction: Vector3 = race.course.tangent(8)
	player.last_position = cp + direction
	player.position = cp - direction
	race.check_gate(player)
	expect(player.passed == 0,"reverse checkpoint rejected")
	player.last_position = race.course.at(16) - race.course.tangent(16)
	player.position = race.course.at(16) + race.course.tangent(16)
	race.check_gate(player)
	expect(player.passed == 0,"skipped checkpoint rejected")
	for passed in 36:
		var index: int = ((passed + 1) * 8) % 96
		cp = race.course.at(index)
		direction = race.course.tangent(index)
		player.last_position = cp - direction
		player.position = cp + direction
		race.check_gate(player)
	expect(race.phase == "results" and player.passed == 36,"three full laps end race")
	expect(player.collision_layer == 0 and player.collision_mask == 0,"finished cars cannot block finish line")
	race.command("garage")
	race.command("preview_car",{"index":2})
	race.command("preview_outfit",{"index":1})
	expect(race.selected_car == 0 and race.selected_outfit == 0,"preview is not equipment")
	race.command("equip")
	expect(race.selected_car == 2 and race.selected_outfit == 1,"equipment applied")
	race.command("start",{"mode":"item"})
	race.phase = "racing"
	player = race.racers[0]
	expect(player.car_type == 2 and player.outfit == 1,"equipment persists into race")
	player.position = race.boxes[0].position
	race.pickup(player)
	expect(player.item != "" and race.boxes[0].cooldown > 0,"box gives item and enters cooldown")
	player.item = "shield"
	race.command("item")
	expect(player.item == "" and player.shield > 0,"shield activation consumes item")
	race.projectiles.append({"position":player.position+Vector3.UP,"target":0,"source":1,"life":1.0})
	race.update_projectiles(0.1)
	expect(player.shield == 0.0 and player.stun == 0.0,"shield blocks one hit")
	player.protection = 0.0
	race.projectiles.append({"position":player.position+Vector3.UP,"target":0,"source":1,"life":1.0})
	race.update_projectiles(0.1)
	expect(player.stun > 0.0,"unshielded missile stuns")
	race.command("restart")
	expect(race.racers[0].passed == 0 and race.racers[0].item == "" and race.projectiles.is_empty(),"restart clears match state")
	race.free()
	return {"ok":failures.is_empty(),"failures":failures,"checks":23}

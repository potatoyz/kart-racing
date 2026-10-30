extends RefCounted

const IDS := ["sunny_coast", "harbor_loop", "ridge_hairpins"]
static func contains(id: String) -> bool:
	return id in IDS
static func definition(id: String) -> Dictionary:
	match id:
		"harbor_loop":
			return {"id":id,"name":"海湾港区","english":"BAY HARBOR","difficulty":"中级","level":2,"width":15.0,"gates":16,"laps":3,"description":"港湾长弯 · 仓库 S 弯 · 漂移接喷","color":"50c6b5","radius":32.0,"scale":0.76,
				"vertices":[Vector2(190,-170),Vector2(240,-70),Vector2(175,10),Vector2(225,110),Vector2(125,185),Vector2(-20,145),Vector2(-150,190),Vector2(-215,95),Vector2(-170,10),Vector2(-215,-90),Vector2(-140,-170)],
				"ramp_fractions":[0.60],"box_fractions":[0.10,0.31,0.54,0.88]}
		"ridge_hairpins":
			return {"id":id,"name":"山岭发卡赛道","english":"SUNRIDGE PASS","difficulty":"高级","level":3,"width":12.0,"gates":20,"laps":3,"description":"双发卡弯 · 弯前制动 · 出弯控线","color":"eea278","radius":24.0,"scale":0.70,
				"vertices":[Vector2(220,-190),Vector2(250,-90),Vector2(245,170),Vector2(180,170),Vector2(175,-10),Vector2(125,-70),Vector2(70,-10),Vector2(70,140),Vector2(20,190),Vector2(-40,170),Vector2(-65,80),Vector2(-125,50),Vector2(-180,135),Vector2(-230,120),Vector2(-260,40),Vector2(-240,-100),Vector2(-180,-190)],
				"ramp_fractions":[0.90],"box_fractions":[0.10,0.37,0.58,0.94]}
	return {"id":"sunny_coast","name":"晴空海岸","english":"SUNNY COAST","difficulty":"初级","level":1,"width":18.0,"gates":12,"laps":3,"description":"海风、长弯与双跳台","color":"64c9df","vertices":[],"ramp_fractions":[],"box_fractions":[]}

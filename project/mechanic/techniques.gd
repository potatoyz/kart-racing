extends RefCounted

const MINI_WINDOW := 1.15
const DOUBLE_MIN := 0.16
const DOUBLE_MAX := 0.50
const LANDING_WINDOW := 0.55
const BUFFER := 0.12
var clock := 0.0
var mini_window := 0.0
var mini_stock := 0
var double_window := 0.0
var last_fire := -100.0
var buffer := 0.0
var grounded := true
var air_time := 0.0
var air_origin := 0.0
var air_qualified := false
var air_available := false
var air_spent := false
var air_window := 0.0
var landing_window := 0.0
var last_technique := ""
var combo_label := ""
var combo_time := 0.0
var history: Array = []

func tick(dt: float) -> Array[String]:
	clock += dt
	mini_window = maxf(0.0,mini_window-dt)
	double_window = maxf(0.0,double_window-dt)
	landing_window = maxf(0.0,landing_window-dt)
	air_window = maxf(0.0,air_window-dt)
	combo_time = maxf(0.0,combo_time-dt)
	if mini_window <= 0.0 and double_window <= 0.0: mini_stock = 0
	if air_window <= 0.0: air_available = false
	if buffer > 0.0:
		buffer = maxf(0.0,buffer-dt)
		var key := try_spray()
		if not key.is_empty():
			buffer = 0.0
			return [key]
	return []

func bank_drift(duration: float, work: float, counter: float) -> String:
	if duration < 0.38 or work < 0.055: return ""
	mini_stock = 2 if duration >= 0.7 and work >= 0.16 and counter >= 0.08 else 1
	mini_window = MINI_WINDOW
	double_window = 0.0
	return "double_ready" if mini_stock == 2 else "mini_ready"

func observe_ground(on_ground: bool, dt: float, height: float, vertical_speed: float) -> Array[String]:
	var events: Array[String] = []
	if not on_ground:
		if grounded:
			air_time = 0.0
			air_origin = height
			air_qualified = false
			air_available = false
			air_spent = false
			landing_window = 0.0
		air_time += dt
		if not air_qualified and air_time >= 0.10 and (absf(height-air_origin) > 0.3 or absf(vertical_speed) > 3.0):
			air_qualified = true
			air_available = true
			air_window = 0.95
			events.append("air_ready")
	elif not grounded:
		if air_qualified and air_time >= 0.22:
			landing_window = LANDING_WINDOW
			events.append("landing_ready")
		air_available = false
		air_window = 0.0
		air_time = 0.0
	grounded = on_ground
	return events

func press_spray() -> String:
	var key := try_spray()
	if key.is_empty(): buffer = BUFFER
	else: buffer = 0.0
	return key

func try_spray() -> String:
	if clock - last_fire < DOUBLE_MIN: return ""
	var key := ""
	if not grounded and air_available and not air_spent:
		air_available = false
		air_spent = true
		key = "air_boost"
	elif grounded and landing_window > 0.0:
		landing_window = 0.0
		key = "landing_boost"
	elif grounded and double_window > 0.0 and mini_stock == 1:
		mini_stock = 0
		double_window = 0.0
		key = "double_boost"
	elif grounded and mini_window > 0.0 and mini_stock > 0:
		mini_stock -= 1
		mini_window = 0.0
		double_window = DOUBLE_MAX if mini_stock == 1 else 0.0
		key = "small_boost"
	if not key.is_empty():
		last_fire = clock
		remember(key)
	return key

func remember(key: String) -> void:
	last_technique = key
	var names := {"small_boost":"小喷", "double_boost":"双喷", "nitro_used":"氮气大喷", "air_boost":"空中喷", "landing_boost":"落地喷"}
	combo_label = names.get(key,key)
	var previous: Dictionary = history[-1] if not history.is_empty() else {}
	if not previous.is_empty() and clock-float(previous.time) <= 1.25:
		if previous.kind == "nitro_used" and key in ["small_boost","double_boost"]: combo_label = "CW 连喷"
		if history.size() >= 2:
			var older: Dictionary = history[-2]
			if float(previous.time)-float(older.time) <= 1.25:
				if older.kind == "nitro_used" and previous.kind == "small_boost" and key == "double_boost": combo_label = "CWW 连喷"
				if older.kind == "small_boost" and previous.kind == "nitro_used" and key == "double_boost": combo_label = "WCW 连喷"
	if not previous.is_empty() and previous.kind == "air_boost" and key == "landing_boost" and clock-float(previous.time) <= 3.0:
		combo_label = "空落连喷"
	combo_time = 1.8
	history.append({"kind":key,"time":clock})
	if history.size() > 6: history.pop_front()

func clear() -> void:
	mini_window = 0.0
	mini_stock = 0
	double_window = 0.0
	landing_window = 0.0
	buffer = 0.0
	air_available = false
	air_spent = false
	air_window = 0.0
	air_time = 0.0
	air_qualified = false
	grounded = true
	last_fire = -100.0
	combo_label = ""
	combo_time = 0.0
	last_technique = ""
	history.clear()

func snapshot() -> Dictionary:
	return {"mini_window":mini_window,"mini_stock":mini_stock,"double_window":double_window,"double_wait":maxf(0.0,DOUBLE_MIN-(clock-last_fire)),"air_window":air_window if air_available else 0.0,"landing_window":landing_window,"airborne":not grounded,"air_time":air_time,"combo":combo_label if combo_time > 0.0 else "","last_technique":last_technique}

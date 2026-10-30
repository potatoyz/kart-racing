extends RefCounted
const SpeedFeel = preload("res://presentation/vfx/speed_feel.gd")

func run_test() -> Dictionary:
	var errors: Array[String] = []
	if SpeedFeel.speed_intensity(-40.0) != 0.0 or SpeedFeel.speed_intensity(10.0) != 0.0:
		errors.append("reverse/parking generated high-speed wind")
	if SpeedFeel.speed_intensity(56.0) <= SpeedFeel.speed_intensity(36.0):
		errors.append("wind did not scale with speed")
	var envelopes: Array[float] = []
	for hz in [30, 60, 120]:
		var fx = SpeedFeel.new()
		var state := {"speed": 52.0, "boost": 2.1, "mini_boost": 0.0}
		var dt := 1.0 / float(hz)
		for frame in hz:
			fx.advance(state, dt, true, false)
			fx.pending_burst = 0.0
		envelopes.append(fx.boost_power)
		if fx.fov_target() < 75.0: errors.append("nitro lacks sustained lens response")
		state.boost = 0.0
		var previous: float = fx.boost_power
		fx.advance(state, dt, true, false)
		if fx.boost_power <= 0.0 or fx.boost_power >= previous: errors.append("boost exit did not ease out")
		for frame in hz * 2: fx.advance(state, dt, true, false)
		if fx.boost_power > 0.001: errors.append("boost envelope leaked after expiry")
		state.boost = 2.1
		fx.advance(state, dt, true, true)
		if fx.fov_target() != 65.0: errors.append("reduced motion changed the lens")
		fx.advance(state, dt, false, false)
		if fx.speed_power != 0.0 or fx.boost_power != 0.0 or fx.pending_burst != 0.0:
			errors.append("finish/garage retained speed effects")
		state.speed = 0.0
		for frame in hz:
			fx.advance(state, dt, true, false)
			fx.pending_burst = 0.0
		if fx.boost_power != 0.0 or fx.burst != 0.0: errors.append("stationary nitro produced rushing wind")
		fx.free()
	if absf(envelopes[0] - envelopes[2]) > 0.00001: errors.append("boost envelope depends on frame rate")
	return {"ok": errors.is_empty(), "message": "; ".join(errors)}

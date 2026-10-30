extends RefCounted

# Follow body steering immediately, but carry drift's camera offset across
# state transitions. Only an explicit spawn/reset is allowed to cut this state.
const OFFSET_RESPONSE := 18.0
const MAX_OFFSET_RATE := 1.8
var offset := 0.0
var yaw := 0.0
var initialized := false

func step(car: Dictionary, dt: float, cut: bool, paused: bool) -> float:
	if initialized and paused and not cut: return yaw
	var body_yaw := float(car.get("visual_yaw",car.yaw))
	var motion: Vector3 = car.travel
	var airborne_for_camera: bool = not car.grounded and float(car.tricks.air_time) >= 0.08
	var drifting: bool = car.drift_phase != "grip" or airborne_for_camera
	var target_offset := 0.0
	if drifting and motion.length() > 5.0:
		var motion_yaw := atan2(-motion.x,-motion.z)
		target_offset = wrapf(motion_yaw-body_yaw,-PI,PI)*0.75
	if cut or not initialized:
		offset = target_offset
		initialized = true
	else:
		var blended := lerp_angle(offset,target_offset,1.0-exp(-OFFSET_RESPONSE*dt))
		var change := wrapf(blended-offset,-PI,PI)
		offset = wrapf(offset+clampf(change,-MAX_OFFSET_RATE*dt,MAX_OFFSET_RATE*dt),-PI,PI)
	yaw = body_yaw+offset
	return yaw

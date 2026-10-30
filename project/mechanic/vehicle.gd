extends CharacterBody3D

const Techniques = preload("res://mechanic/techniques.gd")
# Equal gameplay mass, with a little separation and no pinball bounce.
const CAR_RESTITUTION := 0.08
# Arcade tuning, not real-car tyre limits or parameters copied from another
# game. Preserve quick corrections; sustained steering has a modest speed cost.
const GRIP_HIGH_SPEED_STEER := 0.90
const GRIP_BOOST_STEER := 0.85
const GRIP_TURN_SPEED_LOSS := 0.08
const DRIFT_GRIP := 2.2
const DRIFT_TURN_GAIN := 1.15
var tricks = Techniques.new()
var racer_id := 0
var car_type := 0
var outfit := 0
var speed := 0.0
var charge := 0.0
var nitro := 0
var boost := 0.0
var shield := 0.0
var stun := 0.0
var reset_cooldown := 0.0
var drifting := false
var drift_phase := "grip"
var drift_duration := 0.0
var drift_work := 0.0
var counter_time := 0.0
var drift_sign := 0.0
var recovery_time := 0.0
var steer_input := 0.0
var yaw_rate := 0.0
var slip_angle := 0.0
var corner_load := 0.0
var tyre_response := 70.0
var mini_boost := 0.0
var spray_strength := 0.0
var vertical_speed := 0.0
var grounded := true
var ramp_lift := 0.0
var tilt := 0.0
var _previous_shift := false
var _drift_armed := false
var passed := 0
var item := ""
var finished := false
var finish_time := 0.0
var last_position := Vector3.ZERO
var travel := Vector3.ZERO
var stuck := 0.0
var gate_stall := 0.0
var ai_item_clock := 0.0
var protection := 0.0
const STATS := [
	{"name": "晴空 GT", "top": 43.0, "accel": 18.0, "steer": 1.65},
	{"name": "流星 S", "top": 48.0, "accel": 15.0, "steer": 1.42},
	{"name": "海燕 R", "top": 40.0, "accel": 21.0, "steer": 1.95}
]

func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.35
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(40.0)
	# Fine curved walls can produce several adjacent contacts in one fast step.
	# Permit shallow-angle glancing contact rather than humanoid wall blocking.
	max_slides = 16
	wall_min_slide_angle = 0.0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.65,0.9,2.9)
	collider.shape = shape
	collider.position.y = 0.45
	add_child(collider)

func forward() -> Vector3:
	return -transform.basis.z

# The same time-based motor runs in live physics and deterministic handling tests.
# Collision resolution remains native, in drive(). No presentation state here.
func integrate_motor(dt: float, throttle: float, steer: float, shift: bool, offroad: bool) -> Array[String]:
	var events: Array[String] = []
	var stats: Dictionary = STATS[car_type]
	boost = maxf(0.0,boost-dt)
	mini_boost = maxf(0.0,mini_boost-dt)
	shield = maxf(0.0,shield-dt)
	stun = maxf(0.0,stun-dt)
	protection = maxf(0.0,protection-dt)
	reset_cooldown = maxf(0.0,reset_cooldown-dt)
	if stun > 0.0:
		cancel_techniques()
	else:
		for key in tricks.tick(dt):
			apply_spray(key)
			events.append(key)
	if shift and not _previous_shift: _drift_armed = true
	if not shift: _drift_armed = false
	_previous_shift = shift
	# Arcade input must not pass through a slow steering filter. Slide belongs
	# to the drift tyre state, not to ordinary left/right input.
	steer_input = clampf(steer,-1.0,1.0)
	var requested_load := steer_input*steer_input*smoothstep(8.0,25.0,absf(speed)) if grounded else 0.0
	corner_load = lerpf(corner_load,requested_load,1.0-exp(-(3.0 if requested_load > corner_load else 10.0)*dt))
	if drift_phase == "grip" and _drift_armed and absf(steer) > 0.2 and speed > 13.0 and grounded and stun <= 0.0 and not offroad:
		drift_phase = "drift"
		drift_sign = signf(steer)
		drift_duration = 0.0
		drift_work = 0.0
		counter_time = 0.0
		recovery_time = 0.0
		_drift_armed = false
		events.append("drift_started")
	var counter := steer*drift_sign < -0.2
	if drift_phase != "grip":
		if counter: counter_time += dt
		if drift_phase == "drift" and (not shift or counter_time >= 0.12):
			drift_phase = "recover"
			recovery_time = 0.0
			events.append("drift_released")
		if drift_phase == "recover": recovery_time += dt
		if speed < 9.0 or offroad or stun > 0.0:
			drift_phase = "grip"
			drift_duration = 0.0
			drift_work = 0.0
	drifting = drift_phase != "grip"
	var bonus := maxf(18.0 if boost > 0.0 else 0.0,spray_strength if mini_boost > 0.0 else 0.0)
	# Successful chaining keeps strong acceleration without unbounded stacked speed.
	if boost > 0.0 and mini_boost > 0.0: bonus += 5.0
	var target: float = stats.top + bonus
	if offroad: target *= 0.48
	if drifting: target *= 0.96
	elif grounded: target *= 1.0-GRIP_TURN_SPEED_LOSS*corner_load
	if stun > 0.0: target = 4.0
	if throttle > 0.0 or bonus > 0.0:
		speed = move_toward(speed,target,(float(stats.accel) + (30.0 if bonus > 0.0 else 0.0) if speed < target else 22.0)*dt)
	elif throttle < 0.0:
		speed = move_toward(speed,-9.0,30.0*dt)
	else:
		speed = move_toward(speed,0.0,(3.5 if drifting else 7.0)*dt)
	var steering: float = float(stats.steer)*clampf(absf(speed)/16.0,0.0,1.0)
	var desired_yaw := -steer_input*steering*signf(speed)
	if drift_phase == "drift": desired_yaw *= DRIFT_TURN_GAIN
	elif grounded and not drifting:
		var high_speed := smoothstep(float(stats.top)*0.45,float(stats.top)*0.90,absf(speed))
		var boosted_speed := smoothstep(float(stats.top),float(stats.top)+18.0,absf(speed))
		desired_yaw *= lerpf(1.0,GRIP_HIGH_SPEED_STEER,high_speed)
		desired_yaw *= lerpf(1.0,GRIP_BOOST_STEER/GRIP_HIGH_SPEED_STEER,boosted_speed)
	if not grounded: desired_yaw *= 0.32
	if grounded and not drifting:
		yaw_rate = desired_yaw
	else:
		yaw_rate = lerpf(yaw_rate,desired_yaw,1.0-exp(-24.0*dt))
	rotation.y += yaw_rate*dt
	var grip := 70.0
	if drift_phase == "drift": grip = DRIFT_GRIP
	elif drift_phase == "recover":
		grip = lerpf(DRIFT_GRIP,6.5,smoothstep(0.0,1.1,recovery_time))
		if counter: grip += 2.0
	if not grounded: grip = 0.45
	# Losing grip is immediate. Regaining it stays continuous across the
	# recover -> grip transition, avoiding a one-frame velocity correction.
	tyre_response = minf(tyre_response,grip) if grip < tyre_response else move_toward(tyre_response,grip,24.0*dt)
	# Turn the velocity direction independently, preserving its magnitude.
	# This avoids the artificial braking caused by vector lerp through a bend.
	var motion_yaw := atan2(-travel.x,-travel.z) if travel.length() > 0.5 else rotation.y
	var wanted_yaw := rotation.y + (PI if speed < 0.0 else 0.0)
	motion_yaw = lerp_angle(motion_yaw,wanted_yaw,1.0-exp(-tyre_response*dt))
	travel = Vector3(-sin(motion_yaw),0,-cos(motion_yaw))*absf(speed)
	slip_angle = wrapf(rotation.y-motion_yaw,-PI,PI) if speed > 0.0 else 0.0
	if drifting and grounded:
		drift_duration += dt
		if absf(slip_angle) > 0.06:
			drift_work += absf(slip_angle)*dt
			if nitro < 2:
				charge += dt*45.0*clampf(absf(slip_angle)*2.7,0.0,1.35)
				if charge >= 100.0:
					charge -= 100.0
					nitro += 1
					events.append("nitro_ready")
		if drift_phase == "recover" and ((recovery_time >= 0.20 and absf(slip_angle) < 0.10) or recovery_time >= 1.15):
			var ready: String = tricks.bank_drift(drift_duration,drift_work,counter_time)
			drift_phase = "grip"
			drifting = false
			if not ready.is_empty(): events.append(ready)
	return events

func drive(dt: float, throttle: float, steer: float, shift: bool, offroad: bool) -> Array[String]:
	last_position = position
	grounded = is_on_floor()
	var events := integrate_motor(dt,throttle,steer,shift,offroad)
	if grounded:
		var normal := get_floor_normal()
		var uphill := -travel.dot(normal)/maxf(normal.y,0.2)
		ramp_lift = maxf(0.0,uphill)
		vertical_speed = uphill - 1.0 if uphill > 0.5 else -3.0
	else:
		vertical_speed -= 18.0*dt
	velocity = Vector3(travel.x,vertical_speed,travel.z)
	move_on_track()
	var now_grounded := is_on_floor()
	if grounded and not now_grounded and ramp_lift > 1.0:
		vertical_speed = minf(12.0,ramp_lift)
	elif now_grounded:
		vertical_speed = 0.0
	grounded = now_grounded
	if stun <= 0.0:
		events.append_array(tricks.observe_ground(grounded,dt,position.y,vertical_speed))
	else:
		tricks.clear()
		tricks.grounded = grounded
	tilt = lerpf(tilt,clampf(-vertical_speed/55.0,-0.22,0.25) if not grounded else 0.0,1.0-exp(-8.0*dt))
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if absf(hit.get_normal().y) < 0.5:
			var other := hit.get_collider()
			if other is CharacterBody3D and other.get_script() == get_script():
				resolve_vehicle_contact(other,hit.get_normal())
			else:
				set_contact_travel(travel.slide(hit.get_normal()))
				if absf(speed) < 9.0: cancel_techniques()
	return events

func resolve_vehicle_contact(other, normal: Vector3) -> void:
	if finished or other.finished: return
	var horizontal_normal := Vector3(normal.x,0.0,normal.z).normalized()
	# CharacterBody's slide solver treats the other car as an immovable wall.
	# Use the cars' intended motion, not its already-clipped output velocity.
	var closing_speed: float = (travel-other.travel).dot(horizontal_normal)
	if closing_speed >= 0.0: return
	var impulse := horizontal_normal*(-closing_speed*(1.0+CAR_RESTITUTION)*0.5)
	set_contact_travel(travel+impulse)
	other.set_contact_travel(other.travel-impulse)
	# Both cars are updated immediately. Repeated contacts see separating
	# velocities, so they cannot apply the same impact or drain speed again.

func set_contact_travel(motion: Vector3) -> void:
	travel = motion
	speed = travel.length()*(-1.0 if travel.dot(forward()) < -0.001 else 1.0)
	velocity.x = travel.x
	velocity.z = travel.z

func move_on_track() -> void:
	var requested := velocity
	move_and_slide()
	# Godot's grounded solver can treat two almost parallel curved-wall
	# contacts as a corner and zero the remaining tangent motion. Finish that
	# remainder with native sweeps, only for the SAME continuous air-wall shell.
	# Sharp corners, cars, ramps and other colliders retain ordinary response.
	if velocity.length_squared() > 0.000001 or requested.length_squared() < 1.0: return
	var walls: Array[KinematicCollision3D] = []
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		if is_air_wall(contact): walls.append(contact)
	if walls.size() < 2: return
	var last: KinematicCollision3D = walls[-1]
	var previous: KinematicCollision3D = walls[-2]
	if previous.get_collider() != last.get_collider() or previous.get_normal().dot(last.get_normal()) < 0.98: return
	var wall := last.get_collider()
	var normal := last.get_normal()
	var remaining := last.get_remainder()
	remaining.y = 0.0
	var horizontal := Vector3(requested.x,0,requested.z)
	for iteration in 16:
		remaining = remaining.slide(normal)
		if remaining.length_squared() < 0.000001 or remaining.dot(horizontal) <= 0.0: break
		var hit := move_and_collide(remaining,false,safe_margin)
		if hit == null:
			var along := horizontal.slide(normal)
			velocity = Vector3(along.x,velocity.y,along.z)
			break
		if not is_air_wall(hit) or hit.get_collider() != wall or normal.dot(hit.get_normal()) < 0.98: break
		normal = hit.get_normal()
		remaining = hit.get_remainder()
		remaining.y = 0.0

func is_air_wall(hit: KinematicCollision3D) -> bool:
	var collider := hit.get_collider() as PhysicsBody3D
	return collider != null and (collider.collision_layer & 4) != 0 and absf(hit.get_normal().y) < 0.01

func use_small_boost() -> String:
	if stun > 0.0 or finished: return ""
	var key: String = tricks.press_spray()
	if not key.is_empty(): apply_spray(key)
	return key

func apply_spray(key: String) -> void:
	var spec: Vector2 = {"small_boost":Vector2(0.65,12.0),"double_boost":Vector2(0.80,14.0),"air_boost":Vector2(0.70,11.0),"landing_boost":Vector2(0.85,15.0)}.get(key,Vector2.ZERO)
	mini_boost = maxf(mini_boost,spec.x)
	spray_strength = spec.y

func use_nitro() -> bool:
	if nitro <= 0 or boost > 0.0 or stun > 0.0 or finished: return false
	nitro -= 1
	boost = 2.1
	tricks.remember("nitro_used")
	return true

func cancel_techniques() -> void:
	drift_phase = "grip"
	drifting = false
	drift_duration = 0.0
	drift_work = 0.0
	counter_time = 0.0
	boost = 0.0
	mini_boost = 0.0
	tricks.clear()

func reset_to(p: Vector3, yaw: float) -> void:
	position = p
	rotation.y = yaw
	if is_inside_tree(): reset_physics_interpolation()
	last_position = p
	velocity = Vector3.ZERO
	travel = Vector3.ZERO
	speed = 0.0
	stun = 0.0
	cancel_techniques()
	steer_input = 0.0
	yaw_rate = 0.0
	slip_angle = 0.0
	corner_load = 0.0
	tyre_response = 70.0
	vertical_speed = 0.0
	ramp_lift = 0.0
	tilt = 0.0
	grounded = true
	_previous_shift = false
	_drift_armed = false
	protection = 1.5
	reset_cooldown = 2.0
	stuck = 0.0
	gate_stall = 0.0

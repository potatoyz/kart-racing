extends Node3D
## Player-only wind, boost envelope and two reusable world-space pressure waves.
## Uses the simulation clock so pause also freezes every shader animation.
const WindPool = preload("res://presentation/vfx/wind_pool.gd")

var speed_power := 0.0
var boost_power := 0.0
var burst := 0.0
var flow_clock := 0.0
var fx_clock := 0.0
var reduced := false
var previous_boost := false
var pending_burst := 0.0
var burst_count := 0
var overlay: ColorRect
var screen_material: ShaderMaterial
var wind
var waves: Array[MeshInstance3D] = []
var wave_ages := [1.0, 1.0]
var wave_cursor := 0

static func speed_intensity(speed: float) -> float:
	return smoothstep(20.0, 56.0, maxf(0.0, speed))

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_material = ShaderMaterial.new()
	screen_material.shader = preload("res://presentation/vfx/speed_screen.gdshader")
	overlay.material = screen_material
	layer.add_child(overlay)
	wind = WindPool.new()
	wind.name = "WorldWind"
	add_child(wind)
	for i in 2:
		var wave := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		wave.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = preload("res://presentation/vfx/air_burst.gdshader")
		wave.material_override = material
		wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wave)
		waves.append(wave)
	clear()

func trigger(kind: String) -> void:
	pending_burst = maxf(pending_burst, 1.0 if kind == "nitro_used" else 0.48)

func advance(state: Dictionary, dt: float, active: bool, low_motion: bool) -> void:
	reduced = low_motion
	if not active:
		clear()
		return
	var moving := smoothstep(2.0, 18.0, float(state.speed))
	var big: bool = float(state.boost) > 0.0
	# Also covers item boosters, which do not emit nitro_used.
	if big and not previous_boost and pending_burst == 0.0: trigger("nitro_used")
	previous_boost = big
	var target := (1.0 if big else 0.34 if float(state.mini_boost) > 0.0 else 0.0) * moving
	speed_power = lerpf(speed_power, speed_intensity(float(state.speed)), 1.0 - exp(-7.0 * dt))
	boost_power = lerpf(boost_power, target, 1.0 - exp(-(11.0 if target > boost_power else 5.0) * dt))
	burst = maxf(0.0, burst - dt * 3.2)
	if pending_burst > 0.0:
		burst = maxf(burst, pending_burst * moving)
	fx_clock += dt
	flow_clock += dt * (0.35 + speed_power * 1.15 + boost_power * 0.85) * (0.45 if reduced else 1.0)
	if reduced:
		for i in waves.size(): waves[i].visible = false; wave_ages[i] = 1.0

func update_effects(snapshot: Dictionary, camera: Camera3D, car: Node3D, dt: float) -> void:
	if snapshot.paused: return
	var state: Dictionary = snapshot.cars[0]
	var active: bool = snapshot.phase == "racing" and not state.finished
	advance(state, dt, active, snapshot.reduced_motion)
	if not active: return
	if pending_burst > 0.0 and not reduced and burst > 0.05:
		var wave := waves[wave_cursor]
		wave.global_transform = car.global_transform
		wave.global_position = car.to_global(Vector3(0, 0.80, 0.1))
		wave.set_meta("origin", wave.global_transform)
		# Advect the pressure front with the launch velocity; a stationary ring
		# would pass below the chase camera almost immediately at 200 km/h.
		wave.set_meta("velocity", state.travel * 0.82)
		wave_ages[wave_cursor] = 0.0
		wave.material_override.set_shader_parameter("strength", pending_burst)
		wave_cursor = (wave_cursor + 1) % waves.size()
		burst_count += 1
	wind.update_wind(car.global_transform, state.travel, speed_power, boost_power, reduced, pending_burst, dt)
	pending_burst = 0.0
	for i in waves.size():
		wave_ages[i] = minf(1.0, float(wave_ages[i]) + dt / 0.48)
		waves[i].visible = wave_ages[i] < 1.0 and not reduced
		if not waves[i].visible: continue
		var origin: Transform3D = waves[i].get_meta("origin")
		origin.origin += Vector3(waves[i].get_meta("velocity")) * float(wave_ages[i]) * 0.48
		var expansion: float = 0.90 + wave_ages[i] * 4.6
		waves[i].global_transform = origin * Transform3D(Basis.from_scale(Vector3(expansion, expansion * 0.55, 1.0)), Vector3(0, 0, wave_ages[i] * 2.8))
		waves[i].material_override.set_shader_parameter("life", wave_ages[i])
	overlay.visible = speed_power + boost_power + burst > 0.015
	var ahead: Vector3 = car.global_position + car.global_basis.z * -38.0 + Vector3.UP * 0.7
	if state.travel.length_squared() > 4.0: ahead = car.global_position + state.travel.normalized() * 38.0 + Vector3.UP * 0.7
	var focus := Vector2(0.5, 0.4)
	if not camera.is_position_behind(ahead):
		focus = camera.unproject_position(ahead) / get_viewport().get_visible_rect().size
		focus = focus.clamp(Vector2(0.36, 0.30), Vector2(0.64, 0.49))
	screen_material.set_shader_parameter("focus", focus)
	screen_material.set_shader_parameter("flow_clock", flow_clock)
	screen_material.set_shader_parameter("speed_power", speed_power)
	screen_material.set_shader_parameter("boost_power", boost_power)
	screen_material.set_shader_parameter("burst", burst)
	screen_material.set_shader_parameter("reduced", 1.0 if reduced else 0.0)

func fov_target() -> float:
	return 65.0 if reduced else 65.0 + speed_power * 3.0 + boost_power * 8.0 + burst * 1.2

func clear() -> void:
	speed_power = 0.0; boost_power = 0.0; burst = 0.0; pending_burst = 0.0
	previous_boost = false
	if overlay != null: overlay.visible = false
	if wind != null: wind.clear()
	for i in waves.size(): waves[i].visible = false; wave_ages[i] = 1.0

func diagnostics() -> Dictionary:
	return {"speed": speed_power, "boost": boost_power, "burst": burst, "clock": flow_clock,
		"reduced": reduced, "waves": burst_count, "overlay": overlay.visible, "fov_target": fov_target(),
		"wind_count": wind.count, "wind_emitted": wind.emitted}

extends Node3D

const Jet=preload("res://presentation/vfx/vehicle_jet.gd")
const Pool=preload("res://presentation/vfx/particle_pool.gd")
const Marks=preload("res://presentation/vfx/skid_marks.gd")
const Art=preload("res://presentation/generated_assets.gd")
const Course=preload("res://mechanic/course.gd")
const SpeedFeel=preload("res://presentation/vfx/speed_feel.gd")
var speed_fx
var course=Course.new()
var player_marks:Node3D
var ai_marks:Node3D
var smoke:Node3D
var sparks:Node3D
var vehicles:Array=[]
var clock:=0.0
var event_seen:Dictionary={}
var event_counts:Dictionary={}
var rng:=RandomNumberGenerator.new()
var enabled:=true
var previously_enabled:=true
var previous_reduced:=false
var step_us:=0
var ray_count:=0
var total_emitted:=0
var surface_counts:Dictionary={"asphalt":0,"grass":0,"sand":0}

func _ready() -> void:
	rng.seed=20261028
	speed_fx=SpeedFeel.new();speed_fx.name="SpeedFeel";add_child(speed_fx)
	player_marks=Marks.new();player_marks.capacity=2304;add_child(player_marks)
	ai_marks=Marks.new();ai_marks.capacity=1792;add_child(ai_marks)
	smoke=Pool.new();smoke.capacity=400;add_child(smoke)
	sparks=Pool.new();sparks.capacity=112;sparks.sparks=true;add_child(sparks)

func bind_cars(nodes:Array[Node3D], states:Array) -> void:
	for data in vehicles:
		if is_instance_valid(data.jet):data.jet.queue_free()
	vehicles.clear()
	clear()
	for i in nodes.size():
		var profile:Dictionary=Art.catalogue()["car_%d" % int(states[i].type)]
		var jet=Jet.new()
		jet.sockets=profile.vfx.exhausts
		jet.name="NitroJet"
		nodes[i].add_child(jet)
		var rear:Array=[]
		for wheel in nodes[i].get_meta("wheels",[]):
			if not wheel.front:rear.append(wheel)
		vehicles.append({"car":nodes[i],"jet":jet,"rear":rear,"probe":0.0,"spark":0.0,
			"surface_clock":0.0,"surface":"asphalt","landing":0.0,"smoke_credit":0.0,"intensity":0.0})

func on_event(key:String,data:Dictionary) -> void:
	if key in ["race_reset","garage_entered","track_changed"]:
		clear();return
	if key=="reset":
		clear_racer(int(data.get("racer",0)));return
	if key not in ["nitro_used","small_boost","double_boost","air_boost","landing_boost"]:return
	var racer:=int(data.get("racer",-1))
	if racer<0 or racer>=vehicles.size():return
	var seq:=int(data.get("seq",-1))
	if seq>=0 and seq<=int(event_seen.get(racer,-1)):return
	event_seen[racer]=seq
	vehicles[racer].jet.trigger(key)
	if racer==0:speed_fx.trigger(key)
	if key=="landing_boost":vehicles[racer].landing=0.22
	event_counts[key]=int(event_counts.get(key,0))+1

static func drift_strength(state:Dictionary) -> float:
	if not state.grounded or state.finished or not state.drifting or absf(float(state.speed))<9.0:return 0.0
	var lateral:=absf(float(state.speed)*sin(float(state.slip_angle)))
	return smoothstep(1.0,9.0,lateral)*smoothstep(8.0,20.0,absf(float(state.speed)))

func update_effects(snapshot:Dictionary,camera:Camera3D,dt:float) -> void:
	var start:=Time.get_ticks_usec()
	if snapshot.paused:return
	if not enabled:
		if previously_enabled:clear()
		previously_enabled=false
		return
	previously_enabled=true
	if not vehicles.is_empty():speed_fx.update_effects(snapshot,camera,vehicles[0].car,dt)
	clock+=dt
	player_marks.tick(clock);ai_marks.tick(clock)
	var racing:bool=snapshot.phase=="racing"
	var reduced:bool=snapshot.reduced_motion
	if reduced and not previous_reduced:
		sparks.clear()
		for entry in vehicles:entry.jet.warm_pulse=0.0
	previous_reduced=reduced
	for i in vehicles.size():
		var entry:Dictionary=vehicles[i]
		var state:Dictionary=snapshot.cars[i]
		var car:Node3D=entry.car
		var distance:=camera.global_position.distance_to(car.global_position)
		var active:bool=racing and not state.finished
		entry.jet.tick(state,dt,clock,active,reduced)
		entry.jet.visible=entry.jet.visible and car.visible and distance<95.0
		entry.intensity=lerpf(float(entry.intensity),drift_strength(state) if active else 0.0,1.0-exp(-14.0*dt))
		entry.probe+=dt;entry.spark+=dt;entry.surface_clock-=dt
		entry.landing=maxf(0.0,float(entry.landing)-dt)
		if entry.surface_clock<=0.0:
			entry.surface_clock=0.25
			var near:Dictionary=course.nearest(car.global_position)
			var radius:=Vector2(car.position.x,car.position.z).length()
			entry.surface="asphalt" if float(near.distance)<course.width*0.5+0.5 else "sand" if course.id=="sunny_coast" and radius>156.0 else "grass"
		var interval:=1.0/30.0 if i==0 else 0.08 if distance<65.0 else 0.18
		if entry.probe>=interval:
			entry.probe=0.0
			update_contacts(i,entry,state,active and distance<110.0,reduced)
		if entry.spark>=(0.10 if i==0 else 0.20):
			entry.spark=0.0
			if active and entry.jet.level>0.25 and not reduced and distance<55.0 and car.visible:
				for socket in entry.jet.sockets:
					var pos:=car.to_global(Vector3(socket[0],socket[1],socket[2]+0.2))
					var velocity:Vector3=state.travel*0.16+car.global_basis.z*4.0+Vector3(rng.randf_range(-0.5,0.5),rng.randf_range(-0.2,0.7),0)
					var angle:=atan2(velocity.dot(camera.global_basis.y),velocity.dot(camera.global_basis.x))/TAU
					if sparks.emit(i,pos,velocity,0.12,0.2,0.18,entry.jet.current_color,angle,clock):total_emitted+=1
		vehicles[i]=entry
	smoke.advance(dt,clock);sparks.advance(dt,clock)
	step_us=Time.get_ticks_usec()-start

func update_contacts(id:int,entry:Dictionary,state:Dictionary,active:bool,reduced:bool) -> void:
	var trail=player_marks if id==0 else ai_marks
	var car:Node3D=entry.car
	var airborne:bool=not state.grounded
	var needed:bool=float(entry.intensity)>0.055 or float(entry.landing)>0.0 or (entry.surface!="asphalt" and absf(float(state.speed))>10.0)
	if not active or airborne or not needed:
		for wheel_index in entry.rear.size():trail.break_strip(id*2+wheel_index)
		return
	for wheel_index in entry.rear.size():
		var key:int=id*2+wheel_index
		if not active or airborne:
			trail.break_strip(key);continue
		var wheel:Dictionary=entry.rear[wheel_index]
		var center:Vector3=wheel.pivot.global_position
		var query:=PhysicsRayQueryParameters3D.create(center+Vector3.UP*0.18,center-Vector3.UP*(float(wheel.radius)+0.23),1)
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		ray_count+=1
		if hit.is_empty():trail.break_strip(key);continue
		var normal:Vector3=hit.normal
		var gap:float=(center-hit.position).dot(normal)-float(wheel.radius)
		if gap>0.16 or normal.y<0.65:trail.break_strip(key);continue
		var point:Vector3=hit.position+normal*0.017
		var strength:float=entry.intensity
		if entry.surface=="asphalt" and strength>0.055:
			trail.add_contact(key,point,normal,float(wheel.radius)*0.62,0.24+0.46*strength,7.0 if id==0 else 4.0,0.45 if id==0 else 0.90)
		else:trail.break_strip(key)
		var dust:bool=entry.surface!="asphalt" and absf(float(state.speed))>10.0
		var puff:bool=strength>0.12 or dust or float(entry.landing)>0.0
		if not puff:continue
		if reduced and rng.randf()>0.35:continue
		if id>0 and rng.randf()>0.45:continue
		var color:=Color(0.72,0.77,0.78,0.42+strength*0.16)
		if entry.surface=="grass":color=Color(0.52,0.58,0.38,0.34)
		if entry.surface=="sand":color=Color(0.77,0.66,0.42,0.4)
		var speed:Vector3=state.travel*0.45+normal*0.38+car.global_basis.x*rng.randf_range(-0.5,0.5)
		var size_value:=0.16+strength*0.10
		if float(entry.landing)>0.0:size_value+=0.10
		if smoke.emit(id,point+normal*0.10,speed,size_value,0.70,0.68,color,rng.randf(),clock):
			total_emitted+=1;surface_counts[entry.surface]+=1

func clear_racer(id:int) -> void:
	if id<0 or id>=vehicles.size():return
	if id==0:speed_fx.clear()
	vehicles[id].jet.reset();vehicles[id].intensity=0.0;vehicles[id].landing=0.0
	for key in [id*2,id*2+1]:
		player_marks.break_strip(key);ai_marks.break_strip(key)
	smoke.clear_owner(id);sparks.clear_owner(id)

func clear() -> void:
	if speed_fx!=null:speed_fx.clear()
	if player_marks==null:return
	player_marks.clear();ai_marks.clear();smoke.clear();sparks.clear()
	for entry in vehicles:
		if is_instance_valid(entry.jet):entry.jet.reset()
		entry.intensity=0.0;entry.landing=0.0
	event_seen.clear()

func diagnostics() -> Dictionary:
	var levels:Array=[]
	for entry in vehicles:levels.append(entry.jet.level)
	return {"clock":clock,"smoke":smoke.count,"sparks":sparks.count,"smoke_peak":smoke.peak,"sparks_peak":sparks.peak,
		"marks":player_marks.active_count()+ai_marks.active_count(),"written":player_marks.written+ai_marks.written,
		"maximum_segment":maxf(player_marks.maximum_segment,ai_marks.maximum_segment),"rays":ray_count,"emitted":total_emitted,
		"events":event_counts.duplicate(),"surfaces":surface_counts.duplicate(),"jet_levels":levels,"step_us":step_us,
		"capacity_particles":smoke.capacity+sparks.capacity,"capacity_marks":player_marks.capacity+ai_marks.capacity,
		"speed_feel":speed_fx.diagnostics()}

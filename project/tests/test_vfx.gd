extends RefCounted
const FX=preload("res://presentation/vfx/race_vfx.gd")
const Pool=preload("res://presentation/vfx/particle_pool.gd")
const Marks=preload("res://presentation/vfx/skid_marks.gd")

func run_test() -> Dictionary:
	var errors:Array[String]=[]
	var state:={"grounded":true,"finished":false,"drifting":true,"speed":35.0,"slip_angle":0.3}
	if FX.drift_strength(state)<0.9:errors.append("strong slide unreadable")
	state.grounded=false
	if FX.drift_strength(state)!=0.0:errors.append("airborne skid intensity")
	state.grounded=true;state.slip_angle=0.005
	if FX.drift_strength(state)!=0.0:errors.append("ordinary steering produced skid")
	state.slip_angle=0.3;state.speed=0.0
	if FX.drift_strength(state)!=0.0:errors.append("stationary skid intensity")
	var pool=Pool.new();pool.capacity=4;pool._ready()
	for i in 4:pool.emit(i%2,Vector3(i,0,0),Vector3.RIGHT,0.2,0.1,1.0,Color.WHITE,0.2,0.0)
	if pool.emit(0,Vector3.ZERO,Vector3.ZERO,1,0,1,Color.WHITE,0,0):errors.append("particle overflow accepted")
	pool.advance(0.25,0.25)
	pool.clear_owner(0)
	if pool.count!=2 or pool.multi.visible_instance_count!=2:errors.append("owner cleanup failed")
	pool.advance(0.1,1.1)
	if pool.count!=0 or pool.multi.visible_instance_count!=0:errors.append("expired particles retained")
	pool.free()
	var marks=Marks.new();marks.capacity=8;marks._ready()
	marks.tick(0.0)
	marks.add_contact(0,Vector3.ZERO,Vector3.UP,0.3,0.5,7.0,0.45)
	marks.add_contact(0,Vector3(3,0,0),Vector3.UP,0.3,0.5,7.0,0.45)
	if marks.written!=6:errors.append("distance sampling failed")
	# Dummy/headless RenderingServer does not implement MultiMesh readback.
	if not marks.corners[2].is_equal_approx(marks.corners[4]) or not marks.corners[3].is_equal_approx(marks.corners[5]):errors.append("adjacent marks are disconnected")
	marks.add_contact(0,Vector3(80,0,0),Vector3.UP,0.3,0.5,7.0,0.45)
	if marks.written!=6 or marks.heads.has(0):errors.append("teleport bridge generated")
	marks.tick(7.01)
	if marks.active_count()!=0:errors.append("mark expiry failed")
	marks.clear()
	var normal:=Vector3(-0.5,1,0).normalized()
	marks.add_contact(2,Vector3.ZERO,normal,0.3,0.5,7,0.45)
	marks.add_contact(2,Vector3(2,1,0),normal,0.3,0.5,7,0.45)
	var slope:Vector3=marks.corners[3]
	if absf(slope.y-slope.x*0.5)>0.0001:errors.append("mark flattened off slope")
	marks.free()
	return {"ok":errors.is_empty(),"message":"; ".join(errors)}

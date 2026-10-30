extends Node3D
## Dense, bounded world-space particles. No nodes or resources allocated on emission.

var capacity:=400
var sparks:=false
var count:=0
var peak:=0
var dropped:=0
var last_clock:=0.0
var multi:MultiMesh
var material:ShaderMaterial
var positions:=PackedVector3Array()
var velocities:=PackedVector3Array()
var radii:=PackedFloat32Array()
var growth:=PackedFloat32Array()
var births:=PackedFloat32Array()
var lives:=PackedFloat32Array()
var seeds:=PackedFloat32Array()
var colors:=PackedColorArray()
var owners:=PackedInt32Array()

func _ready() -> void:
	top_level=true
	positions.resize(capacity);velocities.resize(capacity);radii.resize(capacity)
	growth.resize(capacity);births.resize(capacity);lives.resize(capacity)
	seeds.resize(capacity);colors.resize(capacity);owners.resize(capacity)
	multi=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.use_custom_data=true
	multi.instance_count=capacity
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE
	multi.mesh=quad
	multi.visible_instance_count=0
	multi.custom_aabb=AABB(Vector3(-450,-20,-450),Vector3(900,160,900))
	material=ShaderMaterial.new()
	material.shader=preload("res://presentation/vfx/spark.gdshader") if sparks else preload("res://presentation/vfx/smoke.gdshader")
	if not sparks:material.set_shader_parameter("puff_texture",preload("res://assets/vfx_v8/puff_atlas.png"))
	var instance:=MultiMeshInstance3D.new()
	instance.multimesh=multi
	instance.material_override=material
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func emit(owner_id:int, position_value:Vector3, velocity_value:Vector3, radius:float, expand:float, life:float, color:Color, seed_value:float, clock:float) -> bool:
	if count>=capacity:
		dropped+=1
		return false
	var i:=count
	positions[i]=position_value;velocities[i]=velocity_value;radii[i]=radius;growth[i]=expand
	births[i]=clock;lives[i]=life;colors[i]=color;seeds[i]=seed_value;owners[i]=owner_id
	count+=1;peak=maxi(peak,count)
	return true

func erase(index:int) -> void:
	count-=1
	if index==count:return
	positions[index]=positions[count];velocities[index]=velocities[count]
	radii[index]=radii[count];growth[index]=growth[count]
	births[index]=births[count];lives[index]=lives[count]
	colors[index]=colors[count];seeds[index]=seeds[count];owners[index]=owners[count]

func advance(dt:float, clock:float) -> void:
	last_clock=clock
	for i in range(count-1,-1,-1):
		if clock-births[i]>=lives[i]:erase(i)
	for i in count:
		var age:=clock-births[i]
		velocities[i]*=exp(-dt*(1.2 if sparks else 1.6))
		if not sparks:velocities[i].y+=dt*0.5
		positions[i]+=velocities[i]*dt
		var size_value:=radii[i]+growth[i]*age
		var scale_value:=Vector3(size_value*2.0,size_value*(0.36 if sparks else 2.0),1.0)
		multi.set_instance_transform(i,Transform3D(Basis.from_scale(scale_value),positions[i]))
		multi.set_instance_color(i,colors[i])
		multi.set_instance_custom_data(i,Color(births[i],lives[i],seeds[i],0))
	multi.visible_instance_count=count
	material.set_shader_parameter("fx_clock",clock)

func clear_owner(owner_id:int) -> void:
	for i in range(count-1,-1,-1):
		if owners[i]==owner_id:erase(i)
	advance(0.0,last_clock)

func clear() -> void:
	count=0
	if multi!=null:multi.visible_instance_count=0

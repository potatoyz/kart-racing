extends Node3D
## Four-corner streamed quads: continuous on slopes, with shader-controlled lifetime.

var capacity:=2304
var multi:MultiMesh
var material:ShaderMaterial
var cursor:=0
var written:=0
var populated:=0
var births:=PackedFloat32Array()
var lifetimes:=PackedFloat32Array()
var corners:=PackedVector3Array()
var heads:Dictionary={}
var clock:=0.0
var maximum_segment:=0.0

func _ready() -> void:
	top_level=true
	births.resize(capacity);lifetimes.resize(capacity)
	corners.resize(capacity*4)
	multi=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_custom_data=true
	multi.instance_count=capacity
	multi.visible_instance_count=0
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE
	multi.mesh=quad
	multi.custom_aabb=AABB(Vector3(-450,-20,-450),Vector3(900,160,900))
	material=ShaderMaterial.new()
	material.shader=preload("res://presentation/vfx/skid.gdshader")
	var instance:=MultiMeshInstance3D.new()
	instance.multimesh=multi
	instance.material_override=material
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func tick(value:float) -> void:
	clock=value
	material.set_shader_parameter("fx_clock",clock)

func break_strip(key:int) -> void:
	heads.erase(key)

func add_contact(key:int, point:Vector3, normal:Vector3, width:float, strength:float, life:float, spacing:float) -> void:
	if not heads.has(key):
		heads[key]={"point":point,"normal":normal,"left":point,"right":point,"ready":false,"uv":0.0}
		return
	var head:Dictionary=heads[key]
	var delta:Vector3=point-head.point
	if delta.length()>6.0 or normal.dot(head.normal)<0.5:
		break_strip(key);return
	var steps:=mini(12,int(delta.length()/spacing))
	for _step in steps:
		var direction:Vector3=(point-head.point).normalized()
		var end:Vector3=head.point+direction*spacing
		var side:=direction.cross(normal).normalized()*width*0.5
		if not head.ready:
			head.left=head.point-side;head.right=head.point+side;head.ready=true
		var left:=end-side
		var right:=end+side
		multi.set_instance_transform(cursor,Transform3D(Basis(head.left,head.right,left),right))
		corners[cursor*4]=head.left;corners[cursor*4+1]=head.right
		corners[cursor*4+2]=left;corners[cursor*4+3]=right
		multi.set_instance_custom_data(cursor,Color(clock,life,strength,float(head.uv)))
		births[cursor]=clock;lifetimes[cursor]=life
		cursor=(cursor+1)%capacity
		populated=mini(capacity,populated+1)
		multi.visible_instance_count=populated
		written+=1
		maximum_segment=maxf(maximum_segment,spacing)
		head.point=end;head.left=left;head.right=right;head.normal=normal;head.uv+=spacing*2.0
	heads[key]=head

func active_count() -> int:
	var result:=0
	for i in capacity:
		if lifetimes[i]>0.0 and clock-births[i]<lifetimes[i]:result+=1
	return result

func clear() -> void:
	heads.clear();cursor=0;populated=0
	lifetimes.fill(0.0)
	if multi!=null:multi.visible_instance_count=0

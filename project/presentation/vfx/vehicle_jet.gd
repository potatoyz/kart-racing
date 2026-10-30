extends Node3D

var sockets:Array=[]
var outer:Array[Node3D]=[]
var inner:Array[Node3D]=[]
var outer_material:ShaderMaterial
var inner_material:ShaderMaterial
var level:=0.0
var pulse_strength:=0.0
var warm_pulse:=0.0
var last_kind:="small_boost"
var pulse_count:=0
var current_color:=Color("4dcfff")
static var plume_mesh:ArrayMesh

static func mesh() -> ArrayMesh:
	if plume_mesh!=null:return plume_mesh
	var vertices:=PackedVector3Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for plane in 3:
		var basis_value:=Basis(Vector3.BACK,plane*PI/3.0)
		var start:=vertices.size()
		for section in 13:
			var length_value:=float(section)/12.0
			vertices.append(basis_value*Vector3(-0.5,0,length_value));uv.append(Vector2(0,length_value))
			vertices.append(basis_value*Vector3(0.5,0,length_value));uv.append(Vector2(1,length_value))
		for section in 12:
			for i in [0,2,1,1,2,3]:indices.append(start+section*2+i)
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	plume_mesh=ArrayMesh.new()
	plume_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return plume_mesh

func _ready() -> void:
	outer_material=ShaderMaterial.new()
	outer_material.shader=preload("res://presentation/vfx/jet.gdshader")
	inner_material=outer_material.duplicate()
	inner_material.set_shader_parameter("core",1.0)
	for socket in sockets:
		for core_index in 2:
			var node:=MeshInstance3D.new()
			node.mesh=mesh()
			node.position=Vector3(socket[0],socket[1],socket[2])
			node.material_override=outer_material if core_index==0 else inner_material
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			if core_index==0:outer.append(node)
			else:inner.append(node)
	visible=false

func trigger(kind:String) -> void:
	last_kind=kind
	pulse_strength=1.0
	if kind in ["small_boost","double_boost","landing_boost"]:warm_pulse=1.0
	pulse_count+=1

func tick(state:Dictionary, dt:float, clock:float, active:bool, reduced:bool) -> void:
	var big:bool=float(state.boost)>0.0
	var small:bool=float(state.mini_boost)>0.0
	var target:=1.0 if big else 0.62 if small else 0.0
	if not active:target=0.0
	level=move_toward(level,target,dt*(14.0 if target>level else 5.0))
	pulse_strength=maxf(0.0,pulse_strength-dt*5.0)
	warm_pulse=maxf(0.0,warm_pulse-dt*6.0)
	visible=level>0.005
	if not visible:return
	var base_color:=current_color
	if big:base_color=Color("43bfff")
	elif small:base_color=Color("8cebea") if last_kind=="air_boost" else Color("ffb34d")
	current_color=base_color.lerp(Color("ffd486"),warm_pulse*0.45 if big else 0.0)
	var pulse:=pulse_strength*(0.12 if reduced else 0.28)
	outer_material.set_shader_parameter("fx_clock",clock)
	inner_material.set_shader_parameter("fx_clock",clock)
	outer_material.set_shader_parameter("power",level*(0.86+pulse))
	inner_material.set_shader_parameter("power",level)
	outer_material.set_shader_parameter("tint",current_color)
	inner_material.set_shader_parameter("tint",current_color)
	outer_material.set_shader_parameter("motion_amount",0.3 if reduced else 1.0)
	inner_material.set_shader_parameter("motion_amount",0.3 if reduced else 1.0)
	for i in outer.size():
		var width:float=float(sockets[i][3])*(1.0+pulse)
		var length_value:float=(2.1 if big else 1.05)*level*(1.0+pulse)
		outer[i].scale=Vector3(width*4.5,width*4.5,length_value)
		inner[i].scale=Vector3(width*1.05,width*1.05,length_value*0.76)

func reset() -> void:
	level=0.0;pulse_strength=0.0;warm_pulse=0.0;visible=false

static func clear_cache() -> void:
	plume_mesh=null

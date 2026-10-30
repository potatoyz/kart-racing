extends Node3D

const DriverIK = preload("res://presentation/driver_ik.gd")
var vehicle_art: Node3D
var racer: Node3D
var spec: Dictionary
var wheel: Node3D
var modifier: SkeletonModifier3D
var grips: Dictionary = {}
var neutral_basis := Basis.IDENTITY
var current_angle := 0.0

func _ready() -> void:
	wheel = vehicle_art.find_child("SteeringWheel",true,false) as Node3D
	if wheel == null: return
	wheel.reparent(self,true)
	var center: Array = spec.center
	wheel.position = Vector3(center[0],center[1],center[2])
	var old_scale := wheel.transform.basis.get_scale().x
	wheel.scale *= float(spec.radius)/(float(spec.source_radius)*old_scale)
	neutral_basis = wheel.basis
	var column := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius=0.025
	cylinder.bottom_radius=0.035
	cylinder.height=0.29
	cylinder.radial_segments=12
	column.mesh=cylinder
	var column_material:=StandardMaterial3D.new()
	column_material.albedo_color=Color("263943")
	column_material.roughness=0.65
	column.material_override=column_material
	var shaft_direction:=Vector3(0,-0.55,-0.84).normalized()
	column.position=wheel.position+shaft_direction*0.145
	column.quaternion=Quaternion(Vector3.UP,shaft_direction)
	add_child(column)
	for side in ["Left","Right"]:
		var grip := Marker3D.new()
		grip.name = side+"GripTarget"
		grip.position = Vector3(0,0,float(spec.source_radius)*(-1.0 if side=="Left" else 1.0))
		wheel.add_child(grip)
		grips[side] = grip
	var skeleton := racer.find_child("Skeleton3D",true,false) as Skeleton3D
	if skeleton == null: return
	modifier = DriverIK.new()
	modifier.name = "DrivingArmIK"
	skeleton.add_child(modifier)
	modifier.configure(skeleton,wheel,grips)

func set_steering(normalized: float) -> void:
	if not is_instance_valid(wheel): return
	current_angle = -clampf(normalized,-1.0,1.0)*deg_to_rad(float(spec.max_angle_degrees))
	wheel.basis = neutral_basis*Basis(Vector3.RIGHT,current_angle)

func grip_metrics() -> Dictionary:
	return modifier.metrics if is_instance_valid(modifier) else {}

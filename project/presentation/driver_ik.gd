extends SkeletonModifier3D
## Analytic arm IK in skeleton space. Grip points include wrist orientation offsets.

var wheel: Node3D
var targets: Dictionary = {}
var chains: Array[Dictionary] = []
var metrics: Dictionary = {}
var configured := false

func configure(skeleton: Skeleton3D, wheel_node: Node3D, grip_targets: Dictionary) -> void:
	wheel = wheel_node
	targets = grip_targets
	for side in ["Left","Right"]:
		var upper := skeleton.find_bone(side+"UpperArm")
		var fore := skeleton.find_bone(side+"ForeArm")
		var hand := skeleton.find_bone(side+"Hand")
		var grip := skeleton.find_bone(side+"Grip")
		assert(mini(mini(upper,fore),mini(hand,grip))>=0,"Missing driver arm chain")
		var shoulder_rest := skeleton.get_bone_global_rest(upper)
		var elbow_rest := skeleton.get_bone_global_rest(fore)
		var hand_rest := skeleton.get_bone_global_rest(hand)
		var grip_rest := skeleton.get_bone_global_rest(grip)
		var hand_world := skeleton.global_basis.orthonormalized()*hand_rest.basis.orthonormalized()
		chains.append({"side":side,"upper":upper,"fore":fore,"hand":hand,"grip":grip,
			"upper_length":shoulder_rest.origin.distance_to(elbow_rest.origin),
			"fore_length":elbow_rest.origin.distance_to(hand_rest.origin),
			"grip_offset":hand_rest.affine_inverse()*grip_rest.origin,
			"hand_in_wheel":wheel.global_basis.orthonormalized().inverse()*hand_world,
			"pole":elbow_rest.origin+Vector3(0,-0.15,-0.08 if side=="Left" else 0.08)})
	configured = true

func set_bone_world_basis(skeleton: Skeleton3D, bone: int, desired: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	var local := parent_basis.inverse()*desired
	skeleton.set_bone_pose_rotation(bone,local.orthonormalized().get_rotation_quaternion())

func align_bone(skeleton: Skeleton3D, bone: int, child: int, end: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var current := skeleton.get_bone_global_pose(child).origin-pose.origin
	var desired := end-pose.origin
	var delta := Quaternion(current.normalized(),desired.normalized())
	set_bone_world_basis(skeleton,bone,Basis(delta)*pose.basis)

func _process_modification_with_delta(_dt: float) -> void:
	if not configured or not is_instance_valid(wheel): return
	var skeleton := get_skeleton()
	var inverse := skeleton.global_transform.affine_inverse()
	var scale_value := skeleton.global_basis.get_scale().x
	for chain in chains:
		for bone in [chain.upper,chain.fore,chain.hand]: skeleton.reset_bone_pose(bone)
		var target: Node3D = targets[chain.side]
		var hand_world_basis: Basis = wheel.global_basis.orthonormalized()*chain.hand_in_wheel
		var wanted_wrist: Vector3 = inverse*(target.global_position-hand_world_basis*chain.grip_offset*scale_value)
		var shoulder: Vector3 = skeleton.get_bone_global_pose(chain.upper).origin
		var delta := wanted_wrist-shoulder
		var length_a: float = chain.upper_length
		var length_b: float = chain.fore_length
		var distance := clampf(delta.length(),absf(length_a-length_b)+0.00001,length_a+length_b-0.00001)
		var axis := delta.normalized()
		var along := (length_a*length_a-length_b*length_b+distance*distance)/(2.0*distance)
		var height := sqrt(maxf(0.0,length_a*length_a-along*along))
		var pole: Vector3 = chain.pole-shoulder
		pole -= axis*pole.dot(axis)
		if pole.length_squared()<0.000001: pole = axis.cross(Vector3.UP)
		var elbow := shoulder+axis*along+pole.normalized()*height
		var wrist := shoulder+axis*distance
		align_bone(skeleton,chain.upper,chain.fore,elbow)
		align_bone(skeleton,chain.fore,chain.hand,wrist)
		set_bone_world_basis(skeleton,chain.hand,skeleton.global_basis.inverse()*hand_world_basis)
		var pose := skeleton.get_bone_global_pose(chain.hand)
		var actual_grip: Vector3 = skeleton.global_transform*(pose*chain.grip_offset)
		var actual_basis := (skeleton.global_basis*pose.basis).orthonormalized()
		var angular_error := rad_to_deg(actual_basis.get_rotation_quaternion().angle_to(hand_world_basis.orthonormalized().get_rotation_quaternion()))
		var upper_actual := skeleton.get_bone_global_pose(chain.upper).origin.distance_to(skeleton.get_bone_global_pose(chain.fore).origin)
		var fore_actual := skeleton.get_bone_global_pose(chain.fore).origin.distance_to(pose.origin)
		metrics[chain.side]={"error":actual_grip.distance_to(target.global_position),
			"angular_error_degrees":angular_error,"bone_length_error":(absf(upper_actual-length_a)+absf(fore_actual-length_b))*scale_value,
			"reach_excess":maxf(0.0,delta.length()-length_a-length_b)*scale_value,
			"elbow":skeleton.global_transform*skeleton.get_bone_global_pose(chain.fore).origin,
			"grip":actual_grip,"target":target.global_position,
			"upper_length":length_a*scale_value,"fore_length":length_b*scale_value}

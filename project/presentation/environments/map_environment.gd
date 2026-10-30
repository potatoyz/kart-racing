extends Node3D
const Model=preload("res://presentation/models.gd")
const Props=preload("res://presentation/environments/map_props.gd")
var course
var placements:Dictionary={}
func _ready()->void:
	var center:Vector2=course.bounds.get_center()
	var span:Vector2=course.bounds.size+Vector2(90,90)
	var harbor:bool=course.id=="harbor_loop"
	if harbor:
		var sea:=Model.box(self,Vector3(2400,.3,2400),Vector3(0,-4,0),Color("4dbdc8"))
		var mat:=ShaderMaterial.new();mat.shader=preload("res://presentation/coastal_water.gdshader");sea.material_override=mat
		Model.box(self,Vector3(span.x,5,span.y),Vector3(center.x,-2.6,center.y),Color("b4c4bf"))
		var quay:=Model.box(self,Vector3(span.x+2,.4,span.y+2),Vector3(center.x,-.22,center.y),Color("839d9a"))
		var quay_material:=ShaderMaterial.new();quay_material.shader=preload("res://presentation/environments/harbor_ground.gdshader")
		quay.material_override=quay_material
	else:
		var ground:=Model.box(self,Vector3(1800,2,1800),Vector3(0,-1.1,0),Color("81a38b"))
		var mat:=ShaderMaterial.new();mat.shader=preload("res://presentation/coastal_ground.gdshader");ground.material_override=mat
	var floor_body:=StaticBody3D.new()
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new();shape.size=Vector3(span.x,1,span.y)
	collider.shape=shape;collider.position=Vector3(center.x,-.56,center.y)
	floor_body.add_child(collider);add_child(floor_body)
	if harbor:build_harbor(center,span)
	else:build_ridge(center)
	for id in placements:Props.batch(self,id,placements[id])
func place(id:String,pos:Vector3,yaw:float=0.0,scale_value:Vector3=Vector3.ONE)->void:
	# Keep the full transformed footprint outside road and camera clearance.
	if id != "map_mountain_gate":
		var model: ArrayMesh=Props.mesh(id)
		if model==null:return
		var size:Vector3=model.get_aabb().size*scale_value
		var radius:=Vector2(size.x,size.z).length()*.5
		if course.nearest(pos).distance<course.width*.5+3.5+radius:return
	if not placements.has(id):placements[id]=[]
	placements[id].append(Transform3D(Basis(Vector3.UP,yaw).scaled(scale_value),pos))
func beside(s:float,offset:float)->Vector3:
	return course.at_distance(s)+course.direction_at(s).cross(Vector3.UP)*offset
func safe(pos:Vector3,clearance:float)->bool:
	return course.nearest(pos).distance>clearance
func landmark(text:String,s:float,offset:float)->void:
	var label:=Label3D.new();label.text=text;label.font_size=90;label.pixel_size=.035
	label.position=beside(s,offset)+Vector3.UP*7.5
	label.rotation.y=course.yaw_at(s);label.modulate=Color("fff2cc")
	add_child(label)
func build_harbor(center:Vector2,span:Vector2)->void:
	for fraction in [.22,.35,.48,.77]:
		var s:float=fraction*course.length
		var pos:=beside(s,38)
		if safe(pos,25):place("map_warehouse",pos,course.yaw_at(s),Vector3.ONE*1.15)
	for fraction in [.12,.57,.84]:
		var s:float=fraction*course.length
		var pos:=beside(s,-42)
		if safe(pos,26):place("map_crane",pos,course.yaw_at(s))
	for i in range(60,int(course.length),24):
		var s:=float(i)
		var pos:=beside(s,24)
		if safe(pos,20):
			place("map_container",pos,course.yaw_at(s))
			if i%3==0:place("map_container",pos+Vector3.UP*3.1,course.yaw_at(s),Vector3(.8,.9,1))
	for i in range(15,int(course.length),34):
		var s:=float(i)
		place("map_harbor_lamp",beside(s,-course.width*.5-5.0),course.yaw_at(s))
	# Quayside mooring posts, floating cargo barges and breakwater.
	for i in range(-3,4):
		var pos:=Vector3(center.x+i*45,-1.8,center.y+span.y*.5+14)
		Model.cylinder(self,pos,.7,7,Color("466b77"))
	for i in 3:
		var pos:=Vector3(center.x-85+i*80,-2.8,center.y+span.y*.5+43)
		Model.box(self,Vector3(39,2.0,16),pos,Color("3a6171"))
		for x in [-11,0,11]:place("map_container",pos+Vector3(x,1.0,0),PI*.5,Vector3(.8,.8,.8))
	landmark("BAY  /  HARBOR",course.length*.26,29)
	landmark("DOCK  02",course.length*.57,-27)
func build_ridge(center:Vector2)->void:
	var rng:=RandomNumberGenerator.new();rng.seed=1103
	# Cliffs form a set-back mountain wall; the inner road and camera stay clear.
	for i in range(15,int(course.length),25):
		var s:=float(i)
		for side in [-1.0,1.0]:
			var offset:float=side*(26.0+rng.randf_range(0,13))
			var pos:=beside(s,offset)
			if safe(pos,21):
				if i%3==0:place("map_cliff",pos-Vector3.UP*2,course.yaw_at(s)+side*PI*.5,Vector3(rng.randf_range(1,1.5),rng.randf_range(.8,1.7),rng.randf_range(.8,1.2)))
				else:place("map_ridge_rock",pos,rand_angle(rng),Vector3.ONE*rng.randf_range(.8,1.8))
	for i in 170:
		var pos:=Vector3(rng.randf_range(course.bounds.position.x-65,course.bounds.end.x+65),0,rng.randf_range(course.bounds.position.y-65,course.bounds.end.y+65))
		if not safe(pos,21):continue
		place("map_pine_tall" if i%2==0 else "map_pine_round",pos,rand_angle(rng),Vector3.ONE*rng.randf_range(.65,1.4))
	# Distant silhouettes stay outside all drivable bounds.
	for i in 12:
		var angle:=float(i)*TAU/12.0
		var pos:=Vector3(center.x+cos(angle)*390,0,center.y+sin(angle)*350)
		place("map_cliff",pos-Vector3.UP*8,angle,Vector3(4,4.5+float(i%3)*1.6,3.5))
	for fraction in [.30,.68]:
		var s:float=fraction*course.length
		var pos:=beside(s,-24)
		if safe(pos,17):place("map_lookout",pos,course.yaw_at(s))
	# Gate is authored with twenty metres of clear span.
	place("map_mountain_gate",course.at_distance(64),course.yaw_at(64),Vector3(.85,1,.85))
	landmark("SUNRIDGE  /  PASS",64,0)
	landmark("HAIRPIN  /  BRAKE",course.length*.27,-20)
func rand_angle(rng:RandomNumberGenerator)->float:
	return rng.randf_range(-PI,PI)

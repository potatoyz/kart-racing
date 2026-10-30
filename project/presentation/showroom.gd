extends SubViewportContainer

const Model = preload("res://presentation/models.gd")
var api: Node
var viewport: SubViewport
var display: Node3D
var preview: Node3D
var preview_key := ""
var turn := 0.0
var dragging := false

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	viewport = SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	display = Node3D.new()
	viewport.add_child(display)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d7e9ef")
	environment.ambient_light_energy = 0.65
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("b4d9e5")
	sky_material.sky_horizon_color = Color("f0f2dd")
	sky_material.ground_bottom_color = Color("698590")
	sky_material.ground_horizon_color = Color("c7e4df")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world.environment = environment
	display.add_child(world)
	for angles in [Vector3(-40,-35,0), Vector3(-30,145,0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = angles
		light.light_color = Color("fff2db") if angles.y < 0 else Color("bde9ff")
		light.light_energy = 0.95 if angles.y < 0 else 0.55
		light.shadow_enabled = angles.y < 0
		display.add_child(light)
	var stage := Model.cylinder(display,Vector3(0,-0.12,0),2.35,0.2,Color("eaf3ec"))
	stage.mesh.radial_segments = 96
	var ring := Model.cylinder(display,Vector3(0,-0.24,0),2.42,0.08,Color("42b4bc"))
	ring.mesh.radial_segments = 96
	var camera := Camera3D.new()
	camera.position = Vector3(4.8,2.9,-6.0)
	camera.fov = 28
	camera.current = true
	display.add_child(camera)
	camera.look_at(Vector3(0,0.7,0))
	gui_input.connect(_on_gui_input)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): dragging = false)

func _process(_dt: float) -> void:
	if not is_visible_in_tree(): return
	var s: Dictionary = api.snapshot()
	var key := "%d:%d" % [s.preview_car,s.preview_outfit]
	if preview_key != key:
		if is_instance_valid(preview): preview.free()
		preview = Model.car(int(s.preview_car),int(s.preview_outfit))
		display.add_child(preview)
		preview_key = key
		turn = 0.0
	if is_instance_valid(preview): preview.rotation.y = turn

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	if event is InputEventMouseMotion and dragging:
		turn += event.relative.x * 0.008

extends CanvasLayer

const Map = preload("res://presentation/minimap.gd")
const Art = preload("res://presentation/generated_assets.gd")
const Showroom = preload("res://presentation/showroom.gd")
var api: Node
var picker: Control
var track_button: Button
var track_title: Label
var track_description: Label
var garage_track_info: Label
var pause_track_title: Label
var result_track_title: Label
var result_track_caption: Label
var garage_map: Control
var pause_map: Control
var root: Control
var garage: Control
var hud: Control
var pause: Control
var results: Control
var title: Label
var stats: Label
var equip: Button
var outfit_title: Label
var rank: Label
var lap: Label
var timer: Label
var speed: Label
var charge: ProgressBar
var nitro: Label
var item: Label
var notice: Label
var countdown: Label
var result_title: Label
var result_body: Label
var minimap: Control
var motion_button: Button
var mute_button: Button
var technique: Label
var technique_hint: Label
var technique_window: ProgressBar
var car_number: Label
var outfit_portrait: TextureRect
var attribute_bars: Array[ColorRect] = []
var showroom: SubViewportContainer
var display_font: SystemFont
var data_font: SystemFont
var portrait_key := -1
var previous_screen := ""
var ink := Color("17394d")
var cream := Color("f8f2df")
var coral := Color("ee815f")
var accent := Color("ffd157")

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	theme.default_font = font
	theme.default_font_size = 22
	display_font = SystemFont.new()
	display_font.font_names = PackedStringArray(["Bahnschrift", "Microsoft YaHei UI"])
	display_font.font_weight = 700
	data_font = SystemFont.new()
	data_font.font_names = PackedStringArray(["Consolas", "Microsoft YaHei UI"])
	theme.set_color("font_color", "Label", cream)
	theme.set_color("font_color", "Button", ink)
	theme.set_color("font_hover_color", "Button", ink)
	theme.set_color("font_pressed_color", "Button", ink)
	theme.set_color("font_focus_color", "Button", ink)
	theme.set_stylebox("normal", "Button", style(Color("edf4ef"), 7))
	theme.set_stylebox("hover", "Button", style(Color("c7f0e9"), 7))
	theme.set_stylebox("pressed", "Button", style(accent, 7))
	var focus := style(Color(0,0,0,0),10)
	focus.set_border_width_all(3)
	focus.border_color = Color("19bfc5")
	theme.set_stylebox("focus","Button",focus)
	root.theme = theme
	build_garage()
	build_hud()
	build_pause()
	build_results()
	picker = preload("res://presentation/track_picker.gd").new()
	picker.api = api
	picker.host = self
	root.add_child(picker)
	picker.closed.connect(func(): garage.show();track_button.grab_focus())

func style(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	return s

func layer() -> Control:
	var node := Control.new()
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(node)
	return node

func label(parent: Control, text: String, rect: Rect2, font_size: int = 24, color: Color = Color("f8f2df")) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func panel(parent: Control, rect: Rect2, color: Color) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel",style(color,16))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func button(parent: Control, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary: node.add_theme_stylebox_override("normal", style(accent,10))
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func artwork(parent: Control, asset_id: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.position = rect.position
	node.size = rect.size
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture = Art.texture(asset_id)
	parent.add_child(node)
	return node

func rule(parent: Control, rect: Rect2, color: Color) -> void:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)

func build_garage() -> void:
	garage = layer()
	rule(garage,Rect2(0,0,1600,900),Color("7dcbd7"))
	artwork(garage,"menu_coast",Rect2(0,0,1600,900))
	# Shallow translucent masthead keeps the real title readable over the art.
	panel(garage,Rect2(38,32,530,174),Color("14384de8"))
	rule(garage,Rect2(62,54,44,5),accent)
	label(garage,"SUNNY DRIFT  /  COASTAL RACING",Rect2(120,41,410,30),19,Color("97e5df")).add_theme_font_override("font",display_font)
	label(garage,"晴空疾驰",Rect2(61,78,465,83),67).add_theme_font_override("font",display_font)
	label(garage,"漂移入弯，把夏天甩在身后。",Rect2(66,164,445,28),18,Color("d4e5e3"))
	panel(garage,Rect2(1200,38,360,60),Color("14384de8"))
	garage_track_info = label(garage,"晴空海岸   ·   3 圈 / 6 位车手",Rect2(1220,51,325,31),21)
	panel(garage,Rect2(40,258,318,443),Color("14384df2"))
	label(garage,"我的赛车",Rect2(62,278,240,30),19,Color("9bdfdb"))
	car_number = label(garage,"01 / 03",Rect2(248,280,90,28),17,accent)
	car_number.add_theme_font_override("font",data_font)
	title = label(garage,"",Rect2(62,320,270,57),39)
	rule(garage,Rect2(62,391,274,1),Color("487183"))
	stats = label(garage,"",Rect2(62,405,274,115),20)
	stats.add_theme_constant_override("line_spacing",12)
	for i in 3:
		rule(garage,Rect2(62,440+i*41,274,4),Color("35576a"))
		var bar := ColorRect.new()
		bar.position = Vector2(62,440+i*41)
		bar.size = Vector2(274,4)
		bar.color = Color("63d2c5") if i != 0 else accent
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		garage.add_child(bar)
		attribute_bars.append(bar)
	button(garage,"‹ 上一辆",Rect2(62,548,130,48),func(): cycle_car(-1))
	button(garage,"下一辆 ›",Rect2(205,548,131,48),func(): cycle_car(1))
	equip = button(garage,"装备当前搭配",Rect2(62,618,274,53),func(): api.command("equip"),true)
	equip.add_theme_font_size_override("font_size",19)
	showroom = Showroom.new()
	showroom.api = api
	showroom.position = Vector2(354,245)
	showroom.size = Vector2(884,470)
	garage.add_child(showroom)
	panel(garage,Rect2(650,684,290,37),Color("14384dc9"))
	label(garage,"拖动赛车，查看每一处细节",Rect2(669,689,265,26),16)
	panel(garage,Rect2(1260,258,300,443),Color("14384df2"))
	label(garage,"车手装束",Rect2(1282,278,250,30),19,Color("9bdfdb"))
	outfit_portrait = artwork(garage,"driver_portrait_0",Rect2(1290,321,240,166))
	outfit_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	outfit_title = label(garage,"",Rect2(1282,495,256,43),28)
	label(garage,"换上你的海岸配色",Rect2(1282,546,256,29),18,Color("b5d5d7"))
	button(garage,"‹",Rect2(1282,595,117,47),func(): cycle_outfit(-1))
	button(garage,"›",Rect2(1417,595,117,47),func(): cycle_outfit(1))
	label(garage,"外观搭配 · 不影响赛车性能",Rect2(1282,657,260,27),16,Color("b5d5d7"))
	panel(garage,Rect2(40,750,1520,114),Color("14384df5"))
	track_button = button(garage,"",Rect2(50,760,505,94),func():picker.open())
	track_button.name = "OpenTrackPicker"
	track_button.add_theme_stylebox_override("normal",style(Color("244f61"),10))
	garage_map = Map.new()
	garage_map.position=Vector2(0,0);garage_map.size=Vector2(169,94)
	garage_map.mouse_filter=Control.MOUSE_FILTER_IGNORE
	track_button.add_child(garage_map)
	track_title = label(track_button,"晴空海岸  ›",Rect2(182,3,315,40),27)
	track_description = label(track_button,"",Rect2(182,52,315,30),17,Color("b5d5d7"))
	label(garage,"WASD 驾驶  /  Shift 漂移\nJ 小喷  ·  Space 氮气  ·  E 道具",Rect2(578,779,405,64),18)
	button(garage,"竞速赛  →",Rect2(1014,775,248,64),func(): api.command("start",{"mode":"speed"}),true)
	button(garage,"道具赛  →",Rect2(1282,775,252,64),func(): api.command("start",{"mode":"item"}))
	label(garage,"本地自动保存搭配与最佳成绩",Rect2(45,870,650,22),14,ink)

func build_hud() -> void:
	hud = layer()
	panel(hud,Rect2(35,30,260,155),Color("17394de8"))
	rank = label(hud,"",Rect2(56,37,230,85),60)
	lap = label(hud,"",Rect2(59,128,220,38),23,accent)
	panel(hud,Rect2(1295,30,270,260),Color("17394dde"))
	minimap = Map.new()
	minimap.position = Vector2(1310,80)
	minimap.size = Vector2(240,195)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(minimap)
	timer = label(hud,"",Rect2(1317,43,235,35),23)
	panel(hud,Rect2(1255,659,310,207),Color("17394df0"))
	speed = label(hud,"",Rect2(1276,663,277,77),58)
	nitro = label(hud,"",Rect2(1277,751,270,39),23,accent)
	charge = ProgressBar.new()
	charge.position = Vector2(1278,802)
	charge.size = Vector2(263,17)
	charge.show_percentage = false
	charge.add_theme_stylebox_override("background",style(Color("416376"),8))
	charge.add_theme_stylebox_override("fill",style(Color("44d7d2"),8))
	hud.add_child(charge)
	label(hud,"Shift 漂移集气   /   Space 使用",Rect2(1278,826,267,27),16)
	panel(hud,Rect2(480,748,730,118),Color("17394de8"))
	technique = label(hud,"",Rect2(500,756,690,40),25,accent)
	technique_hint = label(hud,"",Rect2(500,801,690,30),17)
	technique_window = ProgressBar.new()
	technique_window.position = Vector2(500,840)
	technique_window.size = Vector2(686,8)
	technique_window.show_percentage = false
	technique_window.add_theme_stylebox_override("background",style(Color("416376"),4))
	technique_window.add_theme_stylebox_override("fill",style(Color("ffd157"),4))
	hud.add_child(technique_window)
	panel(hud,Rect2(35,738,410,128),Color("17394de8"))
	item = label(hud,"",Rect2(57,747,365,46),25,accent)
	label(hud,"R 安全复位    Esc 暂停",Rect2(57,814,365,30),19)
	notice = label(hud,"",Rect2(400,124,800,60),29,Color("ffe9a2"))
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown = label(hud,"",Rect2(500,280,600,180),115)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pause_button := button(hud,"Ⅱ",Rect2(743,28,114,49),func(): api.command("pause"))
	pause_button.focus_mode = Control.FOCUS_NONE

func build_pause() -> void:
	pause = layer()
	panel(pause,Rect2(0,0,1600,900),Color("0b263dc4")).mouse_filter = Control.MOUSE_FILTER_STOP
	panel(pause,Rect2(290,85,1020,730),Color("14384dfc"))
	pause_map = Map.new()
	pause_map.position=Vector2(306,101);pause_map.size=Vector2(388,215)
	pause_map.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pause.add_child(pause_map)
	pause_track_title = label(pause,"",Rect2(334,313,340,42),24,accent)
	rule(pause,Rect2(306,358,388,5),coral)
	label(pause,"连喷练习",Rect2(334,393,345,45),30,accent)
	label(pause,"Shift + 方向起漂，松手侧滑\n反打收尾后，点 J / W 小喷\n\n双喷：长漂 + 反打 → 连点两次\n两喷间隔 0.16 — 0.50 秒\n\n空中喷 → 着地后 0.55 秒内点喷\nCWW：大喷 → 小喷 → 第二喷\nWCW：小喷 → 大喷 → 第二喷",Rect2(334,453,345,297),19,Color("d2e2e2"))
	label(pause,"PIT STOP  /  暂停",Rect2(743,122,500,36),19,Color("8edbd6"))
	label(pause,"休息一下",Rect2(739,176,490,87),55)
	button(pause,"继续比赛",Rect2(743,299,510,62),func(): api.command("pause",{"value":false}),true)
	button(pause,"重新发车",Rect2(743,380,510,54),func(): api.command("restart"))
	button(pause,"返回车库",Rect2(743,451,510,54),func(): api.command("garage"))
	rule(pause,Rect2(743,536,510,1),Color("426377"))
	motion_button = button(pause,"",Rect2(743,565,510,51),func(): api.command("settings",{"reduced_motion":not api.snapshot().reduced_motion}))
	mute_button = button(pause,"",Rect2(743,636,510,51),func(): api.command("settings",{"muted":not api.snapshot().muted}))
	label(pause,"所有赛车与计时已暂停  ·  Esc 继续",Rect2(743,733,510,35),19,Color("aac9cf"))

func build_results() -> void:
	results = layer()
	panel(results,Rect2(0,0,1600,900),Color("102c3fa9")).mouse_filter = Control.MOUSE_FILTER_STOP
	panel(results,Rect2(240,135,1120,630),Color("14384dfb"))
	artwork(results,"menu_coast",Rect2(256,151,364,598))
	panel(results,Rect2(273,593,330,137),Color("14384de8"))
	result_track_title = label(results,"晴空海岸",Rect2(296,611,286,49),29)
	label(results,"下一次，把纪录留在身后。",Rect2(296,672,286,32),19,Color("c9dedb"))
	result_track_caption = label(results,"SUNNY COAST  /  FINISH",Rect2(673,185,630,40),21,accent)
	result_title = label(results,"",Rect2(667,254,640,100),58)
	rule(results,Rect2(673,375,630,2),Color("4c7382"))
	result_body = label(results,"",Rect2(673,410,630,172),27)
	button(results,"再来一局",Rect2(673,635,298,66),func(): api.command("restart"),true)
	button(results,"返回车库",Rect2(994,635,305,66),func(): api.command("garage"))

func cycle_car(delta: int) -> void:
	api.command("preview_car",{"index":posmod(int(api.snapshot().preview_car)+delta,3)})

func cycle_outfit(delta: int) -> void:
	api.command("preview_outfit",{"index":posmod(int(api.snapshot().preview_outfit)+delta,3)})

func time_text(seconds: float) -> String:
	return "%02d:%05.2f" % [int(seconds)/60, fmod(seconds,60.0)]

func _process(_dt: float) -> void:
	var s: Dictionary = api.snapshot()
	if s.cars.is_empty(): return
	var p: Dictionary = s.cars[0]
	garage.visible = s.phase == "garage" and not picker.visible
	if s.phase != "garage": picker.visible = false
	hud.visible = s.phase in ["countdown","racing"]
	pause.visible = s.paused
	results.visible = s.phase == "results"
	var current_screen: String = "map_select" if picker.visible else "pause" if s.paused else s.phase
	if current_screen != previous_screen and not picker.visible:
		var container: Control = pause if s.paused else garage if garage.visible else results if results.visible else hud
		for child in container.get_children():
			if child is Button and child.focus_mode != Control.FOCUS_NONE:
				child.grab_focus()
				break
		previous_screen = current_screen
	var car: Dictionary = s.car_catalog[int(s.preview_car)]
	title.text = car.name
	car_number.text = "%02d / 03" % (int(s.preview_car)+1)
	attribute_bars[0].size.x = float(car.top) / 50.0 * 274.0
	attribute_bars[1].size.x = float(car.accel) * 4.0 * 2.74
	attribute_bars[2].size.x = float(car.steer) * 45.0 * 2.74
	if portrait_key != int(s.preview_outfit):
		portrait_key = int(s.preview_outfit)
		outfit_portrait.texture = Art.texture("driver_portrait_%d" % portrait_key)
	stats.text = "最高速度   %d km/h\n加速能力   %d / 100\n操控能力   %d / 100" % [roundi(float(car.top)*3.6),roundi(float(car.accel)*4),roundi(float(car.steer)*45)]
	outfit_title.text = ["海岸领航员","珊瑚假日","星兔车手"][int(s.preview_outfit)]
	equip.text = "✓ 当前搭配已装备" if s.preview_car == s.selected_car and s.preview_outfit == s.selected_outfit else "装备当前搭配"
	rank.text = "%d / 6" % p.rank
	lap.text = "第 %d / %d 圈" % [p.lap,s.lap_count]
	timer.text = time_text(s.elapsed)
	speed.text = "%03d  km/h" % roundi(absf(float(p.speed))*3.6)
	charge.value = p.charge
	nitro.text = "N₂  %s %s" % ["●" if p.nitro >= 1 else "○","●" if p.nitro >= 2 else "○"]
	if p.boost > 0.0: nitro.text += "   加速中"
	var names := {"":"等待拾取","missile":"追踪导弹","shield":"防御护盾","boost":"疾速推进"}
	item.text = "E  ·  " + names[p.item] if s.mode == "item" else "竞速赛  ·  漂移赢得优势"
	if p.shield > 0.0: item.text += "  [护盾]"
	notice.text = "漂移中 · 正在集气" if p.drifting else s.message
	var t: Dictionary = p.tricks
	if not str(t.combo).is_empty(): notice.text = t.combo
	technique.text = "Shift 起漂 · 松手保留惯性"
	technique_hint.text = "J / W 点喷   ·   Space / Ctrl 大喷   ·   暂停菜单查看连招"
	var remaining := 0.0
	var maximum := 1.15
	if t.landing_window > 0.0:
		technique.text = "落地喷就绪   ·   点 J / W"
		remaining = t.landing_window
		maximum = 0.55
	elif t.air_window > 0.0:
		technique.text = "空中喷就绪   ·   点 J / W"
		remaining = t.air_window
		maximum = 0.95
	elif t.double_window > 0.0:
		technique.text = "第二喷！再点 J / W" if t.double_wait <= 0.0 else "双喷节奏 · 松键，准备第二次点按"
		remaining = t.double_window
		maximum = 0.5
	elif t.mini_window > 0.0:
		technique.text = "双喷已备好 · 点 J / W" if t.mini_stock == 2 else "小喷就绪 · 点 J / W"
		remaining = t.mini_window
	elif p.drift_phase == "recover":
		technique.text = "惯性侧滑  ·  反打收尾"
	elif p.drift_phase == "drift":
		technique.text = "漂移中  ·  松 Shift + 反打准备双喷"
	elif not p.grounded:
		technique.text = "空中滑行 · 准备落地喷"
	if remaining > 0.0: technique_hint.text = "窗口剩余 %.2f 秒  ·  点按生效，按住不会连续触发" % remaining
	technique_window.max_value = maximum
	technique_window.value = remaining
	if p.stun > 0.0: notice.text = "被导弹击中 · 减速中"
	countdown.text = str(maxi(1,ceili(s.countdown))) if s.phase == "countdown" else ""
	if minimap.track.get("id","") != s.active_track_id:
		minimap.set_track(s.track)
		garage_map.set_track(s.track)
		pause_map.set_track(s.track)
		track_title.text = s.track_name+"  ›"
		track_description.text = s.difficulty+"  ·  点击更换赛道"
		garage_track_info.text = "%s  ·  %d 圈 / 6 位车手" % [s.track_name,s.lap_count]
		pause_track_title.text = s.track_name+" · "+s.difficulty
		result_track_title.text = s.track_name
		result_track_caption.text = s.track.english+"  /  FINISH"
	minimap.cars = s.cars
	minimap.queue_redraw()
	motion_button.text = "低动态模式：" + ("开启" if s.reduced_motion else "关闭")
	mute_button.text = "游戏声音：" + ("关闭" if s.muted else "开启")
	result_title.text = "第 %d 名  /  冲线！" % p.rank
	result_body.text = "%s · %s\n本局用时   %s\n个人最佳   %s" % ["竞速赛" if s.mode == "speed" else "道具赛",s.track_name,time_text(float(p.finish_time) if p.finished else s.elapsed),time_text(float(s.best[s.mode]))]

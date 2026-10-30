extends Control
const Map = preload("res://presentation/minimap.gd")
var api: Node
var host: CanvasLayer
var cards: Array[Button] = []
var records: Array[Label] = []
var selected_badges: Array[Label] = []
var preview := 0
var error_label: Label
signal closed
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	host.panel(self,Rect2(0,0,1600,900),Color("dce9e6")).mouse_filter = Control.MOUSE_FILTER_STOP
	host.label(self,"选择赛道",Rect2(64,34,900,80),48,Color("14384d"))
	host.label(self,"从海岸出发，让每一次入弯更有把握。",Rect2(66,122,1100,40),24,Color("476a76"))
	var catalog: Array = api.snapshot().track_catalog
	for i in catalog.size():
		var info: Dictionary = catalog[i]
		var x := 64.0+i*501.0
		var card: Button = host.button(self,"",Rect2(x,198,469,486),func(): choose(i))
		card.name = "TrackCard_"+str(info.id)
		card.clip_contents=true
		card.add_theme_stylebox_override("normal",host.style(Color("17394d"),14))
		card.add_theme_stylebox_override("hover",host.style(Color("245365"),14))
		card.add_theme_stylebox_override("pressed",host.style(Color("245365"),14))
		card.focus_entered.connect(func(): choose(i,false))
		cards.append(card)
		selected_badges.append(host.label(card,"",Rect2(330,20,120,32),17,Color("ffd157")))
		host.label(card,str(info.difficulty)+"赛道  "+"▰".repeat(int(info.level)),Rect2(24,18,420,38),22,Color(info.color))
		host.label(card,info.name,Rect2(24,66,425,58),34)
		var thumbnail:Texture2D=preload("res://presentation/generated_assets.gd").texture("map_thumb_"+str(info.id))
		var map := Map.new()
		if thumbnail!=null:
			var photo:=TextureRect.new()
			photo.name="Thumbnail"
			photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			photo.texture=thumbnail;photo.position=Vector2(24,133);photo.size=Vector2(421,185)
			photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
			photo.mouse_filter=Control.MOUSE_FILTER_IGNORE
			card.add_child(photo)
			host.panel(card,Rect2(275,180,165,133),Color("14384deb"))
			map.position=Vector2(275,180);map.size=Vector2(165,133);map.line_width=1.8
		else:
			map.position=Vector2(24,133);map.size=Vector2(421,185);map.line_width=4.0
		map.line_color=Color(info.color)
		map.set_track(info);map.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card.add_child(map)
		host.label(card,"%d m   /   %d m 路宽   /   3 圈" % [roundi(info.length),roundi(info.width)],Rect2(24,325,425,34),21,Color("a9c9ce"))
		host.label(card,info.description,Rect2(24,369,425,38),20)
		records.append(host.label(card,"",Rect2(24,422,425,38),18,Color("a9c9ce")))
	error_label=host.label(self,"",Rect2(64,711,950,43),22,Color("a23838"))
	host.label(self,"方向键切换  ·  Enter 确认  ·  Esc 返回",Rect2(64,770,950,42),23,Color("14384d"))
	host.button(self,"取消",Rect2(1056,783,208,72),cancel)
	host.button(self,"选择此赛道",Rect2(1296,783,240,72),confirm,true)
	visible=false
func open() -> void:
	var s: Dictionary=api.snapshot()
	if s.phase!="garage":return
	visible=true
	error_label.text=""
	for i in s.track_catalog.size():
		var info:Dictionary=s.track_catalog[i]
		selected_badges[i].text="已选择" if info.id==s.selected_track_id else ""
		if info.id==s.selected_track_id:preview=i
		var best:Dictionary=s.best_by_track[info.id]
		records[i].text="竞速 %s   ·   道具 %s" % [record_time(best.speed),record_time(best.item)]
	choose(preview)
func record_time(value:float) -> String:
	return "--:--" if value<=0 else "%02d:%05.2f" % [int(value)/60,fmod(value,60)]
func choose(index:int, focus:bool=true) -> void:
	preview=posmod(index,cards.size())
	for i in cards.size():
		var box:StyleBoxFlat=host.style(Color("17394d"),14)
		box.set_border_width_all(4 if i==preview else 1)
		box.border_color=Color("ffd157") if i==preview else Color("426574")
		cards[i].add_theme_stylebox_override("normal",box)
	if focus:cards[preview].grab_focus()
func confirm() -> void:
	var catalog:Array=api.snapshot().track_catalog
	if api.command("select_track",{"track_id":catalog[preview].id}).ok:
		visible=false;closed.emit()
	else:error_label.text="赛道加载失败，请重试。当前选择已保留。"
func cancel() -> void:
	visible=false;closed.emit()
func _input(event:InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:return
	match event.keycode:
		KEY_LEFT:choose(preview-1)
		KEY_RIGHT:choose(preview+1)
		KEY_ESCAPE:cancel()
		KEY_ENTER,KEY_KP_ENTER:confirm()
		_:return
	get_viewport().set_input_as_handled()

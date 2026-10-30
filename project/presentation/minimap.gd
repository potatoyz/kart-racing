extends Control
var track: Dictionary = {}
var cars: Array = []
var line_color := Color("b8ccc9")
var line_width := 3.0
func set_track(info: Dictionary) -> void:
	track = info
	queue_redraw()
func point(p: Vector3) -> Vector2:
	var bounds: Rect2 = track.get("bounds",Rect2(-135,-155,270,310))
	var padding := 16.0
	var scale_value := minf((size.x-padding*2)/maxf(1,bounds.size.x),(size.y-padding*2)/maxf(1,bounds.size.y))
	return (Vector2(p.x,p.z)-bounds.get_center())*scale_value+size*0.5
func _draw() -> void:
	var outline: Array = track.get("outline",[])
	if outline.is_empty(): return
	var path := PackedVector2Array()
	for p in outline: path.append(point(p))
	path.append(path[0])
	draw_polyline(path,Color("325564"),line_width+5.0,true)
	draw_polyline(path,line_color,line_width,true)
	for car in cars: draw_circle(point(car.position),5.5 if car.id == 0 else 3.5,Color("ffcb45") if car.id == 0 else Color("f4eee1"))
	draw_rect(Rect2(point(outline[0])-Vector2(4,5),Vector2(8,10)),Color.WHITE)

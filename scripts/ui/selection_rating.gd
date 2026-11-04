class_name SelectionRating
extends Control

var value: int = 3:
	set(new_value):
		value = clampi(new_value, 0, 5)
		queue_redraw()

func _draw() -> void:
	for index: int in range(5):
		var x: float = float(index) * 50.0
		var polygon: PackedVector2Array = PackedVector2Array([Vector2(x + 7, 2), Vector2(x + 45, 0), Vector2(x + 39, 32), Vector2(x, 34)])
		var filled: bool = index < value
		draw_colored_polygon(polygon, Color("ee943d") if filled else Color("bd9bae"))
		var line: PackedVector2Array = polygon.duplicate()
		line.append(polygon[0])
		draw_polyline(line, Color("c26e33") if filled else Color("98788d"), 2.0, true)
		if filled:
			draw_line(Vector2(x + 10, 6), Vector2(x + 39, 5), Color("ffde91"), 3.0, true)
			draw_line(Vector2(x + 8, 26), Vector2(x + 25, 9), Color(1, 0.82, 0.49, 0.75), 5.0, true)

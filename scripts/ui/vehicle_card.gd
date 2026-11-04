class_name VehicleCard
extends Button

var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
var _icon: TextureRect
var _label: Label

func configure(entry: VehicleSelectionEntry, font: Font) -> void:
	custom_minimum_size = Vector2(220, 174)
	size = custom_minimum_size
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	disabled = entry.locked
	tooltip_text = "更多座驾将在后续加入" if entry.locked else entry.title
	_icon = TextureRect.new()
	_icon.texture = entry.thumbnail
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(45, 9)
	_icon.size = Vector2(130, 120)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_label = Label.new()
	_label.text = entry.card_title
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 27)
	_label.add_theme_color_override("font_color", Color("ead1da") if not entry.locked else Color("ae93b7"))
	_label.position = Vector2(13, 126)
	_label.size = Vector2(194, 37)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var polygon: PackedVector2Array = PackedVector2Array([Vector2(17, 11), Vector2(size.x - 24, 1), Vector2(size.x - 1, 21), Vector2(size.x - 12, size.y - 12), Vector2(size.x - 32, size.y - 1), Vector2(2, size.y - 14)])
	var outline: PackedVector2Array = polygon.duplicate()
	outline.append(polygon[0])
	if selected:
		draw_polyline(outline, Color(1, 0.51, 0.15, 0.12), 22.0, true)
		draw_polyline(outline, Color(1, 0.72, 0.28, 0.25), 12.0, true)
	draw_colored_polygon(polygon, Color("45304e") if selected else Color("30213f"))
	var border: Color = Color("ffe2a2") if selected else Color("93659d")
	if is_hovered() and not disabled:
		border = Color("f4bd86")
	if disabled:
		border = Color("62506e")
	draw_polyline(outline, border, 5.0 if selected else 3.0, true)
	draw_line(Vector2(25, size.y - 42), Vector2(size.x - 24, size.y - 44), Color(0.86, 0.60, 0.76, 0.18), 1.0, true)

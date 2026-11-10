extends Control

var Music:
	get: return get_node("/root/Music")


var card: Control
var now_playing: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.01, 0.09, 0.8)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = Control.new()
	card.size = Vector2(800, 760)
	add_child(card)
	var art := TextureRect.new()
	art.texture = load("res://assets/selection/info-panel.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = card.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	card.add_theme_font_override("font", font)
	card.add_theme_color_override("font_color", Color("50283f"))
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 22
	ui_theme.set_color("font_color", "Label", Color("50283f"))
	ui_theme.set_color("font_color", "CheckButton", Color("50283f"))
	ui_theme.set_color("font_focus_color", "CheckButton", Color("50283f"))
	var field := StyleBoxFlat.new()
	field.bg_color = Color("663d78")
	field.set_corner_radius_all(7)
	field.content_margin_left = 16
	ui_theme.set_stylebox("normal", "OptionButton", field)
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("765276")
	rail.content_margin_top = 5
	rail.content_margin_bottom = 5
	rail.set_corner_radius_all(5)
	ui_theme.set_stylebox("slider", "HSlider", rail)
	var fill := rail.duplicate() as StyleBoxFlat
	fill.bg_color = Color("ed9c32")
	ui_theme.set_stylebox("grabber_area", "HSlider", fill)
	ui_theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	card.theme = ui_theme
	_label("音乐设置", Vector2(95, 65), 36)
	var enabled := CheckButton.new()
	enabled.text = "播放背景音乐"
	enabled.position = Vector2(95, 125)
	enabled.size = Vector2(610, 42)
	enabled.add_theme_font_size_override("font_size", 23)
	enabled.button_pressed = Music.enabled
	enabled.toggled.connect(func(value: bool) -> void: Music.enabled = value; Music.apply_volume(); Music.save())
	card.add_child(enabled)
	_slider("音乐音量", 195, Music.music_volume, "music_volume")
	_slider("音效音量", 270, Music.sfx_volume, "sfx_volume")
	_label("播放方式", Vector2(95, 350), 23)
	var modes := OptionButton.new()
	modes.position = Vector2(285, 345)
	modes.size = Vector2(420, 45)
	for title: String in Music.MODES: modes.add_item(title)
	modes.select(Music.mode)
	modes.item_selected.connect(Music.set_mode)
	card.add_child(modes)
	_label("选择曲目", Vector2(95, 420), 23)
	var tracks := OptionButton.new()
	tracks.position = Vector2(285, 415)
	tracks.size = Vector2(420, 45)
	for title: String in Music.TITLES: tracks.add_item(title)
	tracks.select(Music.selected)
	tracks.item_selected.connect(func(index: int) -> void: Music.selected = index; Music.save())
	card.add_child(tracks)
	now_playing = _label("", Vector2(95, 480), 21)
	_label("按场景：菜单《水族馆》 · 对局《狂喜之诗》", Vector2(95, 525), 19)
	_label("试听会切换当前音乐；场景变化后恢复场景配乐。", Vector2(95, 555), 18)
	_button("试听选曲", Vector2(95, 600), func() -> void: Music.play_track(Music.selected))
	_button("下一首", Vector2(305, 600), Music.next_track)
	_button("完成", Vector2(515, 600), Music.close_settings)
	_label("设置自动保存 · Esc 关闭", Vector2(245, 675), 18)
	Music.changed.connect(_refresh)
	_refresh()
	resized.connect(_layout)
	_layout()
	enabled.grab_focus()

func _layout() -> void:
	var factor := minf(size.x / 850.0, size.y / 790.0)
	card.scale = Vector2.ONE * factor
	card.position = (size - card.size * factor) * 0.5

func _refresh() -> void:
	now_playing.text = "正在播放：" + (Music.TITLES[Music.current] if Music.current >= 0 else "等待片头结束") + ("（已静音）" if not Music.enabled or Music.music_volume == 0 else "")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Music.close_settings()

func _label(value: String, pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(label)
	return label

func _slider(title: String, y: float, value: float, key: String) -> void:
	_label(title, Vector2(95, y), 23)
	var number := _label(str(roundi(value * 100)) + "%", Vector2(635, y), 22)
	var slider := HSlider.new()
	slider.position = Vector2(285, y + 5)
	slider.size = Vector2(325, 32)
	slider.max_value = 100
	slider.value = value * 100
	slider.value_changed.connect(func(amount: float) -> void:
		Music.set(key, amount / 100)
		number.text = str(roundi(amount)) + "%"
		Music.apply_volume()
		Music.save())
	card.add_child(slider)

func _button(title: String, pos: Vector2, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.position = pos
	button.size = Vector2(190, 55)
	button.add_theme_font_size_override("font_size", 23)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("663d78")
	style.border_color = Color("be85bc")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color("fff0ce"))
	button.pressed.connect(action)
	card.add_child(button)

class_name VehicleSelect
extends Control

const DESIGN_SIZE: Vector2 = Vector2(1672, 941)
const START_PATH: String = "res://scenes/ui/start_screen.tscn"
const MATCH_PATH: String = "res://scenes/match.tscn"
const BACKGROUND: Texture2D = preload("res://assets/selection/background.png")
const HEADING: Texture2D = preload("res://assets/selection/heading.png")
const PANEL: Texture2D = preload("res://assets/selection/info-panel.png")
const STRIP: Texture2D = preload("res://assets/selection/paper-strip.png")
const TAG: Texture2D = preload("res://assets/selection/section-label.png")
const PREVIEW: PackedScene = preload("res://scenes/ui/components/vehicle_preview.tscn")

@export var entries: Array[Resource] = []
@export_range(0.0, 1.0) var transition_seconds: float = 0.3

var selected_index: int = 0
var composition: Control
var cards: Array[VehicleCard] = []
var preview: VehiclePreview
var name_label: Label
var description_label: Label
var trait_label: Label
var growth: SelectionRating
var impact: SelectionRating
var start_button: Button
var back_button: Button
var left_button: TextureButton
var right_button: TextureButton
var _name_icon: TextureRect
var _trait_icon: TextureRect
var _details: Control
var _curtain: ColorRect
var _notice: Label
var _font: SystemFont
var _body_font: SystemFont
var _fade: Tween
var _detail_tween: Tween
var _leaving: bool = false

func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["KaiTi", "STKaiti", "Microsoft YaHei"])
	_font.font_weight = 700
	_body_font = SystemFont.new()
	_body_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	_build_ui()
	resized.connect(_layout)
	_layout()
	for index: int in range(entries.size()):
		var entry: VehicleSelectionEntry = entries[index] as VehicleSelectionEntry
		if entry != null and entry.profile != null and int(entry.profile.kind) == CrashMatch.selected_vehicle:
			selected_index = index
	select_entry(selected_index, false)
	_fade_to(0.0)

func _build_ui() -> void:
	var background: TextureRect = TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	composition = Control.new()
	composition.name = "Composition"
	composition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	composition.size = DESIGN_SIZE
	add_child(composition)
	_art(composition, _atlas(HEADING, Rect2(76, 56, 1722, 718)), Rect2(26, 22, 423, 176))
	_art(composition, _atlas(PANEL, Rect2(12, 0, 1232, 1244)), Rect2(941, 25, 704, 660))
	preview = PREVIEW.instantiate() as VehiclePreview
	preview.position = Vector2(198, 184)
	preview.size = Vector2(660, 420)
	composition.add_child(preview)
	left_button = _arrow("left", Vector2(108, 366))
	right_button = _arrow("right", Vector2(847, 366))
	left_button.pressed.connect(func() -> void: cycle(-1))
	right_button.pressed.connect(func() -> void: cycle(1))

	_details = Control.new()
	_details.name = "Information"
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	composition.add_child(_details)
	_name_icon = _art(_details, null, Rect2(994, 85, 66, 64))
	name_label = _label(_details, "", Rect2(1065, 74, 515, 84), 58)
	name_label.add_theme_color_override("font_outline_color", Color("4d2b30"))
	name_label.add_theme_constant_override("outline_size", 2)
	var line: ColorRect = ColorRect.new()
	line.color = Color(0.37, 0.18, 0.22, 0.4)
	line.position = Vector2(1065, 161)
	line.size = Vector2(497, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(line)
	description_label = _label(_details, "", Rect2(1018, 182, 566, 78), 25)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_art(_details, _atlas(STRIP, Rect2(15, 111, 2134, 480)), Rect2(993, 312, 605, 179))
	_section("能力评估", Vector2(982, 264))
	_art(_details, load("res://assets/selection/icons/growth.svg") as Texture2D, Rect2(1017, 330, 54, 53))
	_label(_details, "发育", Rect2(1080, 329, 120, 44), 34)
	_label(_details, "成长效率", Rect2(1082, 370, 150, 26), 18, true)
	_art(_details, load("res://assets/selection/icons/impact.svg") as Texture2D, Rect2(1017, 409, 54, 53))
	_label(_details, "碰撞", Rect2(1080, 407, 120, 44), 34)
	_label(_details, "对抗定位", Rect2(1082, 449, 150, 26), 18, true)
	growth = SelectionRating.new()
	growth.position = Vector2(1315, 343)
	growth.size = Vector2(245, 36)
	growth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(growth)
	impact = SelectionRating.new()
	impact.position = Vector2(1315, 423)
	impact.size = Vector2(245, 36)
	impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(impact)
	var rating_note: Label = _label(_details, "能力格为定位参考", Rect2(1285, 471, 275, 27), 17, true)
	rating_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rating_note.modulate.a = 0.7
	_art(_details, _atlas(STRIP, Rect2(15, 111, 2134, 480)), Rect2(993, 548, 605, 114))
	_section("专属特性", Vector2(982, 502))
	_trait_icon = _art(_details, null, Rect2(1018, 571, 57, 57))
	trait_label = _label(_details, "", Rect2(1087, 561, 468, 99), 24)
	trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trait_label.add_theme_constant_override("line_spacing", 1)

	for index: int in range(entries.size()):
		var card: VehicleCard = VehicleCard.new()
		card.name = "VehicleCard%d" % index
		card.position = Vector2(102 + index * 244, 703)
		card.configure(entries[index] as VehicleSelectionEntry, _font)
		composition.add_child(card)
		card.pressed.connect(select_entry.bind(index))
		cards.append(card)
	start_button = _make_start_button()
	start_button.pressed.connect(start_match)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.position = Vector2(101, 889)
	back_button.size = Vector2(206, 38)
	back_button.text = "‹  返回主菜单"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.add_theme_font_override("font", _body_font)
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.add_theme_color_override("font_color", Color("f2d3c0"))
	for state: String in ["normal", "hover", "pressed", "focus"]:
		back_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	composition.add_child(back_button)
	back_button.pressed.connect(back_to_menu)
	var hint: Label = _label(composition, "A / D 或 ← / → 切换  ·  Enter 开始", Rect2(1090, 874, 535, 42), 19, true)
	hint.add_theme_color_override("font_color", Color("ead1ce"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice = _label(composition, "", Rect2(1130, 684, 485, 38), 20, true)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Color("ffdc9b"))
	_curtain = ColorRect.new()
	_curtain.color = Color(0.035, 0.018, 0.065, 1)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curtain)
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _atlas(source: Texture2D, region: Rect2) -> AtlasTexture:
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = source
	texture.region = region
	texture.filter_clip = true
	return texture

func _art(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var art: TextureRect = TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.position = rect.position
	art.size = rect.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func _label(parent: Node, text: String, rect: Rect2, font_size: int, body: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", _body_font if body else _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("4d2b30"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _section(text: String, point: Vector2) -> void:
	_art(_details, _atlas(TAG, Rect2(59, 125, 2047, 450)), Rect2(point, Vector2(253, 58)))
	var label: Label = _label(_details, text, Rect2(point + Vector2(44, 9), Vector2(165, 42)), 31)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("ffe6ce"))

func _arrow(direction: String, point: Vector2) -> TextureButton:
	var button: TextureButton = TextureButton.new()
	button.texture_normal = load("res://assets/selection/icons/" + direction + ".svg") as Texture2D
	button.position = point
	button.size = Vector2(60, 84)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "上一辆" if direction == "left" else "下一辆"
	composition.add_child(button)
	button.mouse_entered.connect(func() -> void: button.modulate = Color(1.15, 1.08, 1.0))
	button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	return button

func _make_start_button() -> Button:
	var button: Button = Button.new()
	button.name = "StartMatch"
	button.position = Vector2(1177, 733)
	button.size = Vector2(433, 118)
	button.pivot_offset = button.size * 0.5
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	composition.add_child(button)
	var art: TextureRect = _art(button, _atlas(STRIP, Rect2(15, 111, 2134, 480)), Rect2(0, 0, 433, 118))
	art.modulate = Color(1.0, 0.65, 0.25)
	var triangle: Polygon2D = Polygon2D.new()
	triangle.polygon = PackedVector2Array([Vector2(53, 38), Vector2(53, 80), Vector2(87, 59)])
	triangle.color = Color("653122")
	button.add_child(triangle)
	var caption: Label = _label(button, "开始游戏", Rect2(104, 26, 278, 72), 47)
	caption.add_theme_color_override("font_outline_color", Color("4d2b30"))
	caption.add_theme_constant_override("outline_size", 2)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.mouse_entered.connect(func() -> void: button.modulate = Color(1.06, 1.06, 1.0))
	button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	button.button_down.connect(func() -> void: button.scale = Vector2.ONE * 0.98)
	button.button_up.connect(func() -> void: button.scale = Vector2.ONE)
	return button

func _layout() -> void:
	if composition == null:
		return
	var factor: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	composition.scale = Vector2.ONE * factor
	composition.position = (size - DESIGN_SIZE * factor) * 0.5

func select_entry(index: int, animate: bool = true) -> void:
	if _leaving or index < 0 or index >= entries.size():
		return
	var entry: VehicleSelectionEntry = entries[index] as VehicleSelectionEntry
	if entry == null or entry.locked or entry.profile == null:
		return
	selected_index = index
	CrashMatch.selected_vehicle = int(entry.profile.kind)
	name_label.text = entry.title
	description_label.text = entry.introduction
	trait_label.text = entry.trait_text()
	_name_icon.texture = entry.thumbnail
	_trait_icon.texture = entry.thumbnail
	growth.value = entry.growth_rating
	impact.value = entry.collision_rating
	for card_index: int in range(cards.size()):
		cards[card_index].selected = card_index == index
	preview.set_vehicle(entry)
	if _detail_tween != null:
		_detail_tween.kill()
	_details.modulate.a = 0.45 if animate else 1.0
	if animate:
		_detail_tween = create_tween()
		_detail_tween.tween_property(_details, "modulate:a", 1.0, 0.16)

func cycle(direction: int) -> void:
	for step: int in range(1, entries.size() + 1):
		var candidate: int = posmod(selected_index + direction * step, entries.size())
		var entry: VehicleSelectionEntry = entries[candidate] as VehicleSelectionEntry
		if entry != null and not entry.locked and entry.profile != null:
			select_entry(candidate)
			return

func _unhandled_input(event: InputEvent) -> void:
	if _leaving or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_to_menu()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		start_match()
	elif event is InputEventKey and event.pressed:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_A or key == KEY_LEFT:
			cycle(-1)
		elif key == KEY_D or key == KEY_RIGHT:
			cycle(1)
		elif key >= KEY_1 and key <= KEY_3:
			select_entry(key - KEY_1)
	elif event is InputEventJoypadButton:
		if event.is_action_pressed("ui_left"):
			cycle(-1)
		elif event.is_action_pressed("ui_right"):
			cycle(1)

func _process(_delta: float) -> void:
	if _leaving:
		return
	for device: int in Input.get_connected_joypads():
		if absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_X)) > 0.5:
			if Input.is_action_just_pressed("ui_left"):
				cycle(-1)
			elif Input.is_action_just_pressed("ui_right"):
				cycle(1)

func start_match() -> void:
	if _leaving:
		return
	CrashMatch.ability_lab = false
	_leave(MATCH_PATH)

func back_to_menu() -> void:
	_leave(START_PATH)

func _leave(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	start_button.disabled = true
	back_button.disabled = true
	left_button.disabled = true
	right_button.disabled = true
	_fade_to(1.0)
	if transition_seconds > 0.0:
		await _fade.finished
	var result: Error = get_tree().change_scene_to_file(path)
	if result != OK:
		_notice.text = "暂时无法进入，请重试"
		_leaving = false
		start_button.disabled = false
		back_button.disabled = false
		left_button.disabled = false
		right_button.disabled = false
		_fade_to(0.0)

func _fade_to(alpha: float) -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(_curtain, "modulate:a", alpha, transition_seconds)

class_name StartScreen
extends Control

var Music:
	get: return get_node("/root/Music")

## Startup -> optional movie -> menu -> selection. A new scene never replays the movie.

signal intro_finished(reason: String)

enum Stage { INTRO, MENU, STARTING }

const DESIGN_SIZE: Vector2 = Vector2(1672, 941)
const SELECTION_PATH: String = "res://scenes/ui/vehicle_select.tscn"
const BACKGROUND: Texture2D = preload("res://assets/menu/background.png")
const TITLE_ATLAS: Texture2D = preload("res://assets/menu/title.png")
const BUTTON_ATLAS: Texture2D = preload("res://assets/menu/start-button.png")

static var intro_checked_this_launch: bool = false

@export_group("片头视频接口")
## Put the finished Ogg Theora video here, or assign intro_stream in the Inspector.
@export_file("*.ogv") var intro_video_path: String = "res://assets/cinematics/intro.ogv"
@export var intro_stream: VideoStream
@export var allow_intro_skip: bool = true
@export_range(0.1, 3.0) var intro_aspect_ratio: float = 16.0 / 9.0
## A stalled or invalid video must not trap the player on a black screen.
@export_range(1.0, 30.0) var intro_stall_timeout: float = 8.0
@export_group("开始界面")
@export var gentle_motion: bool = true
@export_range(0.0, 1.0) var fade_seconds: float = 0.35

var stage: Stage = Stage.MENU
var background: TextureRect
var composition: Control
var title_art: Sprite2D
var start_button: TextureButton
var video_layer: Control
var video_player: VideoStreamPlayer
var skip_button: Button
var status_label: Label
var curtain: ColorRect
var _fade: Tween
var _button_tween: Tween
var _elapsed: float = 0.0
var _intro_elapsed: float = 0.0
var _stalled_seconds: float = 0.0
var _last_video_position: float = 0.0
var _hovered: bool = false
var _using_keyboard: bool = false
var _movie_ratio: float = 16.0 / 9.0


func _ready() -> void:
	_build_ui()
	resized.connect(_layout)
	_layout()
	_boot()

func _exit_tree() -> void:
	if is_instance_valid(video_player):
		video_player.stop()
		video_player.stream = null

func _build_ui() -> void:
	background = TextureRect.new()
	background.name = "Background"
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	composition = Control.new()
	composition.name = "Composition"
	composition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(composition)
	composition.size = DESIGN_SIZE

	# Atlas regions trim transparent padding without changing the supplied PNG files.
	# GUI controls snap to whole pixels. A Sprite2D keeps slow motion subpixel-smooth.
	title_art = Sprite2D.new()
	title_art.name = "Title"
	title_art.texture = _atlas(TITLE_ATLAS, Rect2(50, 28, 1836, 733))
	title_art.centered = false
	title_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	title_art.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	title_art.position = Vector2(389, 107)
	title_art.scale = Vector2.ONE * (930.0 / 1836.0)
	composition.add_child(title_art)

	start_button = TextureButton.new()
	start_button.name = "StartButton"
	start_button.texture_normal = _atlas(BUTTON_ATLAS, Rect2(514, 518, 644, 146))
	start_button.ignore_texture_size = true
	start_button.stretch_mode = TextureButton.STRETCH_SCALE
	start_button.position = Vector2(514, 518)
	start_button.size = Vector2(644, 146)
	start_button.pivot_offset = start_button.size * 0.5
	start_button.focus_mode = Control.FOCUS_ALL
	start_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start_button.tooltip_text = "开始游戏 · Enter / 空格"
	# Only the orange plaque is clickable, not the full transparent canvas or rays.
	var mask: BitMap = BitMap.new()
	mask.create(Vector2i(644, 146))
	for y: int in range(12, 136):
		var inset: int = int(absf(float(y) - 74.0) * 0.82)
		mask.set_bit_rect(Rect2i(80 + inset, y, 484 - inset * 2, 1), true)
	start_button.texture_click_mask = mask
	composition.add_child(start_button)
	start_button.pressed.connect(start_game)
	start_button.mouse_entered.connect(func() -> void: _hovered = true; _update_button())
	start_button.mouse_exited.connect(func() -> void: _hovered = false; _update_button())
	start_button.focus_entered.connect(_update_button)
	start_button.focus_exited.connect(_update_button)
	start_button.button_down.connect(func() -> void: _animate_button(0.97, Color(0.94, 0.90, 0.92)))
	start_button.button_up.connect(_update_button)

	var music_button := Button.new()
	music_button.name = "MusicSettings"
	music_button.text = "♫ 音乐设置"
	music_button.position = Vector2(1370, 825)
	music_button.size = Vector2(230, 60)
	music_button.add_theme_font_size_override("font_size", 24)
	var music_style := StyleBoxFlat.new()
	music_style.bg_color = Color("4d285e")
	music_style.border_color = Color("b87fb1")
	music_style.set_border_width_all(2)
	music_style.set_corner_radius_all(12)
	music_button.add_theme_stylebox_override("normal", music_style)
	music_button.pressed.connect(Music.open_settings)
	composition.add_child(music_button)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.position = Vector2(456, 700)
	status_label.size = Vector2(760, 48)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 23)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.65))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	composition.add_child(status_label)

	video_layer = Control.new()
	video_layer.name = "Intro"
	add_child(video_layer)
	video_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black: ColorRect = ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_layer.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_player = VideoStreamPlayer.new()
	video_player.name = "Video"
	video_player.expand = true
	video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_player.finished.connect(func() -> void: _finish_intro("finished"))
	video_layer.add_child(video_player)
	skip_button = Button.new()
	skip_button.name = "SkipIntro"
	skip_button.text = "跳过片头  Esc"
	skip_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip_button.add_theme_font_size_override("font_size", 18)
	skip_button.pressed.connect(skip_intro)
	video_layer.add_child(skip_button)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.position = size - Vector2(208, 72)
	skip_button.size = Vector2(180, 44)
	video_layer.hide()

	curtain = ColorRect.new()
	curtain.name = "Transition"
	curtain.color = Color(0.035, 0.018, 0.065, 1)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _atlas(source: Texture2D, region: Rect2) -> AtlasTexture:
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = source
	texture.region = region
	texture.filter_clip = true
	return texture

func _layout() -> void:
	if composition == null:
		return
	var factor: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	composition.scale = Vector2.ONE * factor
	composition.position = (size - DESIGN_SIZE * factor) * 0.5
	var movie_size: Vector2 = Vector2(size.x, size.x / _movie_ratio)
	if movie_size.y > size.y:
		movie_size = Vector2(size.y * _movie_ratio, size.y)
	video_player.size = movie_size
	video_player.position = (size - movie_size) * 0.5
	skip_button.position = size - Vector2(208, 72)

func _boot() -> void:
	_movie_ratio = intro_aspect_ratio
	if intro_checked_this_launch:
		_show_menu()
		return
	intro_checked_this_launch = true
	var movie: VideoStream = intro_stream
	if movie == null and not intro_video_path.is_empty() and ResourceLoader.exists(intro_video_path):
		movie = load(intro_video_path) as VideoStream
	if movie == null:
		_show_menu()
		return
	Music.set_context("intro")
	stage = Stage.INTRO
	composition.hide()
	start_button.disabled = true
	video_layer.show()
	skip_button.visible = allow_intro_skip
	video_player.stream = movie
	video_player.play()
	_layout()
	_fade_to(0.0)

func _process(delta: float) -> void:
	_elapsed += delta
	if stage == Stage.MENU and gentle_motion:
		title_art.position.y = 107.0 + sin(_elapsed * TAU / 6.0) * 4.0
	if stage != Stage.INTRO:
		return
	_intro_elapsed += delta
	var play_position: float = video_player.stream_position
	_stalled_seconds = 0.0 if play_position > _last_video_position + 0.001 else _stalled_seconds + delta
	_last_video_position = play_position
	var frame: Texture2D = video_player.get_video_texture()
	if frame != null and frame.get_height() > 0:
		var actual_ratio: float = float(frame.get_width()) / float(frame.get_height())
		if not is_equal_approx(actual_ratio, _movie_ratio):
			_movie_ratio = actual_ratio
			_layout()
	if _stalled_seconds >= intro_stall_timeout or _intro_elapsed > 300.0:
		_finish_intro("unavailable")

func _input(event: InputEvent) -> void:
	if Music.settings_open: return
	if get_viewport().gui_get_focus_owner() == composition.get_node_or_null("MusicSettings"): return
	if event is InputEventMouseMotion:
		if _using_keyboard:
			_using_keyboard = false
			_update_button()
	elif event is InputEventKey or event is InputEventJoypadButton:
		_using_keyboard = true
	if stage == Stage.INTRO:
		if allow_intro_skip and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
			get_viewport().set_input_as_handled()
			skip_intro()
	elif stage == Stage.MENU and event.is_action_pressed("ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		start_game()

func skip_intro() -> void:
	if allow_intro_skip:
		_finish_intro("skipped")

func _finish_intro(reason: String) -> void:
	if stage != Stage.INTRO:
		return
	video_player.stop()
	video_player.stream = null
	intro_finished.emit(reason)
	_show_menu()

func _show_menu() -> void:
	stage = Stage.MENU
	video_layer.hide()
	composition.show()
	start_button.disabled = false
	curtain.modulate.a = 1.0
	_update_button()
	Music.set_context("menu")
	_fade_to(0.0)

func start_game() -> void:
	if stage != Stage.MENU or Music.settings_open:
		return
	stage = Stage.STARTING
	start_button.disabled = true
	start_button.release_focus()
	status_label.text = "正在进入…"
	_fade_to(1.0)
	if fade_seconds > 0.0:
		await _fade.finished
	# Gameplay is created only after the player confirms a vehicle in the next scene.
	CrashMatch.ability_lab = false
	var result: Error = get_tree().change_scene_to_file(SELECTION_PATH)
	if result != OK:
		status_label.text = "暂时无法开始，请重试"
		_show_menu()

func _update_button() -> void:
	if start_button == null or stage != Stage.MENU:
		return
	var highlighted: bool = _hovered or (_using_keyboard and start_button.has_focus())
	_animate_button(1.025 if highlighted and gentle_motion else 1.0, Color(1.1, 1.065, 1.025) if highlighted else Color.WHITE)

func _animate_button(factor: float, tint: Color) -> void:
	if _button_tween != null:
		_button_tween.kill()
	_button_tween = create_tween().set_parallel(true)
	_button_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_button_tween.tween_property(start_button, "scale", Vector2.ONE * factor, 0.12)
	_button_tween.tween_property(start_button, "modulate", tint, 0.12)

func _fade_to(alpha: float) -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(curtain, "modulate:a", alpha, fade_seconds)

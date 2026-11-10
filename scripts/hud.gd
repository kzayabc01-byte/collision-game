class_name PrototypeHUD
extends CanvasLayer

signal restart_requested
signal pause_requested
signal vehicle_requested(kind: int)
signal lab_requested
signal menu_requested
signal selection_requested

const INK: Color = Color("54272e")
const CREAM: Color = Color("fff0d5")
const ART_PATH: String = "res://assets/battle_ui/"
var candy_label: Label
var speed_label: Label
var mass_label: Label
var clock_label: Label
var notice_label: Label
var ranking_label: Label
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var role_label: Label
var ability_label: Label
var speed_bar: TextureProgressBar
var rank_label: Label
var gain_label: Label
var state_label: Label
var state_art: TextureRect
var avatar: TextureRect
var root: Control
var stats: Control
var leaderboard: Control
var timer: Control
var help: Control
var left_corner: TextureRect
var right_corner: TextureRect
var marker: Control
var marker_ring: MeshInstance3D
var pause_button: Button
var resume_button: Button
var restart_button: Button
var modal: Control
var modal_art: TextureRect
var trophy: TextureRect
var result_rows: Label
var gain_art: TextureRect
var buffs: Control
var defense_label: Label
var acceleration_label: Label
var drive_label: Label
var _font: SystemFont
var _heading_font: SystemFont
var _textures: Dictionary = {}
var _regions: Dictionary = {}
var _rank_rows: Array[Label] = []
var _rank_highlight: TextureRect
var _player: CrashCar
var _notice_remaining: float = 0.0
var _gain_remaining: float = 0.0
var _gain_sum: int = 0
var _lab: bool = false
var _scale: float = 1.0
var _ordered: Array[CrashCar] = []

func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	_heading_font = SystemFont.new()
	_heading_font.font_names = PackedStringArray(["KaiTi", "STKaiti", "Microsoft YaHei"])
	_heading_font.font_weight = 700
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(ART_PATH + "manifest.json"))
	for item: Dictionary in manifest:
		_regions[item["name"]] = item["layout_bounds_alpha32"]
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()

func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		var tex: AtlasTexture = AtlasTexture.new()
		tex.atlas = load(ART_PATH + id + ".png") as Texture2D
		var b: Array = _regions[id]
		tex.region = Rect2(float(b[0]), float(b[1]), float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
		tex.filter_clip = true
		_textures[id] = tex
	return _textures[id] as Texture2D

func _control(parent: Node, title: String, rect: Rect2) -> Control:
	var node: Control = Control.new()
	node.name = title
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _art(parent: Node, id: String, rect: Rect2) -> TextureRect:
	var node: TextureRect = TextureRect.new()
	parent.add_child(node)
	node.texture = texture(id)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _label(parent: Node, text: String, rect: Rect2, font_size: int = 22, color: Color = INK, heading: bool = false) -> Label:
	var node: Label = Label.new()
	parent.add_child(node)
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", _heading_font if heading else _font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _unique(node: Node, id: String) -> void:
	node.name = id
	node.owner = self
	node.unique_name_in_owner = true

func _button(parent: Node, id: String, text: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var node: Button = Button.new()
	parent.add_child(node)
	_unique(node, id)
	node.position = rect.position
	node.size = rect.size
	node.focus_mode = Control.FOCUS_NONE
	node.text = text
	node.add_theme_font_override("font", _heading_font)
	node.add_theme_font_size_override("font_size", 27)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		node.add_theme_color_override(state, INK if primary else CREAM)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		node.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var art: TextureRect = _art(node, "button_primary" if primary else "button_secondary", Rect2(Vector2.ZERO, rect.size))
	art.show_behind_parent = true
	node.mouse_entered.connect(func() -> void: art.modulate = Color(1.12, 1.12, 1.12))
	node.mouse_exited.connect(func() -> void: art.modulate = Color.WHITE)
	node.button_down.connect(func() -> void: art.modulate = Color(0.85, 0.85, 0.85))
	node.button_up.connect(func() -> void: art.modulate = Color.WHITE)
	node.pressed.connect(action)
	return node

func _build() -> void:
	root = _control(self, "Root", Rect2(0, 0, 1672, 941))
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	marker = _control(root, "PlayerMarker", Rect2(0, 0, 58, 62))
	_art(marker, "player_pointer", Rect2(0, 0, 58, 62))
	var you: Label = _label(marker, "你", Rect2(0, 0, 58, 44), 29, INK, true)
	you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats = _control(root, "Stats", Rect2(16, 16, 470, 258))
	_art(stats, "status_panel", Rect2(0, 0, 470, 258))
	_art(stats, "title_strip", Rect2(84, 3, 258, 52))
	role_label = _label(stats, "小马车", Rect2(104, 6, 219, 42), 29, CREAM, true)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar = _art(stats, "avatar_pony", Rect2(29, 27, 65, 69))
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art(stats, "portrait_frame", Rect2(15, 17, 92, 92))
	_art(stats, "icon_candy", Rect2(111, 63, 47, 40))
	candy_label = _label(stats, "20", Rect2(167, 49, 100, 64), 47, INK, true)
	rank_label = _label(stats, "第 1 / 4 名", Rect2(325, 71, 122, 32), 21)
	gain_art = _art(stats, "gain_badge", Rect2(264, 53, 52, 52))
	gain_label = _label(gain_art, "", Rect2(0, 0, 52, 52), 22)
	gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gain_art.hide()
	speed_label = _label(stats, "速度 0.0 / 9", Rect2(30, 115, 150, 31), 22)
	_art(stats, "speed_track", Rect2(189, 121, 245, 24))
	speed_bar = TextureProgressBar.new()
	stats.add_child(speed_bar)
	speed_bar.position = Vector2(192, 124)
	speed_bar.size = Vector2(239, 18)
	speed_bar.nine_patch_stretch = true
	speed_bar.texture_progress = texture("speed_fill")
	speed_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_art = _art(stats, "tag_active", Rect2(27, 151, 154, 36))
	state_label = _label(state_art, "×2 生效", Rect2(0, 0, 154, 36), 23)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_label = _label(stats, "", Rect2(190, 144, 248, 52), 18)
	ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drive_label = _label(stats, "", Rect2(36, 203, 402, 28), 17)
	buffs = _control(stats, "Buffs", Rect2(190, 182, 248, 25))
	_art(buffs, "icon_shield", Rect2(0, 0, 23, 25))
	defense_label = _label(buffs, "", Rect2(27, 0, 91, 25), 17)
	_art(buffs, "icon_acceleration", Rect2(124, 0, 22, 25))
	acceleration_label = _label(buffs, "", Rect2(150, 0, 98, 25), 17)
	buffs.hide()
	mass_label = _label(stats, "", Rect2())
	mass_label.hide()
	timer = _control(root, "Timer", Rect2(0, 16, 402, 70))
	_art(timer, "title_strip", Rect2(0, 0, 402, 70))
	_art(timer, "icon_hourglass", Rect2(24, 10, 40, 49))
	_label(timer, "剩余时间", Rect2(78, 15, 130, 40), 27, CREAM, true)
	clock_label = _label(timer, "03:00", Rect2(215, 6, 165, 56), 46, CREAM, true)
	pause_button = _button(root, "PauseButton", "Ⅱ 暂停 Esc", Rect2(0, 16, 185, 52), func() -> void: pause_requested.emit())
	leaderboard = _control(root, "Leaderboard", Rect2(0, 86, 310, 257))
	_art(leaderboard, "ranking_panel", Rect2(0, 18, 310, 239))
	_art(leaderboard, "title_strip", Rect2(25, 0, 260, 52))
	_art(leaderboard, "icon_lollipop", Rect2(29, 3, 42, 46))
	_label(leaderboard, "糖果排行", Rect2(79, 3, 190, 42), 30, CREAM, true)
	_rank_highlight = _art(leaderboard, "rank_highlight", Rect2(24, 62, 266, 39))
	for i: int in range(4):
		_rank_rows.append(_label(leaderboard, "", Rect2(37, 59 + i * 44, 240, 38), 25, INK, true))
	ranking_label = _label(leaderboard, "", Rect2())
	ranking_label.hide()
	left_corner = _art(root, "corner_lantern", Rect2(0, 0, 210, 140))
	right_corner = _art(root, "corner_candles", Rect2(0, 0, 170, 100))
	help = _control(root, "Help", Rect2(0, 0, 514, 45))
	_art(help, "title_strip", Rect2(0, 0, 514, 45))
	var controls: Label = _label(help, "W/S 前后 · A/D 转向 · Shift 刹车", Rect2(20, 0, 474, 45), 22, CREAM)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label = _label(root, "", Rect2(0, 102, 620, 60), 22, CREAM)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.03, 0.16, 0.9))
	notice_label.add_theme_constant_override("shadow_offset_y", 2)
	_build_overlay()
	# The pause toggle stays clickable above the full-screen overlay.
	root.move_child(pause_button, -1)

func _build_overlay() -> void:
	overlay = _control(root, "Overlay", Rect2())
	_unique(overlay, "Overlay")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.06, 0.025, 0.12, 0.74)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal = _control(overlay, "Modal", Rect2(0, 0, 690, 745))
	modal_art = _art(modal, "modal_pause", Rect2(0, 0, 690, 745))
	trophy = _art(modal, "icon_trophy", Rect2(291, 0, 108, 95))
	overlay_title = _label(modal, "比赛暂停", Rect2(60, 91, 570, 65), 45, INK, true)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body = _label(modal, "", Rect2(60, 161, 570, 85), 27)
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_rows = _label(modal, "", Rect2(130, 254, 430, 159), 26)
	result_rows.add_theme_constant_override("line_spacing", 7)
	resume_button = _button(modal, "ResumeButton", "▶ 继续游戏", Rect2(145, 292, 400, 75), func() -> void: pause_requested.emit(), true)
	restart_button = _button(modal, "PlayAgainButton", "重新开始  R", Rect2(165, 392, 360, 64), func() -> void: restart_requested.emit())
	_button(modal, "SelectVehicleButton", "更换座驾", Rect2(165, 474, 360, 62), func() -> void: selection_requested.emit())
	_button(modal, "MenuButton", "返回主菜单", Rect2(165, 554, 360, 62), func() -> void: menu_requested.emit())
	var lab: Button = _button(modal, "LabButton", "能力试验 F2", Rect2(200, 639, 290, 44), func() -> void: lab_requested.emit())
	lab.add_theme_font_size_override("font_size", 21)
	overlay.hide()

func _layout() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	_scale = minf(view.x / 1672.0, view.y / 941.0)
	root.scale = Vector2.ONE * _scale
	root.size = view / _scale
	timer.position.x = (root.size.x - timer.size.x) * 0.5
	pause_button.position.x = root.size.x - 201
	leaderboard.position.x = root.size.x - 326
	left_corner.position = Vector2(0, root.size.y - 140)
	right_corner.position = root.size - Vector2(170, 100)
	help.position = root.size - Vector2(620, 64)
	notice_label.position.x = (root.size.x - notice_label.size.x) * 0.5
	overlay.size = root.size
	modal.position = (root.size - modal.size) * 0.5

func configure_vehicle(kind: int, lab: bool) -> void:
	_lab = lab
	avatar.texture = texture(["avatar_pony", "avatar_pumpkin", "avatar_slime"][clampi(kind, 0, 2)])
	(get_node("%LabButton") as Button).text = "返回对局 F2" if lab else "能力试验 F2"

func bind_player(player: CrashCar) -> void:
	if is_instance_valid(_player) and _player.candy_collected.is_connected(_on_collected):
		_player.candy_collected.disconnect(_on_collected)
	_player = player
	_player.candy_collected.connect(_on_collected)
	_player.name_label.hide()
	if marker_ring != player.player_ring:
		if is_instance_valid(marker_ring):
			marker_ring.hide()
		_configure_ground_ring(player)
	_update_marker()

func _configure_ground_ring(player: CrashCar) -> void:
	var art: AtlasTexture = texture("player_ring") as AtlasTexture
	var atlas_size: Vector2 = art.atlas.get_size()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = art.atlas
	material.uv1_offset = Vector3(art.region.position.x / atlas_size.x, art.region.position.y / atlas_size.y, 0.0)
	material.uv1_scale = Vector3(art.region.size.x / atlas_size.x, art.region.size.y / atlas_size.y, 1.0)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2.ONE * player.tuning.base_collision_radius * 2.8
	marker_ring = player.player_ring
	marker_ring.mesh = plane
	marker_ring.material_override = material
	marker_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	if not overlay.visible:
		_notice_remaining = maxf(0.0, _notice_remaining - delta)
		_gain_remaining = maxf(0.0, _gain_remaining - delta)
	notice_label.modulate.a = minf(_notice_remaining, 1.0)
	gain_art.visible = _gain_remaining > 0.0
	gain_art.modulate.a = minf(_gain_remaining * 2.0, 1.0)
	_update_marker()

func _update_marker() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var show_marker: bool = is_instance_valid(_player) and _player.alive and not overlay.visible and camera != null
	if show_marker:
		show_marker = not camera.is_position_behind(_player.global_position)
	marker.visible = show_marker
	if is_instance_valid(marker_ring):
		marker_ring.visible = show_marker
	if not show_marker:
		return
	var top: Vector2 = camera.unproject_position(_player.name_label.global_position + Vector3.UP * 0.5) / _scale
	marker.position = top - Vector2(29, 64)
	var rect: Rect2 = Rect2(marker.position, marker.size)
	if not Rect2(Vector2.ZERO, root.size).encloses(rect):
		marker.hide()
	for panel: Control in [stats, leaderboard, timer, pause_button]:
		if rect.intersects(Rect2(panel.position, panel.size)):
			marker.hide()

func refresh(player: CrashCar, cars: Array[CrashCar], remaining: float) -> void:
	candy_label.text = str(player.candy)
	speed_label.text = "速度 %.1f / %.1f" % [player.velocity.length(), player.tuning.top_speed]
	speed_bar.value = clampf(player.velocity.length() / maxf(player.tuning.top_speed, 0.01) * 100.0, 0, 100)
	mass_label.text = "质量 %.2f · 尺寸 %.2f" % [player.vehicle_mass, CollisionMath.scale_for(player.candy, player.tuning)]
	var seconds: int = maxi(0, ceili(remaining))
	clock_label.text = "能力试验" if _lab else "%02d:%02d" % [seconds / 60, seconds % 60]
	clock_label.add_theme_font_size_override("font_size", 29 if _lab else 46)
	clock_label.add_theme_color_override("font_color", Color("ffba79") if remaining <= 10 and not _lab else CREAM)
	_ordered = cars.duplicate()
	_ordered.sort_custom(func(a: CrashCar, b: CrashCar) -> bool: return a.candy > b.candy)
	var rows: PackedStringArray = []
	var player_rank: int = 1
	for i: int in range(_ordered.size()):
		var car: CrashCar = _ordered[i]
		var rank: int = 1
		for other: CrashCar in _ordered:
			if other.candy > car.candy:
				rank += 1
		var row: String = "%d   %s    %d" % [rank, "你" if car == player else car.driver_name, car.candy]
		rows.append(row)
		if i < _rank_rows.size():
			_rank_rows[i].text = row
		if car == player:
			player_rank = rank
			_rank_highlight.position.y = 60 + i * 44
	ranking_label.text = "\n".join(rows)
	rank_label.text = "第 %d / %d 名" % [player_rank, cars.size()]
	_refresh_ability(player)

func _refresh_ability(player: CrashCar) -> void:
	var profile: VehicleProfile = player.profile
	if profile == null:
		return
	role_label.text = profile.display_name
	buffs.hide()
	var active: bool = false
	match profile.kind:
		VehicleProfile.Kind.PONY:
			active = player.has_double_pickup()
			state_label.text = "×2 生效" if active else "普通拾取"
			ability_label.text = "少于 %d 颗时翻倍\n自掉糖不翻倍" % profile.double_below if active else "已达 %d 颗，×2 关闭\n低于阈值后恢复" % profile.double_below
		VehicleProfile.Kind.PUMPKIN:
			active = true
			state_label.text = "车头吞噬"
			ability_label.text = "目标尺寸 ≤ 自身 %.1f%%\n车头接触，获得全部糖果" % (profile.swallow_size_ratio * 100)
		VehicleProfile.Kind.SLIME:
			active = player.rolling
			state_label.text = "滚动中" if active else "小脚走路"
			ability_label.text = "速度 > %.1f，滚动增益生效" % profile.roll_threshold if active else "速度超过 %.1f 自动滚动" % profile.roll_threshold
			buffs.visible = active and player.alive
			defense_label.text = "减伤 %.1f%%" % roundf((1 - profile.rolling_damage_multiplier) * 100)
			acceleration_label.text = "加速 +%.1f%%" % roundf((profile.rolling_acceleration_multiplier - 1) * 100)
	if not player.alive:
		active = false
		state_label.text = "等待重生"
		ability_label.text = "%.1f 秒后返回赛场\n能力暂未生效" % player.respawn_remaining
	state_art.texture = texture("tag_active" if active else "tag_inactive")
	drive_label.text = "Shift 刹车 · 转向可漂移"
	if player.burst_remaining > 0:
		drive_label.text = "弹射中 · Shift 可中断"
	elif player.burst_ready:
		drive_label.text = "弹射就绪 · 保持 W，松开 Shift"
	elif player.drifting:
		drive_label.text = "漂移中 · 转向后松 Shift 弹射"
	elif player.burst_cooldown > 0:
		drive_label.text = "弹射冷却 %.1f 秒 · 刹车可用" % player.burst_cooldown

func _on_collected(_car: CrashCar, gained: int, _bonus: int) -> void:
	_gain_sum = _gain_sum + gained if _gain_remaining > 1.8 else gained
	_gain_remaining = 2.0
	gain_label.text = "+%d" % _gain_sum
	gain_label.add_theme_font_size_override("font_size", 18 if _gain_sum >= 100 else 22)

func on_swallow(eater: CrashCar, _prey: CrashCar, gained: int) -> void:
	if eater == _player:
		announce("吞噬成功  +%d 颗糖果" % gained)

func announce(message: String) -> void:
	notice_label.text = message
	_notice_remaining = 2.4

func show_overlay(title: String, body: String) -> void:
	var paused: bool = title == "比赛暂停"
	overlay_title.text = title
	overlay_body.text = "休息一下，糖果等你回来\nEsc 继续 · R 重新开始" if paused else body
	modal_art.texture = texture("modal_pause" if paused else "modal_results")
	trophy.visible = not paused
	resume_button.visible = paused
	restart_button.text = "重新开始  R" if paused else "再来一局  R"
	restart_button.position.y = 392 if paused else 424
	(get_node("%SelectVehicleButton") as Button).position.y = 474 if paused else 506
	(get_node("%MenuButton") as Button).position.y = 554 if paused else 586
	(get_node("%LabButton") as Button).visible = paused
	result_rows.visible = not paused
	result_rows.text = ranking_label.text
	result_rows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.show()
	pause_button.text = "Ⅱ 继续 Esc" if paused else "比赛结束"
	pause_button.disabled = not paused
	_update_marker()

func hide_overlay() -> void:
	overlay.hide()
	pause_button.text = "Ⅱ 暂停 Esc"
	pause_button.disabled = false

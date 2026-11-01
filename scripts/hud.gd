class_name PrototypeHUD
extends CanvasLayer

signal restart_requested
signal pause_requested
signal vehicle_requested(kind: int)
signal lab_requested

var _notice_remaining: float = 0.0
var _lab: bool = false

@onready var candy_label: Label = %CandyValue
@onready var speed_label: Label = %SpeedValue
@onready var mass_label: Label = %MassValue
@onready var clock_label: Label = %ClockValue
@onready var speed_bar: ProgressBar = %SpeedBar
@onready var notice_label: Label = %Notice
@onready var ranking_label: Label = %Ranking
@onready var overlay: PanelContainer = %Overlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_body: Label = %OverlayBody
@onready var role_label: Label = %RoleName
@onready var ability_label: Label = %AbilityState

func _ready() -> void:
	(%RestartButton as Button).pressed.connect(func() -> void: restart_requested.emit())
	(%PauseButton as Button).pressed.connect(func() -> void: pause_requested.emit())
	(%PlayAgainButton as Button).pressed.connect(func() -> void: restart_requested.emit())
	(%PonyButton as Button).pressed.connect(func() -> void: vehicle_requested.emit(0))
	(%PumpkinButton as Button).pressed.connect(func() -> void: vehicle_requested.emit(1))
	(%SlimeButton as Button).pressed.connect(func() -> void: vehicle_requested.emit(2))
	(%LabButton as Button).pressed.connect(func() -> void: lab_requested.emit())

func configure_vehicle(kind: int, lab: bool) -> void:
	_lab = lab
	var buttons: Array[Button] = [%PonyButton, %PumpkinButton, %SlimeButton]
	for index: int in range(buttons.size()):
		buttons[index].disabled = index == kind
	(%LabButton as Button).text = "返回对局 F2" if lab else "能力试验 F2"

func _process(delta: float) -> void:
	_notice_remaining = maxf(0.0, _notice_remaining - delta)
	notice_label.modulate.a = clampf(_notice_remaining, 0.0, 1.0)

func refresh(player: CrashCar, cars: Array[CrashCar], remaining: float) -> void:
	candy_label.text = str(player.candy)
	speed_label.text = "%.1f / %.0f" % [player.velocity.length(), player.tuning.top_speed]
	mass_label.text = "质量 %.2f  ·  尺寸 %.2f×" % [player.vehicle_mass, CollisionMath.scale_for(player.candy, player.tuning)]
	clock_label.text = "%02d:%02d" % [int(ceil(remaining)) / 60, int(ceil(remaining)) % 60]
	if _lab:
		clock_label.text = "试验"
	speed_bar.value = player.velocity.length() / player.tuning.top_speed * 100.0
	var ordered: Array[CrashCar] = cars.duplicate()
	ordered.sort_custom(func(a: CrashCar, b: CrashCar) -> bool: return a.candy > b.candy)
	var rows: PackedStringArray = PackedStringArray()
	for index: int in range(ordered.size()):
		var car: CrashCar = ordered[index]
		rows.append("%d  %s     %d" % [index + 1, car.driver_name, car.candy])
	ranking_label.text = "\n".join(rows)
	if player.profile != null:
		role_label.text = player.profile.display_name
		role_label.modulate = player.profile.accent
		match player.profile.kind:
			VehicleProfile.Kind.PONY:
				ability_label.text = "拾糖 ×2 生效 · 自己掉落的糖不翻倍" if player.has_double_pickup() else "已达40颗 · 普通拾取；跌回40以下恢复 ×2"
			VehicleProfile.Kind.PUMPKIN:
				var target_scale: float = CollisionMath.scale_for(player.candy, player.tuning) * player.profile.swallow_size_ratio
				ability_label.text = "车头吞噬：目标尺寸 ≤ %.2f× · 获得目标全部糖果" % target_scale
			VehicleProfile.Kind.SLIME:
				ability_label.text = "滚动：受伤 -30% / 蓄速 +50% / 转90°减速7.5%" if player.rolling else "小脚走路 · 速度超过4后收脚滚动"
		if not player.alive:
			ability_label.text = "等待重生 · 能力暂未生效"
	if not player.alive:
		notice_label.text = "车辆被击溃 · %.1f 秒后重生" % player.respawn_remaining
		_notice_remaining = 1.2

func announce(message: String) -> void:
	notice_label.text = message
	_notice_remaining = 2.4

func show_overlay(title: String, body: String) -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay.show()

func hide_overlay() -> void:
	overlay.hide()

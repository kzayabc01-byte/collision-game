extends Node3D
## The preview uses the real vehicles and collision resolver, including candy transfer.

var _busy: bool = false
var _dragging: bool = false
var _reset_token: int = 0

@onready var pumpkin: CrashCar = $Pumpkin
@onready var prey: CrashCar = $Prey
@onready var resolver: CollisionResolver = $CollisionResolver
@onready var orbit: Node3D = $CameraOrbit
@onready var status: Label = $UI/Panel/Rows/Status
@onready var swallow_button: Button = $UI/Panel/Rows/Buttons/Swallow

func _ready() -> void:
	resolver.candy_system = $CandySystem as CandySystem
	swallow_button.pressed.connect(play_swallow)
	($UI/Panel/Rows/Buttons/Reset as Button).pressed.connect(reset_preview)
	($UI/Panel/Rows/Buttons/Play as Button).pressed.connect(func() -> void:
		CrashMatch.selected_vehicle = 1
		CrashMatch.ability_lab = true
		get_tree().change_scene_to_file("res://scenes/match.tscn"))
	reset_preview()

func reset_preview() -> void:
	_reset_token += 1
	_busy = false
	swallow_button.disabled = false
	pumpkin.reset_at(Vector3.ZERO)
	pumpkin.set_candy(80)
	pumpkin.growth_root.scale = Vector3.ONE * CollisionMath.scale_for(80, pumpkin.tuning)
	prey.reset_at(Vector3(0, 0, -2.35))
	prey.growth_root.scale = Vector3.ONE
	for car: CrashCar in [pumpkin, prey]:
		car.name_label.hide()
		car.feedback.set_speed(0.0, true)
	resolver.clear_for(pumpkin)
	status.text = "南瓜 80 颗  /  目标 20 颗 · 线性尺寸 2 : 1"

func play_swallow() -> void:
	if _busy:
		return
	reset_preview()
	_busy = true
	swallow_button.disabled = true
	var token: int = _reset_token
	# A physics tick registers the reset body transforms before the real swept contact.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if token != _reset_token:
		return
	pumpkin.velocity = Vector3.FORWARD * 1.0
	pumpkin.snapshot()
	prey.snapshot()
	resolver.begin_tick(1.0)
	resolver.record(pumpkin, pumpkin.move_vehicle(0.2))
	resolver.resolve_events()
	pumpkin.velocity = Vector3.ZERO
	status.text = "张嘴 → 吞入 → 咬合 → 回弹"
	await get_tree().create_timer(0.95).timeout
	if token != _reset_token:
		return
	status.text = "吞噬完成 · 南瓜 %d 颗 · 再按一次可重播" % pumpkin.candy
	_busy = false
	swallow_button.disabled = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		orbit.rotation.y -= event.relative.x * 0.006
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			play_swallow()
		elif event.keycode == KEY_R:
			reset_preview()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_dragging = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_dragging = false

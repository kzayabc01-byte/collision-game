extends Node3D

var _elapsed: float = 0.0
var _next_bite: float = 0.8
var _next_pickup: float = 1.1
var _paused: bool = false

@onready var pony: VehicleVisual = $Pony
@onready var pumpkin: VehicleVisual = $Pumpkin
@onready var slime: VehicleVisual = $Slime
@onready var state_label: Label = $Labels/SlimeState

func _ready() -> void:
	($Labels/PlayButton as Button).pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/match.tscn"))

func _process(delta: float) -> void:
	if _paused:
		return
	_elapsed += delta
	var rolling: bool = fmod(_elapsed, 8.0) >= 4.0
	pony.animate(delta, 2.5, 1.0, false, true)
	pumpkin.animate(delta, 2.0, 1.0, false, false)
	slime.animate(delta, 6.0 if rolling else 3.0, 1.0, rolling, false)
	state_label.text = "滚动中 · 速度 6.0" if rolling else "小脚走路 · 速度 3.0"
	if _elapsed >= _next_bite:
		_next_bite += 3.0
		pumpkin.swallow()
	if _elapsed >= _next_pickup:
		_next_pickup += 2.0
		pony.pickup()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_paused = not _paused
		for visual: VehicleVisual in [pony, pumpkin, slime]:
			visual.animations.speed_scale = 0.0 if _paused else 1.0

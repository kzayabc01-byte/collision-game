extends Node3D

@export var shake_enabled: bool = true
var _strength: float = 0.0

@onready var camera: Camera3D = $Camera3D
@onready var _base_position: Vector3 = camera.position

func _process(delta: float) -> void:
	_strength = move_toward(_strength, 0.0, delta * 1.7)
	var offset: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _strength
	camera.position = _base_position + offset

func shake(tier: int) -> void:
	if shake_enabled:
		_strength = maxf(_strength, 0.035 + tier * 0.065)

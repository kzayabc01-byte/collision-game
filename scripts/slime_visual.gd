extends VehicleVisual
## The editable roll_pose clip owns deformation; this script supplies speed and phase.

@onready var morph_player: AnimationPlayer = $MorphPlayer
@onready var jelly: MeshInstance3D = $Motion/Model/SlimeArt/RollRoot/JellyBody

func _ready() -> void:
	super._ready()
	roll_root = $Motion/Model/SlimeArt/RollRoot as Node3D
	_prepare_morph()

func animate(delta: float, speed: float, size_scale: float, rolling: bool, _bonus: bool) -> void:
	_phase += speed * delta * 3.5 / maxf(0.5, size_scale)
	_rolling = rolling
	var fold_target: float = 1.0 if rolling else 0.0
	if not rolling:
		roll_root.rotation.x = wrapf(roll_root.rotation.x, -PI, PI)
		# Keep the hat tucked until the body is upright, including abrupt wall slowdowns.
		if absf(roll_root.rotation.x) > 0.06:
			fold_target = 1.0
			roll_root.rotation.x = lerpf(roll_root.rotation.x, 0.0, 1.0 - exp(-14.0 * delta))
		else:
			roll_root.rotation.x = 0.0
	_roll_blend = lerpf(_roll_blend, fold_target, 1.0 - exp(-transition_speed * delta))
	if rolling and _roll_blend > 0.9:
		# Model is turned 180 degrees in its wrapper: positive local X rolls forward.
		roll_root.rotation.x = wrapf(roll_root.rotation.x + speed * delta / (roll_radius * size_scale), -PI, PI)
	_apply_morph(_roll_blend)
	for index: int in range(_feet.size()):
		var step: float = sin(_phase + index * PI) * minf(speed / 3.0, 1.0)
		_feet[index].position = _foot_origins[index] + Vector3(0, maxf(0.0, step) * 0.09 + _roll_blend * 0.28, step * 0.12 * (1.0 - _roll_blend))
		_feet[index].scale = _foot_scales[index] * maxf(0.001, 1.0 - _roll_blend)
		_feet[index].visible = _roll_blend < 0.98
	motion.position.y = absf(sin(_phase)) * 0.035 * (1.0 - _roll_blend)
	if defense_ring != null:
		defense_ring.visible = _roll_blend > 0.1
		defense_ring.rotation.y += delta * 1.4

func reset_pose() -> void:
	super.reset_pose()
	_prepare_morph()

func _prepare_morph() -> void:
	morph_player.play("roll_pose")
	morph_player.pause()
	_apply_morph(0.0)

func _apply_morph(weight: float) -> void:
	morph_player.seek(clampf(weight, 0.0, 1.0) * morph_player.get_animation("roll_pose").length, true)

extends VehicleVisual

@onready var tail: Node3D = $Motion/Model/PonyArt/Tail

func _ready() -> void:
	super._ready()
	bonus_marker = $Motion/Model/PonyArt/BonusMarker as Node3D

func animate(delta: float, speed: float, size_scale: float, rolling: bool, bonus: bool) -> void:
	super.animate(delta, speed, size_scale, rolling, bonus)
	if not animations.is_playing():
		tail.rotation.y = sin(_phase * 0.35) * minf(speed * 0.025, 0.14)

func reset_pose() -> void:
	super.reset_pose()
	tail.rotation = Vector3.ZERO

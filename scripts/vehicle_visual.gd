class_name VehicleVisual
extends Node3D

@export var kind: VehicleProfile.Kind = VehicleProfile.Kind.PONY
@export var wheel_radius: float = 0.18
@export var roll_radius: float = 0.72
@export var transition_speed: float = 9.0
@export var wheel_paths: Array[NodePath] = []
@export var foot_paths: Array[NodePath] = []
@export var jaw_path: NodePath = NodePath("Motion/Jaw")
@export var appetite_angle: float = -0.2
@export var wheel_spin_direction: float = -1.0
@export var swallow_pull_delay: float = 0.0
@export var swallow_pull_seconds: float = 0.28

var _phase: float = 0.0
var _roll_blend: float = 0.0
var _rolling: bool = false
var _wheels: Array[Node3D] = []
var _feet: Array[Node3D] = []
var _foot_origins: Array[Vector3] = []
var _foot_scales: Array[Vector3] = []

@onready var motion: Node3D = $Motion
@onready var animations: AnimationPlayer = $AnimationPlayer
@onready var mouth_socket: Marker3D = $Sockets/MouthSocket
@onready var roll_root: Node3D = get_node_or_null("Motion/RollRoot") as Node3D
@onready var defense_ring: Node3D = get_node_or_null("DefenseRing") as Node3D
@onready var bonus_marker: Node3D = get_node_or_null("BonusMarker") as Node3D
@onready var jaw: Node3D = get_node_or_null(jaw_path) as Node3D

func _ready() -> void:
	for path: NodePath in wheel_paths:
		_wheels.append(get_node(path) as Node3D)
	for path: NodePath in foot_paths:
		var foot: Node3D = get_node(path) as Node3D
		_feet.append(foot)
		_foot_origins.append(foot.position)
		_foot_scales.append(foot.scale)

func animate(delta: float, speed: float, size_scale: float, rolling: bool, bonus: bool) -> void:
	_phase += speed * delta * 3.5 / maxf(0.5, size_scale)
	for wheel: Node3D in _wheels:
		wheel.rotation.x += wheel_spin_direction * speed * delta / (wheel_radius * size_scale)
	if bonus_marker != null:
		bonus_marker.visible = bonus
		bonus_marker.rotation.y += delta * 1.8
	if kind != VehicleProfile.Kind.SLIME:
		motion.position.y = sin(_phase) * minf(speed * 0.003, 0.025)
		return
	if rolling != _rolling and not rolling:
		# End on the nearest complete revolution rather than snapping the body.
		if roll_root != null:
			roll_root.rotation.x = wrapf(roll_root.rotation.x, -PI, PI)
	_rolling = rolling
	_roll_blend = lerpf(_roll_blend, 1.0 if rolling else 0.0, 1.0 - exp(-transition_speed * delta))
	if roll_root != null:
		if rolling:
			roll_root.rotation.x -= speed * delta / (roll_radius * size_scale)
		else:
			roll_root.rotation.x = lerpf(roll_root.rotation.x, 0.0, 1.0 - exp(-10.0 * delta))
		roll_root.scale = Vector3(1.0 + (1.0 - _roll_blend) * 0.08, 0.86 + _roll_blend * 0.14, 1.0)
	for index: int in range(_feet.size()):
		var foot: Node3D = _feet[index]
		var step: float = sin(_phase + index * PI) * minf(speed / 3.0, 1.0)
		foot.position = _foot_origins[index] + Vector3(0, maxf(0.0, step) * 0.13 + _roll_blend * 0.35, step * 0.15)
		foot.scale = _foot_scales[index] * maxf(0.001, 1.0 - _roll_blend)
		foot.visible = _roll_blend < 0.98
	motion.position.y = absf(sin(_phase)) * 0.045 * (1.0 - _roll_blend)
	if defense_ring != null:
		defense_ring.visible = _roll_blend > 0.1
		defense_ring.rotation.y += delta * 2.0
		defense_ring.scale = Vector3.ONE * (0.92 + _roll_blend * 0.08)

func pickup() -> void:
	if animations.has_animation("pickup"):
		animations.play("pickup")

func swallow() -> void:
	if animations.has_animation("swallow"):
		animations.play("swallow")
		animations.seek(0.0, true)

func set_appetite(enabled: bool) -> void:
	if jaw != null and not animations.is_playing():
		jaw.rotation.x = appetite_angle if enabled else 0.0

func reset_pose() -> void:
	animations.stop()
	animations.play("RESET")
	animations.advance(0.0)
	animations.stop()
	_phase = 0.0
	_roll_blend = 0.0
	_rolling = false
	motion.position = Vector3.ZERO
	if roll_root != null:
		roll_root.rotation = Vector3.ZERO
		roll_root.scale = Vector3.ONE
	for index: int in range(_feet.size()):
		_feet[index].position = _foot_origins[index]
		_feet[index].scale = _foot_scales[index]
		_feet[index].show()
	if defense_ring != null:
		defense_ring.hide()

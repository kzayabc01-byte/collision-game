extends Node3D

@export var shake_enabled: bool = true
@export var follow_speed: float = 5.0
@export var view_margin: float = 2.0
var _strength: float = 0.0
var _base_view_size: float
var _viewport_size: Vector2
var _arena_bounds: Rect2
var _shake_direction: Vector3 = Vector3.RIGHT
var _shake_age: float = 1.0

@onready var camera: Camera3D = $Camera3D
@onready var _base_position: Vector3 = camera.position

func _ready() -> void:
	var floor: MeshInstance3D = get_node("../Arena/Ground/Mesh") as MeshInstance3D
	var floor_box: AABB = floor.global_transform * floor.get_aabb()
	_arena_bounds = Rect2(Vector2(floor_box.position.x, floor_box.position.z), Vector2(floor_box.size.x, floor_box.size.z))
	_base_view_size = camera.size
	_fit_camera_to_window()
	_follow_player(1.0)

func _process(delta: float) -> void:
	if get_viewport().get_visible_rect().size != _viewport_size:
		_fit_camera_to_window()
	_shake_age += delta
	var envelope: float = maxf(0.0, 1.0 - _shake_age / 0.18)
	var offset: Vector3 = _shake_direction * sin(_shake_age * 65.0) * _strength * envelope * envelope
	camera.position = _base_position + offset
	_follow_player(1.0 - exp(-follow_speed * delta))
	_keep_view_inside_arena()

func _fit_camera_to_window() -> void:
	_viewport_size = get_viewport().get_visible_rect().size
	if _viewport_size.x <= 0.0 or _viewport_size.y <= 0.0:
		return
	camera.size = _base_view_size
	var visible_ground: Rect2 = _ground_footprint()
	var available: Vector2 = _arena_bounds.size - Vector2.ONE * view_margin * 2.0
	var fit: float = minf(1.0, minf(available.x / visible_ground.size.x, available.y / visible_ground.size.y))
	camera.size *= fit

func _follow_player(weight: float) -> void:
	var player: Node3D = get_node_or_null("../Vehicles/PlayerCar") as Node3D
	if player == null:
		return
	var visible_ground: Rect2 = _ground_footprint()
	var half_view: Vector2 = visible_ground.size * 0.5
	var center: Vector2 = visible_ground.position + half_view
	var minimum: Vector2 = _arena_bounds.position + Vector2.ONE * view_margin + half_view
	var maximum: Vector2 = _arena_bounds.end - Vector2.ONE * view_margin - half_view
	var target: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	target = target.clamp(minimum, maximum)
	var shift: Vector2 = (target - center) * weight
	global_position.x += shift.x
	global_position.z += shift.y

func _keep_view_inside_arena() -> void:
	var visible_ground: Rect2 = _ground_footprint()
	var minimum: Vector2 = _arena_bounds.position + Vector2.ONE * view_margin
	var maximum: Vector2 = _arena_bounds.end - Vector2.ONE * view_margin
	global_position.x += maxf(minimum.x - visible_ground.position.x, 0.0) - maxf(visible_ground.end.x - maximum.x, 0.0)
	global_position.z += maxf(minimum.y - visible_ground.position.y, 0.0) - maxf(visible_ground.end.y - maximum.y, 0.0)

func _ground_footprint() -> Rect2:
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	for corner: Vector2 in [Vector2.ZERO, Vector2(_viewport_size.x, 0.0), _viewport_size, Vector2(0.0, _viewport_size.y)]:
		var origin: Vector3 = camera.project_ray_origin(corner)
		var direction: Vector3 = camera.project_ray_normal(corner)
		var hit: Vector3 = origin + direction * (-origin.y / direction.y)
		var ground_point: Vector2 = Vector2(hit.x, hit.z)
		minimum = minimum.min(ground_point)
		maximum = maximum.max(ground_point)
	return Rect2(minimum, maximum - minimum)

func shake(tier: int, direction: Vector3 = Vector3.RIGHT) -> void:
	if shake_enabled:
		_strength = 0.035 + tier * 0.08
		_shake_age = 0.0
		_shake_direction = global_basis.inverse() * Vector3(direction.x, 0.0, direction.z).normalized()

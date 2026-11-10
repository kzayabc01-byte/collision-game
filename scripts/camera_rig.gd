extends Node3D
## Fixed-angle player follow, bounded by the arena's inner wall faces.

@export var shake_enabled: bool = true
@export_range(1.0, 20.0, 0.5) var follow_speed: float = 8.0
@export_range(0.0, 3.0, 0.1) var focus_height: float = 0.8
@export_range(4.0, 40.0, 1.0) var teleport_distance: float = 12.0
var _strength: float = 0.0
var _base_view_size: float
var _viewport_size: Vector2
var _arena_bounds: Rect2
var _shake_direction: Vector3 = Vector3.RIGHT
var _shake_age: float = 1.0
var _last_target: Vector3
var _last_player_id: int = 0
var _was_alive: bool = false

@onready var camera: Camera3D = $Camera3D
@onready var _base_position: Vector3 = camera.position

func _ready() -> void:
	# Run before HUD projection, so the 'you' marker uses this frame's camera.
	process_priority = -10
	_base_view_size = camera.size
	var match_node: CrashMatch = get_parent() as CrashMatch
	if match_node != null:
		_arena_bounds = match_node._get_play_bounds()
	_fit_camera_to_window()
	# The match can replace the player in its _ready; resolve it after that.
	recenter.call_deferred()

func _process(delta: float) -> void:
	if get_viewport().get_visible_rect().size != _viewport_size:
		_fit_camera_to_window()
	var match_node: Node = get_parent()
	if match_node is CrashMatch and (match_node as CrashMatch).phase != CrashMatch.Phase.PLAYING:
		return
	# Follow is calculated without shake; otherwise it counteracts the shake
	# and permanently moves the rig after an impact.
	camera.position = _base_position
	var player: CrashCar = get_node_or_null("../Vehicles/PlayerCar") as CrashCar
	if player != null:
		var snap: bool = player.get_instance_id() != _last_player_id
		snap = snap or (player.alive and not _was_alive)
		snap = snap or player.global_position.distance_to(_last_target) > teleport_distance
		if player.alive:
			_follow_player(1.0 if snap else 1.0 - exp(-follow_speed * delta))
		_last_target = player.global_position
		_last_player_id = player.get_instance_id()
		_was_alive = player.alive
	_shake_age += delta
	var envelope: float = maxf(0.0, 1.0 - _shake_age / 0.18)
	var offset: Vector3 = _shake_direction * sin(_shake_age * 65.0) * _strength * envelope * envelope
	camera.position = _base_position + offset
	if not offset.is_zero_approx():
		# Clip the temporary shake without moving the follow rig.
		camera.global_position += _bounded_ground_shift(Vector3.ZERO)

func recenter() -> void:
	camera.position = _base_position
	_follow_player(1.0)
	var player: CrashCar = get_node_or_null("../Vehicles/PlayerCar") as CrashCar
	if player != null:
		_last_target = player.global_position
		_last_player_id = player.get_instance_id()
		_was_alive = player.alive

func _fit_camera_to_window() -> void:
	_viewport_size = get_viewport().get_visible_rect().size
	camera.position = _base_position
	camera.size = _base_view_size
	if not _arena_bounds.has_area() or _viewport_size.x <= 0.0 or _viewport_size.y <= 0.0:
		return
	var footprint: Rect2 = _ground_footprint()
	var fit: float = minf(_arena_bounds.size.x / footprint.size.x, _arena_bounds.size.y / footprint.size.y)
	if fit < 1.0:
		# A wider window can exceed the arena even with the camera centered.
		camera.size *= fit
	global_position += _bounded_ground_shift(Vector3.ZERO)

func _follow_player(weight: float) -> void:
	var player: Node3D = get_node_or_null("../Vehicles/PlayerCar") as Node3D
	if player == null or _viewport_size.x <= 0.0 or _viewport_size.y <= 0.0:
		return
	var focus: Vector3 = player.global_position + Vector3.UP * focus_height
	var center: Vector3 = _screen_on_plane(_viewport_size * 0.5, focus.y)
	var shift: Vector3 = (focus - center) * clampf(weight, 0.0, 1.0)
	global_position += _bounded_ground_shift(shift)

func _bounded_ground_shift(shift: Vector3) -> Vector3:
	if not _arena_bounds.has_area() or _viewport_size.x <= 0.0 or _viewport_size.y <= 0.0:
		return Vector3(shift.x, 0.0, shift.z)
	var footprint: Rect2 = _ground_footprint()
	var minimum: Vector2 = _arena_bounds.position - footprint.position
	var maximum: Vector2 = _arena_bounds.end - footprint.end
	# Allow for floating-point rounding when the view exactly fits one axis.
	maximum = maximum.max(minimum)
	return Vector3(clampf(shift.x, minimum.x, maximum.x), 0.0, clampf(shift.z, minimum.y, maximum.y))

func _screen_on_plane(screen: Vector2, height: float) -> Vector3:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	if absf(direction.y) < 0.00001:
		return origin
	return origin + direction * ((height - origin.y) / direction.y)

func _ground_footprint() -> Rect2:
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	for corner: Vector2 in [Vector2.ZERO, Vector2(_viewport_size.x, 0.0), _viewport_size, Vector2(0.0, _viewport_size.y)]:
		var hit: Vector3 = _screen_on_plane(corner, 0.0)
		minimum = minimum.min(Vector2(hit.x, hit.z))
		maximum = maximum.max(Vector2(hit.x, hit.z))
	return Rect2(minimum, maximum - minimum)

func shake(tier: int, direction: Vector3 = Vector3.RIGHT) -> void:
	if shake_enabled:
		_strength = 0.035 + tier * 0.08
		_shake_age = 0.0
		_shake_direction = global_basis.inverse() * Vector3(direction.x, 0.0, direction.z).normalized()

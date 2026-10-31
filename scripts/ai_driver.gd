extends DriveInput

enum Intent {
	SEEK,
	RUN_UP,
	CHARGE,
}

@export var decision_seconds: float = 0.35
@export var patrol_half_size: Vector2 = Vector2(16.8, 10.5)

var _decision_remaining: float = 0.0
var _target: Vector3 = Vector3.ZERO
var _last_position: Vector3 = Vector3.ZERO
var _stuck_seconds: float = 0.0
var _commit_remaining: float = 0.0
var _intent: Intent = Intent.SEEK
var _patrol_index: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_patrol_index = _rng.randi_range(0, 3)
	_target = _waypoint(_patrol_index)

func sample_direction(car_position: Vector3, context: Dictionary, delta: float) -> Vector3:
	_decision_remaining -= delta
	_commit_remaining -= delta
	_stuck_seconds = _stuck_seconds + delta if car_position.distance_to(_last_position) < 0.008 else 0.0
	_last_position = car_position
	if _intent == Intent.RUN_UP:
		if car_position.distance_to(_target) < 2.0:
			_patrol_index = (_patrol_index + 1) % 4
			_target = _waypoint(_patrol_index)
			_commit_remaining = 12.0
		if _decision_remaining <= 0.0:
			_decision_remaining = decision_seconds
			_try_charge(car_position, context)
	elif _intent == Intent.CHARGE and car_position.distance_to(_target) < 1.2:
		_intent = Intent.SEEK
		_decision_remaining = 0.0
	if _commit_remaining <= 0.0:
		_intent = Intent.SEEK
	if _intent == Intent.SEEK and _decision_remaining <= 0.0:
		_decision_remaining = decision_seconds
		_choose_target(car_position, context)
	if _stuck_seconds > 1.0:
		_intent = Intent.RUN_UP
		_patrol_index = (_patrol_index + 1) % 4
		_target = _waypoint(_patrol_index)
		_commit_remaining = 10.0
		_stuck_seconds = 0.0
	var direction: Vector3 = (_target - car_position).normalized()
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(car_position + Vector3.UP * 0.6, car_position + Vector3.UP * 0.6 + direction * 2.4, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var hit_node: Node = hit["collider"] as Node
		if not hit_node.is_in_group("candy_obstacles") or _intent != Intent.CHARGE:
			var normal: Vector3 = hit["normal"]
			var tangent: Vector3 = normal.cross(Vector3.UP)
			if tangent.dot(direction) < 0.0:
				tangent = -tangent
			direction = (tangent + normal * 0.45).normalized()
	return direction

func _choose_target(car_position: Vector3, context: Dictionary) -> void:
	var nearest_distance: float = INF
	var candy_positions: Array = context.get("candies", [])
	for point: Vector3 in candy_positions:
		var distance: float = car_position.distance_squared_to(point)
		if distance < nearest_distance:
			nearest_distance = distance
			_target = point
	var pickup_range: float = 100.0 if float(context["mass"]) < 1.25 else 16.0
	if nearest_distance < pickup_range:
		return
	var opponents: Array = context.get("opponents", [])
	for opponent: Dictionary in opponents:
		var point: Vector3 = opponent["position"]
		if car_position.distance_squared_to(point) < 12.0 and float(opponent["mass"]) > float(context["mass"]) * 1.3:
			_target = car_position + (car_position - point).normalized() * 7.0
			return
	var obstacles: Array = context.get("obstacles", [])
	if obstacles.is_empty() and not opponents.is_empty():
		_target = opponents[_rng.randi_range(0, opponents.size() - 1)]["position"]
		return
	var best: float = INF
	for index: int in range(4):
		var distance: float = car_position.distance_to(_waypoint(index))
		if distance < best:
			best = distance
			_patrol_index = index
	_target = _waypoint(_patrol_index)
	_intent = Intent.RUN_UP
	_commit_remaining = 12.0

func _try_charge(car_position: Vector3, context: Dictionary) -> void:
	var tuning: GameTuning = context["tuning"] as GameTuning
	var velocity: Vector3 = context["velocity"]
	if velocity.length() < 4.0:
		return
	var obstacles: Array = context.get("obstacles", [])
	var best_angle: float = INF
	var selected: Vector3 = Vector3.ZERO
	for point: Vector3 in obstacles:
		var offset: Vector3 = point - car_position
		if offset.length() < 3.0 or offset.length() > 15.0:
			continue
		var angle: float = velocity.angle_to(offset)
		if angle > deg_to_rad(65.0) or angle >= best_angle:
			continue
		var speed_after_turn: float = velocity.length() * CollisionMath.turn_retention(angle, tuning)
		var energy: float = 0.5 * float(context["mass"]) * speed_after_turn * speed_after_turn
		if energy < tuning.obstacle_break_energy * 1.04:
			continue
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(car_position + Vector3.UP * 0.6, point + Vector3.UP * 0.6, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and (hit["collider"] as Node3D).global_position.distance_to(point) < 0.1:
			best_angle = angle
			selected = point + offset.normalized() * 2.0
	if not is_inf(best_angle):
		_target = selected
		_intent = Intent.CHARGE
		_commit_remaining = 5.0

func _waypoint(index: int) -> Vector3:
	var corners: Array[Vector3] = [
		Vector3(-patrol_half_size.x, 0, -patrol_half_size.y),
		Vector3(patrol_half_size.x, 0, -patrol_half_size.y),
		Vector3(patrol_half_size.x, 0, patrol_half_size.y),
		Vector3(-patrol_half_size.x, 0, patrol_half_size.y),
	]
	return corners[index]

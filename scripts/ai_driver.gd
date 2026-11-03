extends DriveInput

enum Intent { COLLECT, BREAK, HUNT, EVADE, REGROUP, RECOVER }
@export var decision_seconds: float = 0.25
@export var random_seed: int = 0
var intent: Intent = Intent.REGROUP
var target: Vector3 = Vector3.ZERO
var target_key: String = ""
var target_id: int = 0
var reason: String = "initial"
var target_changes: int = 0
var recoveries: int = 0
var abandoned_targets: int = 0
var hunt_seconds: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _clock: float = 0.0
var _decision: float = 0.0
var _age: float = 0.0
var _idle: float = 0.0
var _best_distance: float = INF
var _no_progress: float = 0.0
var _blocked: Dictionary = {}
var _route: PackedVector3Array = PackedVector3Array()
var _route_timer: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _stuck: float = 0.0
var _recover_timer: float = 0.0
var _history: Array[Vector3] = []
var _history_timer: float = 0.0
var _last_encounter: Dictionary = {}

func _ready() -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed

func reset_driver() -> void:
	_decision = 0.0
	_age = 0.0
	_idle = 0.0
	_best_distance = INF
	_no_progress = 0.0
	_stuck = 0.0
	_recover_timer = 0.0
	target_key = ""
	target_id = 0
	_route.clear()
	_history.clear()
	_blocked.clear()

func notify_progress() -> void:
	_idle = 0.0
	_no_progress = 0.0
	_history.clear()

func notify_encounter(opponent_id: int) -> void:
	_last_encounter[opponent_id] = _clock

func sample_controls(position: Vector3, context: Dictionary, delta: float) -> Dictionary:
	_clock += delta
	_age += delta
	_idle += delta
	_decision -= delta
	_route_timer -= delta
	_history_timer -= delta
	_no_progress += delta
	var velocity: Vector3 = context.get("velocity", Vector3.ZERO)
	var heading: Vector3 = context.get("heading", Vector3.FORWARD)
	var speed: float = velocity.length()
	if intent == Intent.HUNT:
		hunt_seconds += delta
	_stuck = _stuck + delta if position.distance_to(_last_position) < delta * 0.15 else 0.0
	_last_position = position
	if _recover_timer > 0.0:
		_recover_timer -= delta
		return {"throttle": -0.75, "steer": 0.8, "brake": false}
	if _stuck > 1.2:
		_abandon("stuck")
		intent = Intent.RECOVER
		_recover_timer = 0.65
		_stuck = 0.0
		recoveries += 1
		return {"throttle": -0.75, "steer": 0.8, "brake": false}
	if _history_timer <= 0.0:
		_history_timer = 0.5
		_history.append(position)
		if _history.size() > 12:
			_history.pop_front()
		if _idle > 6.0 and _history.size() == 12 and position.distance_to(_history[0]) < 3.0:
			_abandon("repeated route")
			_history.clear()
	var distance: float = position.distance_to(target)
	if distance < _best_distance - 0.6:
		_best_distance = distance
		_no_progress = 0.0
	if not target_key.is_empty() and (_no_progress > 3.0 or _age > (6.0 if intent == Intent.HUNT else 9.0)):
		_abandon("no progress / timeout")
	if _decision <= 0.0:
		_decision = decision_seconds
		_choose(position, context)
	if intent == Intent.HUNT:
		var found: bool = false
		for opponent: Dictionary in context.get("opponents", []):
			if int(opponent.get("id", 0)) == target_id:
				var point: Vector3 = opponent["position"]
				var lead: float = clampf(position.distance_to(point) / maxf(4.0, speed), 0.25, 1.0)
				target = _inside(point + (opponent.get("velocity", Vector3.ZERO) as Vector3) * lead, context)
				found = true
				break
		if not found:
			_abandon("target gone")
	if _route_timer <= 0.0 or _route.is_empty():
		_route_timer = 0.65
		_route = ArenaRoute.path(get_tree(), context.get("bounds", Rect2()), position, target, float(context.get("radius", 0.76)), intent == Intent.BREAK)
		if _route.is_empty():
			_abandon("unreachable")
			return {"throttle": 0.0, "steer": 0.0, "brake": speed > 2.0}
	while _route.size() > 1 and position.distance_to(_route[0]) < 2.5:
		_route.remove_at(0)
	var aim: Vector3 = _route[0]
	if _clear_corridor(position, target, float(context.get("radius", 0.76)), intent == Intent.BREAK):
		aim = target
	var angle: float = heading.signed_angle_to((aim - position).normalized(), Vector3.UP)
	var steer: float = clampf(-angle / deg_to_rad(40.0), -1.0, 1.0)
	var throttle: float = 1.0
	var brake: bool = false
	if absf(angle) > deg_to_rad(70.0):
		throttle = 0.22
		brake = speed > 3.0
	elif absf(angle) > deg_to_rad(35.0):
		throttle = 0.65
	var look: float = speed * 0.25 + speed * speed / 16.0 + float(context.get("radius", 0.76))
	var forward: Vector3 = velocity.normalized() if speed > 0.5 else heading
	if not _clear_corridor(position, position + forward * maxf(2.0, look), float(context.get("radius", 0.76)), intent == Intent.BREAK):
		brake = speed > 3.0
		throttle = minf(throttle, 0.35)
	if brake:
		steer *= 0.12
	if intent == Intent.REGROUP and distance < 2.5:
		_abandon("regroup reached")
	return {"throttle": throttle, "steer": steer, "brake": brake}

func _choose(position: Vector3, context: Dictionary) -> void:
	for key: String in _blocked.keys():
		if float(_blocked[key]) <= _clock:
			_blocked.erase(key)
	var choices: Array[Dictionary] = []
	var mass: float = float(context.get("mass", 1.0))
	for point: Vector3 in context.get("candies", []):
		var distance: float = position.distance_to(point)
		if distance <= (26.0 if mass < 1.25 else 18.0):
			choices.append({"intent": Intent.COLLECT, "point": point, "key": "c" + str(point.snapped(Vector3.ONE)), "score": 5.0 - distance * 0.14})
	for point: Vector3 in context.get("obstacles", []):
		choices.append({"intent": Intent.BREAK, "point": point, "key": "b" + str(point), "score": 2.8 - position.distance_to(point) * 0.07})
	for opponent: Dictionary in context.get("opponents", []):
		var point: Vector3 = opponent["position"]
		var distance: float = position.distance_to(point)
		var enemy_velocity: Vector3 = opponent.get("velocity", Vector3.ZERO)
		if distance < 5.0 and float(opponent.get("mass", 1.0)) > mass * 1.5 and enemy_velocity.dot((position - point).normalized()) > 1.0:
			choices.append({"intent": Intent.EVADE, "point": _inside(position + (position - point).normalized().rotated(Vector3.UP, 0.7) * 8.0, context), "key": "evade", "score": 9.0})
		var profile: VehicleProfile = context.get("profile") as VehicleProfile
		var swallow: bool = profile != null and profile.kind == VehicleProfile.Kind.PUMPKIN and float(opponent.get("scale", 1.0)) <= float(context.get("scale", 1.0)) * profile.swallow_size_ratio
		var encounter_age: float = _clock - float(_last_encounter.get(int(opponent.get("id", 0)), 0.0))
		var variety: float = clampf(encounter_age / 10.0, 0.0, 4.0)
		choices.append({"intent": Intent.HUNT, "point": point, "id": opponent.get("id", 0), "key": "h" + str(opponent.get("id", 0)), "score": 4.5 - distance * 0.07 + variety + (2.0 if swallow else 0.0) + (2.0 if _idle > 5.0 else 0.0)})
	var selected: Dictionary = {}
	var best: float = -INF
	var current_valid: bool = false
	for choice: Dictionary in choices:
		var key: String = choice["key"]
		if float(_blocked.get(key, 0.0)) > _clock:
			continue
		var score: float = float(choice["score"])
		if key == target_key:
			current_valid = true
			score += 0.6
		if score > best:
			best = score
			selected = choice
	if current_valid and _age < 0.8 and int(selected.get("intent", 0)) != Intent.EVADE:
		return
	if not selected.is_empty() and best > 0.0:
		if str(selected["key"]) != target_key:
			_set_target(selected["intent"], selected["point"], selected["key"], int(selected.get("id", 0)), "best opportunity")
		elif intent != Intent.HUNT:
			target = selected["point"]
		return
	if intent != Intent.REGROUP or target_key.is_empty() or _age > 2.5:
		var bounds: Rect2 = context.get("bounds", Rect2(-30, -20, 60, 40))
		var center: Vector2 = bounds.get_center()
		var point: Vector3 = Vector3(center.x + _rng.randf_range(-0.3, 0.3) * bounds.size.x, 0, center.y + _rng.randf_range(-0.3, 0.3) * bounds.size.y)
		_set_target(Intent.REGROUP, point, "regroup", 0, "no reachable opportunity")

func _set_target(next: Intent, point: Vector3, key: String, id: int, why: String) -> void:
	intent = next
	target = point
	target_key = key
	target_id = id
	reason = why
	target_changes += 1
	_age = 0.0
	_no_progress = 0.0
	_best_distance = INF
	_route_timer = 0.0
	_route.clear()

func _abandon(why: String) -> void:
	abandoned_targets += 1
	if not target_key.is_empty():
		_blocked[target_key] = _clock + 4.0
	target_key = ""
	target_id = 0
	reason = why
	_decision = 0.0
	_no_progress = 0.0
	_best_distance = INF
	_route.clear()

func _inside(point: Vector3, context: Dictionary) -> Vector3:
	var bounds: Rect2 = context.get("bounds", Rect2())
	if not bounds.has_area():
		return point
	bounds = bounds.grow(-float(context.get("radius", 0.76)) - 1.0)
	return Vector3(clampf(point.x, bounds.position.x, bounds.end.x), 0, clampf(point.z, bounds.position.y, bounds.end.y))

func _clear_corridor(from: Vector3, to: Vector3, radius: float, allow_target: bool) -> bool:
	var side: Vector3 = (to - from).normalized().cross(Vector3.UP) * radius
	for offset: Vector3 in [Vector3.ZERO, side, -side]:
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + offset + Vector3.UP * 0.6, to + offset + Vector3.UP * 0.6, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			var collider: Node3D = hit["collider"] as Node3D
			if not (allow_target and collider.is_in_group("candy_obstacles") and collider.global_position.distance_to(target) < 0.5):
				return false
	return true

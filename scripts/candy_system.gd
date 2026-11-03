class_name CandySystem
extends Node3D

const CandyScene: PackedScene = preload("res://scenes/candy.tscn")

@export var tuning: GameTuning

var clock_seconds: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func tick(delta: float) -> void:
	clock_seconds += delta
	for child: Node in get_children():
		var candy: CandyPickup = child as CandyPickup
		if candy != null:
			candy.tick(delta, clock_seconds)

func positions() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for child: Node in get_children():
		var candy: CandyPickup = child as CandyPickup
		if candy != null and not candy.collected:
			points.append(candy.global_position)
	return points

func total_value() -> int:
	var total: int = 0
	for child: Node in get_children():
		if child is CandyPickup:
			total += (child as CandyPickup).total_value()
	return total

func spawn_drop(origin: Vector3, direction: Vector3, value: int, owner_id: int, tier: int) -> void:
	if value <= 0:
		return
	var available: int = maxi(0, tuning.maximum_candy_nodes - get_child_count())
	var count: int = mini(value, available)
	if count == 0:
		# Preserve each batch's expiry and protection even when visuals are merged.
		var nearest: CandyPickup = null
		var distance: float = INF
		for child: Node in get_children():
			var existing: CandyPickup = child as CandyPickup
			if existing != null and not existing.collected and existing.global_position.distance_squared_to(origin) < distance:
				nearest = existing
				distance = existing.global_position.distance_squared_to(origin)
		if nearest != null:
			nearest.add_lot(value, owner_id, clock_seconds, tuning.owner_protection_seconds, tuning.candy_lifetime)
			return
		# Collected visuals are already leaving; free one visual slot without losing value.
		for child: Node in get_children():
			if child is CandyPickup and (child as CandyPickup).collected:
				remove_child(child)
				child.queue_free()
				count = 1
				break
		if count == 0:
			return
	var tier_index: int = clampi(tier, 0, 2)
	var min_distances: Array[float] = [0.4, 0.8, 1.5]
	var max_distances: Array[float] = [0.8, 1.5, 2.5]
	var min_times: Array[float] = [0.25, 0.4, 0.6]
	var max_times: Array[float] = [0.4, 0.6, 0.9]
	var forward: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	for index: int in range(count):
		var candy: CandyPickup = CandyScene.instantiate() as CandyPickup
		add_child(candy)
		candy.global_position = Vector3(clampf(origin.x, -39.4, 39.4), 0.0, clampf(origin.z, -27.4, 27.4))
		var lot_value: int = value / count + (1 if index < value % count else 0)
		candy.add_lot(lot_value, owner_id, clock_seconds, tuning.owner_protection_seconds, tuning.candy_lifetime)
		var angle: float = _rng.randf_range(-PI * 0.35, PI * 0.35) if _rng.randf() < 0.7 else _rng.randf_range(-PI, PI)
		var scatter: Vector3 = forward.rotated(Vector3.UP, angle)
		var flight_time: float = _rng.randf_range(min_times[tier_index], max_times[tier_index])
		var distance: float = _rng.randf_range(min_distances[tier_index], max_distances[tier_index]) * tuning.initial_car_length
		candy.launch_velocity = scatter * (distance / flight_time) + Vector3.UP * (7.0 * flight_time)

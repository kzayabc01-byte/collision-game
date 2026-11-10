class_name CandyPickup
extends Node3D

@export var visuals: CandyVisualSet

var lots: Array[Dictionary] = []
var launch_velocity: Vector3 = Vector3.ZERO
var flight_height: float = 0.25
var age: float = 0.0
var collected: bool = false
var _bounces: int = 0
var _visual_tween: Tween
var style_index: int = -1
var visual_size: float = 1.0
var _spin_velocity: Vector3 = Vector3.ZERO
var _landing_age: float = 1.0

@onready var visual: Node3D = $VisualRoot
@onready var area: Area3D = $PickupArea
@onready var amount_label: Label3D = $AmountLabel
@onready var spin: Node3D = $VisualRoot/Spin

func _ready() -> void:
	set_style(visuals.choose(randf()), randf_range(1.0 - visuals.size_variation, 1.0 + visuals.size_variation))
	spin.rotation.y = randf_range(-PI, PI)
	_spin_velocity = Vector3(randf_range(-7.0, 7.0), randf_range(-5.0, 5.0), randf_range(-7.0, 7.0))

func set_style(index: int, size_multiplier: float = 1.0) -> void:
	if style_index >= 0:
		return
	style_index = clampi(index, 0, visuals.models.size() - 1)
	visual_size = clampf(size_multiplier, 1.0 - visuals.size_variation, 1.0 + visuals.size_variation)
	spin.add_child(visuals.models[style_index].instantiate())
	visual.scale = Vector3.ONE * visual_size

func add_lot(value: int, owner_id: int, now: float, protection: float, lifetime: float) -> void:
	lots.append({"value": value, "owner": owner_id, "unlock": now + protection, "expires": now + lifetime})
	_update_label()

func total_value() -> int:
	var result: int = 0
	for lot: Dictionary in lots:
		result += int(lot["value"])
	return result

func claim_for(car_id: int, now: float) -> int:
	var result: int = 0
	for lot: Dictionary in claim_lots(car_id, now):
		result += int(lot["value"])
	return result

func claim_lots(car_id: int, now: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var index: int = 0
	# FIFO keeps mixed-origin batches deterministic across the pony threshold.
	while index < lots.size():
		var lot: Dictionary = lots[index]
		if now >= float(lot["expires"]):
			lots.remove_at(index)
		elif int(lot["owner"]) != car_id or now >= float(lot["unlock"]):
			result.append(lot)
			lots.remove_at(index)
		else:
			index += 1
	_update_label()
	return result

func tick(delta: float, now: float) -> void:
	if collected:
		return
	age += delta
	for index: int in range(lots.size() - 1, -1, -1):
		if now >= float(lots[index]["expires"]):
			lots.remove_at(index)
	if lots.is_empty():
		collected = true
		queue_free()
		return
	var horizontal: Vector3 = Vector3(launch_velocity.x, 0.0, launch_velocity.z)
	if horizontal.length_squared() > 0.01:
		var from: Vector3 = global_position + Vector3.UP * 0.4
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + horizontal * delta * 1.5, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			horizontal = horizontal.bounce(hit["normal"]) * 0.5
		global_position += horizontal * delta
		global_position.x = clampf(global_position.x, -39.5, 39.5)
		global_position.z = clampf(global_position.z, -27.5, 27.5)
		launch_velocity.x = horizontal.x
		launch_velocity.z = horizontal.z
	if flight_height > 0.15 or launch_velocity.y > 0.0:
		launch_velocity.y -= 14.0 * delta
		flight_height += launch_velocity.y * delta
		if flight_height <= 0.15:
			flight_height = 0.15
			_bounces += 1
			_landing_age = 0.0
			launch_velocity.y = absf(launch_velocity.y) * 0.3 if _bounces < 2 else 0.0
			launch_velocity.x *= 0.55
			launch_velocity.z *= 0.55
	else:
		launch_velocity = launch_velocity.move_toward(Vector3.ZERO, delta * 6.0)
	visual.position.y = flight_height + (sin(age * 4.0) * 0.045 if _bounces >= 2 else 0.0)
	_landing_age += delta
	if _bounces < 2 and flight_height > 0.17:
		spin.rotation += _spin_velocity * delta
	else:
		spin.rotation.x = lerp_angle(spin.rotation.x, 0.0, 1.0 - exp(-12.0 * delta))
		spin.rotation.z = lerp_angle(spin.rotation.z, 0.0, 1.0 - exp(-12.0 * delta))
		spin.rotation.y += delta * 0.7
	if style_index == 4:
		var squash: float = maxf(0.0, sin(_landing_age * 22.0)) * exp(-_landing_age * 12.0) * 0.32
		visual.scale = Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5) * visual_size
	if age < 0.12:
		return
	for body: Node3D in area.get_overlapping_bodies():
		var car: CrashCar = body as CrashCar
		if car == null or not car.alive:
			continue
		var claimed: Array[Dictionary] = claim_lots(car.get_instance_id(), now)
		if not claimed.is_empty():
			car.collect_batches(claimed)
		if lots.is_empty():
			collected = true
			area.set_deferred("monitoring", false)
			_visual_tween = create_tween().set_parallel(true)
			_visual_tween.tween_property(self, "global_position", car.global_position + Vector3.UP * 0.6, 0.12)
			_visual_tween.tween_property(visual, "scale", Vector3.ZERO, 0.12)
			_visual_tween.chain().tween_callback(queue_free)
			return

func _update_label() -> void:
	if amount_label != null:
		amount_label.text = str(total_value()) if total_value() > 1 else ""

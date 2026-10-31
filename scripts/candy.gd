class_name CandyPickup
extends Node3D

var lots: Array[Dictionary] = []
var launch_velocity: Vector3 = Vector3.ZERO
var flight_height: float = 0.25
var age: float = 0.0
var collected: bool = false
var _bounces: int = 0
var _visual_tween: Tween

@onready var visual: Node3D = $VisualRoot
@onready var area: Area3D = $PickupArea
@onready var amount_label: Label3D = $AmountLabel

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
	for index: int in range(lots.size() - 1, -1, -1):
		var lot: Dictionary = lots[index]
		if now >= float(lot["expires"]):
			lots.remove_at(index)
		elif int(lot["owner"]) != car_id or now >= float(lot["unlock"]):
			result += int(lot["value"])
			lots.remove_at(index)
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
		global_position.x = clampf(global_position.x, -19.0, 19.0)
		global_position.z = clampf(global_position.z, -12.5, 12.5)
		launch_velocity.x = horizontal.x
		launch_velocity.z = horizontal.z
	if flight_height > 0.15 or launch_velocity.y > 0.0:
		launch_velocity.y -= 14.0 * delta
		flight_height += launch_velocity.y * delta
		if flight_height <= 0.15:
			flight_height = 0.15
			_bounces += 1
			launch_velocity.y = absf(launch_velocity.y) * 0.3 if _bounces < 3 else 0.0
			launch_velocity.x *= 0.55
			launch_velocity.z *= 0.55
	else:
		launch_velocity = launch_velocity.move_toward(Vector3.ZERO, delta * 6.0)
	visual.position.y = flight_height + (sin(age * 4.0) * 0.045 if _bounces >= 2 else 0.0)
	visual.rotation.y += delta * 2.0
	if age < 0.12:
		return
	for body: Node3D in area.get_overlapping_bodies():
		var car: CrashCar = body as CrashCar
		if car == null or not car.alive:
			continue
		var value: int = claim_for(car.get_instance_id(), now)
		if value > 0:
			car.collect(value)
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

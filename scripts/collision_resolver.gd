class_name CollisionResolver
extends Node

signal impact_resolved(position: Vector3, tier: int, message: String)
signal vehicle_contact(a: CrashCar, b: CrashCar)
signal impact_visualized(point: Vector3, direction: Vector3, tier: int, player_involved: bool, defeated: bool, color: Color)

@export var tuning: GameTuning
@export var feedback_profile: ImpactProfile = preload("res://config/impact.tres")

var candy_system: CandySystem
var _contacts: Dictionary = {}
var _events: Array[Dictionary] = []
var _time: float = 0.0

func begin_tick(delta: float) -> void:
	_time += delta
	_events.clear()
	for key: String in _contacts.keys():
		var entry: Dictionary = _contacts[key]
		if not is_instance_valid(entry["car"]) or not is_instance_valid(entry["other"]):
			_contacts.erase(key)
			continue
		var car: CrashCar = entry["car"] as CrashCar
		var other: Node3D = entry["other"] as Node3D
		if not car.alive:
			_contacts.erase(key)
			continue
		if not _still_touching(car, other):
			entry["armed"] = true

func record(car: CrashCar, collision: KinematicCollision3D) -> void:
	if collision == null:
		return
	var other: Node3D = collision.get_collider() as Node3D
	if other is CrashCar or other is CrashObstacle:
		_events.append({"car": car, "other": other, "normal": collision.get_normal(), "point": collision.get_position()})

func resolve_events() -> void:
	var seen: Dictionary = {}
	for event: Dictionary in _events:
		var car: CrashCar = event["car"] as CrashCar
		var other: Node3D = event["other"] as Node3D
		var key: String = pair_key(car, other)
		if seen.has(key) or not car.alive:
			continue
		seen[key] = true
		var outward: Vector3 = event["normal"]
		outward.y = 0.0
		outward = outward.normalized()
		if outward.is_zero_approx():
			continue
		if other is CrashCar:
			_resolve_car(car, other as CrashCar, -outward, key, event["point"])
		else:
			_resolve_wall(car, other as CrashObstacle, outward, key, event["point"])

func clear_for(car: CrashCar) -> void:
	for key: String in _contacts.keys():
		var entry: Dictionary = _contacts[key]
		if entry["car"] == car or entry["other"] == car:
			_contacts.erase(key)

func pair_key(a: Node, b: Node) -> String:
	return "%d:%d" % [mini(a.get_instance_id(), b.get_instance_id()), maxi(a.get_instance_id(), b.get_instance_id())]

func _consume_contact(car: CrashCar, other: Node3D, key: String) -> bool:
	if not _contacts.has(key):
		_contacts[key] = {"car": car, "other": other, "armed": true, "last": -100.0}
	var entry: Dictionary = _contacts[key]
	if not bool(entry["armed"]) or _time - float(entry["last"]) < tuning.pair_cooldown:
		return false
	entry["armed"] = false
	entry["last"] = _time
	return true

func _resolve_car(a: CrashCar, b: CrashCar, normal: Vector3, key: String, contact_point: Vector3 = Vector3.INF) -> void:
	if not b.alive:
		return
	# Swallowing uses pre-impact scale and facing, before either car changes size.
	var eater: CrashCar = a if a.can_swallow(b, normal) else (b if b.can_swallow(a, -normal) else null)
	if eater != null and _consume_contact(a, b, key):
		vehicle_contact.emit(a, b)
		a.driver.notify_encounter(b.get_instance_id())
		b.driver.notify_encounter(a.get_instance_id())
		var prey: CrashCar = b if eater == a else a
		var reward: int = prey.candy
		prey.apply_loss(reward)
		eater.collect(reward)
		if eater.character_visual != null:
			eater.character_visual.swallow()
			prey.animate_swallowed(eater.character_visual.mouth_socket, eater.character_visual.swallow_pull_seconds, eater.character_visual.swallow_pull_delay)
		eater.feedback.play_swallow()
		impact_resolved.emit(eater.global_position, 1, "南瓜吞噬！ +%d 糖果" % reward)
		return
	var result: Dictionary = CollisionMath.pair_result(a.pre_mass, b.pre_mass, a.pre_velocity, b.pre_velocity, normal, tuning)
	var impulse: float = result["impulse"]
	if impulse > 0.0:
		a.respond(a.velocity - normal * impulse / a.pre_mass)
		b.respond(b.velocity + normal * impulse / b.pre_mass)
	if not _consume_contact(a, b, key):
		return
	vehicle_contact.emit(a, b)
	a.driver.notify_encounter(b.get_instance_id())
	b.driver.notify_encounter(a.get_instance_id())
	var loss_a: int = mini(a.candy, a.received_damage(float(result["raw_loss_a"])))
	var loss_b: int = mini(b.candy, b.received_damage(float(result["raw_loss_b"])))
	var tier_a: int = CollisionMath.drop_tier(loss_a, a.pre_candy)
	var tier_b: int = CollisionMath.drop_tier(loss_b, b.pre_candy)
	var loss_fraction: float = maxf(float(loss_a) / maxi(1, a.pre_candy), float(loss_b) / maxi(1, b.pre_candy))
	var tier: int = feedback_profile.tier_for(float(result["energy"]), float(result["closing"]), loss_fraction)
	# Both amounts use the same pre-impact snapshot, including simultaneous defeat.
	a.apply_loss(loss_a)
	b.apply_loss(loss_b)
	if loss_a + loss_b > 0:
		a.driver.notify_progress()
		b.driver.notify_progress()
	candy_system.spawn_drop(a.global_position, -normal, loss_a, a.get_instance_id(), maxi(tier_a, tier))
	candy_system.spawn_drop(b.global_position, normal, loss_b, b.get_instance_id(), maxi(tier_b, tier))
	if tier >= 0:
		a.feedback.hit(tier, a.paint, -normal)
		b.feedback.hit(tier, b.paint, normal)
		if not contact_point.is_finite():
			contact_point = a.global_position.lerp(b.global_position, a.radius / maxf(0.01, a.radius + b.radius))
		var receiver: CrashCar = b if loss_b >= loss_a else a
		var kind: int = int(receiver.profile.kind) if receiver.profile != null else 0
		impact_visualized.emit(contact_point, normal, tier, a.is_player or b.is_player, not a.alive or not b.alive, ImpactProfile.syrup_color(kind))
	var message: String = "强力碰撞" if tier == 2 else "碰撞 · 爆糖"
	if not a.alive or not b.alive:
		message = "双方击溃！" if not a.alive and not b.alive else "一撞击溃！"
	impact_resolved.emit((a.global_position + b.global_position) * 0.5, tier, message)

func _resolve_wall(car: CrashCar, obstacle: CrashObstacle, normal: Vector3, key: String, contact_point: Vector3 = Vector3.INF) -> void:
	if obstacle.is_broken:
		return
	if car.pre_velocity.dot(normal) >= -0.01:
		return
	var fresh: bool = _consume_contact(car, obstacle, key)
	if not fresh:
		# Keep the car outside the wall without charging a second contact penalty.
		car.respond(car.velocity.bounce(normal))
		return
	var energy: float = CollisionMath.obstacle_energy(car.pre_mass, car.pre_velocity, normal)
	var destroyed: bool = obstacle.can_break(energy)
	var loss: int = CollisionMath.wall_loss(car.candy, tuning)
	var drop_origin: Vector3 = car.global_position + normal * 0.3
	car.apply_loss(loss)
	candy_system.spawn_drop(drop_origin, normal, loss, car.get_instance_id(), 0)
	var next_velocity: Vector3 = car.pre_velocity if destroyed else car.pre_velocity.bounce(normal)
	car.respond(next_velocity * tuning.wall_speed_retention)
	var tier: int = 0
	var message: String = "撞墙 -5% 速度"
	if destroyed:
		var reward: int = obstacle.break_once()
		car.driver.notify_progress()
		tier = 2 if energy >= tuning.obstacle_break_energy * 2.0 else 1
		var spawn_point: Marker3D = obstacle.get_node("CandySpawn") as Marker3D
		candy_system.spawn_drop(spawn_point.global_position, car.pre_velocity.normalized(), reward, 0, tier)
		message = "撞碎糖箱 · +%d 颗可拾取" % reward
	elif obstacle.destructible:
		message = "力度不足 · 加速后正面撞击"
	var visual_tier: int = feedback_profile.tier_for(energy, maxf(0.0, -car.pre_velocity.dot(normal)))
	if visual_tier >= 0:
		car.feedback.hit(visual_tier, car.paint, normal)
		if not contact_point.is_finite():
			contact_point = car.global_position - normal * car.radius
		var kind: int = int(car.profile.kind) if car.profile != null else 0
		impact_visualized.emit(contact_point + normal * 0.12, normal, visual_tier, car.is_player, not car.alive, ImpactProfile.syrup_color(kind))
	impact_resolved.emit(car.global_position, tier, message)

func _still_touching(car: CrashCar, other: Node3D) -> bool:
	if other is CrashCar:
		var second: CrashCar = other as CrashCar
		return second.alive and car.global_position.distance_to(second.global_position) <= car.radius + second.radius + 0.2
	var obstacle: CrashObstacle = other as CrashObstacle
	if obstacle == null or obstacle.is_broken:
		return false
	var shape_node: CollisionShape3D = obstacle.get_node("BodyCollision") as CollisionShape3D
	var box: BoxShape3D = shape_node.shape as BoxShape3D
	var local: Vector3 = shape_node.to_local(car.global_position + Vector3.UP * 0.6)
	var half: Vector3 = box.size * 0.5
	var closest: Vector3 = shape_node.to_global(Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y), clampf(local.z, -half.z, half.z)))
	var delta: Vector3 = closest - car.global_position
	delta.y = 0.0
	return delta.length() <= car.radius + 0.2

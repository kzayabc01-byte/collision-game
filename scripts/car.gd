class_name CrashCar
extends CharacterBody3D

signal candy_changed(car: CrashCar)
signal defeated(car: CrashCar)
signal candy_collected(car: CrashCar, gained: int, bonus: int)

@export var tuning: GameTuning
@export var profile: VehicleProfile
@export var driver_name: String = "YOU"
@export var paint: Color = Color("67e6c3")
@export var is_player: bool = false
@export var starting_candy: int = -1
@export var paint_mesh_paths: Array[NodePath] = [NodePath("GrowthRoot/HitPivot/Model/Body"), NodePath("GrowthRoot/HitPivot/Model/Hood")]

var candy: int = 20
var vehicle_mass: float = 1.0
var alive: bool = true
var radius: float = 0.76
var pre_velocity: Vector3 = Vector3.ZERO
var pre_mass: float = 1.0
var pre_candy: int = 20
var pre_rolling: bool = false
var pre_forward: Vector3 = Vector3.FORWARD
var rolling: bool = false
var respawn_remaining: float = 0.0
var driven_distance: float = 0.0
var steering_angle: float = 0.0
var control_lock: float = 0.0
var _target_scale: float = 1.0
var _heading: Vector3 = Vector3.FORWARD
var _active_input: bool = false
var _swallow_tween: Tween
var play_bounds: Rect2 = Rect2()

@onready var body_shape: CollisionShape3D = $BodyCollision
@onready var growth_root: Node3D = $GrowthRoot
@onready var hit_pivot: Node3D = $GrowthRoot/HitPivot
@onready var driver: DriveInput = ($Driver if is_player else $AIDriver) as DriveInput
@onready var feedback: CarFeedback = $Feedback
@onready var name_label: Label3D = $NameLabel
@onready var player_ring: MeshInstance3D = $PlayerRing
@onready var character_visual: VehicleVisual = get_node_or_null("GrowthRoot/HitPivot/CharacterVisual") as VehicleVisual

func _ready() -> void:
	body_shape.shape = body_shape.shape.duplicate()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = paint
	material.roughness = 0.55
	for mesh_path: NodePath in paint_mesh_paths:
		var mesh: MeshInstance3D = get_node_or_null(mesh_path) as MeshInstance3D
		if mesh != null:
			mesh.material_override = material
	player_ring.visible = is_player
	feedback.pivot = hit_pivot
	set_candy(tuning.initial_candy if starting_candy < 0 else starting_candy)
	growth_root.scale = Vector3.ONE * _target_scale

func _process(delta: float) -> void:
	if not alive:
		feedback.set_speed(0.0, false)
		return
	growth_root.scale = growth_root.scale.lerp(Vector3.ONE * _target_scale, 1.0 - exp(-12.0 * delta))
	if velocity.length_squared() > 0.15 and alive:
		var desired_yaw: float = atan2(-velocity.x, -velocity.z)
		growth_root.rotation.y = lerp_angle(growth_root.rotation.y, desired_yaw, 1.0 - exp(-10.0 * delta))
	name_label.position.y = 0.25 + _target_scale * 2.0
	feedback.set_speed(velocity.length() / tuning.top_speed, alive)
	feedback.locomotion(velocity.length(), rolling, profile != null and profile.kind == VehicleProfile.Kind.SLIME, is_player)
	if character_visual != null:
		character_visual.animate(delta, velocity.length(), _target_scale, rolling, has_double_pickup())

func prepare_drive(delta: float, context: Dictionary) -> void:
	if not alive:
		return
	control_lock = maxf(0.0, control_lock - delta)
	var desired: Vector3 = driver.sample_direction(global_position, context, delta)
	_active_input = desired.length_squared() > 0.01 and control_lock <= 0.0
	steering_angle = 0.0
	var speed: float = velocity.length()
	update_roll_state()
	if control_lock > 0.0:
		return
	if not _active_input:
		velocity = velocity.move_toward(Vector3.ZERO, tuning.coasting_deceleration * delta)
		update_roll_state()
		return
	desired = desired.normalized()
	if speed > 0.1:
		_heading = velocity.normalized()
	var signed_angle: float = _heading.signed_angle_to(desired, Vector3.UP)
	if speed < 0.1:
		_heading = desired
	elif absf(signed_angle) > deg_to_rad(tuning.turn_deadzone_degrees):
		var turn_rate: float = deg_to_rad(tuning.turn_rate_degrees) / (1.0 + speed * 0.045 + maxf(0.0, vehicle_mass - 1.0) * 0.18)
		steering_angle = clampf(signed_angle, -turn_rate * delta, turn_rate * delta)
		_heading = _heading.rotated(Vector3.UP, steering_angle).normalized()
		speed *= turn_retention(steering_angle)
		_sync_distance_to_speed(speed)
	else:
		_heading = desired
	if absf(steering_angle) < 0.0001:
		var target_speed: float = tuning.base_speed + (tuning.top_speed - tuning.base_speed) * (1.0 - exp(-driven_distance / tuning.acceleration_distance))
		speed = move_toward(speed, target_speed, tuning.acceleration * delta)
	velocity = _heading * minf(speed, tuning.top_speed)
	update_roll_state()

func snapshot() -> void:
	pre_velocity = velocity
	pre_mass = vehicle_mass
	pre_candy = candy
	update_roll_state()
	pre_rolling = rolling
	pre_forward = velocity.normalized() if velocity.length_squared() > 0.01 else _heading

func move_vehicle(delta: float) -> KinematicCollision3D:
	if not alive:
		return null
	var old_position: Vector3 = global_position
	var collision: KinematicCollision3D = move_planar(velocity * delta)
	if _active_input and absf(steering_angle) < 0.0001 and collision == null:
		var gain: float = profile.rolling_distance_multiplier if rolling and profile != null else 1.0
		driven_distance += global_position.distance_to(old_position) * gain
	return collision

func move_planar(motion: Vector3, ignore_vehicles: bool = false) -> KinematicCollision3D:
	constrain_to_arena()
	motion.y = 0.0
	var previous_mask: int = collision_mask
	if ignore_vehicles:
		# Overlap correction already knows the separating direction; don't let 3D
		# penetration recovery choose to eject one cylinder above/below another.
		collision_mask = previous_mask & ~2
	var collision: KinematicCollision3D = move_and_collide(motion)
	collision_mask = previous_mask
	constrain_to_arena()
	return collision

func constrain_to_arena() -> void:
	global_position.y = 0.0
	velocity.y = 0.0
	if not play_bounds.has_area():
		return
	var inset: float = radius + 0.002
	global_position.x = clampf(global_position.x, play_bounds.position.x + inset, play_bounds.end.x - inset)
	global_position.z = clampf(global_position.z, play_bounds.position.y + inset, play_bounds.end.y - inset)

func set_candy(value: int) -> void:
	candy = maxi(0, value)
	vehicle_mass = CollisionMath.mass_for(candy, tuning)
	_target_scale = CollisionMath.scale_for(candy, tuning)
	radius = tuning.base_collision_radius * _target_scale
	var cylinder: CylinderShape3D = body_shape.shape as CylinderShape3D
	cylinder.radius = radius
	cylinder.height = 1.2 * _target_scale
	body_shape.position.y = 0.6 * _target_scale
	player_ring.scale = Vector3(_target_scale, 1.0, _target_scale)
	constrain_to_arena()
	name_label.text = "%s  ·  %d" % [driver_name, candy]
	name_label.modulate = paint
	candy_changed.emit(self)

func apply_loss(amount: int) -> int:
	if not alive:
		return 0
	var removed: int = mini(candy, maxi(0, amount))
	set_candy(candy - removed)
	if candy == 0:
		alive = false
		rolling = false
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		growth_root.hide()
		name_label.hide()
		player_ring.hide()
		respawn_remaining = tuning.respawn_seconds
		defeated.emit(self)
	return removed

func collect(amount: int, source_owner: int = 0) -> int:
	return collect_batches([{"value": amount, "owner": source_owner}])

func collect_batches(batches: Array[Dictionary]) -> int:
	if not alive:
		return 0
	var gained: int = 0
	var consumed: int = 0
	for batch: Dictionary in batches:
		var amount: int = maxi(0, int(batch["value"]))
		var own_drop: bool = int(batch["owner"]) == get_instance_id()
		consumed += amount
		gained += profile.pickup_gain(candy + gained, amount, own_drop) if profile != null else amount
	if gained > 0:
		set_candy(candy + gained)
		feedback.play_pickup()
		if character_visual != null:
			character_visual.pickup()
		feedback.show_gain(gained, gained > consumed, 0.6 + _target_scale * 2.0)
		candy_collected.emit(self, gained, gained - consumed)
	return gained

func has_double_pickup() -> bool:
	return profile != null and profile.kind == VehicleProfile.Kind.PONY and candy < profile.double_below

func update_roll_state() -> void:
	if profile == null or profile.kind != VehicleProfile.Kind.SLIME or not alive:
		rolling = false
	elif velocity.length() > profile.roll_threshold:
		rolling = true
	elif velocity.length() < profile.roll_threshold:
		rolling = false

func turn_retention(angle: float) -> float:
	if rolling and profile != null:
		return pow(profile.rolling_turn_retention, absf(angle) / (PI * 0.5))
	return CollisionMath.turn_retention(angle, tuning)

func received_damage(raw_damage: float) -> int:
	var factor: float = profile.rolling_damage_multiplier if pre_rolling and profile != null else 1.0
	return roundi(raw_damage * factor)

func can_swallow(other: CrashCar, direction: Vector3) -> bool:
	if profile == null or profile.kind != VehicleProfile.Kind.PUMPKIN or not alive or not other.alive:
		return false
	var own_scale: float = CollisionMath.scale_for(pre_candy, tuning)
	var other_scale: float = CollisionMath.scale_for(other.pre_candy, other.tuning)
	return other_scale <= own_scale * profile.swallow_size_ratio + 0.00001 and pre_forward.dot(direction) >= cos(deg_to_rad(profile.mouth_half_angle))

func animate_swallowed(mouth: Node3D) -> void:
	if mouth == null:
		return
	growth_root.show()
	var from: Vector3 = growth_root.global_position
	var old_scale: Vector3 = growth_root.scale
	_swallow_tween = create_tween()
	_swallow_tween.tween_method(func(weight: float) -> void:
		if is_instance_valid(mouth):
			growth_root.global_position = from.lerp(mouth.global_position, weight)
		growth_root.scale = old_scale * (1.0 - weight), 0.0, 1.0, 0.28)
	_swallow_tween.tween_callback(func() -> void:
		growth_root.hide()
		growth_root.position = Vector3.ZERO)

func respond(new_velocity: Vector3) -> void:
	if not alive:
		return
	velocity = new_velocity.limit_length(tuning.top_speed)
	update_roll_state()
	control_lock = 0.12
	_sync_distance_to_speed(velocity.length())

func reset_at(point: Vector3) -> void:
	if _swallow_tween != null and _swallow_tween.is_valid():
		_swallow_tween.kill()
	growth_root.position = Vector3.ZERO
	growth_root.rotation = Vector3.ZERO
	global_position = point
	alive = true
	velocity = Vector3.ZERO
	pre_velocity = Vector3.ZERO
	driven_distance = 0.0
	control_lock = 0.0
	rolling = false
	pre_rolling = false
	_heading = Vector3.FORWARD
	pre_forward = Vector3.FORWARD
	respawn_remaining = 0.0
	collision_layer = 2
	collision_mask = 3
	growth_root.show()
	name_label.show()
	player_ring.visible = is_player
	feedback.reset_feedback()
	if character_visual != null:
		character_visual.reset_pose()
	set_candy(tuning.initial_candy)
	growth_root.scale = Vector3.ONE * _target_scale

func _sync_distance_to_speed(speed: float) -> void:
	var fraction: float = clampf((speed - tuning.base_speed) / (tuning.top_speed - tuning.base_speed), 0.0, 0.9999)
	driven_distance = -tuning.acceleration_distance * log(1.0 - fraction)

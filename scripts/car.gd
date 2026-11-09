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
var braking: bool = false
var drifting: bool = false
var burst_ready: bool = false
var burst_remaining: float = 0.0
var burst_cooldown: float = 0.0
var _drift_seconds: float = 0.0
var _drift_angle: float = 0.0
var _drift_sign: float = 0.0
var _burst_target: float = 0.0
var _burst_elapsed: float = 0.0
var _burst_recovery: bool = false
var _burst_blocked: bool = false
var _suppress_charge: bool = false
var _drift_grace: float = 0.0
var _brake_force: float = 8.0
var _motion_sign: float = 1.0
var _direction_arrow: MeshInstance3D
var throttle_input: float = 0.0
var steer_input: float = 0.0

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
	if is_player:
		_direction_arrow = MeshInstance3D.new()
		var arrow_mesh: ImmediateMesh = ImmediateMesh.new()
		var arrow_material: StandardMaterial3D = StandardMaterial3D.new()
		arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		arrow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		arrow_material.albedo_color = Color("fff09a")
		arrow_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, arrow_material)
		arrow_mesh.surface_add_vertex(Vector3(0, 0.06, -1.65))
		arrow_mesh.surface_add_vertex(Vector3(-0.22, 0.06, -1.12))
		arrow_mesh.surface_add_vertex(Vector3(0.22, 0.06, -1.12))
		arrow_mesh.surface_end()
		_direction_arrow.mesh = arrow_mesh
		add_child(_direction_arrow)
	feedback.pivot = hit_pivot
	set_candy(tuning.initial_candy if starting_candy < 0 else starting_candy)
	growth_root.scale = Vector3.ONE * _target_scale

func _process(delta: float) -> void:
	if is_instance_valid(_direction_arrow):
		_direction_arrow.visible = alive
		_direction_arrow.rotation.y = atan2(-_heading.x, -_heading.z)
		_direction_arrow.scale = Vector3.ONE * _target_scale
	if not alive:
		feedback.set_speed(0.0, false)
		return
	growth_root.scale = growth_root.scale.lerp(Vector3.ONE * _target_scale, 1.0 - exp(-12.0 * delta))
	if alive:
		var desired_yaw: float = atan2(-_heading.x, -_heading.z)
		growth_root.rotation.y = lerp_angle(growth_root.rotation.y, desired_yaw, 1.0 - exp(-10.0 * delta))
	name_label.position.y = 0.25 + _target_scale * 2.0
	feedback.set_speed(velocity.length() / tuning.top_speed, alive)
	feedback.set_maneuver(braking, drifting, burst_ready, burst_remaining > 0.0, delta)
	feedback.locomotion(velocity.length(), rolling, profile != null and profile.kind == VehicleProfile.Kind.SLIME, is_player)
	if character_visual != null:
		character_visual.animate(delta, velocity.length(), _target_scale, rolling, has_double_pickup())

func prepare_drive(delta: float, context: Dictionary) -> void:
	if not alive:
		return
	control_lock = maxf(0.0, control_lock - delta)
	burst_cooldown = maxf(0.0, burst_cooldown - delta)
	context["heading"] = _heading
	context["velocity"] = velocity
	context["bounds"] = play_bounds
	var controls: Dictionary = driver.sample_controls(global_position, context, delta)
	throttle_input = clampf(float(controls.get("throttle", 0.0)), -1.0, 1.0)
	steer_input = clampf(float(controls.get("steer", 0.0)), -1.0, 1.0)
	var brake_pressed: bool = bool(controls.get("brake", false))
	_active_input = absf(throttle_input) > 0.05 and control_lock <= 0.0
	_suppress_charge = brake_pressed or burst_remaining > 0.0
	steering_angle = 0.0
	update_roll_state()
	if control_lock > 0.0:
		return
	var speed: float = velocity.length()
	var longitudinal: float = velocity.dot(_heading)
	if absf(longitudinal) > 0.1:
		_motion_sign = signf(longitudinal)
	elif speed < 0.1:
		_motion_sign = -1.0 if throttle_input < -0.05 else 1.0
	var signed_speed: float = speed * _motion_sign
	var turning: bool = absf(steer_input) > 0.15
	if brake_pressed:
		if not braking:
			_end_burst()
			_clear_drift()
			_burst_blocked = burst_cooldown > 0.0
			_brake_force = tuning.drift_drag if turning and signed_speed > tuning.drift_enter_speed else tuning.brake_deceleration
		braking = true
		if turning:
			_drift_grace = tuning.drift_steer_grace
		else:
			_drift_grace = maxf(0.0, _drift_grace - delta)
		var threshold: float = tuning.drift_exit_speed if drifting else tuning.drift_enter_speed
		drifting = signed_speed > threshold and (turning or (drifting and _drift_grace > 0.0))
	else:
		if braking and burst_ready and throttle_input > 0.1 and signed_speed > tuning.top_speed * tuning.burst_min_speed_fraction:
			burst_remaining = tuning.burst_seconds
			_burst_elapsed = 0.0
			# Never make a boost slower than ordinary full throttle in the new drive model.
			_burst_target = minf(tuning.top_speed * tuning.burst_cap_multiplier, maxf(tuning.top_speed, speed + lerpf(tuning.burst_add_small, tuning.burst_add_big, _size_weight())))
			if is_player:
				feedback.drive_cue(true)
		braking = false
		drifting = false
		_clear_drift()
	if burst_remaining > 0.0 and throttle_input <= 0.1:
		_end_burst()
	var yaw_rate: float = deg_to_rad(tuning.turn_rate_degrees) / (1.0 + minf(0.6, maxf(0.0, vehicle_mass - 1.0) * 0.09))
	if speed < 0.5:
		yaw_rate *= 0.55 # Deliberate low-speed pivot assistance, including when stopped.
	if drifting:
		yaw_rate *= lerpf(tuning.drift_turn_small, tuning.drift_turn_big, _size_weight())
	if burst_remaining > 0.0 and _burst_elapsed < tuning.burst_commit_seconds:
		yaw_rate *= tuning.burst_steer_multiplier
	steering_angle = -steer_input * yaw_rate * _motion_sign * delta
	_heading = _heading.rotated(Vector3.UP, steering_angle).normalized()
	if braking:
		_brake_force = move_toward(_brake_force, tuning.drift_drag if drifting else tuning.brake_deceleration, 18.0 * delta)
		signed_speed = move_toward(signed_speed, 0.0, _brake_force * delta)
		if drifting and turning:
			var turn_sign: float = signf(steering_angle)
			if _drift_sign != 0.0 and turn_sign != _drift_sign:
				_clear_drift()
			_drift_sign = turn_sign
			_drift_angle += absf(steering_angle)
			_drift_seconds += delta
		var was_ready: bool = burst_ready
		burst_ready = not _burst_blocked and burst_cooldown <= 0.0 and signed_speed > tuning.top_speed * tuning.burst_min_speed_fraction and _drift_seconds >= tuning.burst_min_drift_seconds and _drift_angle >= deg_to_rad(tuning.burst_min_angle_degrees)
		if burst_ready and not was_ready and is_player:
			feedback.drive_cue(false)
	else:
		signed_speed *= turn_retention(steering_angle)
		if absf(throttle_input) < 0.05:
			signed_speed = move_toward(signed_speed, 0.0, tuning.coasting_deceleration * delta)
		elif signed_speed * throttle_input < -0.01:
			# A held opposite pedal first stops, then drives in reverse on a later tick.
			signed_speed = move_toward(signed_speed, 0.0, tuning.direction_change_deceleration * delta)
		else:
			var target: float = tuning.top_speed * throttle_input if throttle_input > 0.0 else tuning.reverse_speed * throttle_input
			var acceleration: float = tuning.acceleration if absf(signed_speed) < tuning.top_speed * tuning.fast_acceleration_fraction else tuning.high_speed_acceleration
			if rolling and profile != null:
				acceleration *= profile.rolling_acceleration_multiplier
			if throttle_input < 0.0:
				acceleration = tuning.reverse_acceleration
			if burst_remaining > 0.0:
				target = _burst_target
				acceleration = maxf(acceleration, tuning.burst_acceleration * (1.0 - 0.5 * absf(steer_input)))
			if signed_speed > target:
				acceleration = tuning.burst_recovery_deceleration
			signed_speed = move_toward(signed_speed, target, acceleration * delta)
		if burst_remaining > 0.0:
			_burst_elapsed += delta
			burst_remaining = maxf(0.0, burst_remaining - delta)
			if burst_remaining <= 0.0:
				burst_cooldown = tuning.burst_cooldown_seconds
	# Heading is independent from velocity: reverse never flips the vehicle model.
	var travel_heading: Vector3 = _heading * (-1.0 if signed_speed < 0.0 else 1.0)
	if speed > 0.1 and signed_speed * _motion_sign > 0.0:
		var motion: Vector3 = velocity.normalized()
		var angle: float = motion.signed_angle_to(travel_heading, Vector3.UP)
		var grip: float = tuning.drift_grip if drifting else tuning.normal_grip
		var correction: float = angle * (1.0 - exp(-grip * delta))
		if drifting:
			correction = signf(angle) * maxf(absf(correction), absf(angle) - deg_to_rad(tuning.drift_max_slip_degrees))
		travel_heading = motion.rotated(Vector3.UP, correction).normalized()
	velocity = travel_heading * absf(signed_speed)
	update_roll_state()

func _size_weight() -> float:
	return clampf((CollisionMath.scale_for(candy, tuning) - 1.0) / 1.2, 0.0, 1.0)

func _clear_drift() -> void:
	burst_ready = false
	_drift_seconds = 0.0
	_drift_angle = 0.0
	_drift_sign = 0.0

func _end_burst() -> void:
	if burst_remaining > 0.0:
		burst_remaining = 0.0
		burst_cooldown = tuning.burst_cooldown_seconds

func cancel_maneuver() -> void:
	_end_burst()
	_clear_drift()
	braking = false
	drifting = false
	_burst_blocked = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_player:
		for action: StringName in [&"brake", &"move_left", &"move_right", &"move_up", &"move_down"]:
			Input.action_release(action)
		cancel_maneuver()

func snapshot() -> void:
	pre_velocity = velocity
	pre_mass = vehicle_mass
	pre_candy = candy
	update_roll_state()
	pre_rolling = rolling
	pre_forward = _heading

func move_vehicle(delta: float) -> KinematicCollision3D:
	if not alive:
		return null
	var old_position: Vector3 = global_position
	var collision: KinematicCollision3D = move_planar(velocity * delta)
	if _active_input and not _suppress_charge and absf(steering_angle) < 0.0001 and collision == null:
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
		cancel_maneuver()
		burst_cooldown = 0.0
		_burst_recovery = false
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
		driver.notify_progress()
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

func animate_swallowed(mouth: Node3D, pull_seconds: float = 0.28, opening_seconds: float = 0.0) -> void:
	if mouth == null:
		return
	if _swallow_tween != null and _swallow_tween.is_valid():
		_swallow_tween.kill()
	growth_root.show()
	var from: Vector3 = growth_root.global_position
	var old_scale: Vector3 = growth_root.scale
	_swallow_tween = create_tween()
	if opening_seconds > 0.0:
		_swallow_tween.tween_interval(opening_seconds)
	_swallow_tween.tween_method(func(weight: float) -> void:
		if is_instance_valid(mouth):
			growth_root.global_position = from.lerp(mouth.global_position, weight)
		growth_root.scale = old_scale * maxf(0.001, 1.0 - weight), 0.0, 1.0, pull_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_swallow_tween.tween_callback(func() -> void:
		growth_root.hide()
		growth_root.position = Vector3.ZERO)

func respond(new_velocity: Vector3) -> void:
	if not alive:
		return
	cancel_maneuver()
	velocity = new_velocity.limit_length(tuning.top_speed)
	update_roll_state()
	control_lock = 0.12

func reset_at(point: Vector3) -> void:
	if _swallow_tween != null and _swallow_tween.is_valid():
		_swallow_tween.kill()
	growth_root.position = Vector3.ZERO
	growth_root.rotation = Vector3.ZERO
	global_position = point
	alive = true
	cancel_maneuver()
	burst_cooldown = 0.0
	_burst_recovery = false
	_suppress_charge = false
	velocity = Vector3.ZERO
	pre_velocity = Vector3.ZERO
	driven_distance = 0.0
	control_lock = 0.0
	rolling = false
	pre_rolling = false
	_heading = Vector3.FORWARD
	_motion_sign = 1.0
	_drift_grace = 0.0
	throttle_input = 0.0
	steer_input = 0.0
	driver.reset_driver()
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

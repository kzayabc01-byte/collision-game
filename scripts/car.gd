class_name CrashCar
extends CharacterBody3D

signal candy_changed(car: CrashCar)
signal defeated(car: CrashCar)

@export var tuning: GameTuning
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
var respawn_remaining: float = 0.0
var driven_distance: float = 0.0
var steering_angle: float = 0.0
var control_lock: float = 0.0
var _target_scale: float = 1.0
var _heading: Vector3 = Vector3.FORWARD
var _active_input: bool = false

@onready var body_shape: CollisionShape3D = $BodyCollision
@onready var growth_root: Node3D = $GrowthRoot
@onready var hit_pivot: Node3D = $GrowthRoot/HitPivot
@onready var driver: DriveInput = $Driver
@onready var feedback: CarFeedback = $Feedback
@onready var name_label: Label3D = $NameLabel
@onready var player_ring: MeshInstance3D = $PlayerRing

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
	growth_root.scale = growth_root.scale.lerp(Vector3.ONE * _target_scale, 1.0 - exp(-12.0 * delta))
	if velocity.length_squared() > 0.15 and alive:
		var desired_yaw: float = atan2(-velocity.x, -velocity.z)
		growth_root.rotation.y = lerp_angle(growth_root.rotation.y, desired_yaw, 1.0 - exp(-10.0 * delta))
	name_label.position.y = 1.15 + _target_scale * 0.55
	feedback.set_speed(velocity.length() / tuning.top_speed, alive)

func prepare_drive(delta: float, context: Dictionary) -> void:
	if not alive:
		return
	control_lock = maxf(0.0, control_lock - delta)
	var desired: Vector3 = driver.sample_direction(global_position, context, delta)
	_active_input = desired.length_squared() > 0.01 and control_lock <= 0.0
	steering_angle = 0.0
	var speed: float = velocity.length()
	if control_lock > 0.0:
		return
	if not _active_input:
		velocity = velocity.move_toward(Vector3.ZERO, tuning.coasting_deceleration * delta)
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
		speed *= CollisionMath.turn_retention(steering_angle, tuning)
		_sync_distance_to_speed(speed)
	else:
		_heading = desired
	if absf(steering_angle) < 0.0001:
		var target_speed: float = tuning.base_speed + (tuning.top_speed - tuning.base_speed) * (1.0 - exp(-driven_distance / tuning.acceleration_distance))
		speed = move_toward(speed, target_speed, tuning.acceleration * delta)
	velocity = _heading * minf(speed, tuning.top_speed)

func snapshot() -> void:
	pre_velocity = velocity
	pre_mass = vehicle_mass
	pre_candy = candy

func move_vehicle(delta: float) -> KinematicCollision3D:
	if not alive:
		return null
	var old_position: Vector3 = global_position
	var collision: KinematicCollision3D = move_and_collide(velocity * delta)
	if _active_input and absf(steering_angle) < 0.0001 and collision == null:
		driven_distance += global_position.distance_to(old_position)
	return collision

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
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		growth_root.hide()
		name_label.hide()
		player_ring.hide()
		respawn_remaining = tuning.respawn_seconds
		defeated.emit(self)
	return removed

func collect(amount: int) -> void:
	if alive:
		set_candy(candy + amount)
		feedback.play_pickup()

func respond(new_velocity: Vector3) -> void:
	if not alive:
		return
	velocity = new_velocity.limit_length(tuning.top_speed)
	control_lock = 0.12
	_sync_distance_to_speed(velocity.length())

func reset_at(point: Vector3) -> void:
	global_position = point
	alive = true
	velocity = Vector3.ZERO
	pre_velocity = Vector3.ZERO
	driven_distance = 0.0
	control_lock = 0.0
	respawn_remaining = 0.0
	collision_layer = 2
	collision_mask = 3
	growth_root.show()
	name_label.show()
	player_ring.visible = is_player
	feedback.reset_feedback()
	set_candy(tuning.initial_candy)

func _sync_distance_to_speed(speed: float) -> void:
	var fraction: float = clampf((speed - tuning.base_speed) / (tuning.top_speed - tuning.base_speed), 0.0, 0.9999)
	driven_distance = -tuning.acceleration_distance * log(1.0 - fraction)

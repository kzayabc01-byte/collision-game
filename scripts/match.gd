class_name CrashMatch
extends Node3D

enum Phase {
	PLAYING,
	PAUSED,
	FINISHED,
}

@export var tuning: GameTuning

var phase: Phase = Phase.PLAYING
var remaining_seconds: float = 180.0
var cars: Array[CrashCar] = []
var player: CrashCar
var _neutral_remaining: float = 0.0

@onready var candy_system: CandySystem = $CandySystem
@onready var resolver: CollisionResolver = $CollisionResolver
@onready var hud: PrototypeHUD = $HUD
@onready var spawn_points: Node3D = $Arena/VehicleSpawnPoints
@onready var neutral_points: Node3D = $Arena/CandySpawnPoints

func _ready() -> void:
	remaining_seconds = tuning.round_seconds
	_neutral_remaining = tuning.neutral_spawn_seconds
	resolver.candy_system = candy_system
	resolver.impact_resolved.connect(_on_impact)
	hud.restart_requested.connect(restart)
	hud.pause_requested.connect(toggle_pause)
	for child: Node in $Vehicles.get_children():
		var car: CrashCar = child as CrashCar
		if car != null:
			cars.append(car)
			if car.is_player:
				player = car
	hud.announce("WASD / 方向键移动 · 蓄速撞糖箱，30颗后更容易撞碎")
	_spawn_neutral()
	hud.refresh(player, cars, remaining_seconds)

func _physics_process(delta: float) -> void:
	if phase != Phase.PLAYING:
		return
	resolver.begin_tick(delta)
	var candy_positions: Array[Vector3] = candy_system.positions()
	var obstacle_positions: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group("candy_obstacles"):
		var obstacle: CrashObstacle = node as CrashObstacle
		if obstacle != null and not obstacle.is_broken:
			obstacle_positions.append(obstacle.global_position)
	for car: CrashCar in cars:
		if not car.alive:
			car.respawn_remaining = maxf(0.0, car.respawn_remaining - delta)
			if car.respawn_remaining <= 0.0:
				_try_respawn(car)
			continue
		var opponents: Array[Dictionary] = []
		for other: CrashCar in cars:
			if other != car and other.alive:
				opponents.append({"position": other.global_position, "mass": other.vehicle_mass})
		car.prepare_drive(delta, {"candies": candy_positions, "obstacles": obstacle_positions, "opponents": opponents, "mass": car.vehicle_mass, "radius": car.radius, "velocity": car.velocity, "tuning": tuning})
	for car: CrashCar in cars:
		car.snapshot()
	for car: CrashCar in cars:
		resolver.record(car, car.move_vehicle(delta))
	resolver.resolve_events()
	_separate_grown_cars()
	candy_system.tick(delta)
	_neutral_remaining -= delta
	if _neutral_remaining <= 0.0:
		_neutral_remaining += tuning.neutral_spawn_seconds
		_spawn_neutral()
	# Finish this physics tick before freezing the score and the world.
	remaining_seconds = maxf(0.0, remaining_seconds - delta)
	hud.refresh(player, cars, remaining_seconds)
	if remaining_seconds <= 0.0:
		finish_round()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()
	elif event.is_action_pressed("pause_match"):
		toggle_pause()

func restart() -> void:
	get_tree().reload_current_scene()

func toggle_pause() -> void:
	if phase == Phase.FINISHED:
		return
	phase = Phase.PAUSED if phase == Phase.PLAYING else Phase.PLAYING
	if phase == Phase.PAUSED:
		hud.show_overlay("比赛暂停", "按 Esc 或右上角按钮继续\nR 重新开始")
	else:
		hud.hide_overlay()

func finish_round() -> void:
	phase = Phase.FINISHED
	var best: int = 0
	for car: CrashCar in cars:
		best = maxi(best, car.candy)
	var winners: PackedStringArray = PackedStringArray()
	for car: CrashCar in cars:
		if car.candy == best:
			winners.append(car.driver_name)
		car.velocity = Vector3.ZERO
	hud.show_overlay("并列获胜" if winners.size() > 1 else "比赛结束", "%s\n以 %d 颗糖果获胜" % [" / ".join(winners), best])

func _try_respawn(car: CrashCar) -> void:
	var best_point: Vector3 = Vector3.ZERO
	var best_clearance: float = -1.0
	for node: Node in spawn_points.get_children():
		var marker: Marker3D = node as Marker3D
		var clearance: float = INF
		for other: CrashCar in cars:
			if other != car and other.alive:
				clearance = minf(clearance, marker.global_position.distance_to(other.global_position) - other.radius - tuning.base_collision_radius)
		if clearance > best_clearance:
			best_clearance = clearance
			best_point = marker.global_position
	if best_clearance > 0.6:
		car.reset_at(best_point)
		resolver.clear_for(car)
	else:
		car.respawn_remaining = 0.2

func _spawn_neutral() -> void:
	var markers: Array[Node] = neutral_points.get_children()
	var marker: Marker3D = markers.pick_random() as Marker3D
	candy_system.spawn_drop(marker.global_position, Vector3.FORWARD, tuning.neutral_spawn_amount, 0, 0)

func _separate_grown_cars() -> void:
	for first: int in range(cars.size()):
		for second: int in range(first + 1, cars.size()):
			var a: CrashCar = cars[first]
			var b: CrashCar = cars[second]
			if not a.alive or not b.alive:
				continue
			var offset: Vector3 = b.global_position - a.global_position
			var overlap: float = a.radius + b.radius - offset.length()
			if overlap > 0.02:
				var normal: Vector3 = offset.normalized() if offset.length_squared() > 0.001 else Vector3.RIGHT
				a.move_and_collide(-normal * minf(overlap * 0.5, 0.2))
				b.move_and_collide(normal * minf(overlap * 0.5, 0.2))

func _on_impact(_point: Vector3, tier: int, message: String) -> void:
	$CameraRig.shake(tier)
	hud.announce(message)

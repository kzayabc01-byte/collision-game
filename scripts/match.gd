class_name CrashMatch
extends Node3D

enum Phase {
	PLAYING,
	PAUSED,
	FINISHED,
}

const VehiclePaths: Array[String] = [
	"res://scenes/vehicles/pony_car.tscn",
	"res://scenes/vehicles/pumpkin_car.tscn",
	"res://scenes/vehicles/slime_car.tscn",
]

static var selected_vehicle: int = 0
static var ability_lab: bool = false

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
	hud.vehicle_requested.connect(select_vehicle)
	hud.lab_requested.connect(toggle_lab)
	for child: Node in $Vehicles.get_children():
		var car: CrashCar = child as CrashCar
		if car != null:
			cars.append(car)
			if car.is_player:
				player = car
	if player.profile == null or int(player.profile.kind) != selected_vehicle:
		_replace_player(selected_vehicle)
	hud.configure_vehicle(selected_vehicle, ability_lab)
	if ability_lab:
		_setup_ability_lab()
	else:
		hud.announce("1 小马 / 2 南瓜 / 3 史莱姆 · F2 能力试验")
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
		if ability_lab and car != player:
			car.velocity = Vector3.ZERO
			continue
		var opponents: Array[Dictionary] = []
		for other: CrashCar in cars:
			if other != car and other.alive:
				opponents.append({"position": other.global_position, "mass": other.vehicle_mass, "scale": CollisionMath.scale_for(other.candy, tuning)})
		car.prepare_drive(delta, {"candies": candy_positions, "obstacles": obstacle_positions, "opponents": opponents, "mass": car.vehicle_mass, "radius": car.radius, "velocity": car.velocity, "tuning": tuning, "profile": car.profile, "rolling": car.rolling, "scale": CollisionMath.scale_for(car.candy, tuning)})
	for car: CrashCar in cars:
		car.snapshot()
	for car: CrashCar in cars:
		resolver.record(car, car.move_vehicle(delta))
	resolver.resolve_events()
	_update_appetites()
	_separate_grown_cars()
	candy_system.tick(delta)
	_neutral_remaining -= delta if not ability_lab else 0.0
	if _neutral_remaining <= 0.0 and not ability_lab:
		_neutral_remaining += tuning.neutral_spawn_seconds
		_spawn_neutral()
	# Finish this physics tick before freezing the score and the world.
	remaining_seconds = maxf(0.0, remaining_seconds - delta) if not ability_lab else remaining_seconds
	hud.refresh(player, cars, remaining_seconds)
	if remaining_seconds <= 0.0:
		finish_round()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = (event as InputEventKey).physical_keycode
		if key >= KEY_1 and key <= KEY_3:
			select_vehicle(key - KEY_1)
			return
		if key == KEY_F2:
			toggle_lab()
			return
	if event.is_action_pressed("restart"):
		restart()
	elif event.is_action_pressed("pause_match"):
		toggle_pause()

func restart() -> void:
	get_tree().reload_current_scene()

func select_vehicle(kind: int) -> void:
	selected_vehicle = clampi(kind, 0, VehiclePaths.size() - 1)
	restart.call_deferred()

func toggle_lab() -> void:
	ability_lab = not ability_lab
	restart.call_deferred()

func _replace_player(kind: int) -> void:
	var previous: CrashCar = player
	# Load after class initialization; preloading inherited scenes here creates a type-loading cycle.
	var replacement: CrashCar = (load(VehiclePaths[kind]) as PackedScene).instantiate() as CrashCar
	replacement.name = "PlayerCar"
	replacement.is_player = true
	replacement.paint = replacement.profile.accent
	replacement.position = previous.position
	var index: int = cars.find(previous)
	$Vehicles.remove_child(previous)
	previous.queue_free()
	$Vehicles.add_child(replacement)
	cars[index] = replacement
	player = replacement

func _setup_ability_lab() -> void:
	player.reset_at(Vector3(-15, 0, 3))
	cars[1].reset_at(Vector3(0, 0, 4))
	cars[2].reset_at(Vector3(11, 0, -3))
	cars[3].reset_at(Vector3(13, 0, 10))
	if selected_vehicle == VehicleProfile.Kind.PUMPKIN:
		player.global_position = Vector3(-6, 0, 4)
		player.set_candy(80)
		hud.announce("吞噬试验：你80颗，对面20颗；按 D 用车头接触")
	elif selected_vehicle == VehicleProfile.Kind.PONY:
		player.set_candy(38)
		for index: int in range(6):
			var pickup: CandyPickup = CandySystem.CandyScene.instantiate() as CandyPickup
			candy_system.add_child(pickup)
			pickup.position = Vector3(-12 + index * 1.4, 0, 3)
			pickup.add_lot(1, 0, candy_system.clock_seconds, 0.0, 3600.0)
		hud.announce("翻倍试验：从38颗开始，向右吃糖；达到40后恢复普通收益")
	else:
		hud.announce("滚动试验：按 D 直行，速度超过4自动收脚滚动；转向观察减速")

func _update_appetites() -> void:
	for car: CrashCar in cars:
		if car.character_visual == null or car.profile == null or car.profile.kind != VehicleProfile.Kind.PUMPKIN:
			continue
		var ready_to_eat: bool = false
		for other: CrashCar in cars:
			var offset: Vector3 = other.global_position - car.global_position
			if other != car and offset.length() < car.radius + other.radius + 3.0 and car.can_swallow(other, offset.normalized()):
				ready_to_eat = true
		car.character_visual.set_appetite(ready_to_eat)

func toggle_pause() -> void:
	if phase == Phase.FINISHED:
		return
	phase = Phase.PAUSED if phase == Phase.PLAYING else Phase.PLAYING
	$Vehicles.process_mode = Node.PROCESS_MODE_DISABLED if phase == Phase.PAUSED else Node.PROCESS_MODE_INHERIT
	candy_system.process_mode = Node.PROCESS_MODE_DISABLED if phase == Phase.PAUSED else Node.PROCESS_MODE_INHERIT
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

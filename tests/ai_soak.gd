extends SceneTree

var _impacts: int = 0
var _defeats: int = 0
var _breaks: int = 0
var _peak_speeds: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _confined: bool = true
var car_contacts: int = 0
var player_contacts: int = 0
var first_contact: float = -1.0
var target_bound: bool = true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: CrashMatch = (load("res://scenes/match.tscn") as PackedScene).instantiate() as CrashMatch
	var run_seed: int = 20261103
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			run_seed = int(arg.trim_prefix("--seed="))
	seed(run_seed)
	for child: Node in game.get_node("Vehicles").get_children():
		(child.get_node("AIDriver") as Node).set("random_seed", run_seed + child.get_index())
	root.add_child(game)
	current_scene = game
	game.resolver.vehicle_contact.connect(func(a: CrashCar, b: CrashCar) -> void:
		car_contacts += 1
		if a.is_player or b.is_player:
			player_contacts += 1
		if first_contact < 0.0:
			first_contact = 180.0 - game.remaining_seconds)

	game.resolver.impact_resolved.connect(func(_point: Vector3, _tier: int, _message: String) -> void: _impacts += 1)
	for car: CrashCar in game.cars:
		car.defeated.connect(func(_car: CrashCar) -> void: _defeats += 1)
	for node: Node in get_nodes_in_group("candy_obstacles"):
		(node as CrashObstacle).broken.connect(func(_obstacle: CrashObstacle) -> void: _breaks += 1)
	for index: int in range(12500):
		await physics_frame
		for car_index: int in range(game.cars.size()):
			_peak_speeds[car_index] = maxf(_peak_speeds[car_index], game.cars[car_index].velocity.length())
			var car: CrashCar = game.cars[car_index]
			if not car.is_player and not str(car.driver.get("target_key")).is_empty():
				target_bound = target_bound and float(car.driver.get("_age")) <= 9.2
			var bounds: Rect2 = car.play_bounds.grow(-car.radius + 0.005)
			if car.alive and (absf(car.position.y) > 0.001 or not bounds.has_point(Vector2(car.position.x, car.position.z))):
				_confined = false
				push_error("Car escaped the ground plane or arena: " + str(car.position))
				break
		if not _confined:
			break
		if game.phase == CrashMatch.Phase.FINISHED:
			break
	print("SOAK phase=%s remaining=%.3f impacts=%d defeats=%d obstacles_broken=%d loose_value=%d nodes=%d" % [game.phase, game.remaining_seconds, _impacts, _defeats, _breaks, game.candy_system.total_value(), game.candy_system.get_child_count()])
	for car: CrashCar in game.cars:
		print("CAR ", car.driver_name, " candy=", car.candy, " position=", car.global_position)
	print("PEAK SPEEDS ", _peak_speeds)
	print("ALL CARS CONFINED ", _confined)
	print("CONTACTS ", car_contacts, " PLAYER_CONTACTS ", player_contacts, " FIRST_CONTACT ", first_contact, " BOUNDED_TARGETS ", target_bound)
	for car: CrashCar in game.cars:
		if not car.is_player:
			print("AI ", car.driver_name, " hunts=", car.driver.get("hunt_seconds"), " changes=", car.driver.get("target_changes"), " abandoned=", car.driver.get("abandoned_targets"), " recoveries=", car.driver.get("recoveries"))
	var passed: bool = car_contacts >= 8 and player_contacts > 0 and first_contact < 20.0 and target_bound and _confined and game.phase == CrashMatch.Phase.FINISHED and _impacts > 0 and _breaks > 0 and game.candy_system.get_child_count() <= game.tuning.maximum_candy_nodes
	game.queue_free()
	for index: int in range(5):
		await process_frame
	quit(0 if passed else 1)

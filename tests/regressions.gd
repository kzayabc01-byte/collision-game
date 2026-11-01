extends SceneTree

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var watchdog: Timer = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 30.0
	root.add_child(watchdog)
	watchdog.timeout.connect(func() -> void: quit(2))
	watchdog.start()
	check(await _input_isolation(), "input isolation suite finished")
	check(await _growth_at_walls(), "wall growth suite finished")
	check(await _gain_cleanup(), "gain cleanup suite finished")
	print("REGRESSION: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func frames(count: int = 3) -> void:
	for index: int in range(count):
		await physics_frame

func _input_isolation() -> bool:
	CrashMatch.ability_lab = false
	for selected: int in range(3):
		CrashMatch.selected_vehicle = selected
		var game: CrashMatch = (load("res://scenes/match.tscn") as PackedScene).instantiate() as CrashMatch
		root.add_child(game)
		game.set_physics_process(false)
		var player_drivers: int = 0
		for car: CrashCar in game.cars:
			if car.driver.get_script().resource_path.ends_with("player_driver.gd"):
				player_drivers += 1
		check(player_drivers == 1, "only one player input driver for selection %d" % selected)
		for action: String in ["move_left", "move_right", "move_up", "move_down"]:
			var context: Dictionary = {"mass": 1.0, "obstacles": [], "candies": [], "opponents": [], "velocity": Vector3.ZERO, "radius": 0.76, "tuning": game.tuning}
			var before: Array[Vector3] = []
			for index: int in range(1, game.cars.size()):
				var driver: DriveInput = game.cars[index].driver
				if driver.get_script().resource_path.ends_with("ai_driver.gd"):
					driver.set("_target", game.cars[index].global_position + Vector3.FORWARD * 8.0)
					driver.set("_intent", 1)
					driver.set("_decision_remaining", 100.0)
					driver.set("_commit_remaining", 100.0)
				before.append(driver.sample_direction(game.cars[index].global_position, context, 0.0))
			Input.action_press(action)
			var unchanged: bool = true
			for index: int in range(1, game.cars.size()):
				unchanged = unchanged and before[index - 1].is_equal_approx(game.cars[index].driver.sample_direction(game.cars[index].global_position, context, 0.0))
			check(unchanged, "AI decisions ignore %s for selection %d" % [action, selected])
			check(not game.player.driver.sample_direction(game.player.global_position, context, 0.0).is_zero_approx(), "player receives %s" % action)
			Input.action_release(action)
		game.queue_free()
		await frames()
	CrashMatch.selected_vehicle = 0
	return true

func _inside(car: CrashCar) -> bool:
	return absf(car.global_position.x) + car.radius <= 19.51 and absf(car.global_position.z) + car.radius <= 13.51 and absf(car.global_position.y) < 0.001

func _growth_at_walls() -> bool:
	CrashMatch.selected_vehicle = 2
	var game: CrashMatch = (load("res://scenes/match.tscn") as PackedScene).instantiate() as CrashMatch
	root.add_child(game)
	game.set_physics_process(false)
	for index: int in range(1, game.cars.size()):
		game.cars[index].apply_loss(game.cars[index].candy)
		game.cars[index].respawn_remaining = 99999.0
	var car: CrashCar = game.player
	var points: Array[Vector3] = [
		Vector3(18.8, 0, 12.8), Vector3(-18.8, 0, 12.8),
		Vector3(18.8, 0, -12.8), Vector3(-18.8, 0, -12.8),
		Vector3(18.8, 0, 4), Vector3(-18.8, 0, 4),
		Vector3(0, 0, 12.8), Vector3(0, 0, -12.8),
	]
	for point: Vector3 in points:
		car.reset_at(point)
		car.set_candy(5)
		car.global_position = point
		await frames()
		car.set_candy(135)
		var kept_inside: bool = true
		for frame: int in range(90):
			var outward: Vector3 = Vector3(signf(point.x), 0, signf(point.z)).normalized()
			car.velocity = outward * 9.0
			car.snapshot()
			game.resolver.begin_tick(1.0 / 60.0)
			game.resolver.record(car, car.move_vehicle(1.0 / 60.0))
			game.resolver.resolve_events()
			if not _inside(car):
				if kept_inside:
					print("ESCAPE origin=", point, " pos=", car.position, " radius=", car.radius)
				kept_inside = false
			await physics_frame
		check(kept_inside, "growth and repeated impact remain inside at %s" % point)
		game.resolver.clear_for(car)
	# Repeated growth while two cars are squeezed next to an outer wall.
	var other: CrashCar = game.cars[1]
	car.reset_at(Vector3(17.8, 0, 10))
	other.reset_at(Vector3(16.5, 0, 10))
	var separation_safe: bool = true
	for count: int in range(20, 141, 4):
		car.set_candy(count)
		other.set_candy(count)
		game._separate_grown_cars()
		separation_safe = separation_safe and _inside(car) and _inside(other)
		await physics_frame
	check(separation_safe, "growing cars cannot push each other out or off ground plane")
	print("SQUEEZED positions=", car.position, " / ", other.position)
	car.reset_at(Vector3(16, 0, 9))
	other.reset_at(Vector3(16, 0, 9))
	car.set_candy(135)
	other.set_candy(5)
	await frames()
	game._separate_grown_cars()
	print("OVERLAP positions=", car.position, " / ", other.position)
	check(absf(car.position.y) < 0.001 and absf(other.position.y) < 0.001, "deep vehicle overlap cannot eject a car vertically")
	check(car.position.distance_to(other.position) >= car.radius + other.radius - 0.02, "overlapping cars actually separate horizontally")
	game.queue_free()
	await frames()
	CrashMatch.selected_vehicle = 0
	return true

func _gain_cleanup() -> bool:
	var car: CrashCar = (load("res://scenes/vehicles/pony_car.tscn") as PackedScene).instantiate() as CrashCar
	root.add_child(car)
	car.collect(1)
	check(car.feedback.gain_label.visible, "pickup amount initially visible")
	await frames(50)
	check(not car.feedback.gain_label.visible, "pickup text and outline disappear completely")
	car.collect(1)
	await frames(10)
	car.collect(1)
	await frames(50)
	check(not car.feedback.gain_label.visible, "repeated pickup restarts then clears label")
	car.queue_free()
	await frames()
	return true

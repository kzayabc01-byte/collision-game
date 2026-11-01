extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var car: CrashCar = (load("res://scenes/car.tscn") as PackedScene).instantiate() as CrashCar
	car.is_player = true
	root.add_child(car)
	await physics_frame
	Input.action_press("move_right")
	for index: int in range(300):
		car.prepare_drive(1.0 / 60.0, {})
		car.move_vehicle(1.0 / 60.0)
		await physics_frame
	Input.action_release("move_right")
	print("STRAIGHT distance=", car.global_position.length(), " speed=", car.velocity.length(), " stored_distance=", car.driven_distance)
	var passed: bool = car.global_position.x > 15.0 and car.velocity.length() > 6.0
	var before_speed: float = car.velocity.length()
	Input.action_press("move_up")
	for index: int in range(120):
		car.prepare_drive(1.0 / 60.0, {})
		car.move_vehicle(1.0 / 60.0)
		await physics_frame
		if car.velocity.normalized().dot(Vector3.FORWARD) > 0.999:
			break
	Input.action_release("move_up")
	var retained: float = car.velocity.length() / before_speed
	print("TURN RETENTION ", retained)
	passed = passed and retained > 0.84 and retained < 0.88
	print("KEY_LEFT=", KEY_LEFT, " KEY_RIGHT=", KEY_RIGHT, " KEY_UP=", KEY_UP, " KEY_DOWN=", KEY_DOWN)
	car.queue_free()
	await process_frame
	quit(0 if passed else 1)

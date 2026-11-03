extends SceneTree

var car: CrashCar
var passed: int = 0
var failed: int = 0
var trace: Array[String] = ["phase,time,speed,x,z,heading_x,heading_z,slip_degrees,ready,burst"]

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("PASS " if ok else "FAIL ", label)

func controls(forward: bool = false, reverse: bool = false, left: bool = false, right: bool = false, brake: bool = false) -> void:
	var actions: Array[String] = ["move_up", "move_down", "move_left", "move_right", "brake"]
	var values: Array[bool] = [forward, reverse, left, right, brake]
	for i: int in range(actions.size()):
		Input.action_release(actions[i])
		if values[i]:
			Input.action_press(actions[i])

func setup(heading: Vector3 = Vector3.FORWARD, speed: float = 0.0) -> void:
	controls()
	car.reset_at(Vector3.ZERO)
	car._heading = heading
	car.velocity = heading * speed

func tick(frames: int, phase: String = "", fps: float = 60.0) -> void:
	for i: int in range(frames):
		car.prepare_drive(1.0 / fps, {})
		car.move_vehicle(1.0 / fps)
		if not phase.is_empty():
			trace.append("%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.3f,%s,%.4f" % [phase, i/fps, car.velocity.length(), car.position.x, car.position.z, car._heading.x, car._heading.z, rad_to_deg(car._heading.angle_to(car.velocity)) if car.velocity.length() > 0.1 else 0.0, car.burst_ready, car.burst_remaining])

func _run() -> void:
	car = (load("res://scenes/car.tscn") as PackedScene).instantiate() as CrashCar
	car.is_player = true
	root.add_child(car)
	var shift_bound: bool = false
	var space_bound: bool = false
	for event: InputEvent in InputMap.action_get_events("brake"):
		if event is InputEventKey:
			shift_bound = shift_bound or event.physical_keycode == KEY_SHIFT
			space_bound = space_bound or event.physical_keycode == KEY_SPACE
	check(shift_bound and not space_bound, "Shift replaces Space for braking")
	var physical: InputEventKey = InputEventKey.new()
	physical.physical_keycode = KEY_W
	physical.keycode = KEY_W
	physical.shift_pressed = true
	physical.pressed = true
	Input.parse_input_event(physical)
	Input.flush_buffered_events()
	await process_frame
	check(float(car.driver.sample_controls(Vector3.ZERO, {}, 0.0)["throttle"]) > 0.5, "physical W still accelerates with Shift held")
	var released: InputEventKey = physical.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	Input.flush_buffered_events()
	await process_frame
	setup()
	controls(true)
	tick(60, "launch")
	print("LAUNCH 1s speed=", car.velocity.length())
	check(car.velocity.length() >= 8.8 and car.velocity.length() <= 9.001, "full throttle reaches near top in 1 second")
	setup(Vector3.BACK)
	controls(true)
	tick(20)
	check(car.position.z > 0.5 and car._heading.dot(Vector3.BACK) > 0.99, "W moves forward relative to downward-facing car")
	controls(true, false, true)
	tick(10)
	check(car._heading.x > 0.1, "A steers vehicle-left when facing screen down")
	setup()
	controls(false, true)
	tick(60, "reverse")
	check(car.velocity.z > 3.4 and car.velocity.length() <= 3.501 and car._heading.z < -0.99, "S reverses with limited speed without flipping car")
	controls(false, true, true)
	tick(10)
	check(car._heading.x > 0.1, "reverse uses steering-wheel yaw convention")
	setup(Vector3.FORWARD, 9.0)
	controls(false, true)
	tick(10)
	check(car.velocity.z < -6.5, "opposite pedal brakes before reversing")
	tick(100)
	check(car.velocity.z > 3.4, "holding S transitions through stop into reverse")
	setup()
	controls(true, true, true, true)
	tick(30)
	check(car.velocity.length() < 0.001 and car._heading.dot(Vector3.FORWARD) > 0.999, "opposing keys cancel")
	setup()
	controls(true, false, false, true)
	tick(60)
	check(car.velocity.length() > 7.5, "throttle continues accelerating through a turn")
	setup(Vector3.FORWARD, 9.0)
	controls(false, false, false, false, true)
	tick(30, "brake")
	check(car.velocity.length() > 4.8 and car.velocity.length() < 5.2, "half-second Shift leaves controllable speed")
	tick(40)
	check(car.velocity.length() < 0.001 and car.position.length() > 4.8 and car.position.length() < 5.2, "straight stop takes about 1.13s and 5 units")
	check(not car.burst_ready, "straight brake does not earn burst")
	setup(Vector3.FORWARD, 9.0)
	controls(true, false, true, false, true)
	tick(36, "drift")
	var speed: float = car.velocity.length()
	var slip: float = rad_to_deg(car._heading.angle_to(car.velocity))
	print("DRIFT .6s speed=", speed, " slip=", slip)
	check(car.drifting and speed > 6.5 and speed < 7.8, "drift remains active and moving for .6 seconds")
	check(slip > 15.0 and slip <= 40.1, "drift separates heading and travel visibly")
	check(car.burst_ready, "normal held-input drift reliably arms burst")
	controls(true, false, true)
	tick(10, "burst-turn")
	check(car.burst_remaining > 0.0 and car.velocity.length() > speed, "burst accelerates even with A still held")
	controls(true)
	tick(10, "burst-straight")
	check(car.velocity.length() <= 9.451 and car.velocity.length() >= 9.0, "exit burst reaches limited overspeed")
	check(rad_to_deg(car._heading.angle_to(car.velocity)) < 3.0, "release smoothly restores grip")
	tick(80)
	check(absf(car.velocity.length() - 9.0) < 0.01, "burst returns to ordinary full throttle")
	setup(Vector3.FORWARD, 9.0)
	controls(true, false, true, false, true)
	tick(30)
	controls(false)
	tick(1)
	check(car.burst_remaining == 0.0, "no W means no automatic forward burst")
	setup(Vector3.FORWARD, 9.0)
	controls(true, false, true, false, true)
	tick(30)
	controls(true, false, false, true, true)
	tick(1)
	check(not car.burst_ready, "countersteer resets qualification")
	setup(Vector3.FORWARD, 9.0)
	controls(true, false, true, false, true)
	tick(30)
	controls(true)
	tick(1)
	car.respond(Vector3.RIGHT * 5.0)
	check(car.burst_remaining == 0 and car.burst_cooldown > 0 and not car.burst_ready, "impact interrupts boost and preserves cooldown")
	car.apply_loss(999)
	car.reset_at(Vector3.ZERO)
	check(car.burst_remaining == 0 and car.burst_cooldown == 0 and not car.braking, "respawn resets maneuver state")
	var results: Array[float] = []
	for fps: int in [30, 60, 120]:
		setup(Vector3.FORWARD, 9.0)
		controls(true, false, true, false, true)
		tick(int(fps * 0.6), "", float(fps))
		results.append(car.velocity.length())
	check(absf(results.max() - results.min()) < 0.05, "drift speed consistent at 30/60/120Hz")
	controls()
	var file: FileAccess = FileAccess.open("user://v2-driving.csv", FileAccess.WRITE)
	file.store_string("\n".join(trace))
	print("DRIVING V2: ", passed, " passed, ", failed, " failed; trace=user://v2-driving.csv")
	car.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

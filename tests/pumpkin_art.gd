extends SceneTree

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func frames(count: int) -> void:
	for index: int in range(count):
		await process_frame

func _run() -> void:
	var watchdog: Timer = Timer.new()
	watchdog.wait_time = 20.0
	watchdog.one_shot = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func() -> void: quit(2))
	watchdog.start()
	var car: CrashCar = (load("res://scenes/vehicles/pumpkin_car.tscn") as PackedScene).instantiate() as CrashCar
	root.add_child(car)
	car.set_process(false)
	var visual: VehicleVisual = car.character_visual
	check(visual._wheels.size() == 4, "imported car has four independently driven small wheels")
	check(visual.wheel_radius < 0.25, "wheel size preserves small-wheel design")
	check(visual.jaw != null, "imported lower jaw remains an editable separate part")
	var player: AnimationPlayer = visual.animations
	var animation: Animation = player.get_animation("swallow")
	check(animation.length >= 0.75 and animation.length <= 0.85, "full swallow clip has the planned timing")
	var paths_valid: bool = true
	for i: int in range(animation.get_track_count()):
		paths_valid = paths_valid and visual.has_node(animation.track_get_path(i))
	check(paths_valid, "all imported animation tracks resolve in the game wrapper")
	for candy: int in [5, 20, 80, 135]:
		car.set_candy(candy)
		var radius: float = (car.body_shape.shape as CylinderShape3D).radius
		var shape_transform: Transform3D = car.body_shape.transform
		visual.swallow()
		player.seek(0.2, true)
		check(visual.jaw.rotation.x > 0.4, "jaw visibly opens at candy=%d" % candy)
		player.seek(0.57, true)
		check(visual.jaw.rotation.x < -0.5, "jaw visibly closes at candy=%d" % candy)
		check(car.position.y == 0.0 and car.body_shape.transform == shape_transform and is_equal_approx((car.body_shape.shape as CylinderShape3D).radius, radius), "animation leaves physical body untouched at candy=%d" % candy)
		visual.reset_pose()
		check(visual.jaw.rotation.is_zero_approx(), "RESET restores jaw at candy=%d" % candy)
	visual.swallow()
	player.seek(0.57, true)
	visual.swallow()
	check(is_zero_approx(player.current_animation_position) and visual.jaw.rotation.is_zero_approx(), "rapid subsequent swallow restarts the opening phase")
	car.queue_free()
	await frames(2)
	var studio: Node3D = (load("res://scenes/pumpkin_studio.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(studio)
	var pumpkin: CrashCar = studio.get_node("Pumpkin") as CrashCar
	var prey: CrashCar = studio.get_node("Prey") as CrashCar
	await frames(3)
	studio.call("play_swallow")
	await frames(8)
	check(pumpkin.candy == 100 and not prey.alive, "studio uses real swallow with one candy transfer")
	check(prey.collision_layer == 0 and prey.growth_root.visible, "swallowed target is visual only during pull")
	studio.call("reset_preview")
	await frames(70)
	check(prey.alive and prey.growth_root.visible and prey.growth_root.position.is_zero_approx(), "reset during pull cancels pending tween")
	check(pumpkin.candy == 80 and not bool(studio.get("_busy")), "reset cancels pending preview completion")
	studio.call("play_swallow")
	await frames(75)
	check(pumpkin.candy == 100 and not prey.growth_root.visible, "replay completes with target hidden before bite settles")
	check(not bool(studio.get("_busy")), "preview becomes replayable after completion")
	studio.queue_free()
	await frames(2)
	print("PUMPKIN ART TESTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

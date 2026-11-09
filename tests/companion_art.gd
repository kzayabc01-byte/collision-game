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

func _run() -> void:
	var watchdog: Timer = Timer.new()
	watchdog.wait_time = 20.0
	watchdog.one_shot = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func() -> void: quit(2))
	watchdog.start()
	var pony: CrashCar = (load("res://scenes/vehicles/pony_car.tscn") as PackedScene).instantiate() as CrashCar
	var slime: CrashCar = (load("res://scenes/vehicles/slime_car.tscn") as PackedScene).instantiate() as CrashCar
	root.add_child(pony)
	root.add_child(slime)
	pony.set_process(false)
	slime.set_process(false)
	var pv: VehicleVisual = pony.character_visual
	var sv: VehicleVisual = slime.character_visual
	var jelly: MeshInstance3D = sv.get_node("Motion/Model/SlimeArt/RollRoot/JellyBody") as MeshInstance3D
	var hat: Node3D = sv.get_node("Motion/Model/SlimeArt/RollRoot/Hat") as Node3D
	check(pv.has_node("Motion/Model/PonyArt/Coach") and pv._wheels.size() == 4, "pony has imported coach and four independent wheels")
	check(pv.wheel_radius < 0.2, "pony wheels stay small")
	pv.animate(0.1, 3.0, 1.0, false, true)
	check(pv.bonus_marker.visible, "pony double-pickup stars turn on")
	pv.animate(0.1, 3.0, 1.0, false, false)
	check(not pv.bonus_marker.visible, "pony stars turn off at the gameplay threshold")
	pv.pickup()
	pv.animations.seek(0.1, true)
	check(absf((pv.get_node("Motion/Model/PonyArt/Head") as Node3D).rotation.x) > 0.1, "pony pickup animates the actual imported head")
	pv.reset_pose()
	check((pv.get_node("Motion/Model/PonyArt/Head") as Node3D).rotation.is_zero_approx(), "pony pickup resets cleanly")
	check(jelly.get_blend_shape_count() == 1 and sv._wheels.is_empty(), "slime has a round morph and no wheels")
	check(sv._feet.size() == 2 and hat.scale.y > 0.9, "slime starts with feet and unfolded hat")
	for candy: int in [5, 20, 80, 135]:
		slime.set_candy(candy)
		var size_scale: float = CollisionMath.scale_for(candy, slime.tuning)
		var shape: Transform3D = slime.body_shape.transform
		var radius: float = (slime.body_shape.shape as CylinderShape3D).radius
		for frame: int in range(90):
			sv.animate(1.0 / 60.0, 6.0, size_scale, true, false)
		check(jelly.get_blend_shape_value(0) > 0.99, "body becomes a round rolling form at candy=%d" % candy)
		check(hat.scale.y < 0.12 and not sv._feet[0].visible, "hat and feet retract at candy=%d" % candy)
		var before: float = sv.roll_root.rotation.x
		sv.animate(1.0 / 60.0, 6.0, size_scale, true, false)
		var increment: float = angle_difference(before, sv.roll_root.rotation.x)
		check(is_equal_approx(increment, 6.0 / (60.0 * sv.roll_radius * size_scale)), "rolling angular speed follows radius and speed at candy=%d" % candy)
		sv.pickup()
		sv.animations.seek(0.1, true)
		check(hat.scale.y < 0.12 and jelly.get_blend_shape_value(0) > 0.99, "pickup does not overwrite rolling pose at candy=%d" % candy)
		check(slime.position.y == 0.0 and slime.body_shape.transform == shape and is_equal_approx((slime.body_shape.shape as CylinderShape3D).radius, radius), "visual rolling does not affect physics at candy=%d" % candy)
		for frame: int in range(120):
			sv.animate(1.0 / 60.0, 0.0, size_scale, false, false)
		check(absf(sv.roll_root.rotation.x) < 0.01 and jelly.get_blend_shape_value(0) < 0.01 and hat.scale.y > 0.99 and sv._feet[0].visible, "stop returns upright then unfolds at candy=%d" % candy)
		sv.reset_pose()
	check(jelly.get_blend_shape_value(0) < 0.001 and sv._feet[0].scale.y < 0.3, "reset preserves foot proportions and walking morph")
	for role_name: String in ["pony", "pumpkin", "slime"]:
		var entry: VehicleSelectionEntry = load("res://config/selection/%s.tres" % role_name) as VehicleSelectionEntry
		check(entry.preview_scene != null, "%s has a real selection model" % role_name)
	pony.queue_free()
	slime.queue_free()
	await process_frame
	print("COMPANION ART: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

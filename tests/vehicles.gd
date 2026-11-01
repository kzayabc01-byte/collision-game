extends SceneTree

const Pony: PackedScene = preload("res://scenes/vehicles/pony_car.tscn")
const Pumpkin: PackedScene = preload("res://scenes/vehicles/pumpkin_car.tscn")
const Slime: PackedScene = preload("res://scenes/vehicles/slime_car.tscn")
const BaseCar: PackedScene = preload("res://scenes/car.tscn")
const MatchScene: PackedScene = preload("res://scenes/match.tscn")

var passed: int = 0
var failed: int = 0
var tuning: GameTuning = preload("res://config/prototype.tres")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var watchdog: Timer = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 30.0
	root.add_child(watchdog)
	watchdog.timeout.connect(func() -> void: quit(2))
	watchdog.start()
	check(await _pickups(), "pickup suite finished")
	check(await _collisions(), "collision suite finished")
	check(await _slime_driving(), "slime driving suite finished")
	check(await _selection(), "selection suite finished")
	print("VEHICLE TESTS: %d passed, %d failed" % [passed, failed])
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

func _pickups() -> bool:
	var pony: CrashCar = Pony.instantiate() as CrashCar
	root.add_child(pony)
	check(pony.character_visual != null and pony.character_visual._wheels.size() == 4, "pony has four editable small wheels")
	pony.set_candy(38)
	check(pony.collect(1) == 2 and pony.candy == 40, "38 plus one candy becomes 40")
	pony.set_candy(39)
	check(pony.collect(3) == 4 and pony.candy == 43, "merged pickup crosses threshold per candy")
	pony.set_candy(20)
	check(pony.collect(12) == 22 and pony.candy == 42, "20 plus twelve pickups becomes 42")
	pony.set_candy(39)
	check(pony.collect(1, pony.get_instance_id()) == 1 and pony.candy == 40, "own drop never doubles")
	pony.set_candy(38)
	var mixed: Array[Dictionary] = [{"value": 1, "owner": pony.get_instance_id()}, {"value": 2, "owner": 0}]
	check(pony.collect_batches(mixed) == 4 and pony.candy == 42, "mixed origin lots preserve order and eligibility")
	var pickup: CandyPickup = CandySystem.CandyScene.instantiate() as CandyPickup
	root.add_child(pickup)
	pickup.add_lot(1, pony.get_instance_id(), 0.0, 0.5, 8.0)
	pickup.add_lot(2, 0, 0.0, 0.5, 8.0)
	pony.set_candy(20)
	check(pony.collect_batches(pickup.claim_lots(pony.get_instance_id(), 0.2)) == 4, "protected own lot stays while neutral lot doubles")
	check(pickup.total_value() == 1, "protected batch remains collectible")
	check(pony.collect_batches(pickup.claim_lots(pony.get_instance_id(), 0.5)) == 1, "own batch keeps provenance after protection expires")
	check(pickup.claim_lots(pony.get_instance_id(), 0.6).is_empty(), "merged node cannot pay twice")
	pickup.queue_free()
	# Exercise the actual Area3D pickup path, not just the formula.
	pony.global_position = Vector3(8, 0, 8)
	pony.set_candy(38)
	var drops: CandySystem = CandySystem.new()
	drops.tuning = tuning
	root.add_child(drops)
	drops.spawn_drop(pony.global_position, Vector3.ZERO, 1, 0, 0)
	var candy: CandyPickup = drops.get_child(0) as CandyPickup
	candy.launch_velocity = Vector3.ZERO
	await frames()
	drops.tick(0.2)
	check(pony.candy == 40 and candy.collected, "area pickup invokes pony bonus exactly once")
	drops.queue_free()
	pony.queue_free()
	await frames()
	return true

func _collisions() -> bool:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var drops: CandySystem = CandySystem.new()
	drops.tuning = tuning
	world.add_child(drops)
	var resolver: CollisionResolver = CollisionResolver.new()
	resolver.tuning = tuning
	resolver.candy_system = drops
	world.add_child(resolver)
	var pumpkin: CrashCar = Pumpkin.instantiate() as CrashCar
	var prey: CrashCar = Slime.instantiate() as CrashCar
	world.add_child(pumpkin)
	world.add_child(prey)
	pumpkin.reset_at(Vector3(-3, 0, 0))
	pumpkin.set_candy(80)
	prey.reset_at(Vector3.ZERO)
	await frames()
	pumpkin.velocity = Vector3.RIGHT * 9.0
	prey.velocity = Vector3.RIGHT * 5.0
	pumpkin.snapshot()
	prey.snapshot()
	check(prey.pre_rolling, "prey rolling before swallowing")
	check(pumpkin.can_swallow(prey, Vector3.RIGHT), "exact half-size target qualifies")
	check(not pumpkin.can_swallow(prey, Vector3.LEFT), "rear contact cannot swallow")
	check(not pumpkin.can_swallow(prey, Vector3.FORWARD), "side contact cannot swallow")
	resolver.begin_tick(0.1)
	var contact: KinematicCollision3D = pumpkin.move_vehicle(0.1)
	check(contact != null, "actual pumpkin contact swept")
	resolver.record(pumpkin, contact)
	resolver.record(pumpkin, contact)
	resolver.resolve_events()
	check(pumpkin.candy == 100 and not prey.alive, "swallow transfers all candy once, including rolling prey")
	check(drops.total_value() == 0, "swallow produces no duplicate physical candy")
	check(is_equal_approx(pumpkin.velocity.length(), 9.0), "successful swallow avoids normal collision impulse")
	check(prey.growth_root.visible, "dead prey remains visual only during swallow")
	await frames(30)
	check(not prey.growth_root.visible, "swallow visual finishes")
	prey.reset_at(Vector3.ZERO)
	check(prey.growth_root.position.is_zero_approx() and prey.alive, "respawn restores visual transform and collisions")
	prey.set_candy(25)
	pumpkin.snapshot()
	prey.snapshot()
	check(not pumpkin.can_swallow(prey, Vector3.RIGHT), "size cap prevents swallowing 25-candy target")
	prey.set_candy(24)
	prey.snapshot()
	check(pumpkin.can_swallow(prey, Vector3.RIGHT), "size cap still allows 24-candy target")
	# Side impact: stationary pumpkin faces north, attacker comes from the east.
	resolver.clear_for(pumpkin)
	pumpkin.reset_at(Vector3.ZERO)
	pumpkin.set_candy(80)
	prey.reset_at(Vector3(3, 0, 0))
	prey.velocity = Vector3.LEFT * 6.0
	pumpkin.snapshot()
	prey.snapshot()
	await frames()
	resolver.begin_tick(0.2)
	resolver.record(prey, prey.move_vehicle(0.2))
	resolver.resolve_events()
	check(pumpkin.candy < 80 and prey.alive, "side collision uses ordinary damage instead of eating")
	# Rolling defense uses the pre-impact state and unrounded incoming damage.
	pumpkin.global_position = Vector3(30, 0, 30)
	prey.reset_at(Vector3.ZERO)
	var attacker: CrashCar = BaseCar.instantiate() as CrashCar
	world.add_child(attacker)
	attacker.global_position = Vector3(-2, 0, 0)
	attacker.velocity = Vector3.RIGHT * 9.0
	prey.velocity = Vector3.FORWARD * 5.0
	attacker.snapshot()
	prey.snapshot()
	await frames()
	resolver.begin_tick(0.1)
	resolver.record(attacker, attacker.move_vehicle(0.1))
	resolver.resolve_events()
	check(prey.candy == 6 and attacker.candy == 16, "rolling defender takes 14 rather than 20 damage")
	check(prey.received_damage(1.6) == 1, "defense applies before integer rounding")
	attacker.global_position = Vector3(40, 0, 40)
	var wall: CrashObstacle = (load("res://scenes/solid_wall.tscn") as PackedScene).instantiate() as CrashObstacle
	world.add_child(wall)
	prey.reset_at(Vector3(-2, 0, 0))
	prey.set_candy(40)
	prey.velocity = Vector3.RIGHT * 6.0
	prey.snapshot()
	await frames()
	resolver.begin_tick(0.1)
	resolver.record(prey, prey.move_vehicle(0.1))
	resolver.resolve_events()
	check(prey.candy == 38 and is_equal_approx(prey.velocity.length(), 5.7), "rolling does not reduce wall penalty")
	world.queue_free()
	await frames()
	return true

func _slime_driving() -> bool:
	var slime: CrashCar = Slime.instantiate() as CrashCar
	var standard: CrashCar = BaseCar.instantiate() as CrashCar
	slime.is_player = true
	standard.is_player = true
	root.add_child(slime)
	root.add_child(standard)
	standard.position.z = 20.0
	check(slime.character_visual._wheels.is_empty() and slime.character_visual._feet.size() == 2, "slime has two feet and no wheels")
	slime.character_visual.animate(0.1, 3.0, 1.0, false, false)
	check(slime.character_visual._feet[0].scale.y < 0.3, "walking preserves authored small foot scale")
	slime.velocity = Vector3.RIGHT * 3.99
	slime.update_roll_state()
	check(not slime.rolling, "below four walks")
	slime.velocity = Vector3.RIGHT * 4.01
	slime.update_roll_state()
	check(slime.rolling, "above four rolls")
	slime.velocity = Vector3.RIGHT * 4.0
	slime.update_roll_state()
	check(slime.rolling, "exactly four retains rolling")
	slime.velocity = Vector3.RIGHT * 3.0
	slime.update_roll_state()
	slime.velocity = Vector3.RIGHT * 4.0
	slime.update_roll_state()
	check(not slime.rolling, "exactly four retains walking")
	slime.velocity = Vector3.RIGHT * 6.0
	slime.update_roll_state()
	check(is_equal_approx(slime.turn_retention(PI / 2.0), 0.925), "rolling ninety degree turn retains 92.5 percent")
	check(is_equal_approx(pow(slime.turn_retention(PI / 120.0), 60), 0.925), "rolling turn is frame-rate independent")
	slime.respond(Vector3.RIGHT * 6.0)
	standard.respond(Vector3.RIGHT * 6.0)
	slime.control_lock = 0.0
	standard.control_lock = 0.0
	Input.action_press("move_right")
	var before: float = slime.driven_distance
	slime.prepare_drive(1.0 / 60.0, {})
	slime.move_vehicle(1.0 / 60.0)
	check(is_equal_approx(slime.driven_distance - before, slime.global_position.x * 1.5), "actual driven distance contributes 150 percent while rolling")
	for index: int in range(240):
		slime.prepare_drive(1.0 / 60.0, {})
		standard.prepare_drive(1.0 / 60.0, {})
		slime.move_vehicle(1.0 / 60.0)
		standard.move_vehicle(1.0 / 60.0)
		await physics_frame
	Input.action_release("move_right")
	check(slime.velocity.length() > standard.velocity.length() + 0.2, "slime reaches high speed faster")
	check(slime.velocity.length() <= tuning.top_speed, "rolling keeps speed cap")
	var speed_before: float = slime.velocity.length()
	Input.action_press("move_up")
	for index: int in range(120):
		slime.prepare_drive(1.0 / 60.0, {})
		slime.move_vehicle(1.0 / 60.0)
		await physics_frame
		if slime.velocity.normalized().dot(Vector3.FORWARD) > 0.999:
			break
	Input.action_release("move_up")
	var retention: float = slime.velocity.length() / speed_before
	check(retention > 0.92 and retention < 0.94, "actual rolling turn loses about 7.5 percent")
	slime.character_visual.animate(1.0, 6.0, 1.0, true, false)
	check(not slime.character_visual._feet[0].visible, "feet disappear during roll")
	slime.reset_at(Vector3.ZERO)
	check(not slime.rolling and slime.character_visual._feet[0].visible, "respawn resets walking pose")
	check(slime.character_visual._feet[0].scale.y < 0.3, "respawn preserves authored foot proportions")
	slime.queue_free()
	standard.queue_free()
	await frames()
	return true

func _selection() -> bool:
	CrashMatch.selected_vehicle = 0
	CrashMatch.ability_lab = false
	var game: CrashMatch = MatchScene.instantiate() as CrashMatch
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	check(game.player.profile.kind == VehicleProfile.Kind.PONY, "default player is pony")
	check(game.cars[1].profile.kind == VehicleProfile.Kind.PUMPKIN and game.cars[2].profile.kind == VehicleProfile.Kind.SLIME, "match contains all three characters")
	check(game.cars[1].driver.get_script().resource_path.ends_with("ai_driver.gd"), "variant enemy uses AI driver")
	game.select_vehicle(1)
	await frames(5)
	game = current_scene as CrashMatch
	game.set_physics_process(false)
	check(game.player.profile.kind == VehicleProfile.Kind.PUMPKIN and game.cars.size() == 4, "selection reloads exactly one player")
	game.toggle_lab()
	await frames(5)
	game = current_scene as CrashMatch
	game.set_physics_process(false)
	check(game.player.candy == 80 and game.cars[1].candy == 20, "pumpkin lab sets half-size target")
	var time_before: float = game.remaining_seconds
	game._physics_process(0.1)
	check(game.remaining_seconds == time_before and game.cars[1].velocity.is_zero_approx(), "lab freezes timer and AI")
	game.select_vehicle(2)
	await frames(5)
	game = current_scene as CrashMatch
	game.set_physics_process(false)
	check(game.player.profile.kind == VehicleProfile.Kind.SLIME and CrashMatch.ability_lab, "switching vehicle preserves lab")
	game.restart()
	await frames(5)
	game = current_scene as CrashMatch
	game.set_physics_process(false)
	check(game.player.profile.kind == VehicleProfile.Kind.SLIME, "restart preserves chosen character")
	game.toggle_pause()
	var old_position: Vector3 = game.player.position
	game._physics_process(1.0)
	check(game.player.position == old_position, "pause blocks movement in lab")
	game.queue_free()
	await frames()
	CrashMatch.selected_vehicle = 0
	CrashMatch.ability_lab = false
	return true

extends SceneTree

const CarScene: PackedScene = preload("res://scenes/car.tscn")
const WallScene: PackedScene = preload("res://scenes/maps/arena/props/solid_wall.tscn")
const ObstacleScene: PackedScene = preload("res://scenes/maps/arena/props/candy_obstacle.tscn")
const MatchScene: PackedScene = preload("res://scenes/match.tscn")

var _passed: int = 0
var _failed: int = 0
var _tuning: GameTuning = preload("res://config/prototype.tres")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var watchdog: Timer = Timer.new()
	watchdog.wait_time = 30.0
	watchdog.one_shot = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func() -> void: push_error("TEST TIMEOUT"); quit(2))
	watchdog.start()
	_check(_test_rules(), "rule tests completed")
	_check(_test_lots(), "batch accounting tests completed")
	_check(await _test_physics(), "physics tests completed")
	_check(await _test_match(), "match tests completed")
	print("TEST RESULTS: %d passed, %d failed" % [_passed, _failed])
	root.get_node("Music").set_context("intro")
	await create_timer(0.3).timeout
	quit(1 if _failed > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS ", label)
	else:
		_failed += 1
		push_error("FAIL " + label)

func _test_rules() -> bool:
	var left_bound: bool = false
	var right_bound: bool = false
	for event: InputEvent in InputMap.action_get_events("move_left"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_LEFT:
			left_bound = true
	for event: InputEvent in InputMap.action_get_events("move_right"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_RIGHT:
			right_bound = true
	_check(left_bound and right_bound, "left/right arrow keys bound correctly")
	_check(CollisionMath.wall_loss(19, _tuning) == 0, "19 candy wall drop is zero")
	_check(CollisionMath.wall_loss(39, _tuning) == 1, "39 candy rounds down")
	_check(CollisionMath.wall_loss(100, _tuning) == 5, "wall drops five percent")
	_check(is_equal_approx(CollisionMath.scale_for(5, _tuning), 0.5), "five candy half size")
	_check(is_equal_approx(CollisionMath.scale_for(80, _tuning), 2.0), "80 candy double size")
	_check(is_equal_approx(CollisionMath.scale_for(999, _tuning), 2.2), "size cap")
	_check(is_equal_approx(CollisionMath.mass_for(30, _tuning), 1.25), "30 candy mass")
	_check(is_equal_approx(CollisionMath.turn_retention(PI / 2.0, _tuning), 0.85), "90 degree turn retains 85 percent")
	var divided: float = pow(CollisionMath.turn_retention(PI / 120.0, _tuning), 60)
	_check(is_equal_approx(divided, 0.85), "turn loss independent of frame subdivision")
	var result: Dictionary = CollisionMath.pair_result(1.0, 1.0, Vector3.RIGHT * 9.0, Vector3.ZERO, Vector3.RIGHT, _tuning)
	_check(result["loss_a"] == 4 and result["loss_b"] == 20, "full speed kills stationary initial car")
	var swapped: Dictionary = CollisionMath.pair_result(1.0, 1.0, Vector3.ZERO, Vector3.RIGHT * 9.0, Vector3.LEFT, _tuning)
	_check(swapped["loss_a"] == result["loss_b"] and swapped["loss_b"] == result["loss_a"], "A/B swap symmetry")
	var glancing: Dictionary = CollisionMath.pair_result(1.0, 1.0, Vector3.FORWARD * 9.0, Vector3.ZERO, Vector3.RIGHT, _tuning)
	_check(glancing["loss_a"] == 0 and glancing["loss_b"] == 0, "tangential motion does not cause damage")
	var energy: float = CollisionMath.obstacle_energy(1.25, Vector3.RIGHT * 6.0, Vector3.LEFT)
	_check(is_equal_approx(energy, 22.5), "30 candy speed 6 reaches break threshold")
	var candy: int = 30
	var speed: float = 6.0
	for expected: int in [41, 51, 61]:
		energy = CollisionMath.obstacle_energy(CollisionMath.mass_for(candy, _tuning), Vector3.RIGHT * speed, Vector3.LEFT)
		_check(energy >= _tuning.obstacle_break_energy - 0.00001, "snowball impact remains strong")
		candy = candy - CollisionMath.wall_loss(candy, _tuning) + 12
		_check(candy == expected, "snowball accounting %d" % expected)
		speed *= 0.95
	return true

func _test_lots() -> bool:
	var pickup: CandyPickup = CandyPickup.new()
	pickup.add_lot(3, 42, 0.0, 0.5, 8.0)
	_check(pickup.claim_for(42, 0.49) == 0, "original owner protected for half second")
	_check(pickup.claim_for(42, 0.5) == 3, "original owner eligible after protection")
	_check(pickup.claim_for(7, 0.5) == 0, "one drop cannot be claimed twice")
	pickup.add_lot(5, 42, 0.0, 0.5, 8.0)
	_check(pickup.claim_for(7, 0.1) == 5, "other car can steal during owner protection")
	pickup.add_lot(2, 42, 0.0, 0.5, 8.0)
	pickup.add_lot(7, 42, 7.9, 0.5, 8.0)
	_check(pickup.claim_for(42, 8.1) == 0, "merged batches preserve separate expiry and protection")
	_check(pickup.claim_for(42, 8.5) == 7, "new batch survives old batch expiry")
	pickup.free()
	return true

func _test_physics() -> bool:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var drops: CandySystem = CandySystem.new()
	drops.tuning = _tuning.duplicate() as GameTuning
	world.add_child(drops)
	var resolver: CollisionResolver = CollisionResolver.new()
	resolver.tuning = _tuning
	resolver.candy_system = drops
	world.add_child(resolver)
	var a: CrashCar = CarScene.instantiate() as CrashCar
	var b: CrashCar = CarScene.instantiate() as CrashCar
	world.add_child(a)
	world.add_child(b)
	a.global_position = Vector3(-2, 0, 0)
	b.global_position = Vector3.ZERO
	await _frames(3)
	a.velocity = Vector3.RIGHT * 9.0
	a.snapshot()
	b.snapshot()
	resolver.begin_tick(0.1)
	var collision: KinematicCollision3D = a.move_vehicle(0.1)
	_check(collision != null, "actual swept car contact detected")
	resolver.record(a, collision)
	resolver.record(a, collision)
	resolver.resolve_events()
	_check(a.candy == 16 and b.candy == 0 and not b.alive, "physical hit applies one-shot kill exactly once")
	_check(drops.total_value() == 24, "all lost candy becomes collectible value")
	a.reset_at(Vector3(-2, 0, 0))
	b.reset_at(Vector3.ZERO)
	resolver.clear_for(a)
	await _frames(3)
	a.velocity = Vector3.RIGHT * 9.0
	b.velocity = Vector3.LEFT * 9.0
	a.snapshot()
	b.snapshot()
	resolver.begin_tick(0.1)
	resolver.record(a, a.move_vehicle(0.1))
	resolver.record(b, b.move_vehicle(0.1))
	resolver.resolve_events()
	_check(not a.alive and not b.alive, "symmetric full speed impact defeats both")
	_check(drops.total_value() == 64, "simultaneous death does not duplicate candy")
	a.reset_at(Vector3.ZERO)
	b.reset_at(Vector3(1.52, 0, 0))
	resolver.clear_for(a)
	var key: String = resolver.pair_key(a, b)
	_check(resolver._consume_contact(a, b, key), "fresh contact armed")
	resolver.begin_tick(0.6)
	_check(not resolver._consume_contact(a, b, key), "persistent contact does not repeat after cooldown")
	b.global_position = Vector3(5, 0, 0)
	resolver.begin_tick(0.6)
	_check(resolver._consume_contact(a, b, key), "separation rearms contact")
	b.global_position = Vector3(50, 0, 50)
	var wall: CrashObstacle = WallScene.instantiate() as CrashObstacle
	world.add_child(wall)
	a.reset_at(Vector3(-2, 0, 0))
	a.set_candy(40)
	await _frames(3)
	a.velocity = Vector3.RIGHT * 9.0
	a.snapshot()
	resolver.begin_tick(0.1)
	resolver.record(a, a.move_vehicle(0.1))
	resolver.resolve_events()
	_check(a.candy == 38, "wall drops floor five percent")
	_check(is_equal_approx(a.velocity.length(), 8.55) and a.velocity.x < 0.0, "wall rebounds with exactly 95 percent speed")
	wall.queue_free()
	await _frames(3)
	var obstacle: CrashObstacle = ObstacleScene.instantiate() as CrashObstacle
	world.add_child(obstacle)
	a.reset_at(Vector3(-2, 0, 0))
	a.set_candy(30)
	await _frames(3)
	var before: int = drops.total_value()
	a.velocity = Vector3.RIGHT * 6.0
	a.snapshot()
	resolver.begin_tick(0.1)
	resolver.record(a, a.move_vehicle(0.1))
	resolver.resolve_events()
	_check(obstacle.is_broken and a.candy == 29, "30 candy breaks obstacle at speed six")
	_check(a.velocity.x > 0.0 and is_equal_approx(a.velocity.length(), 5.7), "broken obstacle allows forward travel")
	_check(drops.total_value() - before == 13, "obstacle twelve plus own one candy")
	_check(obstacle.break_once() == 0, "broken obstacle cannot pay out again")
	_check(not is_equal_approx((a.body_shape.shape as CylinderShape3D).radius, (b.body_shape.shape as CylinderShape3D).radius), "growth collision resources are independent")
	for child: Node in drops.get_children():
		drops.remove_child(child)
		child.queue_free()
	drops.tuning.maximum_candy_nodes = 2
	drops.spawn_drop(Vector3(10, 0, 10), Vector3.RIGHT, 10, 1, 2)
	drops.spawn_drop(Vector3(10, 0, 10), Vector3.RIGHT, 17, 2, 2)
	_check(drops.get_child_count() == 2 and drops.total_value() == 27, "node limit preserves candy and lot metadata")
	for child: Node in drops.get_children():
		drops.remove_child(child)
		child.queue_free()
	a.reset_at(Vector3(8, 0, 8))
	drops.clock_seconds = 0.0
	drops.spawn_drop(a.global_position, Vector3.ZERO, 1, a.get_instance_id(), 0)
	var protected_candy: CandyPickup = drops.get_child(0) as CandyPickup
	protected_candy.launch_velocity = Vector3.ZERO
	await _frames(3)
	drops.tick(0.2)
	_check(a.candy == 20, "overlapping owner cannot collect before protection ends")
	drops.tick(0.31)
	_check(a.candy == 21, "standing owner collects when protection expires without re-entering")
	world.queue_free()
	await _frames(3)
	return true

func _test_match() -> bool:
	var match_scene: CrashMatch = MatchScene.instantiate() as CrashMatch
	root.add_child(match_scene)
	current_scene = match_scene
	match_scene.set_physics_process(false)
	await _frames(3)
	_check(match_scene.cars.size() == 4 and match_scene.player.is_player, "editable scene contains player and three AI")
	match_scene.player.set_candy(80)
	var minimum_wall_x: float = match_scene._get_play_bounds().position.x + match_scene.player.radius
	match_scene.player.global_position = Vector3(minimum_wall_x, 0, 5)
	match_scene.player.set_candy(100)
	await _frames(3)
	match_scene.player.velocity = Vector3.RIGHT * 2.0
	match_scene.player.move_vehicle(0.1)
	_check(match_scene.player.global_position.x > minimum_wall_x, "grown vehicle can move away from adjacent wall")
	match_scene.player.reset_at(match_scene.spawn_points.get_node("PlayerSpawn").global_position)
	var before: float = match_scene.remaining_seconds
	match_scene.toggle_pause()
	match_scene._physics_process(1.0)
	_check(is_equal_approx(match_scene.remaining_seconds, before), "pause freezes round time")
	match_scene.toggle_pause()
	match_scene.player.apply_loss(20)
	match_scene.player.respawn_remaining = 0.0
	match_scene._physics_process(0.016)
	_check(match_scene.player.alive and match_scene.player.candy == 20, "safe respawn restores initial state")
	match_scene.remaining_seconds = 0.001
	match_scene._physics_process(0.016)
	_check(match_scene.phase == CrashMatch.Phase.FINISHED, "round ends at zero")
	var final_candy: int = match_scene.player.candy
	match_scene._physics_process(1.0)
	_check(match_scene.player.candy == final_candy, "finished score frozen")
	match_scene.restart()
	await _frames(5)
	var fresh: CrashMatch = current_scene as CrashMatch
	_check(fresh != null and fresh.phase == CrashMatch.Phase.PLAYING and fresh.player.candy == 20, "restart reloads a playable round")
	fresh.set_physics_process(false)
	fresh.queue_free()
	await _frames(3)
	return true

func _frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame

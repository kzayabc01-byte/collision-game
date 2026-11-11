extends SceneTree

const PROPS: String = "res://scenes/maps/arena/props/reference/"
var checks: int = 0
var failures: int = 0
var tuning: GameTuning = load("res://config/prototype.tres")

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func frames() -> void:
	for i: int in range(3):
		await physics_frame

func run() -> void:
	var arena: Node3D = load("res://scenes/maps/arena/arena.tscn").instantiate()
	root.add_child(arena)
	await frames()
	check(arena.get_node("CandyObstacles").get_child_count() == 23, "Reference has 14 gifts, 5 crates, 3 barrels and one pumpkin")
	check(arena.get_node("SolidWalls/OuterCurves").get_child_count() == 4, "Four editable outer curves")
	check(arena.get_node("SolidWalls/InnerDiagonals").get_child_count() == 4, "Four editable inner diagonals")
	check(arena.get_node("CenterPlaza").get_child_count() == 3, "Three editable paving rings")
	check((arena.get_node("Ground/CollisionShape3D").shape as BoxShape3D).size == Vector3(82,0.4,58), "Ground collision dimensions retained")
	for item: Node in get_nodes_in_group("solid_walls") + get_nodes_in_group("candy_obstacles"):
		var obstacle: CrashObstacle = item as CrashObstacle
		check(obstacle != null and obstacle.get_node("BodyCollision").shape is BoxShape3D, "Obstacle supports collision resolver: " + str(item.name))
		check(obstacle.scale.is_equal_approx(Vector3.ONE) or item.get_parent().name == "SolidWalls", "New obstacle physics has unit scale: " + str(item.name))
	var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var vehicle_shape: CylinderShape3D = CylinderShape3D.new()
	vehicle_shape.radius = tuning.base_collision_radius * tuning.maximum_scale
	vehicle_shape.height = 1.2
	query.shape = vehicle_shape
	query.collision_mask = 1
	for marker: Node3D in arena.get_node("VehicleSpawnPoints").get_children():
		query.transform.origin = marker.global_position + Vector3.UP * 0.6
		check(space.intersect_shape(query).is_empty(), "Maximum-size spawn is clear: " + str(marker.name))
		var route: PackedVector3Array = ArenaRoute.path(self, Rect2(-40,-28,80,56), marker.global_position, Vector3(0,0,12), vehicle_shape.radius, false)
		check(route.size() >= 2 and route[-1].distance_to(Vector3(0,0,12)) < 3.0, "AI can route around walls from " + str(marker.name))
	var candy_shape: SphereShape3D = SphereShape3D.new()
	candy_shape.radius = 0.35
	query.shape = candy_shape
	for marker: Node3D in arena.get_node("CandySpawnPoints").get_children():
		query.transform.origin = marker.global_position + Vector3.UP*0.4
		check(space.intersect_shape(query).is_empty(), "Neutral candy cannot spawn inside obstacles: " + str(marker.name))
	query.transform.origin = Vector3(5,0.4,0)
	check(space.intersect_shape(query).is_empty(), "Paving is traversable")
	var car: CrashCar = load("res://scenes/vehicles/pony_car.tscn").instantiate()
	arena.add_child(car)
	car.position = Vector3(0,0,21)
	await frames()
	car.velocity = Vector3.BACK*6
	var collision: KinematicCollision3D = car.move_vehicle(0.8)
	check(collision == null and car.position.z > 25.0, "Actual car passes through arch opening")
	arena.free()
	await frames()
	for filename: String in ["candy_crate", "candy_barrel", "pumpkin_bucket"]:
		await break_test(filename)
	print("REFERENCE ARENA: ", checks, " checks, ", failures, " failures")
	await create_timer(0.25).timeout
	quit(1 if failures else 0)

func break_test(filename: String) -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var obstacle: CrashObstacle
	if filename == "pumpkin_bucket":
		# Use the actual map instance so its individual reward override is exercised.
		var arena: Node3D = load("res://scenes/maps/arena/arena.tscn").instantiate()
		obstacle = arena.get_node("CandyObstacles/CenterPumpkin")
		obstacle.get_parent().remove_child(obstacle)
		arena.free()
	else:
		obstacle = load(PROPS+filename+".tscn").instantiate()
	world.add_child(obstacle)
	check(not obstacle.can_break(22.49) and obstacle.can_break(22.5), filename + " shares gift break threshold")
	var drops: CandySystem = CandySystem.new()
	drops.tuning = tuning
	world.add_child(drops)
	var resolver: CollisionResolver = CollisionResolver.new()
	resolver.tuning = tuning
	resolver.candy_system = drops
	world.add_child(resolver)
	var car: CrashCar = load("res://scenes/vehicles/pony_car.tscn").instantiate()
	world.add_child(car)
	car.set_candy(30)
	var box: BoxShape3D = obstacle.get_node("BodyCollision").shape
	car.position = Vector3(-box.size.x*0.5-car.radius-0.3,0,0)
	await frames()
	car.velocity = Vector3.RIGHT*6
	car.snapshot()
	resolver.begin_tick(0.1)
	var collision: KinematicCollision3D = car.move_vehicle(0.1)
	check(collision != null and collision.get_collider() == obstacle, filename + " has actual swept collision")
	resolver.record(car, collision)
	resolver.record(car, collision)
	resolver.resolve_events()
	check(obstacle.is_broken and not obstacle.get_node("VisualRoot").visible, filename + " breaks and hides")
	check(car.candy == 29 and is_equal_approx(car.velocity.x,5.7), filename + " retains wall 5 percent penalty")
	var reward: int = 100 if filename == "pumpkin_bucket" else 12
	check(drops.total_value() == reward + 1, filename + " drops %d reward plus one from car, once" % reward)
	check(obstacle.break_once() == 0, filename + " cannot pay reward twice")
	await frames()
	check(obstacle.collision_layer == 0 and obstacle.get_node("BodyCollision").disabled, filename + " no collision after destruction")
	world.free()
	await frames()

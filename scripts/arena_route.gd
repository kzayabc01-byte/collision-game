class_name ArenaRoute
extends RefCounted

static func path(tree: SceneTree, bounds: Rect2, start: Vector3, goal: Vector3, radius: float, break_target: bool) -> PackedVector3Array:
	if not bounds.has_area():
		return PackedVector3Array([goal])
	var grid: AStarGrid2D = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, int(ceil(bounds.size.x / 2.0)), int(ceil(bounds.size.y / 2.0)))
	grid.cell_size = Vector2.ONE * 2.0
	grid.offset = bounds.position + Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var boxes: Array[Rect2] = []
	for group: String in ["solid_walls", "candy_obstacles"]:
		for node: Node in tree.get_nodes_in_group(group):
			var obstacle: CrashObstacle = node as CrashObstacle
			if obstacle == null or obstacle.is_broken:
				continue
			if break_target and obstacle.destructible and obstacle.global_position.distance_to(goal) < 0.5:
				continue
			var shape: CollisionShape3D = obstacle.get_node("BodyCollision") as CollisionShape3D
			var box: BoxShape3D = shape.shape as BoxShape3D
			var world: AABB = shape.global_transform * AABB(-box.size * 0.5, box.size)
			boxes.append(Rect2(Vector2(world.position.x, world.position.z), Vector2(world.size.x, world.size.z)).grow(radius + 0.25))
	var inside: Rect2 = bounds.grow(-radius - 0.3)
	for y: int in range(grid.region.size.y):
		for x: int in range(grid.region.size.x):
			var id: Vector2i = Vector2i(x, y)
			var point: Vector2 = grid.get_point_position(id)
			var solid: bool = not inside.has_point(point)
			for box: Rect2 in boxes:
				if box.has_point(point):
					solid = true
					break
			grid.set_point_solid(id, solid)
	var from_id: Vector2i = _nearest_free(grid, Vector2(start.x, start.z))
	var to_id: Vector2i = _nearest_free(grid, Vector2(goal.x, goal.z))
	if from_id.x < 0 or to_id.x < 0:
		return PackedVector3Array()
	var result: PackedVector3Array = PackedVector3Array()
	for point: Vector2 in grid.get_point_path(from_id, to_id):
		result.append(Vector3(point.x, 0, point.y))
	var goal_point: Vector2 = Vector2(goal.x, goal.z)
	var goal_clear: bool = inside.has_point(goal_point)
	for box: Rect2 in boxes:
		goal_clear = goal_clear and not box.has_point(goal_point)
	if goal_clear and not result.is_empty() and result[result.size() - 1].distance_to(goal) < 3.0:
		result.append(goal)
	return result

static func _nearest_free(grid: AStarGrid2D, point: Vector2) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var distance: float = INF
	for y: int in range(grid.region.size.y):
		for x: int in range(grid.region.size.x):
			var id: Vector2i = Vector2i(x, y)
			if not grid.is_point_solid(id):
				var d: float = point.distance_squared_to(grid.get_point_position(id))
				if d < distance:
					distance = d
					best = id
	return best

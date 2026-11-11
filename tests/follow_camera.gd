extends SceneTree

var failures: int = 0
var checks: int = 0
var game: CrashMatch
var rig: Node3D
var camera: Camera3D

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func settle() -> void:
	for i: int in range(4):
		await process_frame

func focus_error() -> float:
	var p: Vector2 = camera.unproject_position(game.player.global_position + Vector3.UP * rig.focus_height)
	return p.distance_to(root.get_visible_rect().size * 0.5)

func view_inside_walls() -> bool:
	return game.player.play_bounds.grow(0.002).encloses(rig._ground_footprint())

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	CrashMatch.selected_vehicle = 0
	CrashMatch.ability_lab = false
	game = load("res://scenes/match.tscn").instantiate() as CrashMatch
	root.add_child(game)
	current_scene = game
	await settle()
	game.set_physics_process(false)
	game.get_node("Vehicles").process_mode = Node.PROCESS_MODE_DISABLED
	game.candy_system.process_mode = Node.PROCESS_MODE_DISABLED
	rig = game.get_node("CameraRig") as Node3D
	camera = rig.get_node("Camera3D") as Camera3D
	rig.set_process(false)
	var authored_basis: Basis = camera.basis
	var authored_size: float = 38.5
	var bounds: Rect2 = game.player.play_bounds
	var ground: MeshInstance3D = game.get_node("Arena/GroundVisual")
	var backdrop: MeshInstance3D = ground.get_node("OuterBackdrop")
	check((ground.mesh as PlaneMesh).size == Vector2(124, 98), "Existing ground dimensions retained")
	check(backdrop.mesh is ArrayMesh, "Outer ground exists")
	check(backdrop.material_override == ground.material_override, "Outer ground shares original paint")
	check(backdrop.find_children("*", "CollisionObject3D").is_empty(), "Backdrop has no gameplay collision")
	check((game.get_node("Arena/Ground/CollisionShape3D").shape as BoxShape3D).size == Vector3(82, 0.4, 58), "Collision bounds unchanged")
	var vertices: PackedVector3Array = backdrop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = backdrop.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	for i: int in range(4):
		check(uv[i].is_equal_approx(Vector2(vertices[i].x / 124 + 0.5, vertices[i].z / 98 + 0.5)), "Outer UVs preserve paint scale")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1024, 768), Vector2i(2560, 1080)]:
		root.size = dimensions
		await settle()
		rig._fit_camera_to_window()
		game.player.global_position = Vector3.ZERO
		rig.recenter()
		check(focus_error() < 0.1, "Centered away from walls in %s" % [dimensions])
		check(camera.basis.is_equal_approx(authored_basis), "Authored camera angle in %s" % [dimensions])
		if dimensions.x == 2560:
			check(camera.size < authored_size and absf(rig._ground_footprint().size.x - bounds.size.x) < 0.002, "Ultrawide fits the wall width")
		else:
			check(is_equal_approx(camera.size, authored_size), "Authored zoom in %s" % [dimensions])
		for point: Vector3 in [Vector3(-38, 0, -26), Vector3(38, 0, -26), Vector3(-38, 0, 26), Vector3(38, 0, 26), Vector3(0, 0, -26), Vector3(-38, 0, 0)]:
			game.player.global_position = point
			rig.recenter()
			var footprint: Rect2 = rig._ground_footprint()
			check(view_inside_walls(), "View inside walls at %s in %s" % [point, dimensions])
			if absf(point.x) > 30.0:
				var gap: float = footprint.position.x - bounds.position.x if point.x < 0.0 else bounds.end.x - footprint.end.x
				check(absf(gap) < 0.002, "View stops at side wall in %s" % [dimensions])
			if absf(point.z) > 20.0:
				var gap: float = footprint.position.y - bounds.position.y if point.z < 0.0 else bounds.end.y - footprint.end.y
				check(absf(gap) < 0.002, "View stops at end wall in %s" % [dimensions])
	root.size = Vector2i(1280, 720)
	await settle()
	rig._fit_camera_to_window()
	check(is_equal_approx(camera.size, authored_size), "Normal zoom returns after resizing from ultrawide")
	game.player.global_position = Vector3(38, 0, 0)
	rig.recenter()
	var at_side_wall: Vector3 = rig.global_position
	game.player.global_position.z += 4.0
	for i: int in range(60):
		rig._process(1.0 / 60.0)
	check(absf(rig.global_position.x - at_side_wall.x) < 0.002 and rig.global_position.z > at_side_wall.z + 3.9, "Follow continues along the wall")
	# Frame-rate independent smoothing and no snap during normal movement.
	var results: Array[Vector3] = []
	for fps: int in [30, 60, 120]:
		game.player.global_position = Vector3.ZERO
		rig.recenter()
		game.player.global_position.x = 4.0
		rig._process(1.0 / fps)
		check(focus_error() > 0.1, "Short movement smooths instead of snapping")
		for i: int in range(fps - 1):
			rig._process(1.0 / fps)
		results.append(rig.global_position)
		check(focus_error() < 0.2, "Camera settles promptly")
	check(results[0].distance_to(results[2]) < 0.001, "Smoothing matches at 30 and 120 FPS")
	game.player.global_position = Vector3(38, 0, 26)
	rig._process(1.0 / 60)
	check(view_inside_walls() and absf(rig._ground_footprint().end.x - bounds.end.x) < 0.002, "Teleport immediately stops at the wall")
	var before: Vector3 = rig.global_position
	rig.shake(2, Vector3.RIGHT)
	for i: int in range(60):
		rig._process(1.0 / 60)
		check(view_inside_walls(), "Impact shake stays inside the walls")
	check(rig.global_position.distance_to(before) < 0.001, "Impact shake never drifts the follow rig")
	game.toggle_pause()
	var paused: Transform3D = camera.global_transform
	game.player.global_position.x -= 2
	rig._process(0.5)
	check(camera.global_transform.is_equal_approx(paused), "Pause freezes camera")
	game.toggle_pause()
	game.player.alive = false
	rig._process(0.1)
	game.player.global_position = Vector3(-38, 0, -26)
	game.player.alive = true
	rig._process(1.0 / 60)
	check(view_inside_walls() and absf(rig._ground_footprint().position.x - bounds.position.x) < 0.002, "Respawn immediately stops at the opposite wall")
	# Actual rendered corner capture, not a concept image.
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 800)
		await settle()
		rig._fit_camera_to_window()
		game.player.global_position = Vector3(38, 0, 26)
		rig.recenter()
		game.hud.refresh(game.player, game.cars, 146)
		game.hud._notice_remaining = 0
		await settle()
		await RenderingServer.frame_post_draw
		var output: String = OS.get_environment("FOLLOW_CAPTURE")
		if not output.is_empty():
			check(root.get_texture().get_image().save_png(output) == OK, "Saved live edge view")
	print("FOLLOW CAMERA: %d checks, %d failures" % [checks, failures])
	root.get_node("Music").set_context("intro")
	game.free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)

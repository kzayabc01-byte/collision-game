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
	var authored_size: float = camera.size
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
		for point: Vector3 in [Vector3(-38, 0, -26), Vector3(38, 0, -26), Vector3(-38, 0, 26), Vector3(38, 0, 26), Vector3(0, 0, -26), Vector3(-38, 0, 0)]:
			game.player.global_position = point
			rig.recenter()
			game.hud._update_marker()
			check(focus_error() < 0.1, "Centered at %s in %s" % [point, dimensions])
			var player_rect: Rect2 = Rect2(camera.unproject_position(point) - Vector2(40, 60), Vector2(80, 90))
			for panel: Control in [game.hud.stats, game.hud.leaderboard, game.hud.timer, game.hud.pause_button, game.hud.help]:
				check(not panel.get_global_rect().intersects(player_rect), "Player clears HUD panel %s" % panel.name)
			check(game.hud.marker.visible, "Player label visible at map boundary")
			var footprint: Rect2 = rig._ground_footprint()
			var world: AABB = backdrop.global_transform * backdrop.get_aabb()
			check(Rect2(Vector2(world.position.x, world.position.z), Vector2(world.size.x, world.size.z)).encloses(footprint), "No empty floor at edge")
			check(camera.basis.is_equal_approx(authored_basis) and is_equal_approx(camera.size, authored_size), "No rotation or automatic zoom")
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
	check(focus_error() < 0.1, "Teleport recenters immediately")
	var before: Vector3 = rig.global_position
	rig.shake(2, Vector3.RIGHT)
	for i: int in range(60):
		rig._process(1.0 / 60)
	check(rig.global_position.distance_to(before) < 0.001 and focus_error() < 0.1, "Impact shake never drifts tracking center")
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
	check(focus_error() < 0.1, "Respawn recenters immediately")
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
	quit(1 if failures else 0)

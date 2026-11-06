extends SceneTree
## Run with a real renderer: --path . --script res://tests/dream_ground.gd

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	print("GROUND_CHECK ", "PASS " if condition else "FAIL ", label)

func settle() -> void:
	for index: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw

func capture(path: String) -> Image:
	var image: Image = root.get_texture().get_image()
	check(image.save_png(path) == OK, "Saved " + path)
	return image

func difference(first: Image, second: Image) -> float:
	var total: float = 0.0
	var samples: int = 0
	# Sample only ground, excluding the background border.
	for y: int in range(100, first.get_height() - 100, 12):
		for x: int in range(100, first.get_width() - 100, 12):
			var a: Color = first.get_pixel(x, y)
			var b: Color = second.get_pixel(x, y)
			total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			samples += 3
	return total / maxf(samples, 1.0)

func palette_error(image: Image, camera: Camera3D, material: ShaderMaterial) -> float:
	var mask: Image = (material.get_shader_parameter("layer_weights") as Texture2D).get_image()
	var pigments: Array[Color] = []
	for key: String in ["blue_pigment", "rose_pigment", "teal_pigment", "lavender_pigment"]:
		pigments.append((material.get_shader_parameter(key) as Color).srgb_to_linear())
	var error_sum: float = 0.0
	var count: int = 0
	for y: int in range(200, image.get_height() - 150, 137):
		for x: int in range(200, image.get_width() - 150, 149):
			# Project uses logical coordinates; screenshots use physical pixels.
			var screen: Vector2 = Vector2(x + 0.5, y + 0.5) * root.get_visible_rect().size / Vector2(image.get_size())
			var world: Vector3 = camera.project_ray_origin(screen)
			var uv: Vector2 = Vector2(world.x / 124.0 + 0.5, world.z / 98.0 + 0.5)
			uv.y = (uv.y - 0.5) * 98.0 * 1.77683316 / 124.0 + 0.5
			uv = Vector2(1.0 - absf(fposmod(uv.x, 2.0) - 1.0), 1.0 - absf(fposmod(uv.y, 2.0) - 1.0))
			var pixel: Vector2i = Vector2i(uv * Vector2(mask.get_size())).clamp(Vector2i.ZERO, mask.get_size() - Vector2i.ONE)
			var w: Color = mask.get_pixelv(pixel)
			var expected: Color = (pigments[0] * w.r + pigments[1] * w.g + pigments[2] * w.b + pigments[3] * w.a) / (w.r + w.g + w.b + w.a)
			expected = expected.linear_to_srgb()
			var actual: Color = image.get_pixel(x, y)
			error_sum += absf(expected.r - actual.r) + absf(expected.g - actual.g) + absf(expected.b - actual.b)
			count += 3
	return error_sum / count

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-results")
	root.size = Vector2i(1240, 980)
	var arena: Node3D = load("res://scenes/maps/arena/arena.tscn").instantiate()
	var ground: MeshInstance3D = arena.get_node("GroundVisual")
	check((ground.mesh as PlaneMesh).size == Vector2(124, 98), "New ground keeps 124 x 98")
	check(ground.material_override.resource_path == "res://assets/materials/dream_ground.tres", "Material is on GroundVisual")
	check(not (arena.get_node("Ground/Mesh") as MeshInstance3D).visible, "Old floor stays hidden")
	check((arena.get_node("Ground/CollisionShape3D").shape as BoxShape3D).size == Vector3(82, 0.4, 58), "Existing gameplay collision retained")
	arena.free()

	var preview: Node3D = load("res://scenes/tests/dream_ground_preview.tscn").instantiate()
	root.add_child(preview)
	current_scene = preview
	check(preview.find_children("*", "Light3D", true, false).is_empty(), "Preview has no light nodes")
	var camera: Camera3D = preview.get_node("Camera3D")
	check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.rotation_degrees.x, -90.0), "True orthographic top-down camera")
	await settle()
	var baseline: Image = capture("res://test-results/dream-ground-topdown.png")
	var material: ShaderMaterial = (preview.get_node("GroundVisual") as MeshInstance3D).material_override
	var colour_error: float = palette_error(baseline, camera, material)
	print("GROUND_PALETTE_ERROR ", colour_error)
	check(colour_error < 0.006, "Renderer reconstructs linear pigment colours correctly")
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -20, 0)
	sun.light_color = Color(0.9, 0.25, 1.0)
	sun.light_energy = 8.0
	preview.add_child(sun)
	var environment: Environment = (preview.get_node("WorldEnvironment") as WorldEnvironment).environment
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.2, 1.0, 0.3)
	environment.ambient_light_energy = 2.0
	await settle()
	var lit: Image = capture("res://test-results/dream-ground-lights-on.png")
	var light_difference: float = difference(baseline, lit)
	print("GROUND_LIGHT_DIFFERENCE ", light_difference)
	check(light_difference < 0.0001, "Changing scene lights does not recolour unlit ground")
	material.set_shader_parameter("rose_amount", 0.0)
	material.set_shader_parameter("teal_amount", 0.0)
	await settle()
	var changed: Image = capture("res://test-results/dream-ground-mask-check.png")
	var mask_difference: float = difference(baseline, changed)
	print("GROUND_MASK_DIFFERENCE ", mask_difference)
	check(mask_difference > 0.005, "Pigment mask parameters change the rendered surface")
	material.set_shader_parameter("rose_amount", 1.0)
	material.set_shader_parameter("teal_amount", 1.0)
	preview.queue_free()
	await process_frame

	var match_scene: Node3D = load("res://scenes/match.tscn").instantiate()
	root.add_child(match_scene)
	current_scene = match_scene
	await settle()
	capture("res://test-results/dream-ground-in-game.png")
	print("DREAM_GROUND_CHECKS ", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

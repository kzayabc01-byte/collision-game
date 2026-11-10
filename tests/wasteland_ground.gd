extends SceneTree
## Structural verification + actual Compatibility-renderer captures.
## Output only goes to the ignored test-results/wasteland directory.

var failures: int = 0
var checks: int = 0
var game: Node3D
const OUT: String = "res://test-results/wasteland/"

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	print("WASTELAND ", "PASS " if condition else "FAIL ", label)

func settle() -> void:
	for i: int in range(5):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(OUT + name + ".png") == OK, "Capture " + name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440, 900)
	game = load("res://scenes/match.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.get_node("Vehicles").process_mode = Node.PROCESS_MODE_DISABLED
	game.get_node("CandySystem").process_mode = Node.PROCESS_MODE_DISABLED
	await settle()
	var rig: Node3D = game.get_node("CameraRig")
	rig.set_process(false)
	rig.shake_enabled = false
	var camera: Camera3D = rig.get_node("Camera3D")
	var authored_basis: Basis = camera.basis
	var authored_size: float = camera.size
	var arena: Node3D = game.get_node("Arena")
	var ground: MeshInstance3D = arena.get_node("GroundVisual")
	var scatter: Node3D = ground.get_node("GroundScatter")
	check((ground.mesh as PlaneMesh).size == Vector2(124, 98), "Visible ground stays 124 x 98")
	check((arena.get_node("Ground/CollisionShape3D").shape as BoxShape3D).size == Vector3(82, 0.4, 58), "Collision stays 82 x 0.4 x 58")
	check(is_equal_approx(arena.get_node("Ground").position.y, -0.2), "Collision top stays Y=0")
	check(not arena.get_node("Ground/Mesh").visible, "Old floor remains hidden")
	check(scatter.find_children("*", "CollisionObject3D", true, false).is_empty(), "All decorations have no collision")
	check(scatter.find_children("*", "CollisionShape3D", true, false).is_empty(), "No hidden decorative collision shapes")
	check(ground.material_override.resource_path == "res://assets/materials/wasteland_ground.tres", "Wasteland material is connected")
	var backdrop: MeshInstance3D = ground.get_node("OuterBackdrop")
	check(backdrop.material_override == ground.material_override, "Backdrop shares soil material")
	var image: Image = (ground.material_override.get_shader_parameter("grass_mask") as Texture2D).get_image()
	check(image.get_size() == Vector2i(2480, 1960), "Mask matches 124:98 ground aspect")
	var instance_count: int = 0
	for group: Node in scatter.get_children():
		for item: Node3D in group.get_children():
			instance_count += 1
			check(item.scene_file_path.ends_with(".tscn"), "Editable instance " + item.name)
			check(Vector2(item.position.x / 1.15, item.position.z).length() >= 8.7, "Central clearing " + item.name)
	check(instance_count == 126, "126 static sparse ground instances")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/wasteland/model_info.json"))
	check(manifest.assets.size() == 12, "12 separate ground models")
	for asset: Dictionary in manifest.assets:
		var model: Node3D = load("res://assets/models/wasteland/" + asset.name + ".glb").instantiate()
		root.add_child(model)
		var min_y: float = INF
		var max_y: float = -INF
		for mesh_node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = mesh_node.global_transform * mesh_node.get_aabb()
			min_y = minf(min_y, bounds.position.y)
			max_y = maxf(max_y, bounds.end.y)
		check(absf(min_y) < 0.001, "Bottom-center origin " + asset.name)
		check(max_y < (0.12 if asset.group == "Stones" else 0.42), "Low silhouette " + asset.name)
		model.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless":
		var player: Node3D = game.get_node("Vehicles/PlayerCar")
		player.position = Vector3(-22, 0, 8)
		rig.recenter()
		game.get_node("HUD")._notice_remaining = 0.0
		game.get_node("HUD").refresh(game.player, game.cars, 180)
		await capture("gameplay-west")
		player.position = Vector3(0, 0, 0)
		rig.recenter()
		await capture("gameplay-center")
		player.position = Vector3(37, 0, 24)
		rig.recenter()
		await capture("gameplay-edge")
		check(camera.basis.is_equal_approx(authored_basis) and is_equal_approx(camera.size, authored_size), "Gameplay camera pitch and zoom unchanged")
		# Temporary inspection only: other assets are hidden in memory, never saved.
		game.get_node("HUD").hide()
		game.get_node("Vehicles").hide()
		game.get_node("CandySystem").hide()
		for child: Node in arena.get_children():
			if child is Node3D and child.name not in ["GroundVisual", "Sun", "Ground"]:
				(child as Node3D).hide()
		player.position = Vector3(-22, 0, 8)
		rig.recenter()
		await capture("ground-only-game-camera")
		scatter.hide()
		await capture("soil-only-game-camera")
		var current_material: Material = ground.material_override
		ground.material_override = load("res://assets/materials/dream_ground.tres")
		backdrop.material_override = ground.material_override
		await capture("previous-soil-same-camera")
		ground.material_override = current_material
		backdrop.material_override = current_material
		scatter.show()
		# Supplemental overview, deliberately separate from actual-camera captures.
		camera.global_position = Vector3(0, 100, 65)
		camera.look_at(Vector3.ZERO)
		camera.size = 97.0
		await capture("ground-overview")
		# Separate close-up sheet to inspect shape, thickness and contact shading.
		scatter.hide()
		var sheet: Node3D = Node3D.new()
		arena.add_child(sheet)
		var asset_index: int = 0
		for asset: Dictionary in manifest.assets:
			var prop: Node3D = load("res://scenes/maps/arena/ground/props/" + asset.name + ".tscn").instantiate()
			sheet.add_child(prop)
			prop.position = Vector3((asset_index % 4 - 1.5) * 1.8, 0, (asset_index / 4 - 1) * 1.65)
			asset_index += 1
		camera.global_position = Vector3(0, 10, 7)
		camera.look_at(Vector3.ZERO)
		camera.size = 6.2
		await capture("ground-assets-closeup")
	print("WASTELAND_RESULT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

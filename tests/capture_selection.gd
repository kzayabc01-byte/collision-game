extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output: String = "user://selection.png"
	var dimensions: Vector2i = Vector2i(1672, 941)
	var index: int = 0
	var scene_path: String = "res://scenes/ui/vehicle_select.tscn"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--size="):
			var parts: PackedStringArray = argument.trim_prefix("--size=").split("x")
			dimensions = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--vehicle="):
			index = int(argument.trim_prefix("--vehicle="))
		elif argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
	root.content_scale_size = Vector2i.ZERO
	root.size = dimensions
	CrashMatch.selected_vehicle = index
	var scene: Node = load(scene_path).instantiate()
	root.add_child(scene)
	current_scene = scene
	for tick: int in range(60):
		await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(output)
	print("SELECTION_CAPTURE ", result, " ", output)
	quit(0 if result == OK else 1)

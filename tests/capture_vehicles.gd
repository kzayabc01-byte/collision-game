extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var scene: Node3D = (load("res://scenes/vehicle_showcase.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	for index: int in range(110):
		await process_frame
	await RenderingServer.frame_post_draw
	var output_path: String = "user://vehicle-preview.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	var result: Error = root.get_texture().get_image().save_png(output_path)
	print("VEHICLE_CAPTURE ", result, " ", output_path)
	quit(0 if result == OK else 1)

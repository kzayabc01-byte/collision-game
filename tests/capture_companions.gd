extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var output: String = "user://companion-frames"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var scene: Node3D = (load("res://scenes/vehicle_showcase.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	for frame: int in range(600):
		await process_frame
		await RenderingServer.frame_post_draw
		if frame == 110:
			root.get_texture().get_image().save_png(output.path_join("three-cars.png"))
		if frame >= 180 and frame % 3 == 0:
			var result: Error = root.get_texture().get_image().save_png(output.path_join("frame_%03d.png" % ((frame - 180) / 3)))
			if result != OK:
				quit(1)
				return
	print("COMPANION_CAPTURE ", output)
	quit()

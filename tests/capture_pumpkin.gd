extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var output: String = "user://pumpkin-capture"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var studio: Node3D = (load("res://scenes/pumpkin_studio.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(studio)
	current_scene = studio
	for frame: int in range(150):
		if frame == 45:
			studio.call("play_swallow")
		await process_frame
		await RenderingServer.frame_post_draw
		if frame % 3 == 0:
			var error: Error = root.get_texture().get_image().save_png(output.path_join("frame_%03d.png" % (frame / 3)))
			if error != OK:
				quit(1)
				return
	print("PUMPKIN_CAPTURE ", output)
	quit()

extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	seed(11)
	var output: String = "user://impact-preview"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var scene: Node3D = (load("res://scenes/impact_showcase.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	scene.set_process_unhandled_input(false)
	for button: Button in [scene.get_node("UI/Hit"), scene.get_node("UI/Play")]:
		button.disabled = true
	for tick: int in range(420):
		await process_frame
		if tick == 60:
			scene.play_hit()
		await RenderingServer.frame_post_draw
		if tick == 88:
			root.get_texture().get_image().save_png(output.path_join("impact.png"))
		if tick >= 45 and tick % 3 == 0:
			root.get_texture().get_image().save_png(output.path_join("frame_%03d.png" % ((tick - 45) / 3)))
	print("IMPACT_CAPTURE ", output)
	var cleared: bool = scene.get_node("Effects").get_child_count() == 0
	print("STAIN_CLEARED_AFTER_FIVE_SECONDS ", cleared)
	scene.free()
	var deadline: int = Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < deadline:
		await process_frame
	quit(0 if cleared else 1)

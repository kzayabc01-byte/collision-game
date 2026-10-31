extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var scene: CrashMatch = (load("res://scenes/match.tscn") as PackedScene).instantiate() as CrashMatch
	root.add_child(scene)
	current_scene = scene
	for index: int in range(90):
		await process_frame
	scene.set_physics_process(false)
	scene.player.global_position = Vector3(-6.7, 0, 5.0)
	scene.player.set_candy(30)
	scene.cars[1].global_position = Vector3(7.8, 0, 4.0)
	scene.cars[1].set_candy(44)
	scene.cars[2].global_position = Vector3(-7.5, 0, -3.5)
	scene.cars[3].global_position = Vector3(8.5, 0, -4.0)
	scene.candy_system.spawn_drop(Vector3(0, 0, 4), Vector3.RIGHT, 12, 0, 1)
	for index: int in range(35):
		scene.candy_system.tick(1.0 / 60.0)
		await process_frame
	scene.hud.refresh(scene.player, scene.cars, 168.0)
	scene.hud.announce("30颗糖果 · 正面速度6即可撞碎糖箱")
	await RenderingServer.frame_post_draw
	var output_path: String = "user://prototype-preview.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	var result: Error = root.get_texture().get_image().save_png(output_path)
	print("CAPTURE_RESULT ", result, " ", output_path)
	quit(0 if result == OK else 1)

extends SceneTree

func _initialize() -> void:
	capture.call_deferred()

func capture() -> void:
	var output: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var overview: Node3D = load("res://scenes/maps/arena/arena_overview.tscn").instantiate()
	root.add_child(overview)
	for i: int in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("arena-overview.png"))
	overview.free()
	var game: CrashMatch = load("res://scenes/match.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for i: int in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("arena-gameplay.png"))
	game.player.global_position = Vector3(0,0,12)
	game.get_node("CameraRig").recenter()
	for i: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("arena-center-gameplay.png"))
	root.get_node("Music").set_context("intro")
	game.free()
	await create_timer(0.3).timeout
	quit()

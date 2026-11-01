extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	CrashMatch.selected_vehicle = 2
	var game: CrashMatch = (load("res://scenes/match.tscn") as PackedScene).instantiate() as CrashMatch
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.player.set_candy(135)
	game.player.global_position = Vector3(18.8, 0, 12.8)
	game.player.constrain_to_arena()
	for car: CrashCar in game.cars:
		car.feedback.show_gain(1, false)
	for index: int in range(65):
		await process_frame
	game.hud.refresh(game.player, game.cars, 24)
	game.hud.announce("135颗糖果 · 车身保持在围墙内，玩家与AI独立控制")
	await RenderingServer.frame_post_draw
	var output: String = "user://bugfix-preview.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var result: Error = root.get_texture().get_image().save_png(output)
	print("CAPTURE ", result, " ", game.player.position)
	quit(0 if result == OK else 1)

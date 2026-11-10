extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	seed(11)
	var output: String = "user://match-impact.png"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	var game: CrashMatch = (load("res://scenes/match.tscn") as PackedScene).instantiate() as CrashMatch
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	var a: CrashCar = game.player
	var b: CrashCar = game.cars[2]
	a.reset_at(Vector3(-4.5, 0, 6))
	b.reset_at(Vector3(-1.5, 0, 6))
	a._heading = Vector3.RIGHT
	b._heading = Vector3.LEFT
	a.set_candy(45)
	b.set_candy(45)
	for tick: int in range(60):
		await process_frame
	a.velocity = Vector3.RIGHT * 7.0
	b.velocity = Vector3.LEFT * 2.1
	a.snapshot()
	b.snapshot()
	game.resolver._resolve_car(a, b, Vector3.RIGHT, game.resolver.pair_key(a, b), Vector3(-3, 0.5, 6))
	a.velocity = Vector3.ZERO
	b.velocity = Vector3.ZERO
	a.update_roll_state()
	b.update_roll_state()
	for tick: int in range(28):
		if game.hitstop_remaining > 0.0:
			game._physics_process(1.0 / 60.0)
		else:
			game.candy_system.tick(1.0 / 60.0)
		await process_frame
	game.hud.refresh(a, game.cars, 168.0)
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output)
	print("MATCH_IMPACT_CAPTURE ", error, " ", output)
	game.free()
	var deadline: int = Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < deadline:
		await process_frame
	quit(0 if error == OK else 1)

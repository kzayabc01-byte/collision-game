extends SceneTree
## Run in real time: --max-fps 60, not --fixed-fps (video and audio use a media clock).

var checks: int = 0
var failures: int = 0
var completion_reason: String = ""
var output: String = ""

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)

func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)

func check_audible(message: String) -> void:
	# A playing flag can still mean silent samples; measure the actual mixed output.
	var meter: AudioEffectCapture = AudioEffectCapture.new()
	meter.buffer_length = 0.5
	var effect_index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, meter)
	await create_timer(0.25).timeout
	var samples: PackedVector2Array = meter.get_buffer(meter.get_frames_available())
	var energy: float = 0.0
	for sample: Vector2 in samples:
		energy += sample.length_squared()
	var rms: float = sqrt(energy / maxi(1, samples.size() * 2))
	AudioServer.remove_bus_effect(0, effect_index)
	print("AUDIO RMS ", message, ": ", rms)
	check(rms > 0.002, message)

func make_menu(check_intro: bool, missing: bool = false) -> StartScreen:
	StartScreen.intro_checked_this_launch = not check_intro
	var menu: StartScreen = (load("res://scenes/ui/start_screen.tscn") as PackedScene).instantiate() as StartScreen
	if missing:
		menu.intro_video_path = "res://assets/cinematics/missing-test.ogv"
	menu.intro_finished.connect(func(reason: String) -> void: completion_reason = reason)
	root.add_child(menu)
	current_scene = menu
	return menu

func _run() -> void:
	var watchdog: Timer = Timer.new()
	watchdog.wait_time = 35.0
	watchdog.one_shot = true
	root.add_child(watchdog)
	watchdog.timeout.connect(func() -> void: push_error("media test timed out"); quit(2))
	watchdog.start()
	var menu: StartScreen = make_menu(true)
	var music: AudioStreamMP3 = menu.menu_music.stream as AudioStreamMP3
	check(menu.stage == StartScreen.Stage.INTRO and menu.video_player.is_playing(), "first launch plays the real intro")
	check(not menu.menu_music.playing, "menu music is silent during intro")
	check(music != null and music.loop and is_equal_approx(music.loop_offset, 9.89), "MP3 loop skips the source's leading silence")
	check(music != null and music.get_length() > 55.0 and music.get_length() < 57.0, "supplied 56-second MP3 is loaded")
	await create_timer(2.0).timeout
	check(menu.stage == StartScreen.Stage.INTRO and menu.video_player.stream_position > 1.0, "real video decoder advances")
	await capture("intro-playing")
	var deadline: int = Time.get_ticks_msec() + 13000
	while menu.stage == StartScreen.Stage.INTRO and Time.get_ticks_msec() < deadline:
		await process_frame
	check(completion_reason == "finished" and menu.stage == StartScreen.Stage.MENU, "natural end shows menu, not stall fallback")
	await create_timer(0.5).timeout
	check(menu.menu_music.playing and menu.menu_music.get_playback_position() > 0.0, "natural end starts music")
	check(is_equal_approx(menu.menu_music.volume_db, -4.0), "music reaches the scene-configured volume")
	check(not menu.video_layer.visible and menu.video_player.stream == null, "video audio and layer are released")
	await check_audible("music is audible immediately after natural intro completion")
	await capture("menu-music")
	var prior_position: float = menu.menu_music.get_playback_position()
	menu.skip_intro()
	menu._finish_intro("finished")
	await create_timer(0.1).timeout
	check(menu.menu_music.get_playback_position() >= prior_position, "duplicate end/skip does not restart music")
	menu.menu_music.seek(music.get_length() - 0.2)
	await create_timer(0.8).timeout
	check(menu.menu_music.playing and menu.menu_music.get_playback_position() >= music.loop_offset and menu.menu_music.get_playback_position() < music.loop_offset + 2.0, "music wraps to the audible section")
	await check_audible("music remains audible after looping")
	var old_music: AudioStreamPlayer = menu.menu_music
	menu.start_game()
	await create_timer(0.15).timeout
	check(is_instance_valid(old_music) and old_music.volume_db < -4.0, "entering selection fades music")
	await create_timer(0.5).timeout
	check(current_scene is VehicleSelect and not is_instance_valid(old_music), "selection frees the previous music player")
	if not current_scene is VehicleSelect:
		quit(1)
		return
	(current_scene as VehicleSelect).back_to_menu()
	await create_timer(0.7).timeout
	check(current_scene is StartScreen, "selection can return to menu")
	if not current_scene is StartScreen:
		quit(1)
		return
	menu = current_scene as StartScreen
	check(menu.stage == StartScreen.Stage.MENU and menu.menu_music.playing, "return resumes music without replaying intro")
	check(menu.find_children("MenuMusic", "AudioStreamPlayer", true, false).size() == 1, "return has one music player")
	menu.free()
	menu = make_menu(true)
	await create_timer(0.5).timeout
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	await process_frame
	escape = escape.duplicate() as InputEventKey
	escape.pressed = false
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	await create_timer(0.5).timeout
	check(completion_reason == "skipped" and menu.stage == StartScreen.Stage.MENU, "Esc skips only the intro")
	check(menu.menu_music.playing and menu.video_player.stream == null, "skip switches audio to menu music")
	await check_audible("music is audible immediately after skipping intro")
	menu.free()
	menu = make_menu(true, true)
	await create_timer(0.4).timeout
	check(menu.stage == StartScreen.Stage.MENU and menu.menu_music.playing, "missing intro falls back to menu with music")
	menu.free()
	# Let the audio mixer release stopped playback before shutting down the server.
	await create_timer(0.25).timeout
	print("MENU MEDIA: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

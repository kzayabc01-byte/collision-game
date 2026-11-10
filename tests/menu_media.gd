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
	var music = root.get_node("Music")
	music.config_path = "user://music-test.cfg"
	music.enabled = true
	music.mode = 0
	var menu := make_menu(true)
	check(menu.stage == StartScreen.Stage.INTRO, "intro starts")
	check(music.current == -1, "intro has no BGM")
	await create_timer(1.0).timeout
	menu.skip_intro()
	await create_timer(0.8).timeout
	check(music.current == 0, "skip starts Aquarium")
	check(menu.video_player.stream == null, "intro audio released")
	for index in 3:
		music.play_track(index)
		await create_timer(0.8).timeout
		var player: AudioStreamPlayer = music.players[music.active]
		check(player.stream.get_length() > 60, "track decodes " + str(index))
		player.seek(30)
		if DisplayServer.get_name() != "headless":
			await check_audible("track " + str(index))
	music.set_context("battle")
	await create_timer(0.8).timeout
	check(music.current == 2, "battle uses Ecstasy")
	music.set_paused(true)
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) < -10, "pause attenuates")
	music.set_paused(false)
	music.set_context("menu")
	await create_timer(0.8).timeout
	var active: int = music.active
	var position: float = music.players[active].get_playback_position()
	music.set_context("menu")
	check(music.active == active and music.players[active].get_playback_position() >= position, "menu selection continuity")
	music.set_mode(1)
	music.play_track(2)
	music._finished(music.active)
	check(music.current == 0, "list wraps")
	music.set_mode(2)
	var prior: int = music.current
	music._finished(music.active)
	check(music.current != prior, "shuffle avoids immediate repeat")
	music.set_mode(3)
	prior = music.current
	music._finished(music.active)
	check(music.current == prior, "single repeats")
	music.enabled = false
	music.sfx_volume = 0.67
	music.apply_volume()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "BGM mute")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "SFX independent")
	music.save()
	var cfg := ConfigFile.new()
	check(cfg.load(music.config_path) == OK and cfg.get_value("audio", "sfx_volume") == 0.67, "settings persisted")
	music.enabled = true
	music.set_mode(0)
	music.apply_volume()
	music.open_settings()
	await create_timer(0.5).timeout
	check(music.settings_open, "settings opens")
	menu.start_game()
	check(menu.stage == StartScreen.Stage.MENU, "modal blocks starting game")
	await capture("music-settings")
	music.close_settings()
	check(not music.settings_open, "settings closes")
	menu.start_game()
	await create_timer(1.0).timeout
	check(current_scene is VehicleSelect, "start enters selection")
	check(music.current == 0, "selection keeps Aquarium")
	for player: AudioStreamPlayer in music.players: player.stop()
	print("MUSIC_CHECKS ", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

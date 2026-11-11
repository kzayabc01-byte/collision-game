extends SceneTree
## Use --max-fps 60. A windowed run also verifies real mixed samples.

var passed: int = 0
var failed: int = 0
var record_folder: String = ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			record_folder = arg.trim_prefix("--output=")
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ", message)
	else:
		failed += 1
		push_error(message)

func drive(car: CrashCar, speed: float, throttle: float, ticks: int) -> void:
	car.velocity = Vector3.FORWARD * speed
	car.throttle_input = throttle
	car.update_roll_state()
	for tick: int in range(ticks):
		car._process(1.0 / 60.0)
		await process_frame

func audible() -> void:
	var meter: AudioEffectCapture = AudioEffectCapture.new()
	meter.buffer_length = 0.5
	var index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, meter)
	await create_timer(0.2).timeout
	var samples: PackedVector2Array = meter.get_buffer(meter.get_frames_available())
	var energy: float = 0.0
	for sample: Vector2 in samples:
		energy += sample.length_squared()
	var rms: float = sqrt(energy / maxi(1, samples.size() * 2))
	AudioServer.remove_bus_effect(0, index)
	print("DRIVE AUDIO RMS ", rms)
	check(rms > 0.001, "running loop produces real audio output")

func record(car: CrashCar, kind: int) -> void:
	if record_folder.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(record_folder)
	var meter: AudioEffectCapture = AudioEffectCapture.new()
	meter.buffer_length = 1.0
	var index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, meter)
	var samples: PackedVector2Array = PackedVector2Array()
	car.reset_at(Vector3.ZERO)
	for tick: int in range(270):
		var time: float = float(tick) / 60.0
		var speed: float = minf(9.0, time * 7.5) if time < 2.0 else maxf(0.0, 9.0 - (time - 2.0) * 5.5)
		await drive(car, speed, 1.0 if time < 2.0 else 0.0, 1)
		samples.append_array(meter.get_buffer(meter.get_frames_available()))
	AudioServer.remove_bus_effect(0, index)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 4)
	for frame: int in range(samples.size()):
		data.encode_s16(frame * 4, int(clampf(samples[frame].x, -1.0, 1.0) * 32767))
		data.encode_s16(frame * 4 + 2, int(clampf(samples[frame].y, -1.0, 1.0) * 32767))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(AudioServer.get_mix_rate())
	wav.stereo = true
	wav.data = data
	check(wav.save_to_wav(record_folder.path_join(["pony", "pumpkin", "slime"][kind] + "-acceleration.wav")) == OK, "saved actual acceleration/deceleration preview")

func _run() -> void:
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(sfx_bus, false)
	AudioServer.set_bus_volume_db(sfx_bus, 0.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	for kind: int in range(3):
		var car: CrashCar = (load(CrashMatch.VehiclePaths[kind]) as PackedScene).instantiate() as CrashCar
		car.is_player = true
		root.add_child(car)
		car.set_process(false)
		var loop: AudioStreamPlayer = car.feedback.drive_loop
		check(loop.bus == "SFX" and (loop.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "vehicle %d uses a looping SFX asset" % kind)
		await drive(car, 0.0, 1.0, 5)
		check(not loop.playing, "holding throttle while stationary stays quiet")
		await drive(car, 2.5, 1.0, 20)
		if kind == VehicleProfile.Kind.SLIME:
			check(not loop.playing and car.feedback.movement_sound.playing, "slime walks with footsteps below four")
			await drive(car, 4.0, 1.0, 4)
			check(not loop.playing, "exactly four keeps walking audio state")
			await drive(car, 4.5, 1.0, 20)
		check(loop.playing, "moving vehicle starts continuous audio")
		var low_pitch: float = loop.pitch_scale
		var low_volume: float = loop.volume_db
		var voice: AudioStreamPlayback = loop.get_stream_playback()
		await drive(car, 9.0, 1.0, 30)
		check(loop.pitch_scale > low_pitch + 0.2 and loop.volume_db > low_volume, "acceleration increases pitch and volume")
		check(loop.get_stream_playback() == voice, "speed changes do not restart the looping voice")
		if DisplayServer.get_name() != "headless":
			await audible()
		var powered_volume: float = loop.volume_db
		await drive(car, 9.0, 0.0, 20)
		check(loop.playing and loop.volume_db < powered_volume - 2.0, "coasting keeps quieter rolling audio")
		car.feedback.hit(1, Color.WHITE)
		car.feedback._pickup_sound = CarFeedback.BODY_SOUNDS[0] as AudioStreamWAV
		car.feedback.play_pickup()
		check(loop.playing and loop.get_stream_playback() == voice, "impact and pickup leave the drive voice running")
		car.process_mode = Node.PROCESS_MODE_DISABLED
		await process_frame
		check(loop.stream_paused, "pause freezes continuous driving sound")
		car.process_mode = Node.PROCESS_MODE_INHERIT
		await process_frame
		check(not loop.stream_paused and loop.playing, "resume restores the same loop")
		await drive(car, 0.0, 0.0, 35)
		check(not loop.playing, "stopping fades out and releases the loop")
		await drive(car, 6.0, -1.0, 15)
		check(loop.playing, "reverse motion also has wheel audio")
		car.apply_loss(car.candy)
		check(not loop.playing and not car.feedback.movement_sound.playing, "defeat immediately clears movement audio")
		car.reset_at(Vector3.ZERO)
		check(not loop.playing and loop.volume_db == -80.0, "respawn starts silent")
		await record(car, kind)
		car.free()
		await create_timer(0.2).timeout
	var ai: CrashCar = (load(CrashMatch.VehiclePaths[0]) as PackedScene).instantiate() as CrashCar
	root.add_child(ai)
	ai.set_process(false)
	await drive(ai, 9.0, 1.0, 5)
	check(not ai.feedback.drive_loop.playing, "AI does not add competing continuous loops")
	ai.free()
	await create_timer(0.25).timeout
	print("DRIVE AUDIO: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

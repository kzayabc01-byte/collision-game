extends SceneTree

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ", message)
	else:
		failed += 1
		push_error(message)

func _run() -> void:
	var palette: CandyVisualSet = load("res://config/candy_visuals.tres") as CandyVisualSet
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for index: int in range(100):
		counts[palette.choose((index + 0.5) / 100.0)] += 1
	check(counts == [30, 25, 20, 15, 10], "five cosmetic models have the requested weights")
	for index: int in range(5):
		var candy: CandyPickup = CandySystem.CandyScene.instantiate() as CandyPickup
		root.add_child(candy)
		candy.position = Vector3(25, 0, 25)
		candy.add_lot(1, 8, 0.0, 0.5, 8.0)
		var chosen: int = candy.style_index
		candy.add_lot(4, 9, 0.0, 0.5, 8.0)
		candy.tick(0.1, 0.1)
		check(candy.style_index == chosen and candy.spin.get_child_count() == 1, "merging preserves one chosen visual %d" % index)
		check(candy.total_value() == 5 and candy.visual_size >= 0.9 and candy.visual_size <= 1.1, "cosmetics preserve value and size limits %d" % index)
		check(is_equal_approx((candy.get_node("PickupArea/CollisionShape3D") as CollisionShape3D).shape.radius, 0.35), "pickup radius unchanged %d" % index)
		candy.free()
	var profile: ImpactProfile = load("res://config/impact.tres") as ImpactProfile
	check(profile.tier_for(0.0, 0.0) == -1 and profile.tier_for(2.0, 2.0) == 0, "tangential contact has no splash and small impact stays light")
	check(profile.tier_for(22.0, 9.0, 0.01) == 2, "heavy impact remains heavy despite low candy damage")
	var effect: SugarImpactEffect = CrashMatch.IMPACT_SCENE.instantiate() as SugarImpactEffect
	root.add_child(effect)
	effect.set_process(false)
	effect.setup(Vector3.RIGHT, Color.PINK, 2)
	effect._process(4.0)
	check(not effect.is_queued_for_deletion() and is_equal_approx(float((effect.stain.material_override as ShaderMaterial).get_shader_parameter("fade")), 1.0), "stain stays visible for first four seconds")
	effect._process(0.5)
	check(is_equal_approx(float((effect.stain.material_override as ShaderMaterial).get_shader_parameter("fade")), 0.5), "stain fades during final second")
	effect._process(0.51)
	check(effect.is_queued_for_deletion(), "stain is removed at five seconds")
	await process_frame
	var car: CrashCar = (load("res://scenes/vehicles/pony_car.tscn") as PackedScene).instantiate() as CrashCar
	root.add_child(car)
	car.set_process(false)
	var listener: Camera3D = Camera3D.new()
	root.add_child(listener)
	listener.position = Vector3(0, 2, 4)
	listener.look_at(Vector3.ZERO)
	listener.make_current()
	var meter: AudioEffectCapture = AudioEffectCapture.new()
	meter.buffer_length = 0.5
	var meter_index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, meter)
	var shape: Transform3D = car.body_shape.transform
	car.feedback.hit(2, Color.PINK, Vector3.RIGHT)
	check(car.hit_pivot.scale.x < car.hit_pivot.scale.z and car.body_shape.transform == shape, "side hit compresses visual sideways without changing collider")
	var voice: AudioStreamPlayback = car.feedback.impact_sound.get_stream_playback()
	car.feedback._pickup_sound = CarFeedback.BODY_SOUNDS[0] as AudioStreamWAV
	car.feedback.play_pickup()
	check(car.feedback.impact_sound.playing and car.feedback.impact_sound.get_stream_playback() == voice and car.feedback.sound.playing, "pickup plays independently without restarting impact voice")
	await create_timer(0.15).timeout
	var samples: PackedVector2Array = meter.get_buffer(meter.get_frames_available())
	var energy: float = 0.0
	for sample: Vector2 in samples:
		energy += sample.length_squared()
	var rms: float = sqrt(energy / maxi(1, samples.size() * 2))
	print("IMPACT AUDIO RMS ", rms)
	if DisplayServer.get_name() != "headless":
		check(rms > 0.001, "impact and pickup produce actual mixed audio samples")
	else:
		print("SKIP actual audio samples: run without --headless to test the device mixer")
	AudioServer.remove_bus_effect(0, meter_index)
	listener.free()
	car.character_visual.animate(0.12, 0.0, 1.0, false, false)
	check(absf((car.character_visual.get_node("Motion/Model/PonyArt/Head") as Node3D).rotation.x) > 0.01, "head has delayed secondary impact motion")
	car.reset_at(Vector3.ZERO)
	check(car.hit_pivot.scale.is_equal_approx(Vector3.ONE) and car.hit_pivot.position.is_zero_approx(), "respawn clears impact deformation and recoil")
	car.free()
	CrashMatch.ability_lab = false
	CrashMatch.selected_vehicle = 0
	var game: CrashMatch = (load("res://scenes/match.tscn") as PackedScene).instantiate() as CrashMatch
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game._on_impact_visualized(Vector3.ZERO, Vector3.RIGHT, 2, false, false, Color.PINK)
	check(game.hitstop_remaining == 0.0 and game.get_node("CameraRig").get("_strength") == 0.0, "AI-only collisions never stop or shake the player")
	game._on_impact_visualized(Vector3.ZERO, Vector3.RIGHT, 2, true, false, Color.GREEN)
	check(is_equal_approx(game.hitstop_remaining, 0.065), "player heavy impact requests 65 ms hitstop")
	check(not game.player.feedback.impact_sound.stream_paused and game.player.feedback.impact_sound.can_process(), "hitstop keeps impact audio active")
	check(PhysicsServer3D.body_get_space(game.player.get_rid()).is_valid(), "hitstop keeps vehicle collision registered")
	var time_before: float = game.remaining_seconds
	game._physics_process(0.02)
	check(game.remaining_seconds == time_before, "hitstop pauses the world and round clock consistently")
	game.toggle_pause()
	var frozen: float = game.hitstop_remaining
	game._physics_process(0.1)
	check(game.hitstop_remaining == frozen and game.impact_effects.process_mode == Node.PROCESS_MODE_DISABLED, "pause during hitstop freezes effects and remaining hold")
	game.toggle_pause()
	game._physics_process(0.1)
	check(game.hitstop_remaining == 0.0 and game.get_node("Vehicles").process_mode == Node.PROCESS_MODE_INHERIT, "unpause finishes hitstop and restores processing")
	check(game.impact_effects.get_child_count() == 2, "independent contact effects coexist")
	var first: SugarImpactEffect = game.impact_effects.get_child(0) as SugarImpactEffect
	var second: SugarImpactEffect = game.impact_effects.get_child(1) as SugarImpactEffect
	check(first.stain.material_override != second.stain.material_override, "stain fade and color are per instance")
	game.free()
	check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "leaving a hitstop never changes global time or pause")
	await create_timer(0.25).timeout
	print("IMPACT FEEDBACK: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

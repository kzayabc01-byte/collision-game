class_name CarFeedback
extends Node3D

var pivot: Node3D
var _tween: Tween
var _pickup_cooldown: float = 0.0
var _impact_sound: AudioStreamWAV
var _pickup_sound: AudioStreamWAV
var _swallow_sound: AudioStreamWAV
var _step_sound: AudioStreamWAV
var _roll_sound: AudioStreamWAV
var _gain_tween: Tween
var _step_remaining: float = 0.0
var _was_rolling: bool = false

@onready var particles: CPUParticles3D = $PaperParticles
@onready var trail: CPUParticles3D = $SpeedTrail
@onready var sound: AudioStreamPlayer = $Sound
@onready var movement_sound: AudioStreamPlayer = $MovementSound
@onready var gain_label: Label3D = $Gain

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_impact_sound = _tone(95.0, 0.13, true)
		_pickup_sound = _tone(780.0, 0.075, false)
		_swallow_sound = _tone(145.0, 0.28, false)
		_step_sound = _tone(220.0, 0.055, true)
		_roll_sound = _tone(320.0, 0.18, false)

func _exit_tree() -> void:
	if is_instance_valid(sound):
		sound.stop()
		sound.stream = null
	if is_instance_valid(movement_sound):
		movement_sound.stop()
		movement_sound.stream = null

func _process(delta: float) -> void:
	_pickup_cooldown = maxf(0.0, _pickup_cooldown - delta)
	_step_remaining = maxf(0.0, _step_remaining - delta)

func show_gain(amount: int, doubled: bool, height: float = 2.0) -> void:
	if _gain_tween != null and _gain_tween.is_valid():
		_gain_tween.kill()
	gain_label.text = "+%d%s" % [amount, "  双倍" if doubled else ""]
	gain_label.modulate = Color("ffc8e5") if doubled else Color("ffe6a6")
	gain_label.outline_modulate.a = 1.0
	gain_label.position.y = height
	gain_label.show()
	_gain_tween = create_tween().set_parallel(true)
	_gain_tween.tween_property(gain_label, "position:y", height + 0.8, 0.65)
	_gain_tween.tween_property(gain_label, "modulate:a", 0.0, 0.65)
	_gain_tween.tween_property(gain_label, "outline_modulate:a", 0.0, 0.65)
	_gain_tween.chain().tween_callback(gain_label.hide)

func play_swallow() -> void:
	if _swallow_sound != null:
		sound.stop()
		sound.stream = _swallow_sound
		sound.pitch_scale = 1.0
		sound.volume_db = -12.0
		sound.play()

func locomotion(speed: float, rolling: bool, is_slime: bool, is_player: bool) -> void:
	if not is_slime or not is_player or _step_sound == null:
		return
	var clip: AudioStreamWAV = null
	if rolling != _was_rolling:
		clip = _roll_sound
		_step_remaining = 0.25
	elif not rolling and speed > 0.3 and _step_remaining <= 0.0:
		clip = _step_sound
		_step_remaining = maxf(0.18, 0.7 / speed)
	_was_rolling = rolling
	if clip != null:
		movement_sound.stop()
		movement_sound.stream = clip
		movement_sound.volume_db = -25.0
		movement_sound.play()

func hit(tier: int, color: Color) -> void:
	particles.color = color
	particles.initial_velocity_min = 1.0 + tier
	particles.initial_velocity_max = 2.0 + tier * 1.8
	particles.restart()
	particles.emitting = true
	if is_instance_valid(pivot):
		if _tween != null and _tween.is_valid():
			_tween.kill()
		pivot.scale = Vector3(1.12 + tier * 0.08, 0.78 - tier * 0.06, 1.12 + tier * 0.08)
		_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(pivot, "scale", Vector3.ONE, 0.4)
	if _impact_sound != null:
		sound.stop()
		sound.stream = _impact_sound
		sound.pitch_scale = 1.15 - tier * 0.14
		sound.volume_db = -13.0 + tier * 2.0
		sound.play()

func play_pickup() -> void:
	if _pickup_cooldown > 0.0 or _pickup_sound == null:
		return
	_pickup_cooldown = 0.075
	sound.stop()
	sound.stream = _pickup_sound
	sound.pitch_scale = randf_range(0.95, 1.15)
	sound.volume_db = -20.0
	sound.play()

func set_speed(fraction: float, enabled: bool) -> void:
	trail.emitting = enabled and fraction > 0.55
	trail.initial_velocity_max = 0.8 + fraction

func reset_feedback() -> void:
	if _gain_tween != null and _gain_tween.is_valid():
		_gain_tween.kill()
	gain_label.hide()
	_was_rolling = false
	_step_remaining = 0.0
	movement_sound.stop()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if pivot != null:
		pivot.scale = Vector3.ONE
		pivot.rotation = Vector3.ZERO
	particles.emitting = false

func _tone(frequency: float, seconds: float, noise: bool) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count: int = int(seconds * stream.mix_rate)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	for index: int in range(count):
		var time: float = float(index) / stream.mix_rate
		var envelope: float = pow(1.0 - float(index) / count, 2.0)
		var wave: float = sin(TAU * frequency * time * (1.0 + time * 2.0))
		if noise:
			wave = wave * 0.65 + randf_range(-0.35, 0.35)
		bytes.encode_s16(index * 2, int(wave * envelope * 18000.0))
	stream.data = bytes
	return stream

func drive_cue(released: bool) -> void:
	if _pickup_sound == null:
		return
	sound.stream = _swallow_sound if released else _pickup_sound
	sound.pitch_scale = 1.6 if released else 1.3
	sound.volume_db = -17.0
	sound.play()

func set_maneuver(braking: bool, drifting: bool, ready: bool, bursting: bool, delta: float) -> void:
	if is_instance_valid(pivot):
		pivot.rotation.x = lerp(pivot.rotation.x, -0.10 if braking and not drifting else 0.0, minf(1.0, delta * 15.0))
	trail.color = Color("fff09a") if ready else (Color("ffb86b") if bursting else (Color("eeeeee") if drifting else Color.WHITE))
	if drifting or ready or bursting:
		trail.emitting = true

class_name CarFeedback
extends Node3D

var pivot: Node3D
var _tween: Tween
var _pickup_cooldown: float = 0.0
var _impact_sound: AudioStreamWAV
var _pickup_sound: AudioStreamWAV

@onready var particles: CPUParticles3D = $PaperParticles
@onready var trail: CPUParticles3D = $SpeedTrail
@onready var sound: AudioStreamPlayer = $Sound

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_impact_sound = _tone(95.0, 0.13, true)
		_pickup_sound = _tone(780.0, 0.075, false)

func _exit_tree() -> void:
	if is_instance_valid(sound):
		sound.stop()
		sound.stream = null

func _process(delta: float) -> void:
	_pickup_cooldown = maxf(0.0, _pickup_cooldown - delta)

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
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if pivot != null:
		pivot.scale = Vector3.ONE
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

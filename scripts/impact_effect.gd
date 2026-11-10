class_name SugarImpactEffect
extends Node3D

@export var profile: ImpactProfile
var age: float = 0.0
@onready var stain: MeshInstance3D = $Stain
@onready var flash: MeshInstance3D = $Flash
@onready var droplets: CPUParticles3D = $Droplets

func setup(direction: Vector3, color: Color, tier: int) -> void:
	rotation.y = atan2(-direction.z, direction.x)
	var extent: float = 1.0 + float(tier) * 0.65
	stain.scale = Vector3(extent, 1.0, extent * randf_range(0.75, 1.05))
	var material: ShaderMaterial = stain.material_override as ShaderMaterial
	material.set_shader_parameter("syrup_color", color)
	material.set_shader_parameter("variation", randf() * 10.0)
	flash.scale = Vector3.ONE * (0.6 + tier * 0.4)
	droplets.color = color
	droplets.amount = 5 + tier * 6
	droplets.initial_velocity_min = 2.0 + tier
	droplets.initial_velocity_max = 3.0 + tier * 1.6
	droplets.restart()
	droplets.emitting = true

func _process(delta: float) -> void:
	age += delta
	flash.visible = age < 0.12
	(flash.material_override as ShaderMaterial).set_shader_parameter("fade", maxf(0.0, 1.0 - age / 0.12))
	var opacity: float = 1.0 - clampf((age - profile.stain_fade_start) / maxf(0.01, profile.stain_seconds - profile.stain_fade_start), 0.0, 1.0)
	(stain.material_override as ShaderMaterial).set_shader_parameter("fade", opacity)
	if age >= profile.stain_seconds:
		queue_free()

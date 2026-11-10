class_name ImpactProfile
extends Resource
## Presentation thresholds only; collision damage and impulse stay in GameTuning.

@export var medium_energy: float = 6.0
@export var heavy_energy: float = 18.0
@export var heavy_hitstop: float = 0.065
@export var defeat_hitstop: float = 0.09
@export var hitstop_cooldown: float = 0.25
@export var stain_seconds: float = 5.0
@export var stain_fade_start: float = 4.0
@export var maximum_effects: int = 80

func tier_for(energy: float, closing_speed: float, loss_fraction: float = 0.0) -> int:
	if closing_speed < 0.3 or energy < 0.15:
		return -1
	if energy >= heavy_energy:
		return 2
	if energy >= medium_energy:
		return 2 if loss_fraction >= 0.5 else 1
	return 0

static func syrup_color(kind: int) -> Color:
	return [Color("ee77b1"), Color("ffb743"), Color("98db65")][clampi(kind, 0, 2)]

class_name CandyVisualSet
extends Resource
## Cosmetic choices only; value and pickup radius belong to CandyPickup.

@export var models: Array[PackedScene] = []
@export var weights: PackedFloat32Array = PackedFloat32Array([30, 25, 20, 15, 10])
@export_range(0.0, 0.25) var size_variation: float = 0.1

func choose(unit_roll: float) -> int:
	var total: float = 0.0
	for weight: float in weights:
		total += maxf(0.0, weight)
	var remaining: float = clampf(unit_roll, 0.0, 0.999999) * total
	for index: int in range(mini(models.size(), weights.size())):
		remaining -= maxf(0.0, weights[index])
		if remaining < 0.0:
			return index
	return maxi(0, models.size() - 1)

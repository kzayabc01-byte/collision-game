class_name VehicleProfile
extends Resource

enum Kind { PONY, PUMPKIN, SLIME }

@export var kind: Kind = Kind.PONY
@export var display_name: String = "小马车"
@export_multiline var description: String = ""
@export var accent: Color = Color("ffb6d5")
@export_group("Pony")
@export var double_below: int = 40
@export_group("Pumpkin")
@export_range(0.1, 1.0) var swallow_size_ratio: float = 0.5
@export_range(1.0, 89.0) var mouth_half_angle: float = 60.0
@export_group("Slime")
@export var roll_threshold: float = 4.0
@export_range(0.0, 1.0) var rolling_damage_multiplier: float = 0.7
@export var rolling_distance_multiplier: float = 1.5
@export_range(0.0, 1.0) var rolling_turn_retention: float = 0.925

func pickup_gain(current: int, amount: int, own_drop: bool) -> int:
	var count: int = maxi(0, amount)
	if kind != Kind.PONY or own_drop or current >= double_below:
		return count
	# Split at the threshold even when many candies share one pickup node.
	var doubled: int = mini(count, ceili(float(double_below - current) / 2.0))
	return count + doubled

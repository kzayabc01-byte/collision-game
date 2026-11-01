class_name CollisionMath
extends RefCounted

static func mass_for(candy: int, tuning: GameTuning) -> float:
	return tuning.chassis_mass + tuning.mass_per_candy * maxi(0, candy)

static func scale_for(candy: int, tuning: GameTuning) -> float:
	return clampf(sqrt(float(maxi(0, candy)) / tuning.initial_candy), tuning.minimum_scale, tuning.maximum_scale)

static func wall_loss(candy: int, tuning: GameTuning) -> int:
	return floori(candy * tuning.wall_candy_fraction)

static func turn_retention(angle_radians: float, tuning: GameTuning) -> float:
	return pow(tuning.turn_retention_per_90, absf(angle_radians) / (PI * 0.5))

static func obstacle_energy(mass_value: float, velocity: Vector3, outward_normal: Vector3) -> float:
	var normal_speed: float = maxf(0.0, -velocity.dot(outward_normal))
	return 0.5 * mass_value * normal_speed * normal_speed

static func pair_result(mass_a: float, mass_b: float, velocity_a: Vector3, velocity_b: Vector3, normal: Vector3, tuning: GameTuning) -> Dictionary:
	var closing: float = maxf(0.0, (velocity_a - velocity_b).dot(normal))
	var reduced_mass: float = mass_a * mass_b / (mass_a + mass_b)
	var energy: float = 0.5 * reduced_mass * closing * closing
	var power_a: float = mass_a * pow(maxf(0.0, velocity_a.dot(normal)), 2.0)
	var power_b: float = mass_b * pow(maxf(0.0, -velocity_b.dot(normal)), 2.0)
	var total_power: float = maxf(power_a + power_b, 0.000001)
	var damage: float = tuning.damage_coefficient * energy
	return {
		"energy": energy,
		"closing": closing,
		"raw_loss_a": damage * (0.2 + 0.8 * power_b / total_power) if closing >= tuning.minimum_closing_speed else 0.0,
		"raw_loss_b": damage * (0.2 + 0.8 * power_a / total_power) if closing >= tuning.minimum_closing_speed else 0.0,
		"loss_a": roundi(damage * (0.2 + 0.8 * power_b / total_power)) if closing >= tuning.minimum_closing_speed else 0,
		"loss_b": roundi(damage * (0.2 + 0.8 * power_a / total_power)) if closing >= tuning.minimum_closing_speed else 0,
		"impulse": (1.0 + tuning.restitution) * closing * reduced_mass,
	}

static func drop_tier(loss: int, original_candy: int) -> int:
	var fraction: float = float(loss) / maxi(1, original_candy)
	if fraction >= 0.5:
		return 2
	return 1 if fraction >= 0.2 else 0

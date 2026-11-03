class_name GameTuning
extends Resource

@export_group("Driving")
@export var base_speed: float = 3.0
@export var top_speed: float = 9.0
@export var acceleration: float = 16.0
@export var high_speed_acceleration: float = 4.0
@export var fast_acceleration_fraction: float = 0.7777778
@export var reverse_speed: float = 3.5
@export var reverse_acceleration: float = 8.0
@export var direction_change_deceleration: float = 12.0
@export var normal_grip: float = 18.0
@export var drift_grip: float = 6.0
@export var drift_max_slip_degrees: float = 40.0
@export var drift_steer_grace: float = 0.22
@export var coasting_deceleration: float = 2.0
@export var acceleration_distance: float = 18.0
@export var turn_rate_degrees: float = 160.0
@export var turn_retention_per_90: float = 0.85
@export var turn_deadzone_degrees: float = 4.0
@export_group("Brake and burst")
@export var brake_deceleration: float = 8.0
@export var drift_enter_speed: float = 3.5
@export var drift_exit_speed: float = 2.5
@export var drift_drag: float = 3.0
@export var drift_turn_small: float = 1.3
@export var drift_turn_big: float = 1.15
@export var drift_retention_per_90: float = 0.82
@export var burst_min_angle_degrees: float = 45.0
@export var burst_min_drift_seconds: float = 0.18
@export var burst_min_speed_fraction: float = 0.3
@export var burst_add_small: float = 2.0
@export var burst_add_big: float = 1.2
@export var burst_seconds: float = 0.45
@export var burst_acceleration: float = 18.0
@export var burst_cap_multiplier: float = 1.05
@export var burst_commit_seconds: float = 0.18
@export var burst_steer_multiplier: float = 0.7
@export var burst_cooldown_seconds: float = 0.8
@export var burst_recovery_deceleration: float = 6.0
@export_group("Candy and growth")
@export var initial_candy: int = 20
@export var chassis_mass: float = 0.5
@export var mass_per_candy: float = 0.025
@export var minimum_scale: float = 0.5
@export var maximum_scale: float = 2.2
@export var base_collision_radius: float = 0.76
@export_group("Impact")
@export var damage_coefficient: float = 1.0
@export var minimum_closing_speed: float = 1.5
@export var pair_cooldown: float = 0.5
@export var restitution: float = 0.7
@export var wall_speed_retention: float = 0.95
@export var wall_candy_fraction: float = 0.05
@export var obstacle_break_energy: float = 22.5
@export var obstacle_reward: int = 12
@export_group("Round")
@export var round_seconds: float = 180.0
@export var respawn_seconds: float = 3.0
@export var neutral_spawn_seconds: float = 6.0
@export var neutral_spawn_amount: int = 3
@export_group("Drops")
@export var candy_lifetime: float = 8.0
@export var owner_protection_seconds: float = 0.5
@export var maximum_candy_nodes: int = 240
@export var initial_car_length: float = 1.8

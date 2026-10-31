class_name CrashObstacle
extends StaticBody3D

signal broken(obstacle: CrashObstacle)

@export var destructible: bool = false
@export var tuning: GameTuning
@export var reward_override: int = -1

var is_broken: bool = false

func can_break(energy: float) -> bool:
	return destructible and not is_broken and energy + 0.00001 >= tuning.obstacle_break_energy

func break_once() -> int:
	if not destructible or is_broken:
		return 0
	is_broken = true
	collision_layer = 0
	($BodyCollision as CollisionShape3D).set_deferred("disabled", true)
	$VisualRoot.hide()
	var particles: CPUParticles3D = get_node_or_null("BreakParticles") as CPUParticles3D
	if particles != null:
		particles.restart()
		particles.emitting = true
	broken.emit(self)
	return tuning.obstacle_reward if reward_override < 0 else reward_override

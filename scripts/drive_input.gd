class_name DriveInput
extends Node3D

# throttle: -1 reverse, +1 forward; steer: -1 left, +1 right.
func sample_controls(_position: Vector3, _context: Dictionary, _delta: float) -> Dictionary:
	return {"throttle": 0.0, "steer": 0.0, "brake": false}

func reset_driver() -> void:
	pass

func notify_progress() -> void:
	pass

func notify_encounter(_opponent_id: int) -> void:
	pass
